#!/usr/bin/env bash
# llm-conductor smoke + schema tests. Pure bash; no test framework needed.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export CONDUCTOR_ROOT="$PWD"
export RUNS_DIR="$PWD/runs_test"
CONDUCTOR="./bin/conductor"
source engine/common.sh; source engine/gate.sh
pass=0; fail=0
ok()  { echo "  ok   - $1"; pass=$((pass+1)); }
bad() { echo "  FAIL - $1"; fail=$((fail+1)); }
assert_eq() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (got '$2' want '$3')"; fi; }
assert_true() { if "${@:2}"; then ok "$1"; else bad "$1"; fi; }

rm -rf "$RUNS_DIR"

echo "[1] full pipeline reaches all gates=pass"
$CONDUCTOR init t1 >/dev/null
$CONDUCTOR run all t1 >/dev/null
for s in fetch extract analyze summarize review publish; do
  assert_eq "gate $s == pass" "$(gate_result t1 "$s")" pass
done
assert_true "report.md produced" test -f "$RUNS_DIR/t1/work/report.md"
toks=$(jq '.tokens_consumed_estimate' "$RUNS_DIR/t1/manifest.json")
assert_true "tokens instrumented (>0)" test "$toks" -gt 0

echo "[2] thin document warns and 'run all' stops for a decision"
printf 'Too short.\n' > "$RUNS_DIR/tiny.txt"
CONDUCTOR_INPUT="$RUNS_DIR/tiny.txt" $CONDUCTOR init t2 >/dev/null
out="$(CONDUCTOR_INPUT="$RUNS_DIR/tiny.txt" $CONDUCTOR run all t2)"
assert_eq "analyze gate == warn" "$(gate_result t2 analyze)" warn
if grep -q 'stopping for conductor decision' <<<"$out"; then ok "pipeline stopped on warn"; else bad "pipeline stopped on warn"; fi

echo "[3] override records a decision; abort closes the run"
$CONDUCTOR override summarize --patch '{"note":"manual tweak"}' t2 >/dev/null
nd=$(jq '[.decisions[]|select(.result=="override")]|length' "$RUNS_DIR/t2/manifest.json")
assert_true "decision recorded" test "$nd" -ge 1
$CONDUCTOR abort t2 --reason "demo" >/dev/null
assert_eq "run marked inactive" "$(jq -r '.active' "$RUNS_DIR/t2/manifest.json")" false

echo "[4] artifacts validate against JSON schemas"
if python3 -c 'import jsonschema' 2>/dev/null; then
  validate() { python3 - "$1" "$2" <<'PY'
import json,sys,jsonschema
jsonschema.validate(json.load(open(sys.argv[2])), json.load(open(sys.argv[1])))
PY
  }
  if validate schemas/manifest.json "$RUNS_DIR/t1/manifest.json"; then ok "manifest matches schema"; else bad "manifest schema"; fi
  if validate schemas/gate.json "$RUNS_DIR/t1/analyze/gate.json"; then ok "gate matches schema"; else bad "gate schema"; fi
else
  echo "  (jsonschema not installed, jq structural fallback)"
  if jq -e '.run_id and .stages' "$RUNS_DIR/t1/manifest.json" >/dev/null; then ok "manifest has run_id+stages"; else bad "manifest structure"; fi
  if jq -e '.result and .stats' "$RUNS_DIR/t1/analyze/gate.json" >/dev/null; then ok "gate has result+stats"; else bad "gate structure"; fi
fi

rm -rf "$RUNS_DIR"
echo "----------------------------------------"
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
