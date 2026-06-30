---
name: hackathon-zip-code
description: "Zip a hackathon project's source code into one clean file the participant can upload by hand to the organizer's submission folder. Use when a participant asks to zip, package, save, submit, hand in, or back up their code, or to prepare the source for submission. There is no Google Drive, no MCP, and no GitHub — this produces a local zip and tells the participant where to upload it manually."
---

# Hackathon Zip Code

## Overview

Produce one clean, secret-free zip of the project source and hand it to the participant to
upload **manually** to wherever the organizer asked (a shared folder, an upload form, a drop
box, etc.). This skill never uploads anything itself — building the zip is the only automated
step; the participant does the upload.

## Workflow

1. Read `references/zip-and-upload.md`.
2. Optionally ask the participant what to name the zip (their team or project name). If they
   do not care, default to the project folder name.
3. Build the zip with `scripts/make_code_zip.sh [NAME]` (or `scripts/make_code_zip.ps1` on
   Windows). It excludes `node_modules/`, `.git/`, `data/`, build output, and any `.env`, key,
   token, or `*.db` files, and writes `dist/<name>.zip`.
4. The script refuses to build if it finds secret files (`.env`, service-account JSON, `*.pem`,
   `*.key`). Resolve the finding (an `.env.example` is allowed) before zipping.
5. Report the absolute path to the zip and its size.
6. Tell the participant — in plain language — to upload that single zip file to the organizer's
   designated submission folder/location **by hand**. Do not attempt to upload it for them, and
   do not ask for any cloud login.

## Safety

- Never include `.env`, service-account JSON, tokens, keys, or local database files. The script
  excludes them; do not override that.
- Keep the zip source-only (no `node_modules/`, no `data/`, no build output). The script warns
  above **50 MB**; if you see that warning, trim heavy folders before handing it over.
- This skill only creates a local file. The participant performs the upload manually.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and
  `.agent-memory/handoff.md` before building.
- After building the zip, set `code_zip` in `.agent-memory/state.json` to the zip path and append
  the outcome to `.agent-memory/activity.md`. Record that the manual upload is the participant's
  next action.

## Resources

- `scripts/make_code_zip.sh`: build a clean, secret-free source zip on macOS/Linux and print its path and size.
- `scripts/make_code_zip.ps1`: same on Windows using the built-in `Compress-Archive`.
- `references/zip-and-upload.md`: what is included/excluded and how to upload the zip by hand.
