# Single Image Contract

The final image must include everything judges need to start the project.

## Required

- React production build copied into the runtime image.
- Node.js server or Go binary in the runtime image.
- SQLite runtime support installed in the image only if the backend needs the `sqlite3` CLI at runtime.
- Database initialization from `db/init.sql` or equivalent, without overwriting an existing database in `/app/data`.
- Startup script that creates `/app/data`, creates the SQLite database file before starting the app, and leaves existing data intact.
- Frontend listens on port `9080`.
- Backend listens on port `8090`.
- Backend `/health` succeeds after startup.

## Base Image

- All stages must use Debian slim base images. Do not use Alpine.
- Node stages: use `node:20-bookworm-slim` (Debian 12 "bookworm", slim).
- Go build stage: use `golang:1.22-bookworm`; final runtime stage: use `debian:bookworm-slim`.
- Reason: Alpine uses musl libc, which frequently breaks the SQLite native build (`better-sqlite3`) and CGO-based Go SQLite drivers. Debian slim ships glibc and "just works" for beginners while staying small.
- `node:20-bookworm-slim` does not include native addon build tools. If the backend uses `better-sqlite3`, `sqlite3`, or another native package, install `python3`, `make`, and `g++` in the Node build stage before running `npm install` or `npm ci`.
- Pin the major version in the tag (for example `node:20-bookworm-slim`, not `node:latest`) so builds are reproducible for judges.

## Recommended Runtime Pattern

- Use a multi-stage Dockerfile.
- Build frontend in a `node:20-bookworm-slim` stage.
- Build backend in a `node:20-bookworm-slim` (Node) or `golang:1.22-bookworm` (Go) stage.
- For Go, copy only the compiled binary into a `debian:bookworm-slim` runtime stage.
- Use a simple entrypoint script when database initialization must happen before the app starts.
- Set the runtime database path to `/app/data/hackathon.db`.
- Run containers with `mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" IMAGE` so SQLite persists in the repo's ignored `data/` directory.

## Not Allowed For Final Submission

- Requiring Docker Compose.
- Requiring a separate database container.
- Requiring a managed cloud database.
- Requiring local source files mounted into the container. Mounting the repo-local `data/` directory for SQLite persistence is allowed because it is runtime data, not source code.
