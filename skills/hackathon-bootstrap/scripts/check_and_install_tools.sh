#!/usr/bin/env bash
set -euo pipefail

MODE="check"
if [[ "${1:-}" == "--install" ]]; then
  MODE="install"
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: check_and_install_tools.sh [--install]

Checks tools needed for the core hackathon stack:
git, docker, docker compose, node, npm, go, sqlite3, and zip.

Default mode only reports missing tools. --install prints install guidance.

Container engine: this script NEVER installs Docker. If a working 'docker' command
already exists (from any engine), it is used. If none exists, the participant installs
Rancher Desktop instead — on macOS from the iru self-service portal ("All" section),
on Linux from rancherdesktop.io. The dedicated helper is ensure_container_engine.sh.
USAGE
  exit 0
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

status() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "OK      %s\n" "$name"
  else
    printf "MISSING %s\n" "$name"
    MISSING+=("$name")
  fi
}

# macOS: never install Docker. Guide the participant to the iru self-service portal for
# the container engine (Rancher Desktop) and Node.js; the rest ships with macOS or can
# come from the same portal. This function installs nothing.
install_macos() {
  cat <<'GUIDE'
On macOS, install the missing pieces WITHOUT Docker:

  * Container engine + Node.js: open the iru self-service portal, go to the "All" section,
    and install "Rancher Desktop" and "Node.js". Open Rancher Desktop once and pick the
    "dockerd (moby)" container engine so the 'docker' command works.
  * sqlite3 and zip already ship with macOS.
  * Go is only needed if you chose a Go backend — install it from iru self-service too.

Do not install Docker Desktop. Rancher Desktop provides the same 'docker' command.
After installing, rerun this check.
GUIDE
  # Hand the container-engine verification to the dedicated helper (never installs Docker).
  local ensure="$SCRIPT_DIR/ensure_container_engine.sh"
  [[ -f "$ensure" ]] && bash "$ensure" --install || true
  return 0
}

install_linux_apt() {
  # Never install Docker. Install the language/tooling packages only; the container engine
  # comes from Rancher Desktop (see ensure_container_engine.sh --install).
  sudo apt-get update
  sudo apt-get install -y git curl ca-certificates gnupg nodejs npm golang-go sqlite3 zip
  local ensure="$SCRIPT_DIR/ensure_container_engine.sh"
  [[ -f "$ensure" ]] && bash "$ensure" --install || true
}

MISSING=()
OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Detected OS: $OS"

# Rancher Desktop exposes its docker CLI under ~/.rd/bin; add it so the check sees it.
RD_BIN="$HOME/.rd/bin"
if [[ -d "$RD_BIN" && ":$PATH:" != *":$RD_BIN:"* ]]; then
  export PATH="$RD_BIN:$PATH"
fi

status "git" "command -v git"
status "docker" "command -v docker"
status "docker compose" "docker compose version"
status "node" "command -v node"
status "npm" "command -v npm"
status "go" "command -v go"
status "sqlite3" "command -v sqlite3"
status "zip" "command -v zip"

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "All core tools are available."
  exit 0
fi

echo
echo "Missing tools: ${MISSING[*]}"

if [[ "$MODE" != "install" ]]; then
  echo "Run with --install to attempt installation."
  exit 1
fi

case "$OS" in
  Darwin) install_macos ;;
  Linux)
    if need_cmd apt-get; then
      install_linux_apt
    else
      echo "Unsupported Linux package manager. Install the missing tools manually."
      exit 1
    fi
    ;;
  *)
    echo "Unsupported OS. Install the missing tools manually."
    exit 1
    ;;
esac
