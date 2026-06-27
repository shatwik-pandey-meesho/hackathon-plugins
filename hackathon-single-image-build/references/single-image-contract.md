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
