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

Do not introduce Next.js, Python, Java, MongoDB, Postgres, Redis, Firebase, Supabase, or separate runtime services unless the organizer changes the rules.

## Workflow

1. Before any other action, check whether `.agent-memory/` already exists in the project root.
2. If `.agent-memory/` exists, run `scripts/recontextualize_agent_memory.sh` or `scripts/recontextualize_agent_memory.ps1`, read the memory files, and summarize the current state before asking new questions. Treat the memory files as the project source of truth for prior decisions, completed steps, blockers, ports, build outputs, registry URLs, and next actions.
3. If `.agent-memory/` does not exist, run `scripts/setup_agent_memory.sh` or `scripts/setup_agent_memory.ps1` to create it immediately.
4. Ask for the app idea only if it is missing from memory. Choose Node.js by default for non-technical teams unless they explicitly ask for Go.
5. Run `scripts/check_and_install_tools.sh` first. Use check mode by default; use `--install` only after the user approves installing software.
6. Set up GitHub login and credentials in one step so pushing never prompts for a password. Once git is installed, run `scripts/setup_git_credentials.sh` (or `.ps1`). It stores a GitHub token in a plain-text file and points git's `store` credential helper at it in the global gitconfig. Two methods are supported:
   - `--method gh` (default, easiest): if the participant is not logged in yet, the script launches the GitHub browser login automatically. Because most participants are already signed in to GitHub in their browser, this is just a one-time code paste plus a single "Authorize" click — no password, no PAT page. It then reuses that token.
   - `--method pat`: paste a classic Personal Access Token from https://github.com/settings/tokens (scope: `repo`). Use this only if the browser login is not possible.
   Explain to participants that this saves a private key on their own machine only and is never committed to the project.
7. Create or repair the project so it has `frontend/`, `backend/`, `db/`, `Dockerfile`, `.dockerignore`, `.env.example`, a short `README.md`, and the required `.agent-memory/` files.
8. Make the first screen usable immediately: a simple app title, one example form, one list view, and one health/status endpoint.
9. Add local commands that work without explaining internals:
   - `docker build -t hackathon-app:local .`
   - `mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" hackathon-app:local`
10. Verify the app starts before telling the participant it is ready.
11. After every major step, update the memory files:
   - append a timestamped entry to `.agent-memory/activity.md`
   - update `.agent-memory/state.json` when ports, stack, image tags, registry URLs, repo URLs, or status change
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

- `scripts/check_and_install_tools.sh`: detect OS, check required tools, optionally install common packages on macOS/Linux.
- `scripts/check_and_install_tools.ps1`: check tools and optionally install common packages on Windows.
- `scripts/setup_git_credentials.sh`: store a GitHub token in a plain-text file and configure git's `store` helper on macOS/Linux. Methods: `--method gh` (reuse `gh auth login` token) or `--method pat` (paste a classic PAT).
- `scripts/setup_git_credentials.ps1`: same GitHub credential setup on Windows. Methods: `-Method gh` or `-Method pat`.
- `scripts/setup_agent_memory.sh`: create the required memory files on macOS/Linux.
- `scripts/setup_agent_memory.ps1`: create the required memory files on Windows.
- `scripts/recontextualize_agent_memory.sh`: print the current memory state on macOS/Linux.
- `scripts/recontextualize_agent_memory.ps1`: print the current memory state on Windows.
- `references/project-contract.md`: starter project requirements for all hackathon apps.
- `references/memory-contract.md`: required memory files and update rules.
