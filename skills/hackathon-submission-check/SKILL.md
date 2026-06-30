---
name: hackathon-submission-check
description: "Run the final readiness checklist for a non-technical hackathon team before judging. Use when a participant asks if the project is ready, wants a final check, needs to verify the single Docker image, GitHub repo, proxy registry push, local preview, SQLite initialization, README, or absence of committed secrets."
---

# Hackathon Submission Check

## Overview

Check the complete judging path end to end. The output should be a clear pass/fail list with exact next actions.

## Workflow

1. Read `references/final-checklist.md`.
2. Confirm with the participant: "Is this the final image for submission?" If yes, ask the data question before any final build: "Should the final image start with a clean, empty database, or carry a copy of your current saved data baked inside?" Default to a clean start unless the demo needs pre-filled data. Hand the chosen mode to `hackathon-single-image-build`, which owns the build steps for each mode.
3. Run `scripts/check_submission.sh` from the project root.
4. Build and smoke-test the image if the participant wants a real final check. For a final image, also confirm it starts standalone with no bind mount (`docker run --rm -p 9080:9080 -p 8090:8090 IMAGE`).
5. Confirm the GitHub remote and latest commit.
6. Confirm the registry image URL if proxy push has happened.
7. Summarize in plain language:
   - Ready
   - Needs fixing before judging
   - Could not check because a tool/account is missing

## Required Green Checks

- For a final image, the participant has confirmed it is final and chosen a data mode (clean start, or baked-in data).
- One Docker image builds.
- The image starts with `docker run`, and a final image also starts standalone with no bind mount.
- A browser can load the frontend on `http://localhost:9080`.
- Backend health or API responds on `http://localhost:8090`.
- SQLite initializes.
- GitHub repo is reachable.
- Final image URL is known or ready to push through the organizer proxy.
- No obvious secrets are committed.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before checking readiness.
- After the check, record pass/fail status and the next exact action in `.agent-memory/`.

## Resources

- `scripts/check_submission.sh`: automated readiness checks.
- `references/final-checklist.md`: pass/fail criteria.
