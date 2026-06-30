# Common Failures

## Blank Page

- Check browser console or build output.
- Check React build base path and that API calls use the relative `/api/...` path.
- Verify nginx serves the frontend on port `9080` and that `try_files ... /index.html` is present so SPA routes do not 404 on refresh.
- Verify the frontend calls the backend through the relative `/api/...` path, NOT a hardcoded `http://localhost:8090`. A hardcoded host/port breaks the app once it is deployed on a different domain/subdomain.

## API Calls 404 / "Not Found" / CORS errors (deployed or local)

- Confirm the frontend uses same-origin relative paths like `/api/recipes`, never an absolute backend URL.
- Confirm nginx has a `location /api/ { proxy_pass http://127.0.0.1:8090; }` block (no trailing slash, so the `/api` prefix is preserved) and that backend routes live under `/api/`.
- Confirm `http://localhost:9080/api/health` responds (backend reached through nginx). If `:8090/api/health` works but `:9080/api/health` does not, nginx is not proxying — fix the nginx config.
- In local dev, confirm the React dev server proxies `/api` to `http://localhost:8090`; otherwise dev `/api` calls fail even though the image works.
- CORS errors almost always mean the frontend is calling an absolute cross-origin URL instead of same-origin `/api` — switch it to `/api`.

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
- Check the entrypoint starts the backend in the background and then runs `nginx -g 'daemon off;'` in the foreground, so nginx is the container's main process and the container does not exit immediately.
- Check `nginx` is installed in the runtime stage and its config is copied to `/etc/nginx/conf.d/`.
- Check frontend port `9080` (nginx) and backend port `8090` are exposed and not already used by another program.

## Proxy Push Fails

- Check Docker Desktop is running and `docker info` works.
- Check the proxy host is only the registry host, with no `https://` prefix and no path.
- Check the Docker login username and token are the organizer-provided values.
- Check the local image exists before tagging.
- Check the image passes the local health check: frontend `http://localhost:9080/` and backend through nginx `http://localhost:9080/api/health`.
- Check the final tag uses the identity slug (Meesho email name before `@`) as both folder and image name: `PROXY_HOST/USER/USER:TAG`.

## Code Zip Fails

- If the zip is rejected for secrets, remove the `.env`/key/`*.db` files it reported (an `.env.example` is allowed) and rebuild with `hackathon-zip-code`.
- If `zip` is "not found", install it (macOS ships it; Debian/Ubuntu: `sudo apt-get install zip`). On Windows the script uses the built-in `Compress-Archive`, so no install is needed.
- If the zip is unexpectedly large (over 50 MB), a heavy folder slipped in — confirm `node_modules/`, `data/`, and build output are excluded, then rebuild.
- The zip is uploaded by the participant by hand to the organizer's folder; the skill never uploads. If the upload itself fails, that is an organizer-side / browser issue, not a skill bug.
