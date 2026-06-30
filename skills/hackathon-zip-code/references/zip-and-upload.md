# Zipping Code for Manual Upload

Source code is submitted by building one clean zip and uploading it **by hand** to the place the
organizer specified. There is no Google Drive connector, no MCP, and no GitHub involved.

## What goes in the zip

Included: the project source — `frontend/`, `backend/`, `db/`, `Dockerfile`, config files,
`README.md`, `.env.example`, etc.

Excluded automatically (kept small and safe):

- `node_modules/`, build output (`dist/`, `build/`)
- `.git/`
- `data/` and any `*.db` / `*.sqlite` files (local database data)
- `.env`, `.env.*` (except `.env.example`), `*.pem`, `*.key`, `*service-account*.json` (secrets)
- `.DS_Store`, `*.log`

## Secret safety

The zip script refuses to build if it finds secret-looking files (`.env`, service-account JSON,
`*.pem`, `*.key`). An `.env.example` is allowed. Remove or rename the flagged file and rebuild —
do not bypass the check.

## Keep it small

A typical React + Node/Go + SQLite source tree is well under a megabyte zipped. The script prints
a **warning when the zip is larger than 50 MB**; if you see it, find and exclude the heavy folder
(usually a stray `node_modules/`, a `data/` dump, or build output) and rebuild.

## How to upload (participant does this manually)

1. The script prints the zip path, for example `dist/my-app.zip`, and its size.
2. Open the location the organizer gave you — a shared folder, an upload form, or a drop box.
3. Upload that single `.zip` file there yourself.
4. If the organizer asked for a specific filename (team name, etc.), pass it to the script:
   `make_code_zip.sh "team-name"` so the zip is named accordingly.

The agent does not upload for you — it only builds the zip. The upload is a manual step so no
cloud account or login is ever needed.
