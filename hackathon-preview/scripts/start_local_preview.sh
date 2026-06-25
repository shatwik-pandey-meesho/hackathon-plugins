#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-hackathon-app:local}"
PORT="${PORT:-8080}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: start_local_preview.sh

Runs the current project locally and prints the browser URL.
Environment:
  IMAGE=hackathon-app:local
  PORT=8080
USAGE
  exit 0
fi

if command -v docker >/dev/null 2>&1 && [[ -f Dockerfile ]]; then
  echo "Building Docker image: $IMAGE"
  docker build -t "$IMAGE" .
  echo "Starting preview container on http://localhost:$PORT"
  docker run --rm -p "$PORT:8080" "$IMAGE"
  exit 0
fi

if [[ -f docker-compose.yml || -f compose.yml ]]; then
  echo "Starting Docker Compose preview on http://localhost:$PORT"
  docker compose up --build
  exit 0
fi

if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
  echo "Starting npm preview. Check the terminal output for the URL."
  npm install
  npm run dev --if-present
  exit 0
fi

echo "Could not find a Dockerfile, Compose file, or npm project to preview."
exit 1
