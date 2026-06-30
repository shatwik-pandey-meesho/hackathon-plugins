#!/usr/bin/env bash
set -euo pipefail

# Build a clean, secret-free zip of the current project for MANUAL upload to the organizer's
# submission folder. Excludes dependency folders, build output, local database data, and secret
# files. Prints the zip path and size. It does not upload anything.

case "${1:-}" in
  -h|--help)
    cat <<'USAGE'
Usage: make_code_zip.sh [NAME]

NAME is an optional base name for the zip (for example a team or project name). If omitted,
the current project folder name is used. The zip is written to dist/<name>.zip.

The participant uploads the resulting zip by hand to the organizer's submission folder.
USAGE
    exit 0
    ;;
esac

NAME="${1:-}"

if ! command -v zip >/dev/null 2>&1; then
  echo "ERROR: 'zip' is not installed. Install it (macOS ships it; Debian/Ubuntu: 'sudo apt-get install zip')." >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PWD" | tr '[:upper:] ' '[:lower:]-')"
[[ -n "$NAME" ]] || NAME="$PROJECT_NAME"
# Sanitize the name into a safe filename: lowercase, spaces to dashes, keep alnum . _ -
NAME="$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]._-')"
[[ -n "$NAME" ]] || NAME="$PROJECT_NAME"

OUT_DIR="dist"
OUT_FILE="$OUT_DIR/${NAME}.zip"

# Refuse to package obvious secrets. Look at real files on disk.
SECRETS="$(find . \
  -path ./node_modules -prune -o \
  -path ./.git -prune -o \
  -path ./data -prune -o \
  -path ./dist -prune -o \
  -type f \( \
    -name '.env' -o -name '.env.*' \
    -o -name '*service-account*.json' \
    -o -name '*.pem' -o -name '*.key' \
  \) ! -name '.env.example' -print 2>/dev/null || true)"

if [[ -n "$SECRETS" ]]; then
  echo "ERROR: refusing to build the zip because secret-looking files are present:" >&2
  echo "$SECRETS" >&2
  echo "Remove or rename these (an .env.example is allowed) before zipping for upload." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_FILE"

# Build the zip, excluding heavy and secret paths so it stays small and clean.
zip -r -q "$OUT_FILE" . \
  -x '*/node_modules/*' 'node_modules/*' \
  -x '*/.git/*' '.git/*' \
  -x '*/data/*' 'data/*' \
  -x 'dist/*' \
  -x '*/dist/*' '*/build/*' 'build/*' \
  -x '*.db' '*.sqlite' '*.sqlite3' \
  -x '*.env' '.env' '.env.*' \
  -x '*.pem' '*.key' '*service-account*.json' \
  -x '*.DS_Store' '*.log'

SIZE="$(wc -c < "$OUT_FILE" | tr -d ' ')"
ABS_PATH="$(cd "$(dirname "$OUT_FILE")" && pwd)/$(basename "$OUT_FILE")"
echo "Built zip: $ABS_PATH"
echo "Size (bytes): $SIZE"
echo "Next step (manual): upload this zip to the organizer's submission folder yourself."

if (( SIZE > 50000000 )); then
  echo "WARNING: zip is larger than 50 MB. Trim heavy folders (node_modules/, data/, build output) before uploading." >&2
fi
