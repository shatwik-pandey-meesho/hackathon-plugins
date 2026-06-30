# SQLite Rules

## Schema

- Keep tables small and obvious.
- Add `id INTEGER PRIMARY KEY AUTOINCREMENT` unless the project already uses UUIDs.
- Add `created_at TEXT DEFAULT CURRENT_TIMESTAMP`.
- Use `TEXT` for strings and descriptions.
- Use `INTEGER` for counts and booleans.
- Use `REAL` or integer cents for money-like values; prefer integer cents when accuracy matters.

## Queries

- Always use parameterized SQL.
- Do not string-concatenate user input into SQL.
- Return predictable JSON from APIs.
- Use transactions when multiple writes must succeed together.

## Files

- Store the database under `data/` locally, for example `data/hackathon.db`.
- In Docker, write the database to `/app/data/hackathon.db`.
- Run Docker with the repo-local bind mount `-v "$(pwd)/data:/app/data"` so the SQLite file stays in the repo's ignored `data/` directory after the container exits.
- Ensure the Docker image creates `/app/data` before the app starts and does not overwrite an existing database file.
- Keep `db/init.sql` runnable from scratch for judges.

## Changes

- Prefer additive changes.
- SQLite supports only limited `ALTER TABLE` operations. Adding a column is usually safe, but SQLite cannot add a column with `DEFAULT CURRENT_TIMESTAMP`; add a nullable column or a constant default, then backfill values with `UPDATE`.
- SQLite cannot drop columns in older runtimes and cannot freely change column types or constraints. For those changes, create a new table, copy data, drop the old table only with explicit participant approval, and rename the new table.
- Before destructive changes, ask the participant directly and explain what will be lost.
