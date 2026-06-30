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

Default mode only reports missing tools. --install attempts best-effort installs
on macOS with Homebrew or Debian/Ubuntu with apt.
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

install_macos() {
  if ! need_cmd brew; then
    echo "Homebrew is missing. Install it from https://brew.sh, then rerun this script."
    return 1
  fi
  brew install git node go sqlite zip
  brew install --cask docker || true
  echo "Docker Desktop may need to be opened once before Docker commands work."
}

install_linux_apt() {
  sudo apt-get update
  sudo apt-get install -y git curl ca-certificates gnupg nodejs npm golang-go sqlite3 docker.io docker-compose-plugin zip
  echo "You may need to log out and back in after adding your user to the docker group:"
  echo "  sudo usermod -aG docker \$USER"
}

MISSING=()
OS="$(uname -s)"
echo "Detected OS: $OS"

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
