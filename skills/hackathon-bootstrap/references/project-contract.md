# Project Contract

Use this contract when creating or repairing a participant project.

## Required Shape

- `frontend/`: React.js app.
- `backend/`: Node.js or Go API/server.
- `db/`: SQLite schema and seed files, normally `db/init.sql`.
- `Dockerfile`: builds and runs the final single image. Use Debian slim base images only (`node:20-bookworm-slim` for Node stages; `golang:1.22-bookworm` build + `debian:bookworm-slim` runtime for Go). Do not use Alpine because musl libc breaks SQLite native builds. For Node backends using native SQLite packages such as `better-sqlite3`, install build prerequisites in the build stage: `python3`, `make`, and `g++`.
- `.dockerignore`: excludes dependencies, build outputs, git metadata, env files, and local database files.
- `.env.example`: documents configurable values without secrets.
- `README.md`: gives local preview, build, run, and final image commands.
- `.agent-memory/`: durable agent memory directory.

## Runtime Contract

- Frontend is served by **nginx** on port `9080`. nginx serves the built React app at `/` and
  reverse-proxies `/api/` to the backend (see "Frontend ↔ Backend Routing").
- Backend listens on port `8090`.
- Frontend root path `/` serves the React app at `http://localhost:9080`.
- Backend exposes `GET /api/health`, reachable through nginx at `http://localhost:9080/api/health`
  after SQLite is ready. A direct `http://localhost:8090/api/health` also works.
- Backend reads and writes a local SQLite file at `/app/data/hackathon.db` inside Docker.
- Local preview and final run commands must bind-mount the repo's `data/` directory to `/app/data` so data survives `docker run --rm` restarts: `-v "$(pwd)/data:/app/data"`.
- Database path defaults to `/app/data/hackathon.db` in Docker and `data/hackathon.db` outside Docker.
- Memory files must exist in the project root under `.agent-memory/`.

## Frontend ↔ Backend Routing (MUST FOLLOW)

This is mandatory for every project, dev and image alike. It is what lets the app work behind
any randomly assigned domain or subdomain at judging.

- The frontend talks to the backend **only** through the relative, same-origin path `/api/...`.
  Example: `fetch('/api/recipes')`, never `fetch('http://localhost:8090/recipes')`.
- The frontend must **never** hardcode a host, port, or absolute backend URL, and must not read
  one from an env var baked at build time. Same origin + `/api` prefix, always.
- All backend routes live under the `/api/` prefix (including `/api/health`).
- **In the final image**, nginx (port `9080`) reverse-proxies `/api/` to the backend on
  `127.0.0.1:8090`, preserving the `/api` prefix, and serves the React build for everything else
  with an SPA fallback to `index.html`.
- **In local dev**, the React dev server proxies `/api` to `http://localhost:8090` so the exact
  same `/api` frontend code runs unchanged in dev and in the image.
- Port `8090` may still be exposed for direct debugging, but the app's own frontend→backend
  traffic always goes through nginx `/api`. Do not point the frontend at `8090` directly.

## Port Conflicts

Claude or another agent should configure these ports automatically. If `9080` or `8090` is already used by another local program, tell the participant to close that program or change its port before retrying.
- Credentials are local-only defaults unless the organizer supplies registry/runtime secrets.

## Backend Secrets / Third-Party Tokens

This applies to the **backend** only, and is separate from the frontend routing rule above (the frontend still must never bake a backend URL).

- If the backend calls a third-party API that needs a token or key, the final image must carry that value itself. Judges run the image with a plain `docker run` and pass **no** environment variables and no `--env-file`, so nothing is injected at container start.
- Bake the token into the **Dockerfile runtime stage** with an `ENV` line (for example `ENV THIRD_PARTY_API_KEY=...`) so the image is self-sufficient. The backend reads it via `process.env.THIRD_PARTY_API_KEY` (Node) or `os.Getenv(...)` (Go).
- A local `.env` file / `.env.example` is fine for development, but its values must also be baked into the image for the final build — do not rely on the `.env` file at judging time.
- Use a throwaway/test key that is safe to expose: a baked-in token is readable from the image (`docker history`, `docker inspect`). Never bake a personal, billing-enabled, or production key, and keep the real value out of the committed repo. Rotate or revoke it after judging.
- See "Third-Party API Tokens / Env" in the `hackathon-single-image-build` skill's `single-image-contract.md` for the full detail.

## Single Image Rule

The final submission must not require Docker Compose, a separate database container, local source files, local `node_modules`, or a cloud database. A repo-local `data/` bind mount is allowed for runtime SQLite persistence and must not be committed. Compose is acceptable only for local development.
