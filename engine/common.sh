#!/usr/bin/env bash
# llm-conductor, shared helpers
# shellcheck shell=bash

: "${CONDUCTOR_ROOT:?CONDUCTOR_ROOT must be set}"
RUNS_DIR="${RUNS_DIR:-$CONDUCTOR_ROOT/runs}"
SCHEMA_VERSION="1.0"

# Ordered stages of the example pipeline. A real deployment swaps this list and
# the matching scripts in stages/, the engine is domain-agnostic.
STAGES_ORDERED=(fetch extract analyze summarize review publish)

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }

iso8601() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

current_run_path() { printf '%s/_current' "$RUNS_DIR"; }

resolve_run() {
  # explicit arg wins; else the _current pointer (a hint, not a lock).
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then printf '%s' "$explicit"; return; fi
  local cp; cp="$(current_run_path)"
  [[ -f "$cp" ]] && cat "$cp" || { echo "no current run; pass <run-id> or 'conductor init'" >&2; return 1; }
}

run_dir() { printf '%s/%s' "$RUNS_DIR" "$1"; }
manifest_path() { printf '%s/manifest.json' "$(run_dir "$1")"; }
