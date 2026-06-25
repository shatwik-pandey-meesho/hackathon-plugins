#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -lt 2 ]]; then
  cat <<'USAGE'
Usage: print_swarm_deploy_command.sh FINAL_IMAGE_URL SERVICE_NAME [HOST_PORT]

Prints Docker Swarm commands for judges. It does not execute them.
USAGE
  exit 0
fi

IMAGE_URL="$1"
SERVICE_NAME="$2"
HOST_PORT="${3:-8080}"

cat <<EOF
Create a new Swarm service:
docker service create --name $SERVICE_NAME --publish $HOST_PORT:8080 $IMAGE_URL

Update an existing Swarm service:
docker service update --image $IMAGE_URL $SERVICE_NAME
EOF
