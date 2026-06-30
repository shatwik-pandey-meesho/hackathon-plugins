#!/usr/bin/env bash
set -euo pipefail

PROXY_HOST=""
LOGIN_USER="hackathon"
TOKEN=""
LOCAL_IMAGE=""
USER_SLUG=""
TAG="final"
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
DATA_DIR="${DATA_DIR:-}"
SKIP_SMOKE="false"

usage() {
  cat <<'USAGE'
Usage: push_to_proxy_registry.sh --proxy-host HOST --token TOKEN --local-image IMAGE [options]

Logs in to a token-authenticated Docker proxy, verifies the local image starts,
tags it as HOST/USER/USER:TAG, and pushes it.

Required:
  --proxy-host HOST       Proxy registry host, for example hackathon-proxy-xxxxx.run.app
  --token TOKEN           Registry token or password. Can also use HACKATHON_PROXY_TOKEN.
  --local-image IMAGE     Existing local image to push, for example hackathon-app:final
  --user SLUG             Identity slug for the image path. Pass the part of the participant's
                          Meesho email before @ (for example priya.sharma). A full email is
                          accepted and the part before @ is used. Can also use MEESHO_EMAIL.

Options:
  --login-user USER       Docker login username. Default: hackathon
  --tag TAG               Final image tag. Default: final
  --data-dir DIR          Optional host data dir to mount to /app/data during smoke test.
                          Final images should normally pass without this.
  --skip-smoke            Skip local container health check. Use only if already checked.
  -h, --help              Show this help text.

Final image URL:
  HOST/USER/USER:TAG

Example:
  HACKATHON_PROXY_TOKEN=hackathon2026 \
    ./scripts/push_to_proxy_registry.sh \
      --proxy-host hackathon-proxy-xxxxx.run.app \
      --login-user hackathon \
      --local-image hackathon-app:final \
      --user priya.sharma \
      --tag v1
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --proxy-host)
      PROXY_HOST="${2:-}"
      shift 2
      ;;
    --login-user)
      LOGIN_USER="${2:-}"
      shift 2
      ;;
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --local-image)
      LOCAL_IMAGE="${2:-}"
      shift 2
      ;;
    --user)
      USER_SLUG="${2:-}"
      shift 2
      ;;
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --data-dir)
      DATA_DIR="${2:-}"
      shift 2
      ;;
    --skip-smoke)
      SKIP_SMOKE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$TOKEN" ]] || TOKEN="${HACKATHON_PROXY_TOKEN:-}"
[[ -n "$PROXY_HOST" ]] || fail "--proxy-host is required."
[[ -n "$TOKEN" ]] || fail "--token is required, or set HACKATHON_PROXY_TOKEN."
[[ -n "$LOCAL_IMAGE" ]] || fail "--local-image is required."
[[ -n "$LOGIN_USER" ]] || fail "--login-user cannot be empty."
[[ -n "$TAG" ]] || fail "--tag cannot be empty."

need_cmd docker || fail "Docker is not installed or not on PATH."
need_cmd curl || fail "curl is required for the local health check."
docker info >/dev/null 2>&1 \
  || fail "Docker is installed, but the Docker daemon is not reachable. Start Docker Desktop or fix Docker permissions, then retry."

PROXY_HOST="${PROXY_HOST#http://}"
PROXY_HOST="${PROXY_HOST#https://}"
PROXY_HOST="${PROXY_HOST%/}"
[[ "$PROXY_HOST" != */* ]] || fail "--proxy-host must be only the registry host, without a path."

[[ -n "$USER_SLUG" ]] || USER_SLUG="${MEESHO_EMAIL:-}"
[[ -n "$USER_SLUG" ]] || fail "Could not determine the identity slug. Pass --user (the Meesho email name before @), or set MEESHO_EMAIL."

# Accept a full email and use the part before @; then lowercase for Docker.
USER_SLUG="${USER_SLUG%%@*}"
IMAGE_NAMESPACE="$(echo "$USER_SLUG" | tr '[:upper:]' '[:lower:]')"
IMAGE_NAME="$IMAGE_NAMESPACE"

if [[ ! "$IMAGE_NAMESPACE" =~ ^[a-z0-9]+([._-][a-z0-9]+)*$ ]]; then
  fail "Identity '$USER_SLUG' becomes invalid Docker path '$IMAGE_NAMESPACE'. Pass a Docker-safe --user."
fi
if [[ ! "$TAG" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  fail "Invalid Docker tag '$TAG'. Use letters, numbers, underscores, dots, or dashes."
fi

docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1 \
  || fail "Local image '$LOCAL_IMAGE' does not exist. Build it before pushing."

check_port_available() {
  local port="$1"
  local label="$2"
  if need_cmd lsof && lsof -i ":$port" >/dev/null 2>&1; then
    fail "$label port $port is already being used. Close that program or set FRONTEND_PORT/BACKEND_PORT to free ports."
  fi
}

smoke_test_image() {
  local container="hackathon-proxy-smoke-$RANDOM"
  local run_args=(-d --name "$container" -p "$FRONTEND_PORT:9080" -p "$BACKEND_PORT:8090")

  if [[ -n "$DATA_DIR" ]]; then
    mkdir -p "$DATA_DIR"
    run_args+=(-v "$DATA_DIR:/app/data")
  fi

  cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
  }
  trap cleanup RETURN

  docker run "${run_args[@]}" "$LOCAL_IMAGE" >/dev/null \
    || fail "Local smoke test container failed to start."

  for _ in $(seq 1 45); do
    if curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1 \
      && curl -fsS "http://localhost:$FRONTEND_PORT/api/health" >/dev/null 2>&1; then
      echo "Local image health check passed (frontend and backend via nginx /api)."
      return 0
    fi
    sleep 2
  done

  echo "Local smoke test failed. Recent container logs:" >&2
  docker logs --tail=200 "$container" >&2 || true
  return 1
}

if [[ "$SKIP_SMOKE" != "true" ]]; then
  check_port_available "$FRONTEND_PORT" "Frontend"
  check_port_available "$BACKEND_PORT" "Backend"
  smoke_test_image
else
  echo "Skipping local smoke test because --skip-smoke was provided."
fi

FINAL_URL="$PROXY_HOST/$IMAGE_NAMESPACE/$IMAGE_NAME:$TAG"

echo "Logging in to $PROXY_HOST as $LOGIN_USER"
printf "%s" "$TOKEN" | docker login "$PROXY_HOST" --username "$LOGIN_USER" --password-stdin >/dev/null

docker tag "$LOCAL_IMAGE" "$FINAL_URL"
docker push "$FINAL_URL"

echo "Final image URL:"
echo "$FINAL_URL"
