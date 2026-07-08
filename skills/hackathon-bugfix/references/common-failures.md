# Common Failures

## Blank Page

- Check browser console or build output.
- Check React build base path and that API calls use the relative `/api/...` path.
- Verify nginx serves the frontend on port `9080` and that `try_files ... /index.html` is present so SPA routes do not 404 on refresh.
- Verify the frontend calls the backend through the relative `/api/...` path, NOT a hardcoded `http://localhost:8090`. A hardcoded host/port breaks the app once it is deployed on a different domain/subdomain.

## API Calls 404 / "Not Found" / CORS errors (deployed or local)

- Confirm the frontend uses same-origin relative paths like `/api/recipes`, never an absolute backend URL.
- Confirm nginx has a `location /api/ { proxy_pass http://127.0.0.1:8090; }` block (no trailing slash, so the `/api` prefix is preserved) and that backend routes live under `/api/`.
- Confirm `http://localhost:9080/api/health` responds (backend reached through nginx). If `:8090/api/health` works but `:9080/api/health` does not, nginx is not proxying — fix the nginx config.
- In local dev, confirm the React dev server proxies `/api` to `http://localhost:8090`; otherwise dev `/api` calls fail even though the image works.
- CORS errors almost always mean the frontend is calling an absolute cross-origin URL instead of same-origin `/api` — switch it to `/api`.

## Button Does Nothing

- Check click handler exists.
- Check network request path.
- Check backend route method matches frontend request.
- Check JSON body parsing in backend.

## Data Does Not Save

- Check the SQLite database file exists or can be created.
- If data disappears after restart, check that Docker is run with the repo-local mount `-v "$(pwd)/data:/app/data"` and that the backend writes to `/app/data/hackathon.db`, not a database baked into the image layer.
- Check env vars match backend config.
- Check SQL table and column names.
- Check backend uses parameterized insert/update queries.

## Docker Build Fails

- Check `.dockerignore` is not excluding required files.
- Check frontend and backend install commands.
- Check the Dockerfile matches Node.js or Go backend.
- Check all Docker stages use Debian slim images, not Alpine.
- For Node SQLite packages such as `better-sqlite3`, check the build stage installs `python3`, `make`, and `g++` before `npm install` or `npm ci`.

## Container Starts Then Exits

- Check entrypoint logs.
- Check SQLite database initialization path and file permissions under `/app/data`.
- Check the startup script creates `/app/data` but does not overwrite an existing database file.
- Check the entrypoint starts the backend in the background and then runs `nginx -g 'daemon off;'` in the foreground, so nginx is the container's main process and the container does not exit immediately.
- Check `nginx` is installed in the runtime stage and its config is copied to `/etc/nginx/conf.d/`.
- Check frontend port `9080` (nginx) and backend port `8090` are exposed and not already used by another program.

## Docker Will Not Start

The container engine is **Docker Desktop** on every OS.

### macOS
- If it is installed but the engine is stopped, start it: `open -a Docker` and wait for the whale icon to settle.
- If it is not installed, install Docker Desktop (`brew install --cask docker`, or from https://www.docker.com/products/docker-desktop/), then open it once.

### Windows (Docker Desktop + Hyper-V backend)
- Windows uses **Docker Desktop with the Hyper-V backend** by default. Hyper-V needs virtualization enabled in BIOS and is available on **Windows Pro/Enterprise/Education** (not Home).
- If Docker is present but not running, start **Docker Desktop** and wait for it to finish.
- If Docker is missing, or Hyper-V is not enabled: run `hackathon-bootstrap/scripts/ensure_container_engine.ps1 -Install`. It starts an existing Docker Desktop, or enables the **Hyper-V** and **Containers** Windows features and installs Docker Desktop configured for the Hyper-V backend. Enabling Hyper-V needs an **Administrator** PowerShell and a **reboot** before the engine works.
- To enable Hyper-V by hand (Administrator PowerShell), then reboot:
  - `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart`
  - `Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart`
- Confirm the backend: in Docker Desktop, **Settings → General → "Use the WSL 2 based engine" should be UNCHECKED** so it runs on Hyper-V.
- **Windows Home** has no Hyper-V. There, Docker Desktop must use its **WSL2** backend instead: run `wsl --install` (Administrator), reboot, then install Docker Desktop and leave the default WSL2 engine enabled.

### Windows login/push fails after Docker Desktop is running (credsStore)
- Docker Desktop on Windows writes `"credsStore": "desktop"` into `%USERPROFILE%\.docker\config.json`. This very commonly breaks `docker login`/`docker push` to the proxy (errors like `error storing credentials`, `The stub received bad data`, or a credential-helper failure).
- Fix: remove the `"credsStore": "desktop",` line from `%USERPROFILE%\.docker\config.json`, then log in and push again. The push script does this automatically (it backs the file up to `config.json.bak` first), so a normal deploy handles it — but if you are running `docker login`/`docker push` by hand and it fails, edit that file.
- **Run the retry in a NEW shell.** After editing the config (or after a fresh Docker Desktop install that changed `PATH`), the current shell can hold stale `PATH`/credential state. If `docker` is "not found" or login still fails in the **same** session, stop retrying there — a running process inherits `PATH` at launch and cannot refresh it mid-run. **Close and reopen the terminal, or restart Claude Code, then rerun.** (This is why an agent that keeps retrying in the same session appears "stuck" even after the config is fixed.)

### Linux
- Start the docker service (`sudo systemctl start docker`) and ensure your user is in the `docker` group. Install with `sudo apt-get install -y docker.io docker-compose-plugin` if missing.

## Proxy Push Fails

- Check Docker Desktop is running and `docker info` works. On Windows this is Docker Desktop with the Hyper-V backend; see "Docker Will Not Start" above.
- **Windows credsStore error** (`error storing credentials`, `The stub received bad data`, or credential-helper failures on `docker login`/`docker push`): remove the `"credsStore": "desktop",` line from `%USERPROFILE%\.docker\config.json` and retry. The push script does this automatically (backing up to `config.json.bak`).
- Check the proxy host is only the registry host, with no `https://` prefix and no path.
- Check the Docker login username and token are the organizer-provided values.
- Check the local image exists before tagging.
- Check the image passes the local health check: frontend `http://localhost:9080/` and backend through nginx `http://localhost:9080/api/health`.
- Check the final tag uses the email-derived team ID and timestamp path: `registry.buildathon.meesho.dev/TEAM_ID:TIMESTAMP`.

## Code Zip Fails

- If the zip is rejected for secrets, remove the `.env`/key/`*.db` files it reported (an `.env.example` is allowed) and rebuild with `hackathon-zip-code`.
- If `zip` is "not found", install it (macOS ships it; Debian/Ubuntu: `sudo apt-get install zip`). On Windows the script uses the built-in `Compress-Archive`, so no install is needed.
- If the zip is unexpectedly large (over 50 MB), a heavy folder slipped in — confirm `node_modules/`, `data/`, and build output are excluded, then rebuild.
- The zip is uploaded by the participant by hand to the organizer's folder; the skill never uploads. If the upload itself fails, that is an organizer-side / browser issue, not a skill bug.
