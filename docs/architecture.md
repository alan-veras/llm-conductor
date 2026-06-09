# Architecture

`llm-conductor` is the extracted, domain-agnostic engine from a larger personal
project. The bug-bounty domain it grew up in is stripped out; what remains is the
part worth reusing: **how to let an LLM drive a multi-stage pipeline reliably and
cheaply.**

## The problem it solves

The naive way to "let an agent run a pipeline" is to hand the model the whole
state and let it decide everything in free text. That fails three ways:

1. **Token cost explodes.** Re-reading raw stage output every turn burns context.
2. **It's non-deterministic.** The same run produces different paths; you can't
   reproduce or audit a decision.
3. **There's no brake.** A wrong step cascades through the whole run.

`llm-conductor` inverts the relationship: **the pipeline is deterministic code;
the LLM only makes the small decisions between stages.** The model reads a tiny
JSON gate and emits one command (`proceed` / `override` / `abort`). Tokens go to
judgment, not parsing.

## Execution model

```
  ┌────────────┐    conductor <cmd>     ┌─────────────────────┐
  │ LLM         │ ─────────────────────▶│ bin/conductor (bash) │
  │ conductor   │ ◀──── JSON gate ───────│  state machine       │
  └────────────┘                        └──────────┬──────────┘
                                                    ▼
                          stages: fetch → extract → analyze →
                                  summarize → review → publish
                                                    ▼
                          runs/<id>/ manifest.json + <stage>/gate.json
```

Five invariants (the whole design in five lines):

1. **Stages are idempotent and resumable.** Re-running doesn't double work; a
   failure doesn't corrupt state.
2. **Structured output is mandatory.** Every stage writes a schema-shaped gate.
3. **A gate sits between every stage.** Nothing advances without `proceed`.
4. **The manifest is the single source of truth.** Files are derived; the
   manifest is authoritative and atomically updated.
5. **The LLM spends tokens on decisions, not parsing** (`inspect --jq`).

## Gate semantics

A stage ends with one of three results:

| result | meaning | typical conductor action |
|--------|---------|--------------------------|
| `pass` | success criterion met | `proceed` without deliberation |
| `warn` | completed, but a signal merits inspection | read `warnings`, then proceed or `override` |
| `fail` | criterion not met | `abort`, or `override` and retry |

`run all` walks the stages and **stops the moment a gate is not `pass`** — that
stop is the conductor's decision point. (Try it: feed a 2-word document and watch
`analyze` warn and the run halt.)

## Token economy: `inspect --jq`

A full gate is ~300–600 bytes. In a loop that adds up, so the conductor never
reads the whole thing when it knows the field it wants:

```bash
conductor inspect analyze --jq .stats          # ~50 tokens
conductor inspect analyze --jq '.warnings[].msg'
```

In the parent project this single discipline (plus collapsing 9 spawned agents
into one conductor + two on-demand roles) cut an end-to-end run from an estimated
~315k tokens to under ~50k — roughly **-84%**. The numbers are specific to that
workload, but the lever is general: *don't pay tokens to re-parse state you can
slice.*

## Hybrid storage (and why)

Two stores, split by access pattern:

- **JSON + `flock`** for `manifest.json` and `gate.json` — document-shaped,
  edited rarely, read by humans, diff-friendly in git. Writes are atomic:
  lock → `jq` into a temp file → `mv` into place.
- **SQLite (WAL)** for cross-run metrics (`runs/_metrics.db`) — tabular,
  append-heavy, queried with aggregates ("average duration per stage across all
  runs"). Answering that from N per-run JSON files is a linear scan; an indexed
  query is O(log n).

The rule of thumb: **JSON for state you read one run at a time; SQLite for
questions that span runs.** Scripts never touch a store directly — they go
through `engine/state.sh`, `engine/gate.sh`, `engine/db.sh`, so the storage choice
can change without touching stage code.

## Schema versioning

`schema_version` is `MAJOR.MINOR`. Additive changes (a new optional field) bump
MINOR and are applied as defaults on read — no migrator. Renames, removals and
semantic breaks bump MAJOR and require a migrator. SQLite tracks `PRAGMA
user_version`. Consumers accept `manifest.schema_version <= code.expected` —
strict forward-compatibility. Version validation runs only at `init`/`status`, so
the conductor pays zero extra tokens for it mid-run.

## The three roles

The pipeline replaces what used to be many specialized agents. Only three roles
remain, and two are on-demand — see [`../agents/`](../agents/):

- **operator** — drives the console; reads gates; issues proceed/override/abort.
  Handles the overwhelming majority of steps.
- **analyst** — invoked only for an ambiguous `warn`, to give a quantitative read
  before a decision.
- **reviewer** — a final veto before an irreversible action (here: `publish`).

This is the human-in-the-loop / least-privilege idea applied to agents: narrow
scope per role, every action reviewable, nothing irreversible without a gate.

## What was removed for the public version

The original had domain stages (scope/recon/hunt/dedup/submit) and domain scoring
rules. Those are gone. What you see is the engine and one deliberately boring
example pipeline (summarize a document), so the reusable architecture stands on
its own.
