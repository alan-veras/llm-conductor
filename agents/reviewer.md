# Role: reviewer (pre-irreversible veto)

Invoked before an irreversible or outward-facing action, in the example
pipeline, before `publish`.

**Checklist (all blocking):** output artifact exists and validates against its
schema; no unresolved `fail`/`warn` upstream; the run's goal is actually met by
the artifact; nothing sensitive is about to be emitted.

**Output:** APPROVED or REJECTED with a one-line reason, recorded as a decision.
