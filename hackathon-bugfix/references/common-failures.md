# Common Failures

## Blank Page

- Check browser console or build output.
- Check React build base path and API URL.
- Verify backend serves the built frontend from `/`.

## Button Does Nothing

- Check click handler exists.
- Check network request path.
- Check backend route method matches frontend request.
- Check JSON body parsing in backend.

## Data Does Not Save

- Check MySQL is running.
- Check env vars match backend config.
- Check SQL table and column names.
- Check backend uses parameterized insert/update queries.

## Docker Build Fails

- Check `.dockerignore` is not excluding required files.
- Check frontend and backend install commands.
- Check the Dockerfile matches Node.js or Go backend.

## Container Starts Then Exits

- Check entrypoint logs.
- Check MySQL startup wait loop.
- Check app process is foregrounded or supervised.
- Check port `8080` is exposed and used.

## GCP Push Fails

- Check `gcloud auth list`.
- Check Docker is authenticated for `REGION-docker.pkg.dev`.
- Check Artifact Registry repository exists.
- Check user has write permission.
