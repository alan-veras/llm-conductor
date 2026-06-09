# Role: analyst (on-demand)

Invoked only when a `warn` gate is ambiguous and a quantitative read is needed
before the operator decides.

**Inputs:** the gate's `stats` + `warnings`, and cross-run history via
`conductor metrics` (SQLite). 

**Output:** a short, numeric judgement ("this stage's duration is 4σ above the
30-run mean; investigate before proceed"). The analyst does **not** decide
proceed/abort — that stays with the operator.
