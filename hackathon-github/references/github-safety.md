# GitHub Safety

## Must Ignore

- `.env`
- `.env.*`, except `.env.example`
- service account JSON
- `node_modules/`
- `dist/`
- `build/`
- local database files
- logs

## Before Push

- Run `git status`.
- Scan staged files for obvious secrets.
- Confirm `README.md` explains preview, build, run, and push basics.
- Use normal push, not force push.

## Good Commit Messages

- `Create hackathon starter app`
- `Add customer tracking feature`
- `Build final single image`
- `Prepare submission README`
