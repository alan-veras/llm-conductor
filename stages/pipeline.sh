#!/usr/bin/env bash
# Example pipeline: turn a text document into a reviewed summary report.
# Entirely benign and offline — it exists to exercise the engine, not to do
# anything domain-specific. Swap these functions for your real stages.
# shellcheck shell=bash

workdir() { local d; d="$(run_dir "$1")/work"; mkdir -p "$d"; printf '%s' "$d"; }

# Each stage is a function `stage_<name> <run_id>`. It does its work, then calls
# gate_write with a result and a tiny stats object, and marks the manifest.

stage_fetch() {
  local run="$1"; local w; w="$(workdir "$run")"
  local src="${CONDUCTOR_INPUT:-$CONDUCTOR_ROOT/examples/input.txt}"
  [[ -f "$src" ]] || { gate_write "$run" fetch fail '{"error":"input not found"}'; return 1; }
  cp "$src" "$w/raw.txt"
  local bytes; bytes=$(wc -c <"$w/raw.txt")
  gate_write "$run" fetch pass "$(jq -n --argjson b "$bytes" '{bytes:$b}')" extract \
    '[]' '["conductor inspect fetch --jq .stats.bytes"]'
}

stage_extract() {
  local run="$1"; local w; w="$(workdir "$run")"
  local words paras
  words=$(wc -w <"$w/raw.txt"); paras=$(awk 'BEGIN{RS="";n=0}{n++}END{print n}' "$w/raw.txt")
  jq -n --argjson words "$words" --argjson paras "$paras" '{words:$words,paragraphs:$paras}' >"$w/extracted.json"
  gate_write "$run" extract pass "$(cat "$w/extracted.json")" analyze
}

stage_analyze() {
  local run="$1"; local w; w="$(workdir "$run")"
  local words; words=$(jq -r '.words' "$w/extracted.json")
  local top; top=$(tr '[:upper:] ' '[:lower:]\n' <"$w/raw.txt" | grep -oE '[a-z]{4,}' \
    | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  local rt; rt=$(awk -v w="$words" 'BEGIN{printf "%.1f", w/200}')   # ~200 wpm
  jq -n --arg top "$top" --argjson rt "$rt" '{top_keyword:$top, reading_time_min:$rt}' >"$w/analysis.json"
  # demonstrate a 'warn' result: thin documents are flagged for the conductor.
  local result="pass"; local warn='[]'
  if (( words < 50 )); then
    result="warn"; warn='[{"code":"THIN_DOC","msg":"document under 50 words"}]'
  fi
  gate_write "$run" analyze "$result" "$(jq -s '.[0]*.[1]' "$w/extracted.json" "$w/analysis.json")" \
    summarize "$warn"
}

stage_summarize() {
  local run="$1"; local w; w="$(workdir "$run")"
  # The "LLM" step. Deterministic stand-in: first sentence of each paragraph.
  awk 'BEGIN{RS="";FS="\n"}{ s=$0; sub(/\..*/,".",s); print s }' "$w/raw.txt" >"$w/summary.txt"
  local sw; sw=$(wc -w <"$w/summary.txt")
  # account for the token cost of the model call (instrumentation the engine
  # uses to keep a budget — here an estimate).
  state_add_tokens "$run" $(( sw * 3 ))
  gate_write "$run" summarize pass "$(jq -n --argjson sw "$sw" '{summary_words:$sw}')" review
}

stage_review() {
  local run="$1"; local w; w="$(workdir "$run")"
  local sw ow ratio
  sw=$(wc -w <"$w/summary.txt"); ow=$(jq -r '.words' "$w/extracted.json")
  ratio=$(awk -v s="$sw" -v o="$ow" 'BEGIN{ if(o==0){print 0}else{printf "%.2f", s/o} }')
  local result="pass"; local warn='[]'
  awk -v r="$ratio" 'BEGIN{exit !(r>0.9)}' && { result="warn"; warn='[{"code":"WEAK_COMPRESSION","msg":"summary barely shorter than source"}]'; }
  gate_write "$run" review "$result" "$(jq -n --argjson r "$ratio" '{compression_ratio:$r}')" publish "$warn"
}

stage_publish() {
  local run="$1"; local w; w="$(workdir "$run")"
  { echo "# Report"; echo; echo "## Summary"; echo; cat "$w/summary.txt";
    echo; echo "## Analysis"; jq -r 'to_entries[]|"- \(.key): \(.value)"' "$w/analysis.json"; } >"$w/report.md"
  gate_write "$run" publish pass "$(jq -n --arg p "work/report.md" '{output:$p}')" ""
}

# dispatcher used by bin/conductor
stage_exec() {
  local run="$1"; local stage="$2"
  local start; start=$(date +%s.%N)
  state_set_stage "$run" "$stage" status running
  if "stage_$stage" "$run"; then
    local dur; dur=$(awk -v a="$start" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
    local res; res="$(gate_result "$run" "$stage")"
    state_set_stage "$run" "$stage" status done
    state_set_stage "$run" "$stage" gate "$res"
    db_record "$run" "$stage" "$res" "$dur" 0
    return 0
  else
    state_set_stage "$run" "$stage" status failed
    db_record "$run" "$stage" fail 0 0
    return 1
  fi
}
