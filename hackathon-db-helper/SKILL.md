---
name: hackathon-db-helper
description: "Make safe MySQL database changes for beginner hackathon apps using the allowed React plus Node.js or Go plus MySQL stack. Use when a participant asks to store new data, add a table, change fields, seed sample data, view saved data, reset test data, fix database connection errors, or align backend APIs with MySQL schema."
---

# Hackathon DB Helper

## Overview

Handle database work without making the participant learn SQL. Keep data structures small, readable, and easy to explain.

## Workflow

1. Inspect `db/`, backend database code, and environment variables.
2. Read `references/mysql-rules.md`.
3. For new data, create or update SQL in `db/init.sql` or the project's migration location.
4. Update backend code to use parameterized queries.
5. Update frontend forms and lists if the user asked for visible behavior.
6. Run `scripts/mysql_smoke_check.sh` when a local database is available.
7. Explain the database change in plain language.

## Safety Rules

- Never drop tables or delete data unless the participant explicitly asks to clear test data.
- Prefer additive changes: new columns with defaults, new tables, new indexes.
- Use `INT AUTO_INCREMENT` or `CHAR(36)` IDs; avoid complex composite keys.
- Use `created_at` timestamps for participant-created records.
- Keep sample seed data small and obviously fake.

## Resources

- `scripts/mysql_smoke_check.sh`: verify MySQL connection and list tables.
- `references/mysql-rules.md`: schema and query rules for hackathon projects.
