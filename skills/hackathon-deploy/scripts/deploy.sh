#!/usr/bin/env bash
set -euo pipefail

# Combined hackathon deploy for macOS/Linux.
# Runs, in order: build the linux/amd64 single image + smoke test, readiness checks,
# zip the source for manual upload, and push through the organizer Docker proxy.
# Then prints the go-live instructions for https://buildathon.ltl.sh.
#
# Reuses the existing skill scripts as the single source of truth for build/zip/push.

IMAGE="hackathon-app:final"
ZIP_NAME=""
USER_EMAIL="${MEESHO_EMAIL:-}"
TOKEN="${HACKATHON_PROXY_TOKEN:-}"
TAG=""
PROXY_HOST="registry.buildathon.ltl.sh"
LOGIN_USER="hackathon"
SKIP_ZIP="false"
SKIP_PUSH="false"
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
LIVE_URL="https://buildathon.ltl.sh"

usage() {
  cat <<'USAGE'
Usage: deploy.sh [options]

One-shot deploy: build the linux/amd64 single image, run readiness checks, zip the
source, and push through the organizer proxy. Then follow the printed go-live steps.

Options:
  --user EMAIL        Meesho org email (derives the image team id). Or set MEESHO_EMAIL.
  --token TOKEN       Registry token. Prefer setting HACKATHON_PROXY_TOKEN instead so it
                      is not stored in shell history. Prompted for if a terminal is attached.
  --image IMAGE       Local image tag to build/push. Default: hackathon-app:final
  --name NAME         Base name for the source zip. Default: project folder name.
  --tag TAG           Pushed image tag. Default: UTC timestamp.
  --proxy-host HOST   Proxy registry host. Default: registry.buildathon.ltl.sh
  --login-user USER   Docker login username. Default: hackathon
  --skip-zip          Skip building the source zip.
  --skip-push         Build and check only; do not log in or push.
  -h, --help          Show this help.

Environment: HACKATHON_PROXY_TOKEN, MEESHO_EMAIL, FRONTEND_PORT (9080), BACKEND_PORT (8090)
USAGE
}

fail() { echo "ERROR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) USER_EMAIL="${2:-}"; shift 2 ;;
    --token) TOKEN="${2:-}"; shift 2 ;;
    --image) IMAGE="${2:-}"; shift 2 ;;
    --name) ZIP_NAME="${2:-}"; shift 2 ;;
    --tag) TAG="${2:-}"; shift 2 ;;
    --proxy-host) PROXY_HOST="${2:-}"; shift 2 ;;
    --login-user) LOGIN_USER="${2:-}"; shift 2 ;;
    --skip-zip) SKIP_ZIP="true"; shift ;;
    --skip-push) SKIP_PUSH="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_SCRIPT="$SKILLS_ROOT/hackathon-single-image-build/scripts/build_single_image.sh"
ZIP_SCRIPT="$SKILLS_ROOT/hackathon-zip-code/scripts/make_code_zip.sh"
PUSH_SCRIPT="$SKILLS_ROOT/hackathon-deploy-by-pushing-image/scripts/push_to_proxy_registry.sh"

for s in "$BUILD_SCRIPT" "$ZIP_SCRIPT" "$PUSH_SCRIPT"; do
  [[ -f "$s" ]] || fail "Required helper script not found: $s"
done

need_cmd docker || fail "Docker is not installed or not on PATH."
docker info >/dev/null 2>&1 \
  || fail "Docker is installed, but the daemon is not reachable. Start Docker Desktop, then retry."
[[ -f Dockerfile ]] || fail "Dockerfile not found in current directory. Package your app first, then deploy."

# ---------------------------------------------------------------------------
echo "==> Step 1/4  Build the linux/amd64 single image and smoke-test it"
FRONTEND_PORT="$FRONTEND_PORT" BACKEND_PORT="$BACKEND_PORT" bash "$BUILD_SCRIPT" "$IMAGE"

# ---------------------------------------------------------------------------
echo ""
echo "==> Step 2/4  Readiness checks"

if [[ -f README.md ]]; then
  echo "PASS  README.md present"
else
  echo "WARN  README.md missing (recommended for judges)"
fi

if grep -RInE '(BEGIN (RSA|OPENSSH) PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|password *= *[^ ]+)' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=data --exclude-dir=dist \
    . >/dev/null 2>&1; then
  fail "Possible secret content found in project files. Remove it before deploying."
fi
echo "PASS  no obvious secret content"

echo "Verifying the image runs standalone (no bind mount, as judges will run it)"
if need_cmd lsof; then
  lsof -i ":$FRONTEND_PORT" >/dev/null 2>&1 && fail "Port $FRONTEND_PORT is busy. Free it, then retry."
  lsof -i ":$BACKEND_PORT" >/dev/null 2>&1 && fail "Port $BACKEND_PORT is busy. Free it, then retry."
fi
STANDALONE="deploy-standalone-$RANDOM"
docker run -d --platform linux/amd64 --name "$STANDALONE" \
  -p "$FRONTEND_PORT:9080" -p "$BACKEND_PORT:8090" "$IMAGE" >/dev/null \
  || fail "Standalone container failed to start."
trap 'docker rm -f "$STANDALONE" >/dev/null 2>&1 || true' EXIT

STANDALONE_OK="false"
for _ in $(seq 1 45); do
  if need_cmd curl \
    && curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1 \
    && curl -fsS "http://localhost:$FRONTEND_PORT/api/health" >/dev/null 2>&1; then
    STANDALONE_OK="true"
    break
  fi
  sleep 2
done
if [[ "$STANDALONE_OK" != "true" ]]; then
  echo "Recent container logs:" >&2
  docker logs --tail=100 "$STANDALONE" >&2 || true
fi
docker rm -f "$STANDALONE" >/dev/null 2>&1 || true
trap - EXIT
[[ "$STANDALONE_OK" == "true" ]] \
  || fail "Standalone image did not serve http://localhost:$FRONTEND_PORT/ and /api/health."
echo "PASS  standalone image serves the frontend and backend via nginx /api"

# ---------------------------------------------------------------------------
echo ""
echo "==> Step 3/4  Zip the source for manual upload"
if [[ "$SKIP_ZIP" == "true" ]]; then
  echo "Skipping zip (--skip-zip)."
elif [[ -n "$ZIP_NAME" ]]; then
  bash "$ZIP_SCRIPT" "$ZIP_NAME"
else
  bash "$ZIP_SCRIPT"
fi

# ---------------------------------------------------------------------------
echo ""
echo "==> Step 4/4  Push the image through the organizer proxy"
if [[ "$SKIP_PUSH" == "true" ]]; then
  echo "Skipping push (--skip-push)."
else
  if [[ -z "$USER_EMAIL" ]]; then
    if [[ -t 0 ]]; then
      read -rp "Your Meesho organization email (used only to name the image): " USER_EMAIL
    fi
  fi
  [[ -n "$USER_EMAIL" ]] || fail "A Meesho email is required to name the image. Pass --user or set MEESHO_EMAIL."

  if [[ -z "$TOKEN" ]]; then
    if [[ -t 0 ]]; then
      read -rsp "Organizer registry token (input hidden): " TOKEN
      echo ""
    else
      fail "No registry token. Set HACKATHON_PROXY_TOKEN or pass --token."
    fi
  fi
  [[ -n "$TOKEN" ]] || fail "A registry token is required to push."

  push_args=(--proxy-host "$PROXY_HOST" --login-user "$LOGIN_USER" \
             --local-image "$IMAGE" --user "$USER_EMAIL" --skip-smoke)
  [[ -n "$TAG" ]] && push_args+=(--tag "$TAG")

  # Pass the token via env (read through docker login --password-stdin), never in argv.
  HACKATHON_PROXY_TOKEN="$TOKEN" bash "$PUSH_SCRIPT" "${push_args[@]}"
fi

# ---------------------------------------------------------------------------
cat <<DONE

============================================================
Deploy steps finished. Now make it live for judging:

  1. Open ${LIVE_URL} and log in.
  2. Click the "Deploy Live" button.
  3. Wait for the live link to appear — that is your running
     app for the judges.

Also upload the printed dist/<name>.zip to the organizer's
submission folder by hand if you have not already.
============================================================
DONE
