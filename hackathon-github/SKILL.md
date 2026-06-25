---
name: hackathon-github
description: "Save a hackathon project to GitHub safely for non-technical participants. Use when a participant asks to create a GitHub repo, push code, save progress, make a commit, connect the local folder to GitHub, prepare source code for submission, write a README, or avoid committing secrets in a React plus Node.js or Go plus SQLite project."
---

# Hackathon GitHub

## Overview

Put the project on GitHub without leaking secrets or losing work. Keep git explanations simple and action-focused.

## Workflow

1. Read `references/github-safety.md`.
2. Check whether the folder is already a git repo.
3. Ensure `.gitignore` excludes `.env`, credentials, dependency folders, build outputs, and database data.
4. Create or update a clear `README.md` with preview, build, and image instructions.
5. Run `scripts/push_to_github.sh` with the repo name or existing remote URL.
6. Report the GitHub URL and latest commit hash.

## Safety

- Never force push unless explicitly requested by the organizer.
- Never commit `.env`, service account JSON, tokens, keys, or local database files.
- Do not rewrite history for non-technical participants.
- Prefer small commits with clear messages.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before changing git state.
- After a commit or push, update `.agent-memory/state.json` with the repo URL or commit state and append the outcome to `.agent-memory/activity.md`.

## Resources

- `scripts/push_to_github.sh`: initialize git, scan for obvious secrets, commit, create or use GitHub remote, and push.
- `references/github-safety.md`: safe GitHub handling for participants.
