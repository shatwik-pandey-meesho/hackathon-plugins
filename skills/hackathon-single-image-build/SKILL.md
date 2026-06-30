---
name: hackathon-single-image-build
description: "Build and smoke-test the final required single Docker image for a hackathon app containing React frontend assets, Node.js or Go backend runtime, and SQLite initialization behavior. Use when a participant asks to build the final image, prepare for judging, package frontend/backend/database together, create a Dockerfile, test docker run, or produce the image tag that will be pushed to a registry."
---

# Hackathon Single Image Build

## Overview

Package the whole project into one runnable image for judges. The goal is not production-perfect architecture; it is a reliable judging artifact that starts from one image.

## Workflow

1. Read `references/single-image-contract.md`.
2. Before building, ask the participant: "Is this the final image for submission?"
   - If yes, ask the data question before building: "Should the image start with a clean, empty database, or should it carry a copy of your current saved data baked inside?" Explain the trade-off in plain language:
     - **Clean start (default, recommended):** the image ships with no records. It builds the schema fresh from `db/init.sql` on first run, so judges always see a predictable empty app. Nothing is linked to your machine.
     - **Baked-in data (self-contained snapshot):** the current `data/hackathon.db` is copied into the image at build time, so judges see your existing records even when they run the image with no folder mounted. Use this only when the demo needs pre-filled data.
   - Either way, the final image must run standalone with `docker run` and no bind mount and no link to the participant's machine. Follow the data-mode steps in `references/single-image-contract.md`.
3. Inspect `Dockerfile`, `.dockerignore`, `frontend/`, `backend/`, and `db/`.
4. If missing, create a Dockerfile that builds React, builds Node.js or Go, initializes the SQLite schema, and starts the app. Use Debian slim base images only (`node:20-bookworm-slim` for Node stages, `golang:1.22-bookworm` + `debian:bookworm-slim` for Go). Never use Alpine because musl libc breaks SQLite native builds for beginners. For Node backends using native SQLite packages such as `better-sqlite3`, install `python3`, `make`, and `g++` in the build stage before `npm install` or `npm ci`.
5. Run `scripts/build_single_image.sh <image-name>:<tag>`.
6. Confirm the container starts and `GET /health` or the root page responds. For a final image, verify it also starts with no bind mount (`docker run --rm -p 9080:9080 -p 8090:8090 IMAGE`) so it has no link to the participant's machine.
7. Report the image tag, the chosen data mode (clean start or baked-in data), and the exact `docker run` command.

## Required Behavior

- One image is enough to run the project.
- The frontend listens on container port `9080`.
- The backend listens on container port `8090`.
- SQLite data must live under `/app/data` in the container, with the repo's local `data/` directory bind-mounted there for preview, smoke tests, and judging.
- The image must not require local source files after build.
- Do not rely on Docker Compose for final judging unless the organizer explicitly permits it.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before building.
- After each build attempt, record the image tag, run command, ports, and outcome in `.agent-memory/`.

## Resources

- `scripts/build_single_image.sh`: build and smoke-test the final Docker image.
- `references/single-image-contract.md`: exact packaging expectations.
