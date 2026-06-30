#!/usr/bin/env bash
set -euo pipefail

# Bundle the hackathon skill folders, docs, and install scripts into a single
# distributable zip. The zip extracts to a top-level "hackathon-skills/" folder
# so a participant can unzip and immediately run scripts/install-skills.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/skills"
OUTPUT=""
BUNDLE_NAME="hackathon-skills"
FORCE="false"
LIST_ONLY="false"

SKILLS=(
  "hackathon-bootstrap"
  "hackathon-feature-builder"
  "hackathon-preview"
  "hackathon-bugfix"
  "hackathon-db-helper"
  "hackathon-single-image-build"
  "hackathon-deploy-by-pushing-image"
  "hackathon-zip-code"
  "hackathon-submission-check"
  "hackathon-explainer"
)

DOCS=(
  "README.md"
  "USAGE.md"
  "INSTALLING.md"
)

INSTALL_SCRIPTS=(
  "scripts/install-skills.sh"
  "scripts/install-skills.ps1"
)

usage() {
  cat <<'USAGE'
Usage: bundle-skills.sh [--output PATH] [--name NAME] [--force] [--list]

Bundles the skill folders, docs (README/USAGE/INSTALLING), and the install
scripts into a single zip that extracts to a top-level hackathon-skills/ folder.

Options:
  --output PATH  Output zip path. Default: <repo>/dist/hackathon-skills.zip
  --name NAME    Top-level folder name inside the zip. Default: hackathon-skills
  --force        Overwrite the output zip if it already exists.
  --list         Print what would be bundled and exit.
  --help         Show this help text.

Examples:
  ./scripts/bundle-skills.sh
  ./scripts/bundle-skills.sh --output /tmp/skills.zip --force
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --name)
      BUNDLE_NAME="${2:-}"
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
  echo "Skills:"
  printf "  %s\n" "${SKILLS[@]}"
  echo "Docs:"
  printf "  %s\n" "${DOCS[@]}"
  echo "Install scripts:"
  printf "  %s\n" "${INSTALL_SCRIPTS[@]}"
  exit 0
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip is not installed. Install it (macOS ships it; Debian/Ubuntu: 'apt-get install zip')." >&2
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$ROOT_DIR/dist/$BUNDLE_NAME.zip"
fi

if [[ -e "$OUTPUT" && "$FORCE" != "true" ]]; then
  echo "Output already exists: $OUTPUT" >&2
  echo "Use --force to overwrite." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
BUNDLE_ROOT="$STAGE_DIR/$BUNDLE_NAME"
mkdir -p "$BUNDLE_ROOT/scripts"

# Copy skill folders.
for skill in "${SKILLS[@]}"; do
  SRC="$SKILLS_DIR/$skill"
  if [[ ! -d "$SRC" ]]; then
    echo "Missing skill folder: $SRC" >&2
    exit 1
  fi
  cp -R "$SRC" "$BUNDLE_ROOT/$skill"
done

# Copy docs.
for doc in "${DOCS[@]}"; do
  SRC="$ROOT_DIR/$doc"
  if [[ ! -f "$SRC" ]]; then
    echo "Missing doc: $SRC" >&2
    exit 1
  fi
  cp "$SRC" "$BUNDLE_ROOT/$doc"
done

# Copy install scripts.
for script in "${INSTALL_SCRIPTS[@]}"; do
  SRC="$ROOT_DIR/$script"
  if [[ ! -f "$SRC" ]]; then
    echo "Missing install script: $SRC" >&2
    exit 1
  fi
  cp "$SRC" "$BUNDLE_ROOT/$script"
done
# Keep the .sh installer executable inside the zip.
chmod +x "$BUNDLE_ROOT/scripts/install-skills.sh" 2>/dev/null || true

# Strip junk that should never ship in the bundle.
find "$BUNDLE_ROOT" \
  \( -name ".git" -o -name "node_modules" -o -name ".agent-memory" -o -name "data" -o -name "dist" \) -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$BUNDLE_ROOT" \( -name ".DS_Store" -o -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -type f -delete 2>/dev/null || true

# Create the zip from the stage dir so paths are relative to BUNDLE_NAME/.
rm -f "$OUTPUT"
(
  cd "$STAGE_DIR"
  zip -r -q "$OUTPUT" "$BUNDLE_NAME"
)

COUNT=$(unzip -l "$OUTPUT" | tail -1 | awk '{print $2}')
SIZE=$(du -h "$OUTPUT" | awk '{print $1}')
echo "Created bundle: $OUTPUT ($SIZE, $COUNT files)"
echo "Extracts to:    $BUNDLE_NAME/"
echo "Next:           unzip '$OUTPUT' && cd $BUNDLE_NAME && ./scripts/install-skills.sh --agent claude"
