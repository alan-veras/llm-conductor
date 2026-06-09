#!/usr/bin/env bash
# llm-conductor — gate.json protocol.
# A gate is the small, structured artifact the LLM-conductor reads to decide the
# next move. Keep it tiny: the conductor spends tokens on decisions, not parsing.
# shellcheck shell=bash

gate_path() { printf '%s/%s/gate.json' "$(run_dir "$1")" "$2"; }

# gate_write <run> <stage> <result pass|warn|fail> <stats_json> [next] [warnings_json] [hints_json] [duration]
gate_write() {
  local run="$1" stage="$2" result="$3"
  local stats="${4:-}" next="${5:-}" warnings="${6:-}" hints="${7:-}" dur="${8:-0}"
  [[ -z "$stats" ]] && stats='{}'
  [[ -z "$warnings" ]] && warnings='[]'
  [[ -z "$hints" ]] && hints='[]'
  local gpath; gpath="$(gate_path "$run" "$stage")"
  mkdir -p "$(dirname "$gpath")"
  jq -n --arg sv "$SCHEMA_VERSION" --arg stage "$stage" --arg run "$run" \
        --arg result "$result" --arg now "$(iso8601)" --arg next "$next" \
        --argjson dur "$dur" --argjson stats "$stats" \
        --argjson warnings "$warnings" --argjson hints "$hints" '{
      schema_version:$sv, stage:$stage, run_id:$run, result:$result,
      ended_at:$now, duration_seconds:$dur,
      next_recommended:(if $next=="" then null else $next end),
      stats:$stats, warnings:$warnings, inspect_hints:$hints
    }' > "$gpath"
}

gate_read()   { cat "$(gate_path "$1" "$2")" 2>/dev/null; }
gate_result() { gate_read "$1" "$2" | jq -r '.result // "unknown"' 2>/dev/null; }
