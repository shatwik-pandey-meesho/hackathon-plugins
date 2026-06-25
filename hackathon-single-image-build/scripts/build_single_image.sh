#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-hackathon-app:final}"
PORT="${PORT:-8080}"
CONTAINER="hackathon-smoke-$RANDOM"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: build_single_image.sh [image:tag]

Builds the final single Docker image and smoke-tests it.
Environment:
  PORT=8080
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

echo "Building $IMAGE"
docker build -t "$IMAGE" .

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting smoke test container"
docker run -d --name "$CONTAINER" -p "$PORT:8080" "$IMAGE" >/dev/null

echo "Waiting for app on http://localhost:$PORT"
for _ in $(seq 1 45); do
  if command -v curl >/dev/null 2>&1 && curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "Health check passed."
    echo "Image ready: $IMAGE"
    echo "Run command: docker run --rm -p 8080:8080 $IMAGE"
    exit 0
  fi
  if command -v curl >/dev/null 2>&1 && curl -fsS "http://localhost:$PORT/" >/dev/null 2>&1; then
    echo "Root page responded."
    echo "Image ready: $IMAGE"
    echo "Run command: docker run --rm -p 8080:8080 $IMAGE"
    exit 0
  fi
  sleep 2
done

echo "Smoke test failed. Recent container logs:"
docker logs --tail=200 "$CONTAINER" || true
exit 1
