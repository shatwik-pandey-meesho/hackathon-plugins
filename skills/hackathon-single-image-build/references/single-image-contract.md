# Single Image Contract

The final image must include everything judges need to start the project.

## Target Platform (MUST FOLLOW — fixed at all cost)

- The image **must always** be built and run for **`linux/amd64`**. Deployment supports only amd64 Linux; there is no exception.
- Always pass `--platform linux/amd64` to `docker build` and `docker run`, and prefer exporting `DOCKER_DEFAULT_PLATFORM=linux/amd64` for the build.
- On Apple Silicon (M1/M2/M3) or any ARM host, a default `docker build` produces an **arm64** image that starts locally but **fails on the amd64 deployment**. Forcing the platform prevents this. ARM hosts build/run amd64 under emulation, which is slower but correct.
- To confirm what was actually produced: `docker image inspect <image> --format '{{.Os}}/{{.Architecture}}'` must print `linux/amd64`.

## Required

- React production build copied into the runtime image and served by **nginx**.
- Node.js server or Go binary in the runtime image.
- **nginx** installed in the runtime image, listening on port `9080`, serving the React build at
  `/` with an SPA fallback and reverse-proxying `/api/` to the backend on `127.0.0.1:8090`.
- SQLite runtime support installed in the image only if the backend needs the `sqlite3` CLI at runtime.
- Database initialization from `db/init.sql` or equivalent, without overwriting an existing database in `/app/data`.
- Startup script that creates `/app/data`, creates the SQLite database file, starts the backend on
  `8090`, then starts nginx in the foreground — and leaves existing data intact.
- Frontend (nginx) listens on port `9080`.
- Backend listens on port `8090`.
- `GET /api/health` succeeds **through nginx** at `http://localhost:9080/api/health` after startup.

## nginx + /api Routing (MUST FOLLOW — fixed at all cost)

The frontend must reach the backend only through nginx at the relative path `/api/`, never a
hardcoded host or port. This is what keeps the app working behind any randomly assigned domain or
subdomain at judging. Two ports stay open (`9080` for nginx, `8090` for the backend), but the
app's frontend→backend traffic always goes through nginx `/api`.

Required pieces in the image:

- The React build calls the backend with same-origin relative paths like `/api/...`.
- All backend routes are under `/api/` (including `/api/health`).
- nginx config (for example `/etc/nginx/conf.d/default.conf`):

  ```nginx
  server {
      listen 9080;
      server_name _;
      root /app/frontend;            # React build output (index.html, assets)
      index index.html;

      # App API: preserve the /api prefix and forward to the backend.
      location /api/ {
          proxy_pass http://127.0.0.1:8090;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }

      # SPA fallback so client-side routes work on refresh.
      location / {
          try_files $uri $uri/ /index.html;
      }
  }
  ```

- The `proxy_pass` has **no trailing slash**, so `/api/recipes` reaches the backend as
  `/api/recipes` (prefix preserved). Keep backend routes under `/api/` to match.
- Do not bake an absolute backend URL into the frontend at build time. The same `/api` code must
  run unchanged locally (dev-server proxy) and in the image (nginx proxy).

## Final Image Data Mode

When the participant confirms this is the final submission image, decide the data mode with them before building. The final image must run standalone with `docker run` and no bind mount, so it cannot depend on the participant's local `data/` directory.

### Clean start (default, recommended)

- Do not copy `data/hackathon.db` into the image.
- Keep `data/` excluded in `.dockerignore` so no host database is captured.
- The entrypoint creates `/app/data` and initializes a fresh database from `db/init.sql` on first run.
- Judges always see a predictable empty app; nothing links back to the participant's machine.

### Baked-in data (self-contained snapshot)

- Use only when the demo must show pre-filled records without any mount.
- Build with a current, clean `data/hackathon.db` (no secrets, only obviously fake/demo data).
- Copy it into the image explicitly, for example `COPY data/hackathon.db /app/data/hackathon.db`. If `data/` is in `.dockerignore`, force-include just the database file (for example `!data/hackathon.db`) rather than un-ignoring the whole directory.
- The entrypoint must still create `/app/data` if absent and must not overwrite an existing database file, so the baked-in data survives startup.
- Document the baked-in data in the README so judges know the records are intentional.

In both modes, the standalone run command for judging is `docker run --rm -p 9080:9080 -p 8090:8090 IMAGE`. The repo-local `data/` bind mount remains available for local development and preview but is not required for the final image.

## Third-Party API Tokens / Env (MUST FOLLOW — the image is self-sufficient)

Judges run the final image with a plain `docker run` and **pass no environment variables and no `--env-file`**. So if the app needs a third-party API token or key (for example an OpenAI/Gemini key, a maps key, a payments test key), the image must already contain it — nothing is injected at container start.

- **Bake the value into the Dockerfile with an `ENV` line** so it ships inside the image and is present at runtime with zero setup:

  ```dockerfile
  # Third-party token baked in so the image runs standalone (judges set no env).
  ENV THIRD_PARTY_API_KEY=sk-the-actual-demo-key
  ENV THIRD_PARTY_API_BASE_URL=https://api.example.com
  ```

- Put these `ENV` lines in the **runtime stage** (the final stage) so they persist in the image the judges run. An `ENV` in an earlier build stage does not carry over.
- The backend must read the token from `process.env.THIRD_PARTY_API_KEY` (Node) or `os.Getenv("THIRD_PARTY_API_KEY")` (Go) — the same name as the baked `ENV` — with a clear failure message if it is empty, so a missing key is obvious during the smoke test.
- Do **not** rely on a local `.env` file, a bind-mounted secret, or `docker run -e ...`. The `.env` file is fine for local development, but its values must also be baked into the image for the final build, because judges will not supply it.
- **Use a throwaway / low-limit / test key that is safe to expose.** A baked-in token is readable by anyone who has the image (`docker history`, `docker inspect`), so treat it as public. Never bake a personal, billing-enabled, or production key. Rotate or revoke it after judging.
- Keep the real values out of the git repo — bake them only into the image. The submission code zip and README should reference the variable name, not the secret value.

## Base Image

- All stages must use Debian slim base images. Do not use Alpine.
- Node stages: use `node:20-bookworm-slim` (Debian 12 "bookworm", slim).
- Go build stage: use `golang:1.22-bookworm`; final runtime stage: use `debian:bookworm-slim`.
- Reason: Alpine uses musl libc, which frequently breaks the SQLite native build (`better-sqlite3`) and CGO-based Go SQLite drivers. Debian slim ships glibc and "just works" for beginners while staying small.
- `node:20-bookworm-slim` does not include native addon build tools. If the backend uses `better-sqlite3`, `sqlite3`, or another native package, install `python3`, `make`, and `g++` in the Node build stage before running `npm install` or `npm ci`.
- Pin the major version in the tag (for example `node:20-bookworm-slim`, not `node:latest`) so builds are reproducible for judges.

## Recommended Runtime Pattern

- Use a multi-stage Dockerfile.
- Build frontend in a `node:20-bookworm-slim` stage; copy its build output (e.g. `dist/` or
  `build/`) into `/app/frontend` in the runtime stage where nginx serves it.
- Build backend in a `node:20-bookworm-slim` (Node) or `golang:1.22-bookworm` (Go) stage.
- For Go, copy only the compiled binary into a `debian:bookworm-slim` runtime stage.
- Install nginx in the runtime stage (`apt-get install -y nginx`) and add the config above.
- Use a small entrypoint that initializes the database, starts the backend on `8090` in the
  background, then runs nginx in the foreground (so the container's main process is nginx):

  ```sh
  #!/bin/sh
  set -e
  mkdir -p /app/data
  # initialize SQLite from db/init.sql only if the database does not exist yet
  [ -f /app/data/hackathon.db ] || sqlite3 /app/data/hackathon.db < /app/db/init.sql
  # start the backend on 8090 in the background...
  node /app/backend/server.js &        # (or: /app/backend/server &  for a Go binary)
  # ...then nginx in the foreground on 9080
  nginx -g 'daemon off;'
  ```

- Set the runtime database path to `/app/data/hackathon.db`.
- Run containers with `mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" IMAGE` so SQLite persists in the repo's ignored `data/` directory.
- Verify with `curl http://localhost:9080/` (frontend) and `curl http://localhost:9080/api/health`
  (backend through nginx). The second call is the proof that `/api` proxying works.

## Not Allowed For Final Submission

- Requiring Docker Compose.
- Requiring a separate database container.
- Requiring a managed cloud database.
- Requiring local source files mounted into the container. Mounting the repo-local `data/` directory for SQLite persistence is allowed because it is runtime data, not source code.
