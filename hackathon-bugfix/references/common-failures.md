# Common Failures

## Blank Page

- Check browser console or build output.
- Check React build base path and API URL.
- Verify the frontend is served on port `9080` and its API URL points to the backend on port `8090`.

## Button Does Nothing

- Check click handler exists.
- Check network request path.
- Check backend route method matches frontend request.
- Check JSON body parsing in backend.

## Data Does Not Save

- Check the SQLite database file exists or can be created.
- If data disappears after restart, check that Docker is run with the repo-local mount `-v "$(pwd)/data:/app/data"` and that the backend writes to `/app/data/hackathon.db`, not a database baked into the image layer.
- Check env vars match backend config.
- Check SQL table and column names.
- Check backend uses parameterized insert/update queries.

## Docker Build Fails

- Check `.dockerignore` is not excluding required files.
- Check frontend and backend install commands.
- Check the Dockerfile matches Node.js or Go backend.
- Check all Docker stages use Debian slim images, not Alpine.
- For Node SQLite packages such as `better-sqlite3`, check the build stage installs `python3`, `make`, and `g++` before `npm install` or `npm ci`.

## Container Starts Then Exits

- Check entrypoint logs.
- Check SQLite database initialization path and file permissions under `/app/data`.
- Check the startup script creates `/app/data` but does not overwrite an existing database file.
- Check app process is foregrounded or supervised.
- Check frontend port `9080` and backend port `8090` are exposed and not already used by another program.

## GCP Push Fails

- Check `gcloud auth list`.
- Check Docker is authenticated for `REGION-docker.pkg.dev`.
- Check Artifact Registry repository exists.
- Check user has write permission.
