# Final Checklist

The project is ready when these pass:

- The participant has confirmed whether this is the final image and chosen a data mode for it: clean start (default, empty database initialized from `db/init.sql`) or baked-in data (a copy of the current `data/hackathon.db` built into the image).
- Source is saved in GitHub.
- No obvious secrets are committed.
- `Dockerfile` exists.
- One image builds successfully.
- The image starts with `mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" IMAGE`.
- The final image also starts standalone with no bind mount: `docker run --rm -p 9080:9080 -p 8090:8090 IMAGE`, so it has no link to the participant's machine.
- Browser loads `http://localhost:9080`.
- Backend health returns success at `http://localhost:8090/health`.
- SQLite initializes in `/app/data` and persists in the repo-local ignored `data/` directory across container restarts.
- Final image is pushed or ready to push to Artifact Registry.
- README includes the final run command and image URL when available.

If one check fails, fix that before calling the project ready.
