# Proxy Registry Push

Use the organizer's Docker proxy for all image uploads. Do not install registry clients, authenticate directly to the underlying registry, or create registry repositories from participant machines.

## Required Inputs

- `PROXY_HOST`: proxy registry host, for example `hackathon-proxy-xxxxx.run.app`. Do not include `https://` or a path.
- `LOGIN_USER`: Docker login username, normally `hackathon`.
- `TOKEN`: organizer-provided token or password. Do not print it.
- `LOCAL_IMAGE`: image already built on the participant's machine, for example `hackathon-app:final`.
- `USER`: participant's identity slug, derived strictly from their **Meesho organization email**. Always ask the participant for their email (for example `priya.sharma@meesho.com`); the slug is the part before `@`, lowercased (`priya.sharma`). A full email is accepted and the part before `@` is used. Never invent or substitute this value.
- `TAG`: final image tag, normally `final`, `v1`, or a submission timestamp.

## Final URL Format

The image namespace/folder and image name must both be the participant's identity slug, lowercased for Docker compatibility:

```text
PROXY_HOST/USER/USER:TAG
```

Example:

```text
hackathon-proxy-xxxxx.run.app/priya.sharma/priya.sharma:v1
```

## Safe Command Pattern

Use the provided script instead of hand-writing the login command:

```bash
HACKATHON_PROXY_TOKEN=hackathon2026 \
  ./hackathon-deploy-by-pushing-image/scripts/push_to_proxy_registry.sh \
    --proxy-host hackathon-proxy-xxxxx.run.app \
    --login-user hackathon \
    --local-image hackathon-app:final \
    --user priya.sharma \
    --tag v1
```

The script:

- Checks Docker and curl are available.
- Checks Docker daemon access before inspecting or running images.
- Confirms the local image exists.
- Runs the image locally and requires both `http://localhost:9080/` and `http://localhost:9080/api/health` (backend through nginx) to respond before pushing.
- Stops if ports `9080` or `8090` are already in use.
- Logs in with `docker login --password-stdin` so the token is not placed in shell history as `-p TOKEN`.
- Tags the local image as `PROXY_HOST/USER/USER:TAG`.
- Pushes the final image.

## Edge Cases

- If the proxy host includes `https://`, strip it before Docker login and tagging.
- If the proxy host includes a path, ask for the registry host only.
- If the identity slug contains uppercase letters, lowercase it for the Docker path.
- If the Meesho email / identity slug cannot be read from the Drive account, ask the participant. Do not invent it.
- If the image is missing locally, build it first with `hackathon-single-image-build`.
- If Docker is installed but the daemon is unreachable, ask the participant to start Docker Desktop or fix Docker permissions.
- If the image fails the local health check, fix the app or image before pushing.
- If the final image must be judged without a local bind mount, prefer a smoke test without `--data-dir`. Use `--data-dir` only for local development checks.
- If login fails, re-check proxy host, username, and token before retrying.
- If push fails with an authorization or path error, confirm the proxy supports the `USER/USER:TAG` path and that the token is still valid.
