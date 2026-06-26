#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: check_submission.sh [image:tag]

Builds and smoke-tests the final single image, checks GitHub remote status,
and scans committed files for obvious secrets.
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
[[ -d .git ]] && pass "git repo exists" || warn "git repo missing"

if [[ -d .git ]] && git remote get-url origin >/dev/null 2>&1; then
  pass "GitHub remote configured: $(git remote get-url origin)"
else
  warn "GitHub remote not configured"
fi

if [[ -d .git ]]; then
  if git grep -n -E '(BEGIN (RSA|OPENSSH) PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z_]{30,}|password *= *[^ ]+)' HEAD -- . >/tmp/hackathon-secret-scan.txt 2>/dev/null; then
    fail "possible secret found in committed files; inspect /tmp/hackathon-secret-scan.txt"
  else
    pass "no obvious committed secrets found"
  fi
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
  if have curl && curl -fsS "http://localhost:$BACKEND_PORT/health" >/dev/null 2>&1; then
    READY="true"
    pass "health endpoint responds"
    if curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
      pass "frontend responds"
      break
    fi
  fi
  sleep 2
done

if [[ "$READY" != "true" ]]; then
  fail "app did not respond on frontend http://localhost:$FRONTEND_PORT and backend http://localhost:$BACKEND_PORT/health"
  docker logs --tail=100 "$CONTAINER" || true
fi

if have gcloud; then
  warn "gcloud is installed; registry URL still needs to be confirmed from push output"
else
  warn "gcloud missing; cannot verify Artifact Registry push from this machine"
fi

exit "$FAIL"
