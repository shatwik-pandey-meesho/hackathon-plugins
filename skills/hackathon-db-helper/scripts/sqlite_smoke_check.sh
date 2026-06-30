#!/usr/bin/env bash
set -euo pipefail

DATABASE="${SQLITE_DATABASE:-data/hackathon.db}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: sqlite_smoke_check.sh [database-file]

Checks SQLite database accessibility and lists tables.
Environment:
  SQLITE_DATABASE=data/hackathon.db
USAGE
  exit 0
fi

DATABASE="${1:-$DATABASE}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is not installed."
  exit 1
fi

if [[ ! -f "$DATABASE" ]]; then
  echo "SQLite database file not found: $DATABASE"
  echo "If this is a new project, initialize it from db/init.sql first."
  exit 1
fi

sqlite3 "$DATABASE" "SELECT 'sqlite_ok' AS status; SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
