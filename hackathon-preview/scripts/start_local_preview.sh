#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-hackathon-app:local}"
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
DATA_DIR="${DATA_DIR:-$PWD/data}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: start_local_preview.sh

Runs the current project locally and prints the browser URL.
Environment:
  IMAGE=hackathon-app:local
  FRONTEND_PORT=9080
  BACKEND_PORT=8090
  DATA_DIR=$PWD/data
USAGE
  exit 0
fi

check_port_available() {
  local port="$1"
  local label="$2"
  if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" >/dev/null 2>&1; then
    echo "$label port $port is already being used by another program."
    echo "Close that program or move it to another port, then retry."
    exit 1
  fi
}

if command -v docker >/dev/null 2>&1 && [[ -f Dockerfile ]]; then
  check_port_available "$FRONTEND_PORT" "Frontend"
  check_port_available "$BACKEND_PORT" "Backend"
  mkdir -p "$DATA_DIR"
  echo "Building Docker image: $IMAGE"
  docker build -t "$IMAGE" .
  echo "Starting preview container:"
  echo "  Frontend: http://localhost:$FRONTEND_PORT"
  echo "  Backend:  http://localhost:$BACKEND_PORT/health"
  echo "  Data:     $DATA_DIR mounted at /app/data"
  docker run --rm -p "$FRONTEND_PORT:9080" -p "$BACKEND_PORT:8090" -v "$DATA_DIR:/app/data" "$IMAGE"
  exit 0
fi

if [[ -f docker-compose.yml || -f compose.yml ]]; then
  check_port_available "$FRONTEND_PORT" "Frontend"
  check_port_available "$BACKEND_PORT" "Backend"
  echo "Starting Docker Compose preview:"
  echo "  Frontend: http://localhost:$FRONTEND_PORT"
  echo "  Backend:  http://localhost:$BACKEND_PORT/health"
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
