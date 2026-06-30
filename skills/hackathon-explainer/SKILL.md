---
name: hackathon-explainer
description: "Explain hackathon project state, errors, code changes, Docker, code zipping/submission, proxy registry, SQLite, React, Node.js, or Go in plain language for non-technical participants and organizers. Use when the user asks what changed, what an error means, what to do next, how judges will run the app, or how to describe the project for submission."
---

# Hackathon Explainer

## Overview

Translate technical work into participant-friendly language. Keep explanations accurate but short enough for someone focused on product ideas rather than engineering.

## Style

- Start with the outcome.
- Use common words before tool names.
- Avoid long command dumps unless the participant must run them.
- Separate "what happened", "why it matters", and "what to do next" for errors.
- Mention risks plainly, especially missing accounts, missing Docker, failed builds, or unpushed images.

## Explanation Patterns

For a build result:

```text
Your app has been packaged into one image. Judges can start that image and open the app in a browser.
Image: ...
Run command: ...
```

For an error:

```text
The app could not start because the database file was not created correctly. I am going to make the app create SQLite before it opens.
```

For a feature:

```text
You can now add customers from the form and see them in the table. The app saves them in SQLite, so they are available to the backend.
```

## Memory

- If `.agent-memory/` exists, use it as the primary source for explaining current project state and recent changes.
- When an explanation reveals new status or a resolved blocker, ensure `.agent-memory/session.md` and `.agent-memory/handoff.md` stay aligned.

## Resource

- `references/plain-language.md`: preferred wording for common technical topics.
