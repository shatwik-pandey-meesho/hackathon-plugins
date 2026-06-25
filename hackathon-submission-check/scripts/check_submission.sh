#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: check_submission.sh [image:tag]

Builds and smoke-tests the final single image, checks GitHub remote status,
and scans committed files for obvious secrets.
Environment:
  PORT=8080
USAGE
  exit 0
fi

IMAGE="${1:-hackathon-app:final}"
PORT="${PORT:-8080}"
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

CONTAINER="hackathon-final-check-$RANDOM"
cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if docker run -d --name "$CONTAINER" -p "$PORT:8080" "$IMAGE" >/dev/null; then
  pass "container starts"
else
  fail "container failed to start"
  exit "$FAIL"
fi

READY="false"
for _ in $(seq 1 45); do
  if have curl && curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
    READY="true"
    pass "health endpoint responds"
    break
  fi
  if have curl && curl -fsS "http://localhost:$PORT/" >/dev/null 2>&1; then
    READY="true"
    pass "root page responds"
    break
  fi
  sleep 2
done

if [[ "$READY" != "true" ]]; then
  fail "app did not respond on http://localhost:$PORT"
  docker logs --tail=100 "$CONTAINER" || true
fi

if have gcloud; then
  warn "gcloud is installed; registry URL still needs to be confirmed from push output"
else
  warn "gcloud missing; cannot verify Artifact Registry push from this machine"
fi

exit "$FAIL"
