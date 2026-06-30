#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: check_submission.sh [image:tag]

Builds and smoke-tests the final single image and scans project files for
obvious secrets. Zipping code for submission is handled by hackathon-zip-code.
Environment:
  FRONTEND_PORT=9080
  BACKEND_PORT=8090
  DATA_DIR=$PWD/data
USAGE
  exit 0
fi

IMAGE="${1:-hackathon-app:final}"
FRONTEND_PORT="${FRONTEND_PORT:-9080}"
BACKEND_PORT="${BACKEND_PORT:-8090}"
DATA_DIR="${DATA_DIR:-$PWD/data}"
FAIL=0

pass() { printf "PASS  %s\n" "$1"; }
fail() { printf "FAIL  %s\n" "$1"; FAIL=1; }
warn() { printf "WARN  %s\n" "$1"; }

have() {
  command -v "$1" >/dev/null 2>&1
}

[[ -f Dockerfile ]] && pass "Dockerfile exists" || fail "Dockerfile missing"
[[ -f README.md ]] && pass "README exists" || warn "README missing"

# Scan the project files (not git) for secret-looking files and content.
SECRET_FILES="$(find . \
  -path ./node_modules -prune -o \
  -path ./.git -prune -o \
  -path ./data -prune -o \
  -path ./dist -prune -o \
  -type f \( -name '.env' -o -name '.env.*' -o -name '*service-account*.json' -o -name '*.pem' -o -name '*.key' \) \
  ! -name '.env.example' -print 2>/dev/null || true)"
if [[ -n "$SECRET_FILES" ]]; then
  fail "secret-looking files present (keep these out of the uploaded zip):"
  printf '      %s\n' $SECRET_FILES
else
  pass "no secret-looking files in the project"
fi

if grep -RInE '(BEGIN (RSA|OPENSSH) PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|password *= *[^ ]+)' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=data --exclude-dir=dist \
    . >/tmp/hackathon-secret-scan.txt 2>/dev/null; then
  fail "possible secret found in project files; inspect /tmp/hackathon-secret-scan.txt"
else
  pass "no obvious secret content found"
fi

if grep -q '"code_zip"' .agent-memory/state.json 2>/dev/null \
   && ! grep -qE '"code_zip" *: *(""|null)' .agent-memory/state.json 2>/dev/null; then
  pass "code zip built (code_zip recorded) — remember to upload it to the organizer's folder by hand"
else
  warn "no code zip built yet; run hackathon-zip-code, then upload the zip to the organizer's folder manually"
fi

check_port_available() {
  local port="$1"
  local label="$2"
  if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" >/dev/null 2>&1; then
    fail "$label port $port is already being used by another program. Close that program or move it to another port, then retry."
  fi
}

if ! have docker; then
  fail "Docker missing"
  exit "$FAIL"
fi

if [[ -f Dockerfile ]]; then
  echo "Building image $IMAGE"
  if docker build -t "$IMAGE" .; then
    pass "image builds"
  else
    fail "image build failed"
    exit "$FAIL"
  fi
fi

check_port_available "$FRONTEND_PORT" "Frontend"
check_port_available "$BACKEND_PORT" "Backend"
if [[ "$FAIL" -ne 0 ]]; then
  exit "$FAIL"
fi
mkdir -p "$DATA_DIR"

CONTAINER="hackathon-final-check-$RANDOM"
cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if docker run -d --name "$CONTAINER" -p "$FRONTEND_PORT:9080" -p "$BACKEND_PORT:8090" -v "$DATA_DIR:/app/data" "$IMAGE" >/dev/null; then
  pass "container starts"
  pass "repo-local SQLite data directory mounted: $DATA_DIR -> /app/data"
else
  fail "container failed to start"
  exit "$FAIL"
fi

READY="false"
for _ in $(seq 1 45); do
  if have curl && curl -fsS "http://localhost:$FRONTEND_PORT/api/health" >/dev/null 2>&1; then
    READY="true"
    pass "backend responds through nginx at /api/health"
    if curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
      pass "frontend responds"
      break
    fi
  fi
  sleep 2
done

if [[ "$READY" != "true" ]]; then
  fail "app did not respond on frontend http://localhost:$FRONTEND_PORT/ and backend via nginx http://localhost:$FRONTEND_PORT/api/health (is nginx proxying /api to the backend?)"
  docker logs --tail=100 "$CONTAINER" || true
fi

warn "Registry upload through the organizer proxy is handled by hackathon-deploy-by-pushing-image when the final image is ready"

exit "$FAIL"
