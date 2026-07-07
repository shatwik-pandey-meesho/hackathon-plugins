# Proxy Registry Push

Use the organizer's Docker proxy for all image uploads. Do not install registry clients, authenticate directly to the underlying registry, or create registry repositories from participant machines.

## Required Inputs

- `PROXY_HOST`: proxy registry host. Default: `registry.buildathon.meesho.dev`. Do not include `https://` or a path.
- `LOGIN_USER`: Docker login username, normally `hackathon`.
- `TOKEN`: organizer-provided token or password. Do not print it.
- `LOCAL_IMAGE`: image already built on the participant's machine, for example `hackathon-app:final`.
- `TEAM_ID`: participant's team ID, derived strictly from their **Meesho organization email**. Ask for the email unless `.agent-memory/state.json` already has `participant_email` and `team_id`. The team ID is the part before `@`, lowercased, with every run of characters outside `[a-z0-9_-]` replaced by `-`, then leading/trailing hyphens trimmed. Examples: `priya.sharma@meesho.com` → `priya-sharma`; `team_alpha@meesho.com` → `team_alpha`; `Arnav.Jose+Demo@meesho.com` → `arnav-jose-demo`. Never invent or substitute this value.
- `TAG`: final image tag. Default: UTC timestamp, e.g. `20260701-053012`.

## Final URL Format

The image path must be the participant's team ID plus the timestamp tag:

```text
PROXY_HOST/TEAM_ID:TAG
```

Example:

```text
registry.buildathon.meesho.dev/priya-sharma:20260701-053012
```

## Safe Command Pattern

Use the provided script instead of hand-writing the login command:

```bash
HACKATHON_PROXY_TOKEN=hackathon2026 \
  ./hackathon-deploy-by-pushing-image/scripts/push_to_proxy_registry.sh \
    --login-user hackathon \
    --local-image hackathon-app:final \
    --user priya.sharma@meesho.com
```

The script:

- Checks Docker and curl are available.
- Checks Docker daemon access before inspecting or running images.
- Confirms the local image exists.
- Runs the image locally and requires both `http://localhost:9080/` and `http://localhost:9080/api/health` (backend through nginx) to respond before pushing.
- Stops if ports `9080` or `8090` are already in use.
- Logs in with `docker login --password-stdin` so the token is not placed in shell history as `-p TOKEN`.
- Tags the local image as `PROXY_HOST/TEAM_ID:TAG`.
- Pushes the final image.
- Updates local `.agent-memory/` with non-secret push metadata when that directory exists. It never stores the token.

## Edge Cases

- If the proxy host includes `https://`, strip it before Docker login and tagging.
- If the proxy host includes a path, ask for the registry host only.
- If local memory already contains a participant email and team ID, reuse them unless they are obviously stale or contradictory.
- If the Meesho email / team ID is not in local memory, ask the participant. Do not invent it.
- If a team ID cannot be derived from the email, ask the participant to re-check the email.
- If the image is missing locally, build it first with `hackathon-single-image-build`.
- If Docker is installed but the daemon is unreachable, ask the participant to start Docker Desktop or fix Docker permissions. On **Windows**, if it will not start (often because **WSL2 is missing**), run `hackathon-bootstrap/scripts/ensure_container_engine.ps1 -Install` to enable WSL2 and install the **Rancher Desktop** fallback with the `dockerd (moby)` engine, which provides the same `docker` command for pushing.
- If the image fails the local health check, fix the app or image before pushing.
- If the final image must be judged without a local bind mount, prefer a smoke test without `--data-dir`. Use `--data-dir` only for local development checks.
- If login fails, re-check proxy host, username, and token before retrying.
- If push fails with an authorization or path error, confirm the proxy supports the `TEAM_ID:TAG` path and that the token is still valid.
- If push fails with a Cloud Run request-size, streaming, or layer upload error, tell organizers the registry proxy should move to the GKE/LB path for large images. Do not blame the participant's app unless the local smoke test failed.
