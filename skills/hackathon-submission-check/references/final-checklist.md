# Final Checklist

The project is ready when these pass:

- The participant has confirmed whether this is the final image and chosen a data mode for it: clean start (default, empty database initialized from `db/init.sql`) or baked-in data (a copy of the current `data/hackathon.db` built into the image).
- Source code zip is built (via `hackathon-zip-code`) and uploaded by hand to the organizer's folder.
- No obvious secrets are in the project or the zip.
- `Dockerfile` exists.
- One image builds successfully.
- The image starts with `mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" IMAGE`.
- The final image also starts standalone with no bind mount: `docker run --rm -p 9080:9080 -p 8090:8090 IMAGE`, so it has no link to the participant's machine.
- Browser loads the nginx-served frontend at `http://localhost:9080`.
- Backend responds through nginx at `http://localhost:9080/api/health`, and the frontend calls the backend only via relative `/api/...` paths (no hardcoded host/port), so it works behind any deployed domain/subdomain.
- SQLite initializes in `/app/data` and persists in the repo-local ignored `data/` directory across container restarts.
- Final image is pushed or ready to push through the organizer proxy as `registry.buildathon.ltl.sh/TEAM_ID:TIMESTAMP`.
- README includes the final run command and image URL when available.

If one check fails, fix that before calling the project ready.
