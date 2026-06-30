---
name: hackathon-deploy-by-pushing-image
description: "Push a final single Docker image for hackathon judging through the organizer's token-authenticated Docker proxy. Use when a participant asks to upload the image, push through the hackathon proxy, tag the image, authenticate Docker to the proxy, or produce the final registry URL."
---

# Deploy By Pushing Image

## Overview

Handle only the image upload path through the organizer's Docker proxy. Do not install registry clients, authenticate directly to the underlying registry, or create registry repositories from this skill.

## Workflow

1. Confirm the local image exists. If not, use `hackathon-single-image-build`.
2. Read `references/proxy-registry.md`.
3. Ask for the proxy host, Docker login username, token, local image tag, and final image tag. Defaults: username `hackathon`, tag `final`.
4. Infer the GitHub username from `gh api user`, `git config github.user`, or the GitHub origin remote. Ask only if it cannot be inferred or if the participant wants to override it.
5. The final pushed image path must be based on the GitHub username in both the namespace/folder and image name: `PROXY_HOST/GITHUB_USER/GITHUB_USER:TAG`. The scripts lowercase the GitHub username because Docker repository paths must be lowercase.
6. Run `scripts/push_to_proxy_registry.sh` or `scripts/push_to_proxy_registry.ps1` with explicit arguments. Prefer passing the token through `HACKATHON_PROXY_TOKEN` or `--password-stdin` behavior; do not print the token.
7. The script must smoke-test the local image before pushing unless the participant explicitly says it was already checked and accepts `--skip-smoke`.
8. Report the final image URL:
   `PROXY_HOST/GITHUB_USER/GITHUB_USER:TAG`

## Safety

- Do not print secrets or tokens.
- Do not delete registry images.
- Do not install or run registry clients.
- Do not attempt direct underlying-registry login or repository creation.
- Do not run `docker login -p TOKEN` directly because it can expose the token in process history. Use the provided script, which passes the token through stdin.
- Before pushing, verify the local image starts and responds on frontend `9080` and backend `/health` on `8090`.
- If ports `9080` or `8090` are already in use, stop and tell the participant which port is busy instead of pushing an unverified image.
- Do not invent a GitHub username. Infer it from local GitHub state or ask the participant.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before pushing.
- After a push attempt, update `.agent-memory/state.json` with the registry URL and append the exact result to `.agent-memory/activity.md`.

## Resources

- `scripts/push_to_proxy_registry.sh`: smoke-test a local image, log in to the organizer Docker proxy with a token, tag as `PROXY_HOST/GITHUB_USER/GITHUB_USER:TAG`, and push.
- `scripts/push_to_proxy_registry.ps1`: Windows PowerShell version of the proxy push script.
- `references/proxy-registry.md`: required proxy inputs, image naming rules, safe command pattern, and edge cases.
