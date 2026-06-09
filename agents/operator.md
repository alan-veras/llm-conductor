# Role: operator

The operator drives the pipeline from the console and handles the vast majority
of steps. It does **not** improvise work the pipeline already does — it reads
gates and decides the next move.

**Loop:** `status` → `inspect <stage> --jq <field>` → `proceed | override | abort`.

**Rules**
- Always `inspect --jq <field>` when you know the field — never read the whole gate.
- On `gate=pass`, `proceed`. Do not deliberate.
- On `gate=warn`, read `.warnings`; escalate to the *analyst* only if non-trivial.
- Never advance past a non-`pass` gate without recording a decision (override/abort).
- Never run a step the pipeline covers as a stage.
