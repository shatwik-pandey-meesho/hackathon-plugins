---
name: hackathon-feature-builder
description: "Add participant-requested features to an existing hackathon app while keeping the allowed stack: React.js, Node.js or Go, and SQLite inside one final Docker image. Use when a non-technical participant asks for pages, forms, dashboards, login-like flows, CRUD features, API changes, database changes, UI improvements, or feature wiring across frontend, backend, and SQLite."
---

# Hackathon Feature Builder

## Overview

Turn plain-language product ideas into working code. The participant should focus on what they want the app to do; the agent handles frontend, API, database, and verification.

## Workflow

1. Restate the requested feature in one simple sentence.
2. Inspect the current app structure before editing.
3. Read `references/feature-rules.md`.
4. Plan the smallest complete vertical slice: database table or column, backend endpoint, frontend view/control, and verification.
5. Edit files using the existing project style.
6. Run `scripts/project_sanity_check.sh` after changes.
7. Start or build the app when practical and verify at least one happy path.
8. Explain the result in plain language: what the user can now do, where to click, and any known limitation.

## Feature Rules

- Prefer simple CRUD and dashboard features over complex auth, payments, realtime systems, or external APIs.
- Do not add a second database, cache, message queue, or cloud dependency.
- Keep data models small and understandable.
- Use mock login or simple local roles when the participant says "login" unless real authentication is explicitly required and allowed.
- Keep UI copy short and direct.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before editing.
- After each meaningful change, update those files and append the result to `.agent-memory/activity.md`.

## Resources

- `scripts/project_sanity_check.sh`: quick structural checks after feature work.
- `references/feature-rules.md`: implementation rules for beginner hackathon apps.
