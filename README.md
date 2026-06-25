# Hackathon Skill Pack

This repo contains agent skills for a restricted-stack hackathon where teams build one final Docker image.

Allowed stack:

- React.js frontend
- Node.js or Go backend
- MySQL database
- One final Docker image for judging

## Skills

- `hackathon-bootstrap`: set up tools and create/repair the starter app.
- `hackathon-feature-builder`: add features from plain-language requests.
- `hackathon-preview`: run the app locally and provide a browser URL.
- `hackathon-bugfix`: diagnose and fix common app, Docker, and database failures.
- `hackathon-db-helper`: make safe MySQL schema and data changes.
- `hackathon-single-image-build`: build and smoke-test the final image.
- `hackathon-gcp-push`: push the image to GCP Artifact Registry and print Swarm commands.
- `hackathon-github`: save the project to GitHub without committing secrets.
- `hackathon-submission-check`: run the final judging readiness checklist.
- `hackathon-explainer`: explain technical results in non-technical language.

## Script Safety

Scripts default to checks where possible. Installing packages, creating cloud repositories, and pushing images should be run only after the participant or organizer confirms the action.

## Agent Compatibility

These skills are usable by Codex, Claude, Gemini, or another terminal-capable agent because the important instructions live in plain Markdown and the automation lives in shell scripts.

- Codex: can use each `SKILL.md` as a native skill folder. `agents/openai.yaml` provides Codex UI metadata.
- Claude or Gemini: can use the same folders when their agent runner is told to read the relevant `SKILL.md`, follow linked `references/`, and run scripts from `scripts/`.
- Any terminal agent: should be given the repo path, the relevant skill folder, and permission rules for installs, Docker, GitHub, and GCP.

The only Codex-specific file is `agents/openai.yaml`. The workflows, references, and scripts are tool-agnostic.
