---
name: hackathon-preview
description: "Start, restart, or preview a hackathon project locally so non-technical participants can open the app in a browser. Use when the user says show my app, run it locally, preview changes, start Docker, open the project, check if it works, or get a local URL for a React plus Node or Go plus MySQL single-image project."
---

# Hackathon Preview

## Overview

Make the app viewable with the least explanation possible. Prefer Docker preview because judging uses an image, but use existing project scripts when Docker files are not ready yet.

## Workflow

1. Inspect the project for `Dockerfile`, `docker-compose.yml`, `compose.yml`, `package.json`, `frontend/`, and `backend/`.
2. Run `scripts/start_local_preview.sh` from the project root.
3. If the script fails, collect the exact failing command and logs, then use `hackathon-bugfix`.
4. Give the participant the local URL, usually `http://localhost:8080`.
5. Keep any long-running preview process open only when it is useful; do not leave hidden background processes without reporting them.

## Participant Language

Say "Your app is running here" and give the URL. Put technical logs after the plain result.

## Resource

- `scripts/start_local_preview.sh`: builds or starts the local app and prints the URL.
