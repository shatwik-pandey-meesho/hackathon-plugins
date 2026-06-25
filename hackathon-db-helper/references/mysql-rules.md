# MySQL Rules

## Schema

- Keep tables small and obvious.
- Add `id INT AUTO_INCREMENT PRIMARY KEY` unless the project already uses UUIDs.
- Add `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`.
- Use `VARCHAR(255)` for short text and `TEXT` for long descriptions.
- Use `DECIMAL(10,2)` for money-like values.

## Queries

- Always use parameterized SQL.
- Do not string-concatenate user input into SQL.
- Return predictable JSON from APIs.
- Use transactions only when multiple writes must succeed together.

## Changes

- Prefer additive changes.
- Before destructive changes, ask the participant directly and explain what will be lost.
- Keep `db/init.sql` runnable from scratch for judges.
