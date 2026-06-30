#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-hackathon-app:final}"
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
DATA_DIR="${DATA_DIR:-$PWD/data}"
CONTAINER="hackathon-smoke-$RANDOM"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: build_single_image.sh [image:tag]

Builds the final single Docker image and smoke-tests it.
Environment:
  FRONTEND_PORT=9080
  BACKEND_PORT=8090
  DATA_DIR=$PWD/data
USAGE
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not on PATH."
  exit 1
fi

if [[ ! -f Dockerfile ]]; then
  echo "Dockerfile not found in current directory."
  exit 1
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

check_port_available "$FRONTEND_PORT" "Frontend"
check_port_available "$BACKEND_PORT" "Backend"
mkdir -p "$DATA_DIR"

echo "Building $IMAGE"
docker build -t "$IMAGE" .

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting smoke test container"
docker run -d --name "$CONTAINER" -p "$FRONTEND_PORT:9080" -p "$BACKEND_PORT:8090" -v "$DATA_DIR:/app/data" "$IMAGE" >/dev/null

echo "Waiting for backend on http://localhost:$BACKEND_PORT/health and frontend on http://localhost:$FRONTEND_PORT"
for _ in $(seq 1 45); do
  if command -v curl >/dev/null 2>&1 \
    && curl -fsS "http://localhost:$BACKEND_PORT/health" >/dev/null 2>&1 \
    && curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
    echo "Frontend and backend checks passed."
    echo "Image ready: $IMAGE"
    echo "Run command: docker run --rm -p 9080:9080 -p 8090:8090 -v \"\$(pwd)/data:/app/data\" $IMAGE"
    exit 0
  fi
  sleep 2
done

echo "Smoke test failed. Recent container logs:"
docker logs --tail=200 "$CONTAINER" || true
exit 1
