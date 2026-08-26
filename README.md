# llm-conductor

> A deterministic, schema-validated **multi-stage pipeline that an LLM drives**, 
> via a tiny CLI and small JSON gates. Stages are idempotent and resumable, state
> is atomic, and the conductor spends tokens on *decisions*, not on parsing.
> Extracted and genericized from a larger personal project; ships with a benign
> example pipeline.

[![ci](https://img.shields.io/badge/CI-passing-brightgreen)](.github/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey)](LICENSE)

## The idea

Letting an agent "run a pipeline" by handing it all the state in free text is
expensive, non-deterministic and brakeless. `llm-conductor` flips it: **the
pipeline is deterministic code; the LLM only makes the small decisions between
stages.** Each stage does one thing, writes a tiny structured gate, and stops. A
conductor (model or human) reads the gate and issues one command, `proceed`,
`override`, or `abort`. Nothing advances on its own.

Full design notes: **[docs/architecture.md](docs/architecture.md)**.

## What I built

- A single-file CLI (`bin/conductor`) over a small engine: atomic manifest state
  machine (`flock` + `jq` + temp-file `mv`), a `gate.json` protocol, and a
  hybrid store, **JSON** for per-run state, **SQLite (WAL)** for cross-run
  metrics.
- A `--jq` inspection path so the conductor reads a 50-token slice instead of the
  whole gate, the token-economy lever that cut the parent project's run cost by
  an estimated ~84% (workload-specific; the lever is general).
- JSON Schemas for the manifest and gate, a `MAJOR.MINOR` versioning policy, and
  three lean roles (operator / analyst / reviewer), least-privilege and
  human-in-the-loop applied to agents.
- A deliberately boring example pipeline (summarize a document) so the
  architecture stands on its own, plus a pure-bash test suite.

## What I learned

- The cheapest reliability win is an explicit **gate** between stages: the cost
  of a wrong step becomes one stage, not the whole run.
- **Storage should follow the access pattern**: don't scan N JSON files to answer
  a cross-run question, that's what the SQLite half is for. And don't put
  rarely-edited, human-read state in a database, that's what JSON is for.
- Token budget is an architecture concern, not an afterthought. `inspect --jq`
  and collapsing many agents into one conductor did more than any prompt tweak.

## Run it

```bash
# deps: bash, jq, sqlite3, flock (util-linux)
make demo      # init a run, execute all stages, print status

# or step through as the conductor would:
./bin/conductor init r1 --goal "summarize a document"
./bin/conductor run all r1
./bin/conductor inspect analyze r1 --jq .stats
./bin/conductor metrics            # cross-run stats from SQLite

make test      # smoke + schema tests (14 checks)
```

Watch the brake work, feed a 2-word document and the `analyze` gate returns
`warn`, and `run all` stops for a decision instead of charging ahead.

## Layout

```
bin/conductor        the CLI
engine/              state machine, gate protocol, sqlite metrics (the engine)
stages/pipeline.sh   the example pipeline (swap this for your domain)
schemas/             manifest + gate JSON Schemas
agents/              operator / analyst / reviewer role definitions
docs/architecture.md the design writeup
tests/               pure-bash smoke + schema tests
```

## License

CC BY-NC-SA 4.0, share and adapt freely with attribution; non-commercial; derivatives under the same license. See [LICENSE](LICENSE).
