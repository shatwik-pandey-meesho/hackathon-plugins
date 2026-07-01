#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
MEMORY_DIR="$ROOT/.agent-memory"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: setup_agent_memory.sh [project-root]

Creates the durable .agent-memory files used to resume the project in later sessions.
USAGE
  exit 0
fi

mkdir -p "$MEMORY_DIR"

if [[ ! -f "$MEMORY_DIR/state.json" ]]; then
  cat > "$MEMORY_DIR/state.json" <<'EOF'
{
  "project_name": "",
  "app_idea": "",
  "frontend_port": 9080,
  "backend_port": 8090,
  "frontend_framework": "react",
  "backend_language": "",
  "database": "sqlite",
  "participant_email": "",
  "team_id": "",
  "image_tag": "",
  "registry_url": "",
  "registry_proxy_host": "registry.buildathon.ltl.sh",
  "registry_login_user": "hackathon",
  "last_pushed_image": "",
  "last_pushed_tag": "",
  "code_zip": "",
  "last_successful_step": "",
  "current_status": "bootstrapping",
  "current_blocker": "",
  "next_action": "",
  "last_updated": ""
}
EOF
fi

if [[ ! -f "$MEMORY_DIR/session.md" ]]; then
  cat > "$MEMORY_DIR/session.md" <<'EOF'
# Session Memory

## Current State

- Project idea:
- Stack:
- Frontend URL: http://localhost:9080
- Backend health URL (through nginx /api): http://localhost:9080/api/health
- What works:
- What is blocked:
- Most recent changes:
EOF
fi

if [[ ! -f "$MEMORY_DIR/handoff.md" ]]; then
  cat > "$MEMORY_DIR/handoff.md" <<'EOF'
# Handoff

## Current Blocker

- None recorded.

## Next Action

- None recorded.

## Expected Result

- None recorded.
EOF
fi

if [[ ! -f "$MEMORY_DIR/activity.md" ]]; then
  cat > "$MEMORY_DIR/activity.md" <<'EOF'
# Activity Log

EOF
fi

echo "Agent memory is ready at $MEMORY_DIR"
