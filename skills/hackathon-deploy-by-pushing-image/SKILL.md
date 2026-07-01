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
3. Ask for the token and local image tag. Defaults: proxy host `registry.buildathon.ltl.sh`, username `hackathon`, final image tag as a UTC timestamp.
4. **Always ask the participant for their Meesho organization email** unless `.agent-memory/state.json` already has `participant_email` and `team_id`. Use it strictly to name the image — never infer, guess, or substitute another value. Pass the email to the script with `--user`; the script derives the team ID by taking the part before `@`, lowercasing, replacing every run of characters outside `[a-z0-9_-]` with `-`, and trimming leading/trailing hyphens (`Arnav.Jose+Demo@meesho.com` → `arnav-jose-demo`).
5. The final pushed image path must be based on that email-derived team ID: `PROXY_HOST/TEAM_ID:TAG`.
6. Run `scripts/push_to_proxy_registry.sh` or `scripts/push_to_proxy_registry.ps1` with explicit arguments. Prefer passing the token through `HACKATHON_PROXY_TOKEN` or `--password-stdin` behavior; do not print the token.
7. The script must smoke-test the local image before pushing unless the participant explicitly says it was already checked and accepts `--skip-smoke`.
8. Report the final image URL:
   `PROXY_HOST/TEAM_ID:TAG`

## Safety

- Do not print secrets or tokens.
- Do not delete registry images.
- Do not install or run registry clients.
- Do not attempt direct underlying-registry login or repository creation.
- Do not run `docker login -p TOKEN` directly because it can expose the token in process history. Use the provided script, which passes the token through stdin.
- Before pushing, verify the local image starts and responds on frontend `9080` and backend through nginx at `9080/api/health`.
- If ports `9080` or `8090` are already in use, stop and tell the participant which port is busy instead of pushing an unverified image.
- Do not invent the team ID. Ask the participant for their Meesho organization email if local memory does not already contain it, and derive the team ID strictly from that email.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before pushing.
- After a push attempt, update `.agent-memory/state.json` with `participant_email`, `team_id`, `registry_proxy_host`, `registry_login_user`, `registry_url`, `last_pushed_image`, and `last_pushed_tag`, then append the exact result to `.agent-memory/activity.md`. Never store the token in memory.

## Resources

- `scripts/push_to_proxy_registry.sh`: smoke-test a local image, log in to the organizer Docker proxy with a token, tag as `PROXY_HOST/TEAM_ID:TAG`, and push.
- `scripts/push_to_proxy_registry.ps1`: Windows PowerShell version of the proxy push script.
- `references/proxy-registry.md`: required proxy inputs, image naming rules, safe command pattern, and edge cases.
