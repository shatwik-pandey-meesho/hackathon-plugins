---
name: hackathon-gcp-push
description: "Push a final single Docker image to Google Cloud Artifact Registry for hackathon judging. Use when a participant asks to upload the image, push to GCP, tag the image, authenticate Docker with GCP, create or use an Artifact Registry repository, produce the final registry URL, or prepare an image for judges or swarm deployment."
---

# Hackathon GCP Push

## Overview

Take a locally built image and publish it to the organization registry. Be careful with cloud account state and always report the exact final image URL.

## Workflow

1. Confirm the local image exists. If not, use `hackathon-single-image-build`.
2. Read `references/gcp-artifact-registry.md`.
3. Check `gcloud auth list` and `gcloud config get-value project`.
4. Ask for missing project ID, region, repository, team name, or tag only when they cannot be inferred.
5. Run `scripts/push_to_gcp_registry.sh` with explicit arguments.
6. If judges use Docker Swarm, run `scripts/print_swarm_deploy_command.sh` with the final image URL and service name.
7. Report the final image URL in this form:
   `REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/IMAGE_NAME:TAG`

## Safety

- Do not change organization IAM policies.
- Do not print secrets or tokens.
- Do not delete registry images.
- Use `--create-repo` only when the participant or organizer confirms repository creation is allowed.

## Resources

- `scripts/push_to_gcp_registry.sh`: tag, authenticate, optionally create repo, and push.
- `scripts/print_swarm_deploy_command.sh`: print safe Docker Swarm deployment commands for judges.
- `references/gcp-artifact-registry.md`: required inputs and URL format.
