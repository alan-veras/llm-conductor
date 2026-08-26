#!/usr/bin/env bash
# llm-conductor, cross-run metrics in SQLite (WAL).
# Doc-oriented state lives in JSON (manifest/gate: edited rarely, diff-friendly,
# human-readable). Tabular cross-run metrics live here, where an indexed query
# beats scanning N JSON files. Same hybrid-storage split as the original system.
# shellcheck shell=bash

DB_PATH="${DB_PATH:-$RUNS_DIR/_metrics.db}"

db_init() {
  mkdir -p "$(dirname "$DB_PATH")"
  sqlite3 "$DB_PATH" >/dev/null <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA user_version=1;
CREATE TABLE IF NOT EXISTS stage_runs (
  ts        TEXT NOT NULL,
  run_id    TEXT NOT NULL,
  stage     TEXT NOT NULL,
  result    TEXT NOT NULL,
  duration  REAL NOT NULL,
  tokens    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_stage ON stage_runs(stage);
CREATE INDEX IF NOT EXISTS idx_run ON stage_runs(run_id);
SQL
}

db_record() {
  local run="$1" stage="$2" result="$3" dur="$4" tokens="${5:-0}"
  db_init
  sqlite3 "$DB_PATH" \
    "INSERT INTO stage_runs(ts,run_id,stage,result,duration,tokens)
     VALUES('$(iso8601)','$run','$stage','$result',$dur,$tokens);"
}

# avg duration per stage across all runs, the kind of question JSON-per-run
# can't answer cheaply.
db_stage_stats() {
  db_init
  sqlite3 -json "$DB_PATH" \
    "SELECT stage, COUNT(*) n, ROUND(AVG(duration),3) avg_s,
            SUM(CASE result WHEN 'fail' THEN 1 ELSE 0 END) fails
     FROM stage_runs GROUP BY stage;"
}
