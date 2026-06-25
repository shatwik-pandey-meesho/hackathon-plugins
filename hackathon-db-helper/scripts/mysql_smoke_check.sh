#!/usr/bin/env bash
set -euo pipefail

HOST="${MYSQL_HOST:-127.0.0.1}"
PORT="${MYSQL_PORT:-3306}"
USER="${MYSQL_USER:-root}"
PASSWORD="${MYSQL_PASSWORD:-root}"
DATABASE="${MYSQL_DATABASE:-hackathon_app}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: mysql_smoke_check.sh

Checks MySQL connectivity and lists tables.
Environment:
  MYSQL_HOST=127.0.0.1
  MYSQL_PORT=3306
  MYSQL_USER=root
  MYSQL_PASSWORD=root
  MYSQL_DATABASE=hackathon_app
USAGE
  exit 0
fi

if ! command -v mysql >/dev/null 2>&1; then
  echo "mysql client is not installed."
  exit 1
fi

mysql --host="$HOST" --port="$PORT" --user="$USER" --password="$PASSWORD" \
  --database="$DATABASE" \
  --execute="SELECT 'mysql_ok' AS status; SHOW TABLES;"
