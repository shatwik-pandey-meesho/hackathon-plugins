# Memory Contract

Bootstrap owns the durable agent memory for the project.

## Required Files

Create these files under `.agent-memory/` in the project root:

- `state.json`: machine-readable current state.
- `session.md`: human-readable current project context.
- `handoff.md`: current blocker, next exact action, and expected result.
- `activity.md`: timestamped history of important actions and outcomes.

## Required `state.json` Keys

Use at least these keys:

- `project_name`
- `app_idea`
- `frontend_port`
- `backend_port`
- `frontend_framework`
- `backend_language`
- `database`
- `image_tag`
- `registry_url`
- `code_zip`
- `last_successful_step`
- `current_status`
- `current_blocker`
- `next_action`
- `last_updated`

## Update Rules

- Read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before making new assumptions.
- If the memory exists, do not re-ask questions already answered there unless the values are obviously stale or contradictory.
- After every major project action, append a timestamped note to `.agent-memory/activity.md`.
- When any tracked value changes, update `.agent-memory/state.json`.
- Keep `.agent-memory/session.md` as a short summary of what exists, what works, what fails, and what changed recently.
- Keep `.agent-memory/handoff.md` focused on the current blocker and the next exact command or task.

## Resume Rule

At the beginning of a new session, bootstrap must:

1. detect `.agent-memory/`
2. read the memory files
3. summarize the recovered state
4. continue from that state instead of starting over
