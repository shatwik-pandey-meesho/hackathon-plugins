#!/usr/bin/env bash
set -euo pipefail

# Combined hackathon deploy for macOS/Linux.
# Runs, in order: build the linux/amd64 single image + smoke test, readiness checks,
# zip the source for manual upload, push through the organizer Docker proxy, and then
# call the proxy's deploy API to start the live deployment.
# Finally prints the live application link: https://<team-id>.buildathon.ltl.sh
#
# Reuses the existing skill scripts as the single source of truth for build/zip/push.

IMAGE="hackathon-app:final"
ZIP_NAME=""
USER_EMAIL="${MEESHO_EMAIL:-}"
TOKEN="${HACKATHON_PROXY_TOKEN:-}"
TAG=""
PROXY_HOST="registry.buildathon.meesho.dev"
LOGIN_USER="hackathon"
SKIP_ZIP="false"
SKIP_PUSH="false"
SKIP_DEPLOY="false"
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
# Live apps are served under this base domain as https://<team-id>.<LIVE_SITE_BASE>
LIVE_SITE_BASE="buildathon.ltl.sh"

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
  --proxy-host HOST   Proxy registry host. Default: registry.buildathon.meesho.dev
  --login-user USER   Docker login username. Default: hackathon
  --skip-zip          Skip building the source zip.
  --skip-push         Build and check only; do not log in or push.
  --skip-deploy       Push only; do not call the deploy API to start the live deployment.
  -h, --help          Show this help.

Environment: HACKATHON_PROXY_TOKEN, MEESHO_EMAIL, FRONTEND_PORT (9080), BACKEND_PORT (8090)
USAGE
}

fail() { echo "ERROR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Derive the team id from a Meesho email exactly like push_to_proxy_registry.sh does:
# part before @, lowercased, non-[a-z0-9_-] runs -> '-', trimmed. Keep the two in sync.
slugify_team_id() {
  local raw="$1"
  local prefix="${raw%%@*}"
  printf "%s" "$prefix" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//'
}

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
    --skip-deploy) SKIP_DEPLOY="true"; shift ;;
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

need_cmd docker || fail "Docker is not installed or not on PATH. Install Docker Desktop, then retry."
docker info >/dev/null 2>&1 \
  || fail "Docker is installed, but the daemon is not reachable. Start Docker Desktop, then retry."
[[ -f Dockerfile ]] || fail "Dockerfile not found in current directory. Package your app first, then deploy."

# ---------------------------------------------------------------------------
echo "==> Step 1/5  Build the linux/amd64 single image and smoke-test it"
FRONTEND_PORT="$FRONTEND_PORT" BACKEND_PORT="$BACKEND_PORT" bash "$BUILD_SCRIPT" "$IMAGE"

# ---------------------------------------------------------------------------
echo ""
echo "==> Step 2/5  Readiness checks"

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
echo "==> Step 3/5  Zip the source for manual upload"
if [[ "$SKIP_ZIP" == "true" ]]; then
  echo "Skipping zip (--skip-zip)."
elif [[ -n "$ZIP_NAME" ]]; then
  bash "$ZIP_SCRIPT" "$ZIP_NAME"
else
  bash "$ZIP_SCRIPT"
fi

# ---------------------------------------------------------------------------
echo ""
echo "==> Step 4/5  Push the image through the organizer proxy"
FINAL_URL=""
TEAM_ID=""
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

  # Compute the team id and tag here so we know the exact pushed image_tag the deploy
  # API needs. Default the tag to a UTC timestamp and pass it explicitly to the push.
  TEAM_ID="$(slugify_team_id "$USER_EMAIL")"
  [[ -n "$TEAM_ID" ]] || fail "Email '$USER_EMAIL' produces an empty team id. Use a Meesho email with letters or numbers before @."
  [[ -n "$TAG" ]] || TAG="$(date -u +%Y%m%d-%H%M%S)"
  FINAL_URL="$PROXY_HOST/$TEAM_ID:$TAG"

  push_args=(--proxy-host "$PROXY_HOST" --login-user "$LOGIN_USER" \
             --local-image "$IMAGE" --user "$USER_EMAIL" --tag "$TAG" --skip-smoke)

  # Pass the token via env (read through docker login --password-stdin), never in argv.
  HACKATHON_PROXY_TOKEN="$TOKEN" bash "$PUSH_SCRIPT" "${push_args[@]}"
fi

# ---------------------------------------------------------------------------
echo ""
echo "==> Step 5/5  Start the live deployment"
LIVE_LINK=""
if [[ "$SKIP_PUSH" == "true" ]]; then
  echo "Skipping deploy because the image was not pushed (--skip-push)."
elif [[ "$SKIP_DEPLOY" == "true" ]]; then
  echo "Skipping deploy (--skip-deploy). Image is pushed at $FINAL_URL."
else
  need_cmd curl || fail "curl is required to call the deploy API."
  DEPLOY_API="https://$PROXY_HOST/admin/api/deploy"
  echo "Requesting deploy of $FINAL_URL"
  # Send the pushed image_tag to the proxy's deploy API. The token is the same registry
  # token, sent as a Bearer header. Never print the token.
  deploy_resp="$(curl -sS -w $'\n%{http_code}' -X POST "$DEPLOY_API" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"image_tag\":\"$FINAL_URL\"}")" \
    || fail "Could not reach the deploy API at $DEPLOY_API. Check your network and retry."
  deploy_code="$(printf '%s' "$deploy_resp" | tail -n1)"
  deploy_body="$(printf '%s' "$deploy_resp" | sed '$d')"
  if [[ ! "$deploy_code" =~ ^2 ]]; then
    echo "Deploy API response:" >&2
    printf '%s\n' "$deploy_body" >&2
    fail "Deploy API returned HTTP $deploy_code. Re-check the token and that the image pushed successfully, then retry."
  fi
  echo "PASS  deploy started (HTTP $deploy_code)"
  LIVE_LINK="https://$TEAM_ID.$LIVE_SITE_BASE"
fi

# ---------------------------------------------------------------------------
cat <<DONE

============================================================
Deploy finished.
DONE
if [[ -n "$LIVE_LINK" ]]; then
  cat <<DONE

Your live application link (give this to the judges):

  $LIVE_LINK

It can take a minute or two to come up after the deploy starts.
If it does not load yet, wait a moment and refresh.
DONE
elif [[ "$SKIP_DEPLOY" == "true" && -n "$FINAL_URL" ]]; then
  cat <<DONE

Image pushed but deploy was skipped. Start it later by POSTing
the image_tag "$FINAL_URL" to https://$PROXY_HOST/admin/api/deploy,
then open https://$TEAM_ID.$LIVE_SITE_BASE.
DONE
fi
cat <<DONE

Also upload the printed dist/<name>.zip to the organizer's
submission folder by hand if you have not already.
============================================================
DONE
