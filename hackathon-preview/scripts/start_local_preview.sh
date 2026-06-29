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

npm_script_exists() {
  local dir="$1"
  local script="$2"
  (cd "$dir" && node -e "const p = require('./package.json'); process.exit(p.scripts && p.scripts['$script'] ? 0 : 1)")
}

choose_npm_script() {
  local dir="$1"
  local label="$2"
  local script="start"

  if npm_script_exists "$dir" "dev"; then
    script="dev"
  elif ! npm_script_exists "$dir" "start"; then
    echo "$label package.json does not define a dev or start script." >&2
    exit 1
  fi

  echo "$script"
}

run_npm_backend() {
  local dir="$1"
  local port="$2"
  local script
  script="$(choose_npm_script "$dir" "Backend")"
  echo "Starting Backend from $dir with npm run $script"
  (cd "$dir" && PORT="$port" BACKEND_PORT="$port" DATA_DIR="$DATA_DIR" npm run "$script")
}

run_npm_frontend() {
  local dir="$1"
  local port="$2"
  local script
  script="$(choose_npm_script "$dir" "Frontend")"
  echo "Starting Frontend from $dir with npm run $script"
  if [[ "$script" == "dev" ]]; then
    (cd "$dir" && PORT="$port" FRONTEND_PORT="$FRONTEND_PORT" BACKEND_PORT="$BACKEND_PORT" npm run "$script" -- --host 0.0.0.0 --port "$port")
  else
    (cd "$dir" && PORT="$port" FRONTEND_PORT="$FRONTEND_PORT" BACKEND_PORT="$BACKEND_PORT" npm run "$script")
  fi
}

cleanup_backend() {
  if [[ -n "${BACKEND_PID:-}" ]] && kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
    kill "$BACKEND_PID" >/dev/null 2>&1 || true
  fi
}

start_node_backend() {
  echo "Installing backend dependencies..."
  (cd backend && npm install)
  run_npm_backend "backend" "$BACKEND_PORT" &
  BACKEND_PID="$!"
  trap cleanup_backend EXIT
  sleep 2
  if ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
    echo "Backend stopped before the frontend could start."
    wait "$BACKEND_PID" || true
    exit 1
  fi
}

start_go_backend() {
  echo "Starting Go backend from backend"
  (cd backend && PORT="$BACKEND_PORT" BACKEND_PORT="$BACKEND_PORT" DATA_DIR="$DATA_DIR" go run .) &
  BACKEND_PID="$!"
  trap cleanup_backend EXIT
  sleep 2
  if ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
    echo "Backend stopped before the frontend could start."
    wait "$BACKEND_PID" || true
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

if command -v docker >/dev/null 2>&1 && [[ -f docker-compose.yml || -f compose.yml ]]; then
  check_port_available "$FRONTEND_PORT" "Frontend"
  check_port_available "$BACKEND_PORT" "Backend"
  echo "Starting Docker Compose preview:"
  echo "  Frontend: http://localhost:$FRONTEND_PORT"
  echo "  Backend:  http://localhost:$BACKEND_PORT/health"
  docker compose up --build
  exit 0
fi

if [[ -f frontend/package.json ]] && [[ -f backend/package.json || -f backend/go.mod ]] && command -v npm >/dev/null 2>&1; then
  check_port_available "$FRONTEND_PORT" "Frontend"
  check_port_available "$BACKEND_PORT" "Backend"
  mkdir -p "$DATA_DIR"
  echo "Starting source preview:"
  echo "  Frontend: http://localhost:$FRONTEND_PORT"
  echo "  Backend:  http://localhost:$BACKEND_PORT/health"
  echo "  Data:     $DATA_DIR"
  if [[ -f backend/package.json ]]; then
    start_node_backend
  elif command -v go >/dev/null 2>&1; then
    start_go_backend
  else
    echo "backend/go.mod exists, but Go is not installed or not on PATH."
    exit 1
  fi
  echo "Installing frontend dependencies..."
  (cd frontend && npm install)
  run_npm_frontend "frontend" "$FRONTEND_PORT"
  exit 0
fi

if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
  echo "Starting npm preview. Check the terminal output for the URL."
  npm install
  npm run dev --if-present
  exit 0
fi

echo "Could not find a Dockerfile, Compose file, root npm project, or frontend/ plus backend/ project to preview."
exit 1
