#!/usr/bin/env bash
set -euo pipefail

# Ensure a working 'docker' CLI with a reachable engine on macOS/Linux so the app image
# can be built and pushed to the hackathon registry.
#
# Policy: NEVER install Docker. If a 'docker' command backed by a reachable engine is
# already present, use it — it does not matter whether that engine is Docker Desktop or
# Rancher Desktop's dockerd (moby) engine (both provide the same 'docker' command). If no
# working engine exists, the participant should install RANCHER DESKTOP (not Docker):
#   - macOS: install "Rancher Desktop" and "Node.js" from the iru self-service portal
#            (open iru self-service, go to the "All" section, install both).
#   - Linux: install Rancher Desktop from https://rancherdesktop.io.
# This script never installs anything itself; it verifies the engine and, when it is
# missing, prints the exact Rancher install guidance.

MODE="check"
if [[ "${1:-}" == "--install" ]]; then
  MODE="install"
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: ensure_container_engine.sh [--install]

Verifies that 'docker' works (installed and daemon reachable). Any engine is fine —
Docker Desktop if it is already there, otherwise the docker command that Rancher Desktop
provides. This script NEVER installs Docker. With --install it prints how to install
Rancher Desktop (macOS: from the iru self-service portal; Linux: from rancherdesktop.io).
USAGE
  exit 0
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Rancher Desktop on macOS/Linux exposes its docker CLI under ~/.rd/bin. A freshly
# installed Rancher may not be on this session's PATH yet, so add it before checking.
RD_BIN="$HOME/.rd/bin"
if [[ -d "$RD_BIN" && ":$PATH:" != *":$RD_BIN:"* ]]; then
  export PATH="$RD_BIN:$PATH"
fi

docker_reachable() {
  need_cmd docker || return 1
  docker info >/dev/null 2>&1
}

print_rancher_install_guidance() {
  local os="$1"
  case "$os" in
    Darwin)
      cat <<'GUIDE'
Install a container engine WITHOUT Docker by using Rancher Desktop:

  1. Open the iru self-service portal on your Mac.
  2. Go to the "All" section.
  3. Install "Rancher Desktop" and "Node.js" from there.
  4. Open Rancher Desktop once. In Preferences -> Container Engine, choose
     "dockerd (moby)" so the 'docker' command works, and let it finish starting.
  5. If a new terminal cannot find 'docker' afterwards, make sure ~/.rd/bin is on PATH
     (or just reopen the terminal), then rerun this step.

Do not install Docker Desktop — Rancher Desktop provides the same 'docker' command.
GUIDE
      ;;
    Linux)
      cat <<'GUIDE'
Install a container engine WITHOUT Docker by using Rancher Desktop:

  1. Install Rancher Desktop from https://rancherdesktop.io (see their Linux instructions).
  2. Open it once and choose the "dockerd (moby)" container engine so 'docker' works.
  3. If a new terminal cannot find 'docker', ensure ~/.rd/bin is on PATH, then rerun.

If you already have a working 'docker' from an existing engine, just start it and retry.
Do not install Docker Desktop — Rancher Desktop provides the same 'docker' command.
GUIDE
      ;;
    *)
      echo "Install Rancher Desktop for your OS (https://rancherdesktop.io), choose the"
      echo "'dockerd (moby)' engine, then retry. Do not install Docker."
      ;;
  esac
}

if docker_reachable; then
  echo "OK      docker engine is reachable (using the container engine already installed)"
  exit 0
fi

OS="$(uname -s)"

if need_cmd docker; then
  echo "docker is installed but the engine is not reachable."
  case "$OS" in
    Darwin) echo "Start your container engine (open Rancher Desktop, or Docker Desktop if that is what you have), wait for it to finish starting, then retry." ;;
    Linux)  echo "Start your container engine (Rancher Desktop, or the docker service via sudo systemctl start docker) and ensure your user can run docker, then retry." ;;
    *)      echo "Start your container engine, then retry." ;;
  esac
  exit 1
fi

echo "No working container engine found (docker is not installed)."
if [[ "$MODE" != "install" ]]; then
  echo "Rerun with --install for Rancher Desktop installation guidance."
  exit 1
fi

print_rancher_install_guidance "$OS"
exit 1
