---
name: hackathon-bootstrap
description: "Create or repair a beginner-friendly hackathon starter project using only React.js for the frontend, Node.js or Go for the backend, and SQLite for storage. Use when a participant asks to start a new project, set up their laptop, install required tools, choose the allowed stack, create Docker files, or make the first locally previewable app for a single-image hackathon submission."
---

# Hackathon Bootstrap

## Overview

Help a non-technical participant go from an empty machine or empty folder to a working app they can preview. Keep participant-facing explanations plain, but execute setup with precise terminal checks.

## Allowed Stack

Use only:

- Frontend: React.js
- Backend: Node.js or Go
- Database: SQLite
- Packaging: one Docker image containing app and database startup

Do not introduce any other frontend framework, backend language, database, cache, hosted backend, or separate runtime service unless the organizer changes the rules.

## Workflow

1. Before any other action, check whether `.agent-memory/` already exists in the project root.
2. If `.agent-memory/` exists, run `scripts/recontextualize_agent_memory.sh` or `scripts/recontextualize_agent_memory.ps1`, read the memory files, and summarize the current state before asking new questions. Treat the memory files as the project source of truth for prior decisions, completed steps, blockers, ports, build outputs, registry URLs, and next actions.
3. If `.agent-memory/` does not exist, run `scripts/setup_agent_memory.sh` or `scripts/setup_agent_memory.ps1` to create it immediately.
4. Ask for the app idea only if it is missing from memory. Choose Node.js by default for non-technical teams unless they explicitly ask for Go.
5. Run `scripts/check_and_install_tools.sh` (macOS/Linux) or `scripts/check_and_install_tools.ps1` (Windows) first. Use check mode by default; use `--install`/`-Install` only after the user approves installing software. **The container engine is Docker (Docker Desktop):**
   - **macOS:** use **Docker Desktop**. `--install` installs it via Homebrew (`brew install --cask docker`); open it once (`open -a Docker`) so the engine starts.
   - **Windows:** use **Docker Desktop with the Hyper-V backend** (the default here). If Docker is missing or its daemon will not run, the installer delegates to `scripts/ensure_container_engine.ps1`, which **enables the Hyper-V Windows feature, installs Docker Desktop, and configures the Hyper-V backend** (via winget). Enabling Hyper-V needs **Windows Pro/Enterprise/Education** and a **reboot** before `docker` works. (Windows Home has no Hyper-V — there Docker Desktop must use its WSL2 backend instead.) **After Docker Desktop is freshly installed, `docker` will not be on the current shell's `PATH` — start a new shell (close/reopen the terminal, or restart Claude Code) before running `docker`; retrying in the same session keeps failing because `PATH` is fixed at launch.**
6. Code is submitted as a **zip the participant uploads by hand** — there is no GitHub, no git setup, and no cloud connector. When the team is ready to submit, `hackathon-zip-code` builds a clean source-only zip and tells the participant to upload it to the organizer's designated folder themselves.
7. Create or repair the project so it has `frontend/`, `backend/`, `db/`, `Dockerfile`, `.dockerignore`, `.env.example`, a short `README.md`, and the required `.agent-memory/` files. The Dockerfile must serve the frontend with **nginx** on `9080` and reverse-proxy `/api/` to the backend on `8090` (see the "Frontend ↔ Backend Routing" section of `references/project-contract.md`). The React app must call the backend only via relative `/api/...` paths, and the dev server must proxy `/api` to `http://localhost:8090` so the same code works locally and in the image.
8. Make the first screen usable immediately: a simple app title, one example form, one list view, and an `/api/health` status endpoint. The frontend fetches it as `/api/health` (same origin), never a hardcoded `localhost:8090`.
9. Add local commands that work without explaining internals:
   - `docker build -t hackathon-app:local .`
   - `mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" hackathon-app:local`
10. Verify the app starts before telling the participant it is ready.
11. After every major step, update the memory files:
   - append a timestamped entry to `.agent-memory/activity.md`
   - update `.agent-memory/state.json` when ports, stack, image tags, registry URLs, the code zip path, or status change
   - refresh `.agent-memory/session.md` with the current narrative state
   - refresh `.agent-memory/handoff.md` with the current blocker and next exact action

## Required Ports

- Frontend React app: `9080`
- Backend Node.js or Go API: `8090`

If either port is busy, explain that another program is already using the required door and it must be closed before the app can run.

## Participant Language

Say "I am setting up your app so you can open it in a browser" instead of naming every package. Explain stack choices as "the allowed building blocks for this hackathon."

## Technical Contract

Read `references/project-contract.md` before creating or repairing a starter. The contract defines required ports, folders, env vars, health checks, and the single-image rule.

## Memory Contract

Read `references/memory-contract.md` before first setup and before any resume. Bootstrap must leave the project in a state where a new session can recover the full working context from `.agent-memory/` without depending on chat history.

## Resources

- `scripts/check_and_install_tools.sh`: detect OS, check required tools, optionally install common packages on macOS/Linux (Docker Desktop is the engine).
- `scripts/check_and_install_tools.ps1`: check tools and optionally install common packages on Windows; delegates the container engine to `ensure_container_engine.ps1`.
- `scripts/ensure_container_engine.ps1`: Windows — guarantee a working `docker` engine; starts an existing Docker Desktop, or enables Hyper-V and installs Docker Desktop configured for the Hyper-V backend.
- `scripts/ensure_container_engine.sh`: macOS/Linux — verify a working `docker` engine (Docker Desktop); with `--install`, install it via Homebrew (macOS) or apt (Linux).
- `scripts/setup_agent_memory.sh`: create the required memory files on macOS/Linux.
- `scripts/setup_agent_memory.ps1`: create the required memory files on Windows.
- `scripts/recontextualize_agent_memory.sh`: print the current memory state on macOS/Linux.
- `scripts/recontextualize_agent_memory.ps1`: print the current memory state on Windows.
- `references/project-contract.md`: starter project requirements for all hackathon apps.
- `references/memory-contract.md`: required memory files and update rules.
