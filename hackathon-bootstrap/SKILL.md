---
name: hackathon-bootstrap
description: "Create or repair a beginner-friendly hackathon starter project using only React.js for the frontend, Node.js or Go for the backend, and MySQL for storage. Use when a participant asks to start a new project, set up their laptop, install required tools, choose the allowed stack, create Docker files, or make the first locally previewable app for a single-image hackathon submission."
---

# Hackathon Bootstrap

## Overview

Help a non-technical participant go from an empty machine or empty folder to a working app they can preview. Keep participant-facing explanations plain, but execute setup with precise terminal checks.

## Allowed Stack

Use only:

- Frontend: React.js
- Backend: Node.js or Go
- Database: MySQL
- Packaging: one Docker image containing app and database startup

Do not introduce Next.js, Python, Java, MongoDB, Postgres, Redis, Firebase, Supabase, or separate runtime services unless the organizer changes the rules.

## Workflow

1. Ask for the app idea only if it is missing. Choose Node.js by default for non-technical teams unless they explicitly ask for Go.
2. Run `scripts/check_and_install_tools.sh` first. Use check mode by default; use `--install` only after the user approves installing software.
3. Create or repair the project so it has `frontend/`, `backend/`, `db/`, `Dockerfile`, `.dockerignore`, `.env.example`, and a short `README.md`.
4. Make the first screen usable immediately: a simple app title, one example form, one list view, and one health/status endpoint.
5. Add local commands that work without explaining internals:
   - `docker build -t hackathon-app:local .`
   - `docker run --rm -p 8080:8080 hackathon-app:local`
6. Verify the app starts before telling the participant it is ready.

## Participant Language

Say "I am setting up your app so you can open it in a browser" instead of naming every package. Explain stack choices as "the allowed building blocks for this hackathon."

## Technical Contract

Read `references/project-contract.md` before creating or repairing a starter. The contract defines required ports, folders, env vars, health checks, and the single-image rule.

## Resources

- `scripts/check_and_install_tools.sh`: detect OS, check required tools, optionally install common packages.
- `references/project-contract.md`: starter project requirements for all hackathon apps.
