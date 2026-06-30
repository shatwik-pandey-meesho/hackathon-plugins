#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: project_sanity_check.sh [project-root]

Checks the expected hackathon project structure and runs available frontend/backend tests.
USAGE
  exit 0
fi

ROOT="${1:-.}"
cd "$ROOT"

FAIL=0
check_path() {
  if [[ -e "$1" ]]; then
    printf "OK      %s\n" "$1"
  else
    printf "MISSING %s\n" "$1"
    FAIL=1
  fi
}

echo "Checking hackathon project shape..."
check_path "frontend"
check_path "backend"
check_path "db"
check_path "Dockerfile"

if [[ -f frontend/package.json ]]; then
  echo "OK      frontend/package.json"
elif [[ -f package.json ]]; then
  echo "OK      package.json"
else
  echo "MISSING frontend/package.json or package.json"
  FAIL=1
fi

if [[ -f db/init.sql ]]; then
  echo "OK      db/init.sql"
else
  echo "WARN    db/init.sql not found; ensure SQLite schema is initialized another way"
fi

if command -v npm >/dev/null 2>&1 && [[ -f frontend/package.json ]]; then
  (cd frontend && npm run build --if-present)
fi

if command -v go >/dev/null 2>&1 && [[ -f backend/go.mod ]]; then
  (cd backend && go test ./...)
fi

if command -v npm >/dev/null 2>&1 && [[ -f backend/package.json ]]; then
  (cd backend && npm test --if-present)
fi

exit "$FAIL"
