#!/usr/bin/env bash
set -euo pipefail

# Ensure a working 'docker' CLI with a reachable engine on macOS/Linux so the app image
# can be built and pushed to the hackathon registry.
#
# On macOS and Linux, Docker is the preferred engine (the Rancher Desktop fallback is a
# Windows-only path; see ensure_container_engine.ps1). This script only verifies Docker
# and, with --install, points to the right installer. It never installs Rancher.

MODE="check"
if [[ "${1:-}" == "--install" ]]; then
  MODE="install"
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: ensure_container_engine.sh [--install]

Verifies that 'docker' works (installed and daemon reachable). Docker is preferred on
macOS and Linux. With --install, guides installation via Homebrew (macOS) or apt (Linux).
USAGE
  exit 0
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

docker_reachable() {
  need_cmd docker || return 1
  docker info >/dev/null 2>&1
}

if docker_reachable; then
  echo "OK      docker engine is reachable"
  exit 0
fi

OS="$(uname -s)"

if need_cmd docker; then
  echo "docker is installed but the engine is not reachable."
  case "$OS" in
    Darwin) echo "Start Docker Desktop (open -a Docker), wait for it to finish, then retry." ;;
    Linux)  echo "Start the Docker service (e.g. sudo systemctl start docker) and ensure your user is in the 'docker' group, then retry." ;;
    *)      echo "Start your Docker engine, then retry." ;;
  esac
  exit 1
fi

echo "docker is not installed."
if [[ "$MODE" != "install" ]]; then
  echo "Rerun with --install for installation guidance."
  exit 1
fi

case "$OS" in
  Darwin)
    if need_cmd brew; then
      echo "Installing Docker Desktop via Homebrew (preferred on macOS)..."
      brew install --cask docker || true
      echo "Open Docker Desktop once so the engine starts, then retry."
    else
      echo "Install Homebrew from https://brew.sh, then run: brew install --cask docker"
    fi
    ;;
  Linux)
    if need_cmd apt-get; then
      echo "Install Docker with: sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin"
      echo "Then add your user to the docker group: sudo usermod -aG docker \$USER (log out and back in)."
    else
      echo "Install Docker for your distribution, then retry."
    fi
    ;;
  *)
    echo "Install Docker for your OS, then retry."
    ;;
esac
exit 1
