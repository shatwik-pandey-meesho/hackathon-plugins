---
name: hackathon-db-helper
description: "Make safe SQLite database changes for beginner hackathon apps using the allowed React plus Node.js or Go plus SQLite stack. Use when a participant asks to store new data, add a table, change fields, seed sample data, view saved data, reset test data, fix database file errors, or align backend APIs with SQLite schema."
---

# Hackathon DB Helper

## Overview

Handle database work without making the participant learn SQL. Keep data structures small, readable, and easy to explain.

## Workflow

1. Inspect `db/`, backend database code, and environment variables.
2. Read `references/sqlite-rules.md`.
3. For new data, create or update SQL in `db/init.sql` or the project's migration location.
4. Update backend code to use parameterized queries.
5. Update frontend forms and lists if the user asked for visible behavior.
6. Run `scripts/sqlite_smoke_check.sh` when a local database is available.
7. Explain the database change in plain language.

## Safety Rules

- Never drop tables or delete data unless the participant explicitly asks to clear test data.
- Prefer additive changes: new columns with defaults, new tables, new indexes.
- Use `id INTEGER PRIMARY KEY AUTOINCREMENT` IDs unless the project already uses UUIDs; avoid complex composite keys.
- Use `created_at` timestamps for participant-created records.
- Account for SQLite migration limits before changing existing tables; do not assume MySQL/Postgres `ALTER TABLE` behavior.
- Store Docker SQLite data under `/app/data`, backed by the repo-local ignored `data/` directory.
- Keep Dockerfiles on Debian slim images; do not switch to Alpine for SQLite.
- Keep sample seed data small and obviously fake.

## Memory

- If `.agent-memory/` exists, read `.agent-memory/state.json`, `.agent-memory/session.md`, and `.agent-memory/handoff.md` before changing schema or data behavior.
- After each schema or data change, update the current database state in `.agent-memory/` and append the migration outcome to `.agent-memory/activity.md`.

## Resources

- `scripts/sqlite_smoke_check.sh`: verify SQLite database access and list tables.
- `scripts/sqlite_smoke_check.ps1`: Windows PowerShell SQLite database smoke check.
- `references/sqlite-rules.md`: schema and query rules for hackathon projects.
