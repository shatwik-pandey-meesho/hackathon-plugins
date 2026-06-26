#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CODEX_DEST="${CODEX_HOME:-$HOME/.codex}/skills"
AGENT=""
DEST=""
FORCE="false"
LIST_ONLY="false"
SKILLS_ARG="all"

SKILLS=(
  "hackathon-bootstrap"
  "hackathon-feature-builder"
  "hackathon-preview"
  "hackathon-bugfix"
  "hackathon-db-helper"
  "hackathon-single-image-build"
  "hackathon-gcp-push"
  "hackathon-github"
  "hackathon-submission-check"
  "hackathon-explainer"
)

usage() {
  cat <<'USAGE'
Usage: install-skills.sh --agent codex|claude [--dest PATH] [--skills all|skill1,skill2] [--force] [--list]

Options:
  --agent   Target agent. Use "codex" for native Codex install.
            Use "claude" to copy the skill folders into a destination directory.
  --dest    Destination directory.
            For codex, default: ${CODEX_HOME:-$HOME/.codex}/skills
            For claude, default: $HOME/.claude/skills
  --skills  "all" or a comma-separated list of skill folder names.
  --force   Overwrite existing destination skill folders.
  --list    Print the installable skill names and exit.
  --help    Show this help text.

Examples:
  ./scripts/install-skills.sh --agent codex
  ./scripts/install-skills.sh --agent codex --skills hackathon-bootstrap,hackathon-preview
  ./scripts/install-skills.sh --agent claude --dest "$HOME/claude-skills" --skills all
USAGE
}

join_by() {
  local delimiter="$1"
  shift
  local first="true"
  for item in "$@"; do
    if [[ "$first" == "true" ]]; then
      printf "%s" "$item"
      first="false"
    else
      printf "%s%s" "$delimiter" "$item"
    fi
  done
}

validate_skill() {
  local skill="$1"
  local found="false"
  for candidate in "${SKILLS[@]}"; do
    if [[ "$candidate" == "$skill" ]]; then
      found="true"
      break
    fi
  done
  [[ "$found" == "true" ]]
}

parse_skills() {
  local requested="$1"
  if [[ "$requested" == "all" ]]; then
    printf "%s\n" "${SKILLS[@]}"
    return 0
  fi

  IFS=',' read -r -a selected <<<"$requested"
  for skill in "${selected[@]}"; do
    if ! validate_skill "$skill"; then
      echo "Unknown skill: $skill" >&2
      exit 1
    fi
    printf "%s\n" "$skill"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      AGENT="${2:-}"
      shift 2
      ;;
    --dest)
      DEST="${2:-}"
      shift 2
      ;;
    --skills)
      SKILLS_ARG="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --list)
      LIST_ONLY="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$LIST_ONLY" == "true" ]]; then
  printf "%s\n" "${SKILLS[@]}"
  exit 0
fi

if [[ -z "$AGENT" ]]; then
  echo "--agent is required." >&2
  usage >&2
  exit 1
fi

case "$AGENT" in
  codex)
    if [[ -z "$DEST" ]]; then
      DEST="$DEFAULT_CODEX_DEST"
    fi
    ;;
  claude)
    if [[ -z "$DEST" ]]; then
      DEST="$HOME/.claude/skills"
      echo "No --dest given. Defaulting to the personal Claude skills directory: $DEST"
      echo "For a single project only, pass --dest <project>/.claude/skills instead."
    fi
    ;;
  *)
    echo "Unsupported agent: $AGENT" >&2
    exit 1
    ;;
esac

mkdir -p "$DEST"
SELECTED_SKILLS=()
while IFS= read -r skill; do
  [[ -n "$skill" ]] && SELECTED_SKILLS+=("$skill")
done < <(parse_skills "$SKILLS_ARG")

for skill in "${SELECTED_SKILLS[@]}"; do
  SRC="$ROOT_DIR/$skill"
  DST="$DEST/$skill"

  if [[ ! -d "$SRC" ]]; then
    echo "Missing source skill folder: $SRC" >&2
    exit 1
  fi

  if [[ -e "$DST" ]]; then
    if [[ "$FORCE" != "true" ]]; then
      echo "Destination already exists: $DST" >&2
      echo "Use --force to overwrite." >&2
      exit 1
    fi
    rm -rf "$DST"
  fi

  cp -R "$SRC" "$DST"
  echo "Installed $skill -> $DST"
done

if [[ "$AGENT" == "codex" ]]; then
  echo "Restart Codex to pick up the new skills."
else
  echo "Claude install copied the skill folders into: $DEST"
  echo "Point your Claude agent workflow at that directory or import those folders into your Claude setup."
fi
