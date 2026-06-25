# Final Checklist

The project is ready when these pass:

- Source is saved in GitHub.
- No obvious secrets are committed.
- `Dockerfile` exists.
- One image builds successfully.
- The image starts with `docker run --rm -p 8080:8080 IMAGE`.
- Browser loads `http://localhost:8080`.
- `/health` returns success.
- MySQL initializes inside the image.
- Final image is pushed or ready to push to Artifact Registry.
- README includes the final run command and image URL when available.

If one check fails, fix that before calling the project ready.
