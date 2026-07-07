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
# Deployment supports only linux/amd64. Force it so Apple Silicon / ARM hosts
# never produce an arm64 image that fails at judging.
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build --platform linux/amd64 -t "$IMAGE" .

BUILT_ARCH="$(docker image inspect "$IMAGE" --format '{{.Os}}/{{.Architecture}}' 2>/dev/null || true)"
if [[ "$BUILT_ARCH" != "linux/amd64" ]]; then
  echo "Built image platform is '$BUILT_ARCH', but deployment requires 'linux/amd64'."
  echo "Ensure your Docker engine supports amd64 emulation (e.g. Docker Desktop on macOS) and retry."
  exit 1
fi
echo "Verified image platform: linux/amd64"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting smoke test container"
docker run -d --platform linux/amd64 --name "$CONTAINER" -p "$FRONTEND_PORT:9080" -p "$BACKEND_PORT:8090" -v "$DATA_DIR:/app/data" "$IMAGE" >/dev/null

echo "Waiting for frontend on http://localhost:$FRONTEND_PORT/ and backend via nginx on http://localhost:$FRONTEND_PORT/api/health"
for _ in $(seq 1 45); do
  if command -v curl >/dev/null 2>&1 \
    && curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1 \
    && curl -fsS "http://localhost:$FRONTEND_PORT/api/health" >/dev/null 2>&1; then
    echo "Frontend and backend-through-nginx (/api) checks passed."
    echo "Image ready: $IMAGE"
    echo "Run command: docker run --rm --platform linux/amd64 -p 9080:9080 -p 8090:8090 -v \"\$(pwd)/data:/app/data\" $IMAGE"
    exit 0
  fi
  sleep 2
done

echo "Smoke test failed. Recent container logs:"
docker logs --tail=200 "$CONTAINER" || true
exit 1
