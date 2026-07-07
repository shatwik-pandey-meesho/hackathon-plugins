# Combined Deploy Flow

`deploy` is the one skill that finishes a hackathon submission. It orchestrates the four previously
separate steps and then hands off to the live-deploy website. It reuses the existing skills' scripts
so there is a single source of truth for each phase:

- Build → `hackathon-single-image-build/scripts/build_single_image.{sh,ps1}`
- Zip → `hackathon-zip-code/scripts/make_code_zip.{sh,ps1}`
- Push → `hackathon-deploy-by-pushing-image/scripts/push_to_proxy_registry.{sh,ps1}`

The readiness check (README present, secret-content scan, standalone no-bind-mount run) is done
inline by the orchestrator, because the standalone `hackathon-submission-check` script rebuilds the
image without forcing `linux/amd64` — which on an ARM machine would overwrite the correct amd64
image with an arm64 one. The orchestrator's build phase is the single authoritative build.

## Order of operations

1. **Model** — ask the participant to switch to Opus with high reasoning (`/model` → Opus, reasoning
   high) before anything else. Deploy is the highest-stakes step.
2. **Build** — `build_single_image.sh` builds the image for **`linux/amd64`** (always) and smoke-tests
   it with a bind mount on ports `9080`/`8090`. It verifies the produced image is actually
   `linux/amd64` and aborts otherwise.
3. **Check** — inline readiness gate:
   - `README.md` present (warn if missing).
   - No secret-looking content in the tree (private keys, API keys, `password = ...`).
   - The image runs **standalone with no bind mount** and still serves `/` and `/api/health`, proving
     it has no link to the participant's machine.
4. **Zip** — `make_code_zip.sh` builds a clean, source-only `dist/<name>.zip`. It refuses to build if
   secret files (`.env`, `*.pem`, `*.key`, service-account JSON) are present. The participant uploads
   this zip to the organizer's folder **by hand** — nothing is uploaded automatically.
5. **Push** — `push_to_proxy_registry.sh` logs in to the default proxy and pushes
   `registry.buildathon.meesho.dev/TEAM_ID:TAG`. The orchestrator computes `TEAM_ID` (from the email)
   and `TAG` (UTC timestamp) itself and passes `--tag` explicitly, so it knows the exact pushed
   `image_tag`. It also passes `--skip-smoke` because the image was already smoke-tested in steps 2–3.
6. **Deploy** — the orchestrator calls the proxy's deploy API to start the live deployment
   automatically (no website click):

   ```bash
   curl -X POST https://registry.buildathon.meesho.dev/admin/api/deploy \
     -H 'Authorization: Bearer <registry token>' \
     -H 'Content-Type: application/json' \
     -d '{"image_tag":"registry.buildathon.meesho.dev/TEAM_ID:TAG"}'
   ```

   The `Bearer` token is the **same** registry token used for the push (`HACKATHON_PROXY_TOKEN`). The
   deploy API host is the same as the proxy host. A non-2xx response aborts with the response body.
7. **Live link** — the running app is always `https://TEAM_ID.buildathon.ltl.sh`
   (e.g. `arnav-jose` → `https://arnav-jose.buildathon.ltl.sh`). The registry lives on `meesho.dev`;
   only the live apps are served under `ltl.sh`. It may take a minute or two to come up.

## Inputs and defaults

Only two inputs are ever needed from the participant; everything else defaults.

- **Meesho email** — derives the image team id. Pass with `--user` (sh) / `-User` (ps1), or set
  `MEESHO_EMAIL`. Reused from `.agent-memory/state.json` if already present. Never guessed.
- **Registry token** — the password to submit with. Set `HACKATHON_PROXY_TOKEN` (preferred) so it is
  never printed or placed in argv. If unset and a terminal is attached, the orchestrator prompts for
  it silently.

Defaults (do not ask unless overridden):

- Proxy host: `registry.buildathon.meesho.dev` (also the host of the deploy API)
- Login user: `hackathon`
- Local image: `hackathon-app:final`
- Pushed tag: UTC timestamp (e.g. `20260702-091500`)
- Ports: frontend `9080`, backend `8090`
- Platform: `linux/amd64` (always)
- Deploy API: `POST https://registry.buildathon.meesho.dev/admin/api/deploy`
- Live application link: `https://<team-id>.buildathon.ltl.sh`

## Command shape

macOS/Linux:

```bash
HACKATHON_PROXY_TOKEN=<token> ./scripts/deploy.sh --user john.doe@meesho.com
```

Windows PowerShell:

```powershell
$env:HACKATHON_PROXY_TOKEN = "<token>"
.\scripts\deploy.ps1 -User priya.sharma@meesho.com
```

Useful flags (both platforms): `--image`/`-Image`, `--name`/`-Name` (zip name), `--tag`/`-Tag`,
`--skip-zip`/`-SkipZip`, `--skip-push`/`-SkipPush`, `--skip-deploy`/`-SkipDeploy` (push but don't
start the live deployment).

Windows-only container-engine flags: `-SkipEngineInstall` (do not auto-install an engine if
`docker` is unavailable) and `-PreferRancher` (skip Docker Desktop and use the Rancher Desktop
`dockerd (moby)` engine).

## Edge cases

- **No Dockerfile** — the app isn't packaged yet; build the app first, then deploy.
- **No container engine / engine not running** — never install Docker; use it if present, else
  install **Rancher Desktop**. If a `docker` command already works (Docker Desktop or Rancher
  Desktop's moby engine), the orchestrator uses it. If the engine is installed but stopped, start
  it (open Rancher Desktop, or Docker Desktop if that is what you have) and retry. If nothing is
  installed: on **macOS** open the **iru self-service** portal, go to the **All** section, and
  install **Rancher Desktop** + **Node.js** (pick the `dockerd (moby)` engine); on **Windows**,
  `deploy.ps1` auto-runs `hackathon-bootstrap/scripts/ensure_container_engine.ps1` to enable WSL2
  and install Rancher Desktop (moby). A fresh WSL2 enable usually needs a **reboot** first.
- **Port 9080/8090 busy** — free the port (or set `FRONTEND_PORT`/`BACKEND_PORT`) before retrying;
  never push an unverified image.
- **Secret file present** — the zip step refuses; remove/rename it (an `.env.example` is allowed).
- **ARM machine (Apple Silicon)** — the amd64 build runs under emulation (slower but correct); the
  build aborts if the result is not `linux/amd64`.
- **Login/push fails** — re-check the token and that the Meesho email yields a valid team id; retry.
- **Deploy API fails (non-2xx or unreachable)** — confirm the push reported success (the `image_tag`
  must already exist in the registry), the token is still valid, and the network can reach
  `registry.buildathon.meesho.dev`; then re-run (use `--skip-zip`/`--skip-push` to jump straight to
  the deploy if the image is already pushed, or re-run the curl by hand).
- **Live link doesn't load yet** — the deploy takes a minute or two; wait and refresh
  `https://<team-id>.buildathon.ltl.sh`.
- **Token must never be printed** — pass it only through `HACKATHON_PROXY_TOKEN`; the deploy step
  sends it only as an `Authorization: Bearer` header.
