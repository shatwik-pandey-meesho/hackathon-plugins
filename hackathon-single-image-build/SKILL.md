---
name: hackathon-single-image-build
description: "Build and smoke-test the final required single Docker image for a hackathon app containing React frontend assets, Node.js or Go backend runtime, and SQLite initialization behavior. Use when a participant asks to build the final image, prepare for judging, package frontend/backend/database together, create a Dockerfile, test docker run, or produce the image tag that will be pushed to a registry or swarm."
---

# Hackathon Single Image Build

## Overview

Package the whole project into one runnable image for judges. The goal is not production-perfect architecture; it is a reliable judging artifact that starts from one image.

## Workflow

1. Read `references/single-image-contract.md`.
2. Inspect `Dockerfile`, `.dockerignore`, `frontend/`, `backend/`, and `db/`.
3. If missing, create a Dockerfile that builds React, builds Node.js or Go, initializes the SQLite schema, and starts the app.
4. Run `scripts/build_single_image.sh <image-name>:<tag>`.
5. Confirm the container starts and `GET /health` or the root page responds.
6. Report the image tag and exact `docker run` command.

## Required Behavior

- One image is enough to run the project.
- The frontend listens on container port `9080`.
- The backend listens on container port `8090`.
- SQLite data may be ephemeral for judging unless the rules require persistent volume support.
- The image must not require local source files after build.
- Do not rely on Docker Compose for final judging unless the organizer explicitly permits it.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before building.
- After each build attempt, record the image tag, run command, ports, and outcome in `.agent-memory/`.

## Resources

- `scripts/build_single_image.sh`: build and smoke-test the final Docker image.
- `references/single-image-contract.md`: exact packaging expectations.
