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
   `registry.buildathon.ltl.sh/TEAM_ID:TAG`. The orchestrator passes `--skip-smoke` because the image
   was already smoke-tested in steps 2–3.
6. **Go live** — open `https://buildathon.ltl.sh`, log in, click **Deploy Live**, and wait for the
   live link.

## Inputs and defaults

Only two inputs are ever needed from the participant; everything else defaults.

- **Meesho email** — derives the image team id. Pass with `--user` (sh) / `-User` (ps1), or set
  `MEESHO_EMAIL`. Reused from `.agent-memory/state.json` if already present. Never guessed.
- **Registry token** — the password to submit with. Set `HACKATHON_PROXY_TOKEN` (preferred) so it is
  never printed or placed in argv. If unset and a terminal is attached, the orchestrator prompts for
  it silently.

Defaults (do not ask unless overridden):

- Proxy host: `registry.buildathon.ltl.sh`
- Login user: `hackathon`
- Local image: `hackathon-app:final`
- Pushed tag: UTC timestamp (e.g. `20260702-091500`)
- Ports: frontend `9080`, backend `8090`
- Platform: `linux/amd64` (always)

## Command shape

macOS/Linux:

```bash
HACKATHON_PROXY_TOKEN=<token> ./scripts/deploy.sh --user priya.sharma@meesho.com
```

Windows PowerShell:

```powershell
$env:HACKATHON_PROXY_TOKEN = "<token>"
.\scripts\deploy.ps1 -User priya.sharma@meesho.com
```

Useful flags (both platforms): `--image`/`-Image`, `--name`/`-Name` (zip name), `--tag`/`-Tag`,
`--skip-zip`/`-SkipZip`, `--skip-push`/`-SkipPush`.

## Edge cases

- **No Dockerfile** — the app isn't packaged yet; build the app first, then deploy.
- **Docker daemon not running** — start Docker Desktop, then retry.
- **Port 9080/8090 busy** — free the port (or set `FRONTEND_PORT`/`BACKEND_PORT`) before retrying;
  never push an unverified image.
- **Secret file present** — the zip step refuses; remove/rename it (an `.env.example` is allowed).
- **ARM machine (Apple Silicon)** — the amd64 build runs under emulation (slower but correct); the
  build aborts if the result is not `linux/amd64`.
- **Login/push fails** — re-check the token and that the Meesho email yields a valid team id; retry.
- **Live link doesn't appear** — confirm the push reported success and the participant is logged in
  at `buildathon.ltl.sh`, then click **Deploy Live** again.
- **Token must never be printed** — pass it only through `HACKATHON_PROXY_TOKEN`.
