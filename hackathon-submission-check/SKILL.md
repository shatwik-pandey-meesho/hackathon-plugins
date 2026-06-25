---
name: hackathon-submission-check
description: "Run the final readiness checklist for a non-technical hackathon team before judging. Use when a participant asks if the project is ready, wants a final check, needs to verify the single Docker image, GitHub repo, GCP Artifact Registry push, local preview, SQLite initialization, README, or absence of committed secrets."
---

# Hackathon Submission Check

## Overview

Check the complete judging path end to end. The output should be a clear pass/fail list with exact next actions.

## Workflow

1. Read `references/final-checklist.md`.
2. Run `scripts/check_submission.sh` from the project root.
3. Build and smoke-test the image if the participant wants a real final check.
4. Confirm the GitHub remote and latest commit.
5. Confirm the registry image URL if GCP push has happened.
6. Summarize in plain language:
   - Ready
   - Needs fixing before judging
   - Could not check because a tool/account is missing

## Required Green Checks

- One Docker image builds.
- The image starts with `docker run`.
- A browser can load the frontend on `http://localhost:9080`.
- Backend health or API responds on `http://localhost:8090`.
- SQLite initializes.
- GitHub repo is reachable.
- Final image URL is known or ready to push.
- No obvious secrets are committed.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before checking readiness.
- After the check, record pass/fail status and the next exact action in `.agent-memory/`.

## Resources

- `scripts/check_submission.sh`: automated readiness checks.
- `references/final-checklist.md`: pass/fail criteria.
