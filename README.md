# Hackathon Skill Pack

This repo contains agent skills for a restricted-stack hackathon where teams build one final Docker image.

Allowed stack:

- React.js frontend
- Node.js or Go backend
- SQLite database
- One final Docker image for judging

Required local ports:

- Frontend React app: `9080`
- Backend Node.js or Go API: `8090`

Claude or another agent should handle these ports during setup. If either port is already used by another program, that program must be closed or moved before the prototype can run correctly.

## Skills

- `hackathon-bootstrap`: set up tools and create/repair the starter app.
- `hackathon-feature-builder`: add features from plain-language requests.
- `hackathon-preview`: run the app locally and provide a browser URL.
- `hackathon-bugfix`: diagnose and fix common app, Docker, and database failures.
- `hackathon-db-helper`: make safe SQLite schema and data changes.
- `hackathon-single-image-build`: build and smoke-test the final image.
- `hackathon-gcp-push`: push the image to GCP Artifact Registry and print Swarm commands.
- `hackathon-github`: save the project to GitHub without committing secrets.
- `hackathon-submission-check`: run the final judging readiness checklist.
- `hackathon-explainer`: explain technical results in non-technical language.

## Script Safety

Scripts default to checks where possible. Installing packages, creating cloud repositories, and pushing images should be run only after the participant or organizer confirms the action.

## Agent Compatibility

These skills are usable by Codex, Claude, Gemini, or another terminal-capable agent because the important instructions live in plain Markdown and the automation lives in Bash and PowerShell scripts.

- Codex: can use each `SKILL.md` as a native skill folder. `agents/openai.yaml` provides Codex UI metadata.
- Claude or Gemini: can use the same folders when their agent runner is told to read the relevant `SKILL.md`, follow linked `references/`, and run scripts from `scripts/`.
- Any terminal agent: should be given the repo path, the relevant skill folder, and permission rules for installs, Docker, GitHub, and GCP.

The only Codex-specific file is `agents/openai.yaml`. The workflows, references, and scripts are tool-agnostic.

Windows participants can use the PowerShell scripts in each `scripts/` folder. macOS and Linux participants can use the Bash scripts.

## Installing

Use the repo installer scripts:

- macOS/Linux: `./scripts/install-skills.sh --agent codex`
- Windows PowerShell: `.\scripts\install-skills.ps1 -Agent codex`

For Claude, copy the skill folders into a destination directory:

- macOS/Linux: `./scripts/install-skills.sh --agent claude --dest "$HOME/claude-skills"`
- Windows PowerShell: `.\scripts\install-skills.ps1 -Agent claude -Dest "$HOME\claude-skills"`

See [INSTALLING.md](/Users/shatwik.pandey/Projects/BUILDATHON/skills/INSTALLING.md) for the full method and options.
