#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
MEMORY_DIR="$ROOT/.agent-memory"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: recontextualize_agent_memory.sh [project-root]

Prints the durable memory files so a new session can rebuild project context.
USAGE
  exit 0
fi

if [[ ! -d "$MEMORY_DIR" ]]; then
  echo "No .agent-memory directory found at $MEMORY_DIR"
  exit 1
fi

for file in state.json session.md handoff.md activity.md; do
  path="$MEMORY_DIR/$file"
  if [[ -f "$path" ]]; then
    echo "===== $file ====="
    cat "$path"
    echo
  fi
done
