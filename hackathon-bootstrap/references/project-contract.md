# Project Contract

Use this contract when creating or repairing a participant project.

## Required Shape

- `frontend/`: React.js app.
- `backend/`: Node.js or Go API/server.
- `db/`: SQLite schema and seed files, normally `db/init.sql`.
- `Dockerfile`: builds and runs the final single image.
- `.dockerignore`: excludes dependencies, build outputs, git metadata, env files, and local database files.
- `.env.example`: documents configurable values without secrets.
- `README.md`: gives local preview, build, run, and final image commands.
- `.agent-memory/`: durable agent memory directory.

## Runtime Contract

- Frontend listens on port `9080`.
- Backend listens on port `8090`.
- Frontend root path `/` serves the React app at `http://localhost:9080`.
- Backend `/health` returns a simple successful response at `http://localhost:8090/health` after SQLite is ready.
- Backend reads and writes a local SQLite file, normally `data/hackathon.db` or `app.db`.
- Database path defaults to `data/hackathon.db`.
- Memory files must exist in the project root under `.agent-memory/`.

## Port Conflicts

Claude or another agent should configure these ports automatically. If `9080` or `8090` is already used by another local program, tell the participant to close that program or change its port before retrying.
- Credentials are local-only defaults unless the organizer supplies registry/runtime secrets.

## Single Image Rule

The final submission must not require Docker Compose, a separate database container, local source files, local `node_modules`, or a cloud database. Compose is acceptable only for local development.
