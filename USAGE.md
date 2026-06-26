# Using the Hackathon Skills

This guide shows how the 10 skills work together across a hackathon, then walks through a
**complete example project** from empty laptop to judge-ready image.

You do **not** call skills by name or memorize commands. You talk to your agent in plain
language, and it picks the matching skill automatically. The skill names below are only so
you understand what is happening under the hood.

---

## The skills, in the order you usually need them

| Phase | Say something like… | Skill that runs |
| --- | --- | --- |
| 1. Start | "Set up my laptop and start a new project" | `hackathon-bootstrap` |
| 2. Preview | "Show me my app in the browser" | `hackathon-preview` |
| 3. Build features | "Add a page where users can submit a recipe" | `hackathon-feature-builder` |
| 4. Data | "Save recipes in the database with a rating field" | `hackathon-db-helper` |
| 5. Fix | "The page is blank" / "the button does nothing" | `hackathon-bugfix` |
| 6. Explain | "What changed? Explain it simply" | `hackathon-explainer` |
| 7. Save | "Save my project to GitHub" | `hackathon-github` |
| 8. Package | "Build the final single image for judging" | `hackathon-single-image-build` |
| 9. Push | "Upload the image to GCP for the judges" | `hackathon-gcp-push` |
| 10. Final check | "Is my project ready to submit?" | `hackathon-submission-check` |

You will loop through 2–6 many times while building. Steps 7–10 happen near the end.

---

## The guardrails every skill enforces

So you don't have to think about them:

- **Allowed stack only:** React frontend, Node.js *or* Go backend, SQLite database. No
  Next.js, Python, Java, Postgres, Mongo, Redis, Firebase, etc.
- **Fixed ports:** frontend on `9080`, backend on `8090`.
- **One final Docker image** that contains the frontend, backend, and database setup —
  no Docker Compose or separate database container at judging.
- **Repo-local SQLite data** in `data/hackathon.db` for local runs, mounted into Docker at
  `/app/data` so saved records survive container restarts.
- **Debian slim base images** in every Dockerfile (never Alpine — it breaks SQLite builds).
- **No secrets in GitHub** — `.env`, keys, tokens, and `.db` files are kept out of commits.
- **Durable memory:** progress is written to `.agent-memory/` so a new session can pick up
  exactly where you left off.

---

## Where saved data lives

SQLite is a file database. For these hackathon apps, saved records live in the repo's
`data/hackathon.db` file during local runs. The `data/` folder is ignored by Git, so saved
test records are not pushed to GitHub.

When the app runs in Docker, the repo's `data/` folder is mounted into the container at
`/app/data`:

```bash
mkdir -p data
docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" IMAGE
```

The `--rm` flag may delete the stopped container, but the database file remains in
`./data/` because it is stored in the repo folder, not inside the container image layer.

---

## Worked example: "RecipeBox" by a non-technical team

**Scenario:** Priya's two-person team wants a small web app where people post recipes and
others rate them. Neither teammate codes. They have a fresh MacBook with nothing installed.

### Step 1 — Bootstrap (empty laptop → running app)

Priya opens the project folder in Claude Code and types:

> *"I want to build a recipe sharing app called RecipeBox where users post a recipe and
> others can rate it 1–5 stars. Set up my laptop and create the starter project."*

`hackathon-bootstrap` runs and:

1. Creates `.agent-memory/` so the session is recoverable.
2. Runs the tool check. Priya is missing Docker, Node, and the GitHub CLI, so it asks
   permission and installs them.
3. **Sets up GitHub login the easy way:** since Priya is already signed into GitHub in her
   browser, the credential script launches the browser login — she pastes a one-time code
   and clicks **Authorize**. No password, no token page. Git is now configured to push
   without ever prompting again.
4. Scaffolds `frontend/`, `backend/`, `db/`, a `Dockerfile` (Node on `node:20-bookworm-slim`),
   `.env.example`, and a `README.md`.
5. Builds a first screen: an app title, a "post a recipe" form, a list view, and a
   `/health` endpoint on the backend.

### Step 2 — Preview

> *"Show me the app in my browser."*

`hackathon-preview` starts it and gives her `http://localhost:9080`. She sees the RecipeBox
title and an empty recipe list. It works.

### Step 3 — Add a feature

> *"On the recipe form, add fields for ingredients and cooking time, and show them in the list."*

`hackathon-feature-builder` edits the React form, the backend API, and the list view together,
staying inside the allowed stack. She refreshes the browser and sees the new fields.

### Step 4 — Change the data

> *"Let people give each recipe a star rating from 1 to 5, and store it."*

`hackathon-db-helper` adds a `rating` column to the SQLite schema in `db/init.sql`, updates
the seed data, and aligns the backend's save/read APIs so ratings persist.

### Step 5 — Something breaks

After an edit, the list goes blank.

> *"The recipe list is blank now. Fix it."*

`hackathon-bugfix` finds that the frontend expected a field the API renamed, repairs the
mismatch, and confirms the list renders again.

### Step 6 — Understand what happened

> *"Explain what was broken in simple words, for our demo notes."*

`hackathon-explainer` gives a plain-language summary the team can read to judges.

*(Steps 2–6 repeat as they keep building.)*

### Step 7 — Save to GitHub

> *"Save everything to GitHub."*

`hackathon-github` checks there are no secrets or `.db` files staged, commits, creates a
private repo, pushes, and reports the repo URL and commit hash. Because login was set up in
Step 1, the push does not prompt for a password.

### Step 8 — Build the final single image

> *"Build the one final image for judging and test that it runs."*

`hackathon-single-image-build` builds a multi-stage Debian-slim image containing the built
React app, the Node backend, and SQLite init, then smoke-tests it: it starts a container,
waits for `/health` and the homepage, and prints the exact run command:

```bash
mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" recipebox:final
```

### Step 9 — Push to GCP

> *"Upload the image to GCP Artifact Registry for the judges."*

`hackathon-gcp-push` authenticates Docker with GCP, tags the image for the registry, pushes
it, and prints the final registry URL the judges will pull.

### Step 10 — Final readiness check

> *"Is RecipeBox ready to submit?"*

`hackathon-submission-check` runs the checklist: single image builds and runs, ports correct,
SQLite initializes in the repo-local `data/` directory, GitHub repo exists with no secrets,
README has run instructions, image is in the registry. It reports a green checklist (or tells
her exactly what is still missing).

RecipeBox is submitted.

---

## Resuming after a break or a new session

All progress lives in `.agent-memory/`. When Priya comes back the next day and opens the
project, she can simply say:

> *"Where did we leave off?"*

`hackathon-bootstrap` reads the memory files and summarizes the current state, the last
blocker, and the next exact action — no need to re-explain anything.

---

## Tips 

- **Describe outcomes, not code.** "Users should be able to delete their own recipe" is
  better than naming functions or files.
- **Preview often.** After each change, ask to see it in the browser so problems are caught early.
- **Let it install things.** When a skill asks to install Docker/Node/etc., say yes — that is expected.
- **Don't fight the stack.** If you ask for something outside React + Node/Go + SQLite, the
  agent will steer you back; that constraint is what keeps the final image simple.
- **Save to GitHub regularly**, not just at the end, so work is never lost.

For installation, see [INSTALLING.md](./INSTALLING.md).
