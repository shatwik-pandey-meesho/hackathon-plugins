---
name: hackathon-submission-check
description: "Run the final readiness checklist for a non-technical hackathon team before judging. Use when a participant asks if the project is ready, wants a final check, needs to verify the single Docker image, code zip for submission, proxy registry push, local preview, SQLite initialization, README, or absence of leaked secrets."
---

# Hackathon Submission Check

## Overview

Check the complete judging path end to end. The output should be a clear pass/fail list with exact next actions.

## Workflow

1. Read `references/final-checklist.md`.
2. Confirm with the participant: "Is this the final image for submission?" If yes, ask the data question before any final build: "Should the final image start with a clean, empty database, or carry a copy of your current saved data baked inside?" Default to a clean start unless the demo needs pre-filled data. Hand the chosen mode to `hackathon-single-image-build`, which owns the build steps for each mode.
3. Run `scripts/check_submission.sh` from the project root.
4. Build and smoke-test the image if the participant wants a real final check. For a final image, also confirm it starts standalone with no bind mount (`docker run --rm -p 9080:9080 -p 8090:8090 IMAGE`).
5. Confirm a source code zip was built (the `code_zip` in `.agent-memory/state.json`, via `hackathon-zip-code`) and remind the participant to upload that zip to the organizer's folder by hand. If no zip was built, run `hackathon-zip-code`.
6. Confirm the registry image URL if proxy push has happened. It should normally look like `registry.buildathon.meesho.dev/TEAM_ID:TIMESTAMP`, where `TEAM_ID` came from local `.agent-memory/` or the participant's Meesho email.
7. Summarize in plain language:
   - Ready
   - Needs fixing before judging
   - Could not check because a tool/account is missing

## Required Green Checks

- For a final image, the participant has confirmed it is final and chosen a data mode (clean start, or baked-in data).
- One Docker image builds.
- The image starts with `docker run`, and a final image also starts standalone with no bind mount.
- A browser can load the frontend (served by nginx) on `http://localhost:9080`.
- The backend responds **through nginx** at `http://localhost:9080/api/health` — confirming the frontend's `/api` proxying works (so it survives any deployed domain/subdomain).
- SQLite initializes.
- Source code zip is built (`hackathon-zip-code`) and the participant has uploaded it by hand to the organizer's folder.
- Final image URL is known or ready to push through the organizer proxy, using the email-derived `TEAM_ID:TIMESTAMP` naming.
- No obvious secrets are in the project or the zip.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before checking readiness.
- After the check, record pass/fail status and the next exact action in `.agent-memory/`.

## Resources

- `scripts/check_submission.sh`: automated readiness checks.
- `references/final-checklist.md`: pass/fail criteria.
