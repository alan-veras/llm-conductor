#!/usr/bin/env bash
# llm-conductor, manifest state machine.
# The manifest is the single source of truth; everything else is derived.
# Writes are atomic: flock the lockfile, jq into a tmp file, mv into place.
# shellcheck shell=bash

state_init() {
  local run_id="$1"; local goal="${2:-}"
  local mpath; mpath="$(manifest_path "$run_id")"
  [[ -e "$mpath" ]] && { echo "run already exists: $run_id" >&2; return 1; }
  mkdir -p "$(dirname "$mpath")"
  local now; now="$(iso8601)"
  local stages_json
  stages_json="$(printf '%s\n' "${STAGES_ORDERED[@]}" | jq -R . \
    | jq -s 'map({key:., value:{status:"pending"}}) | from_entries')"
  jq -n --arg sv "$SCHEMA_VERSION" --arg id "$run_id" --arg goal "$goal" \
        --arg now "$now" --argjson stages "$stages_json" '{
      schema_version: $sv, run_id: $id, goal: $goal,
      created_at: $now, updated_at: $now, active: true,
      tokens_consumed_estimate: 0,
      stages: $stages, decisions: []
    }' > "$mpath"
}

state_read() { cat "$(manifest_path "$1")"; }

# state_update <run_id> <jq_expr> [--argjson k v ...] : atomic manifest mutation
state_update() {
  local run_id="$1"; local expr="$2"; shift 2
  local mpath; mpath="$(manifest_path "$run_id")"
  local lock="$mpath.lock"; local tmp="$mpath.tmp.$$"
  [[ -f "$mpath" ]] || { echo "no manifest for run $run_id" >&2; return 1; }
  exec 9>"$lock"
  flock 9
  jq "$@" "$expr" "$mpath" > "$tmp" && mv "$tmp" "$mpath"
  local rc=$?
  flock -u 9
  return $rc
}

state_set_stage() {
  local run_id="$1"; local stage="$2"; local field="$3"; local value="$4"
  state_update "$run_id" \
    ".stages[\$s][\$f]=\$v | .updated_at=\$now" \
    --arg s "$stage" --arg f "$field" --arg v "$value" --arg now "$(iso8601)"
}

state_decision_append() {
  local run_id="$1"; local stage="$2"; local by="$3"; local result="$4"; local rationale="$5"
  state_update "$run_id" \
    '.decisions += [{stage:$s, by:$by, result:$r, rationale:$why, ts:$now}] | .updated_at=$now' \
    --arg s "$stage" --arg by "$by" --arg r "$result" --arg why "$rationale" --arg now "$(iso8601)"
}

state_add_tokens() {
  local run_id="$1"; local n="$2"
  state_update "$run_id" '.tokens_consumed_estimate += $n | .updated_at=$now' \
    --argjson n "$n" --arg now "$(iso8601)"
}

# next pending stage in order, or empty if pipeline complete
state_next_stage() {
  local run_id="$1"
  local m; m="$(state_read "$run_id")"
  for s in "${STAGES_ORDERED[@]}"; do
    local st; st="$(jq -r --arg s "$s" '.stages[$s].status' <<<"$m")"
    [[ "$st" != "done" && "$st" != "skipped" ]] && { printf '%s' "$s"; return; }
  done
}
