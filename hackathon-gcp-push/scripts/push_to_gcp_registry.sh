#!/usr/bin/env bash
set -euo pipefail

CREATE_REPO="false"
if [[ "${1:-}" == "--create-repo" ]]; then
  CREATE_REPO="true"
  shift
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -lt 5 ]]; then
  cat <<'USAGE'
Usage: push_to_gcp_registry.sh [--create-repo] PROJECT_ID REGION REPOSITORY LOCAL_IMAGE FINAL_IMAGE_NAME[:TAG]

Example:
  push_to_gcp_registry.sh my-project asia-south1 hackathon hackathon-app:final team-17:final

Outputs the final Artifact Registry image URL.
USAGE
  exit 0
fi

PROJECT_ID="$1"
REGION="$2"
REPOSITORY="$3"
LOCAL_IMAGE="$4"
FINAL_NAME="$5"
REGISTRY_HOST="$REGION-docker.pkg.dev"
FINAL_URL="$REGISTRY_HOST/$PROJECT_ID/$REPOSITORY/$FINAL_NAME"

for cmd in gcloud docker; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd is not installed or not on PATH."
    exit 1
  fi
done

docker image inspect "$LOCAL_IMAGE" >/dev/null
gcloud config set project "$PROJECT_ID" >/dev/null
gcloud auth list
gcloud auth configure-docker "$REGISTRY_HOST" --quiet

if [[ "$CREATE_REPO" == "true" ]]; then
  gcloud artifacts repositories describe "$REPOSITORY" --location="$REGION" >/dev/null 2>&1 \
    || gcloud artifacts repositories create "$REPOSITORY" --repository-format=docker --location="$REGION"
fi

docker tag "$LOCAL_IMAGE" "$FINAL_URL"
docker push "$FINAL_URL"

echo "Final image URL:"
echo "$FINAL_URL"
