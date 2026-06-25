#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: collect_diagnostics.sh [output-directory]

Collects local project, git, Docker, port, and HTTP diagnostics into text files.
Default output directory: .hackathon-diagnostics
USAGE
  exit 0
fi

OUT="${1:-.hackathon-diagnostics}"
mkdir -p "$OUT"

run_capture() {
  local name="$1"
  shift
  {
    echo "$ $*"
    "$@" 2>&1 || true
  } > "$OUT/$name.txt"
}

echo "Collecting diagnostics in $OUT"
run_capture "pwd" pwd
run_capture "files" find . -maxdepth 3 -type f

if command -v git >/dev/null 2>&1; then
  run_capture "git-status" git status --short
fi

if command -v docker >/dev/null 2>&1; then
  run_capture "docker-version" docker version
  run_capture "docker-ps" docker ps -a
  if [[ -f docker-compose.yml || -f compose.yml ]]; then
    run_capture "docker-compose-logs" docker compose logs --tail=200
  fi
fi

if command -v lsof >/dev/null 2>&1; then
  run_capture "port-8080" lsof -i :8080
fi

if command -v curl >/dev/null 2>&1; then
  run_capture "health-localhost-8080" curl -fsS http://localhost:8080/health
  run_capture "root-localhost-8080" curl -I http://localhost:8080/
fi

echo "Diagnostics collected. Read the files in $OUT."
