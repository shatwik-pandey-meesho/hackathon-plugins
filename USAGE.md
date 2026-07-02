# Using the Hackathon Skills

This guide shows how the 10 skills work together across a hackathon. It starts with a short
**walkthrough of how to actually use them**, then the **full skill list**, the guardrails, and a
**complete worked example** (RecipeBox) from empty laptop to judge-ready image.

You usually do **not** call skills by name or memorize commands — you talk to Claude Code in plain
language and it picks the matching skill automatically. (You *can* also invoke one explicitly with
`/`; see below.) The skill names here are only so you understand what is happening under the hood.

---

## Before you start

1. **Install the skills once** — see [INSTALLING.md](./INSTALLING.md). The quickest way is the
   Claude Code plugin marketplace, from inside Claude Code:

   ```
   /plugin marketplace add shatwik-pandey-meesho/hackathon-plugins
   /plugin install hackathon-skills@hackathon-plugins
   ```

2. **Open your hackathon project folder** in Claude Code (an empty folder is fine for a new
   project) — not the skills repo. Everything the skills do happens inside that project folder.
3. You do **not** need to pre-install Docker, Node, Go, or anything else. The first skill
   (`hackathon-bootstrap`) checks your tools and offers to install whatever is missing.

---

## How to use a skill

You drive everything by **talking to Claude Code in plain language**. A skill runs one of two ways:

- **Automatically (the normal case):** just say what you want — *"set up my laptop and start a new
  project"*, *"show me the app"*, *"the page is blank, fix it"*. Claude reads the skill descriptions
  and picks the matching one. You never have to remember skill names.
- **Explicitly (when you want to force one):** type `/` and choose the skill, e.g.
  `/hackathon-skills:hackathon-bootstrap` or `/hackathon-skills:hackathon-zip-code`. Use this if the
  right skill didn't trigger on its own, or you want a specific step to run now.

When a skill asks permission to install a tool, run Docker, or push an image, **say yes** — that is
expected. Progress is written to `.agent-memory/` inside your project, so you can stop and resume
anytime (see [Resuming](#resuming-after-a-break-or-a-new-session) below).

---

## Quick start walkthrough (what you actually type)

A whole hackathon, start to finish, as the plain-language prompts you would send. Each line
triggers the skill named in parentheses:

1. **Start** *(hackathon-bootstrap)* — "Set up my laptop and create a new project called
   `<name>`: `<one sentence on what it does>`."
2. **See it** *(hackathon-preview)* — "Show me the app in my browser." → opens `http://localhost:9080`.
3. **Build a feature** *(hackathon-feature-builder)* — "Add `<feature>` — for example a form to
   submit X and a list that shows them."  ← repeat this as many times as you like.
4. **Change the data** *(hackathon-db-helper)* — "Store `<field>` for each `<thing>` and show it."
5. **Fix something** *(hackathon-bugfix)* — "`<what looks wrong>`. Fix it." (e.g. "the list is blank").
6. **Understand it** *(hackathon-explainer)* — "Explain what changed in simple words for our demo."
7. **Zip to submit** *(hackathon-zip-code)* — "Zip my code so I can submit it." Then **upload the
   printed `.zip` file to the organizer's folder yourself** (manual step; no login needed).
8. **Package** *(hackathon-single-image-build)* — "Build the final single image and test it runs."
9. **Push for judging** *(hackathon-deploy-by-pushing-image)* — "Push the image through the hackathon
   proxy." It will **ask for your Meesho email** if local memory does not already have it; the image
   is named from the email-derived team ID with a timestamp tag.
10. **Final check** *(hackathon-submission-check)* — "Is my project ready to submit?"

Steps **2–6 are the build loop** you repeat while developing; **7–10 are the wrap-up** at the end.
The detailed version of this exact flow is the [RecipeBox worked example](#worked-example-recipebox-by-a-non-technical-team) further down.

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
| 7. Save | "Zip my code so I can submit it" | `hackathon-zip-code` |
| 8. Package | "Build the final single image for judging" | `hackathon-single-image-build` |
| 9. Push | "Upload the image through the hackathon proxy for the judges" | `hackathon-deploy-by-pushing-image` |
| 10. Final check | "Is my project ready to submit?" | `hackathon-submission-check` |
| 11. Deploy (all-in-one) | "Deploy it" / "ship it" / "go live" | `hackathon-deploy` |

You will loop through 2–6 many times while building. Steps 7–10 happen near the end.

`hackathon-deploy` is the shortcut for the finish line: it runs steps 8 → 10 → 7 → 9 in one guided
flow (build the amd64 image, check readiness, zip the source, push through the proxy) and then sends
you to `buildathon.ltl.sh` to click **Deploy Live** and wait for the live link. It first asks you to
switch to Opus with high reasoning, and works on macOS and Windows.

---

## The guardrails every skill enforces

So you don't have to think about them:

- **Allowed stack only:** React frontend, Node.js *or* Go backend, SQLite database. No
  other frontend framework, backend language, database, cache, hosted backend, or separate service.
- **Fixed ports:** nginx-served frontend on `9080`, backend on `8090`.
- **nginx + `/api` routing (always):** in the image, nginx serves the React build on `9080` and
  reverse-proxies `/api/` to the backend. The frontend calls the backend only via the relative
  `/api/...` path — never a hardcoded host or port — so the app keeps working behind any
  randomly assigned judging domain or subdomain.
- **One final Docker image** that contains nginx, the frontend, the backend, and database setup —
  no Docker Compose or separate database container at judging.
- **Repo-local SQLite data** in `data/hackathon.db` for local runs, mounted into Docker at
  `/app/data` so saved records survive container restarts.
- **Debian slim base images** in every Dockerfile (never Alpine — it breaks SQLite builds).
- **No secrets in the zip** — `.env`, keys, tokens, and `.db` files are kept out of the submission zip.
- **Durable memory:** progress is written to `.agent-memory/` so a new session can pick up
  exactly where you left off.

---

## Where saved data lives

SQLite is a file database. For these hackathon apps, saved records live in the repo's
`data/hackathon.db` file during local runs. The `data/` folder is excluded from the uploaded
zip, so saved test records are never included in the submission zip.

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
2. Runs the tool check. Priya is missing Docker, Node, and `zip`, so it asks
   permission and installs them.
3. **Notes how code will be saved:** there is no GitHub, git, or cloud connector. When the team
   is ready to submit, `hackathon-zip-code` builds a clean zip of the source and Priya uploads
   that file by hand to the organizer's submission folder.
4. Scaffolds `frontend/`, `backend/`, `db/`, a `Dockerfile` (Node on `node:20-bookworm-slim`)
   with **nginx** serving the frontend and proxying `/api/` to the backend, `.env.example`,
   and a `README.md`.
5. Builds a first screen: an app title, a "post a recipe" form, a list view, and an
   `/api/health` endpoint on the backend. The React code calls the backend via `/api/...`
   (same origin), never a hardcoded `localhost:8090`.

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

### Step 7 — Zip the code to submit

> *"Zip my code so I can submit it."*

`hackathon-zip-code` builds a clean, source-only zip (no `.env`, keys, or `.db` files) named
after the project (e.g. `recipebox.zip`, or a team name if Priya gives one), prints its path and
size, and tells Priya to upload that single file by hand to the organizer's submission folder.
The skill never uploads anything itself — no login, no cloud connector.

### Step 8 — Build the final single image

> *"Build the one final image for judging and test that it runs."*

`hackathon-single-image-build` builds a multi-stage Debian-slim image containing nginx, the built
React app, the Node backend, and SQLite init. nginx serves the app on `9080` and proxies `/api/`
to the backend on `8090`. It smoke-tests the image by starting a container and waiting for the
homepage at `http://localhost:9080/` and the backend through nginx at
`http://localhost:9080/api/health`, then prints the exact run command:

```bash
mkdir -p data && docker run --rm -p 9080:9080 -p 8090:8090 -v "$(pwd)/data:/app/data" recipebox:final
```

### Step 9 — Push through the proxy

> *"Upload the image through the hackathon proxy for the judges."*

`hackathon-deploy-by-pushing-image` asks for the organizer token and, if local memory does not
already have it, **Priya's Meesho organization email** (`priya.sharma@meesho.com`). It checks that
the image runs locally, derives the team ID `priya-sharma`, tags the image as
`registry.buildathon.ltl.sh/priya-sharma:20260701-053012`, pushes it through the proxy, records
the non-secret push metadata in local `.agent-memory/`, and prints the final image URL the judges
will pull. The token is never stored.

### Step 10 — Final readiness check

> *"Is RecipeBox ready to submit?"*

`hackathon-submission-check` runs the checklist: single image builds and runs, ports correct,
SQLite initializes in the repo-local `data/` directory, the source zip is built with no secrets
(and Priya has uploaded it by hand to the organizer's folder), README has run instructions, image
is in the registry. It reports a green checklist (or tells her exactly what is still missing).

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
- **Zip and upload your code regularly**, not just at the end, so work is never lost.

For installation, see [INSTALLING.md](./INSTALLING.md).
