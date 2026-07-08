#!/usr/bin/env bash
set -euo pipefail

PROXY_HOST="registry.buildathon.meesho.dev"
LOGIN_USER="hackathon"
TOKEN=""
LOCAL_IMAGE=""
USER_SLUG=""
TAG=""
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
DATA_DIR="${DATA_DIR:-}"
SKIP_SMOKE="false"

usage() {
  cat <<'USAGE'
Usage: push_to_proxy_registry.sh --token TOKEN --local-image IMAGE [options]

Logs in to a token-authenticated Docker proxy, verifies the local image starts,
tags it as HOST/TEAM_ID:TAG, and pushes it.

Required:
  --token TOKEN           Registry token or password. Can also use HACKATHON_PROXY_TOKEN.
  --local-image IMAGE     Existing local image to push, for example hackathon-app:final
  --user EMAIL            Participant's Meesho email. Can also use MEESHO_EMAIL.

Options:
  --proxy-host HOST       Proxy registry host. Default: registry.buildathon.meesho.dev
  --login-user USER       Docker login username. Default: hackathon
  --tag TAG               Final image tag. Default: UTC timestamp, e.g. 20260701-053012
  --data-dir DIR          Optional host data dir to mount to /app/data during smoke test.
                          Final images should normally pass without this.
  --skip-smoke            Skip local container health check. Use only if already checked.
  -h, --help              Show this help text.

Final image URL:
  HOST/TEAM_ID:TAG

Example:
  HACKATHON_PROXY_TOKEN=hackathon2026 \
    ./scripts/push_to_proxy_registry.sh \
      --login-user hackathon \
      --local-image hackathon-app:final \
      --user priya.sharma@meesho.com
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
[[ -n "$TOKEN" ]] || fail "--token is required, or set HACKATHON_PROXY_TOKEN."
[[ -n "$LOCAL_IMAGE" ]] || fail "--local-image is required."
[[ -n "$LOGIN_USER" ]] || fail "--login-user cannot be empty."
[[ -n "$TAG" ]] || TAG="$(date -u +%Y%m%d-%H%M%S)"

need_cmd docker || fail "Docker is not installed or not on PATH. Install Docker Desktop, then retry."
need_cmd curl || fail "curl is required for the local health check."
docker info >/dev/null 2>&1 \
  || fail "Docker is installed, but the Docker daemon is not reachable. Start Docker Desktop or fix Docker permissions, then retry."

PROXY_HOST="${PROXY_HOST#http://}"
PROXY_HOST="${PROXY_HOST#https://}"
PROXY_HOST="${PROXY_HOST%/}"
[[ "$PROXY_HOST" != */* ]] || fail "--proxy-host must be only the registry host, without a path."

[[ -n "$USER_SLUG" ]] || USER_SLUG="${MEESHO_EMAIL:-}"
if [[ -z "$USER_SLUG" && -f ".agent-memory/state.json" ]] && command -v python3 >/dev/null 2>&1; then
  USER_SLUG="$(python3 - <<'PY'
import json

try:
    with open(".agent-memory/state.json", "r", encoding="utf-8") as fh:
        state = json.load(fh)
    print(state.get("participant_email") or state.get("team_id") or "")
except Exception:
    print("")
PY
)"
fi
[[ -n "$USER_SLUG" ]] || fail "Could not determine the participant email. Pass --user, or set MEESHO_EMAIL."

slugify_team_id() {
  local raw="$1"
  local prefix="${raw%%@*}"
  printf "%s" "$prefix" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//'
}

TEAM_ID="$(slugify_team_id "$USER_SLUG")"

if [[ -z "$TEAM_ID" || ! "$TEAM_ID" =~ ^[a-z0-9] || ! "$TEAM_ID" =~ [a-z0-9]$ || ! "$TEAM_ID" =~ ^[a-z0-9_-]+$ ]]; then
  fail "Email '$USER_SLUG' becomes invalid team id '$TEAM_ID'. Use a Meesho email with letters or numbers before @."
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

FINAL_URL="$PROXY_HOST/$TEAM_ID:$TAG"

echo "Logging in to $PROXY_HOST as $LOGIN_USER"
# Use --password (not --password-stdin): the token is only valid from the office IP, so CLI
# exposure is not a concern, and this avoids stdin-piping quirks (notably on Windows). Docker
# may print an insecure-password warning; that is expected. The token itself is never echoed.
docker login "$PROXY_HOST" --username "$LOGIN_USER" --password "$TOKEN" >/dev/null 2>&1 \
  || fail "Docker login failed. Re-check the token, username ($LOGIN_USER), and proxy host ($PROXY_HOST)."

docker tag "$LOCAL_IMAGE" "$FINAL_URL"
docker push "$FINAL_URL"

update_agent_memory() {
  local memory_dir=".agent-memory"
  local state_path="$memory_dir/state.json"
  [[ -f "$state_path" ]] || return 0

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$state_path" "$USER_SLUG" "$TEAM_ID" "$PROXY_HOST" "$LOGIN_USER" "$FINAL_URL" "$TAG" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, email, team_id, host, login_user, final_url, tag = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
data.update({
    "participant_email": email,
    "team_id": team_id,
    "registry_proxy_host": host,
    "registry_login_user": login_user,
    "registry_url": final_url,
    "last_pushed_image": final_url,
    "last_pushed_tag": tag,
    "last_successful_step": "pushed image through registry proxy",
    "current_status": "image pushed",
    "current_blocker": "",
    "next_action": "run final submission check",
    "last_updated": datetime.now(timezone.utc).isoformat(),
})
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
  fi

  {
    printf "\n## %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "Pushed final image for team_id %s to %s.\n" "$TEAM_ID" "$FINAL_URL"
  } >> "$memory_dir/activity.md"
}

update_agent_memory

echo "Final image URL:"
echo "$FINAL_URL"
