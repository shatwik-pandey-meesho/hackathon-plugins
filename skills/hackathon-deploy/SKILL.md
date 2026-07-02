---
name: hackathon-deploy
description: "One-shot hackathon deploy: build the final linux/amd64 single Docker image, run readiness checks, zip the source for manual upload, and push the image through the organizer's token-authenticated proxy — then send the participant to buildathon.ltl.sh to click Deploy Live and get the live link. Use when a participant says deploy, ship it, submit, go live, or 'do everything to get my app judged'. Combines single-image build, submission check, code zip, and proxy push into one guided flow that works on macOS and Windows."
---

# Hackathon Deploy (all-in-one submission)

## Overview

This is the single, final step that takes a working app to a live, judge-ready deployment. It runs
four things in order so the participant does not have to invoke them separately:

1. **Build** the final `linux/amd64` single Docker image and smoke-test it.
2. **Check** readiness (no secrets, README present, image runs standalone with no bind mount).
3. **Zip** the source code into one clean file for manual upload.
4. **Push** the image through the organizer's Docker proxy using the default registry and login.

Then it hands the participant off to **`https://buildathon.ltl.sh`** to click **Deploy Live** and
wait for the live link.

It works on **any device** — macOS/Linux use `scripts/deploy.sh`, Windows uses `scripts/deploy.ps1`.

## Step 0 — Ask the participant to switch to Opus with high reasoning (do this first)

Deploy is the highest-stakes step: it produces the artifact judges run. **Before doing anything
else, ask the participant to switch the model to Opus with high reasoning:**

> "Deploy is the most important step. Please switch to the strongest model first: run `/model`,
> pick **Opus**, and set reasoning effort to **high**. Tell me once you've done that and I'll continue."

Wait for their confirmation before starting the flow. If they decline, proceed but note that Opus +
high reasoning is strongly recommended here.

## Workflow

1. Read `references/deploy-flow.md`.
2. Complete **Step 0** above (model switch) and wait for confirmation.
3. Confirm the app builds into one image: a `Dockerfile` exists at the project root. If not, the app
   isn't ready — stop and route to the feature/build skills first.
4. Ask the **two inputs** the push needs, using defaults for everything else:
   - The participant's **Meesho organization email** (used only to derive the image's team id;
     never guess or substitute it). Skip if `.agent-memory/state.json` already has
     `participant_email`.
   - The **organizer registry token** (the password to submit with). Pass it through the
     `HACKATHON_PROXY_TOKEN` environment variable so it never lands in shell history. **Never print
     the token.**
   - Everything else uses defaults: proxy host `registry.buildathon.ltl.sh`, login user `hackathon`,
     tag = UTC timestamp.
5. Run the orchestrator from the project root:
   - macOS/Linux: `scripts/deploy.sh --user <email>` with `HACKATHON_PROXY_TOKEN` set in the env.
   - Windows: `scripts\deploy.ps1 -User <email>` with `$env:HACKATHON_PROXY_TOKEN` set.
   The orchestrator runs build → check → zip → push in order and stops at the first failure.
6. When the push succeeds, report the final image URL (`registry.buildathon.ltl.sh/TEAM_ID:TAG`) and
   remind the participant to upload the printed `dist/<name>.zip` to the organizer's folder **by hand**.
7. **Go live — give the participant these exact instructions:**
   > 1. Open **https://buildathon.ltl.sh** and log in.
   > 2. Click the **Deploy Live** button.
   > 3. **Wait** for the live link to appear — that link is your running app for the judges.

   Wait with them for the live link. If it doesn't appear after a couple of minutes, have them
   re-check they're logged in and that the push reported success, then retry Deploy Live.

## Defaults (do not ask unless the participant overrides)

- Proxy host: `registry.buildathon.ltl.sh`
- Login user: `hackathon`
- Image platform: **`linux/amd64` — always, no exception** (deployment supports only amd64 Linux).
- Local image tag: `hackathon-app:final`; pushed tag: UTC timestamp.
- Go-live URL: `https://buildathon.ltl.sh` → **Deploy Live**.

## Safety

- Never print the registry token. Pass it via `HACKATHON_PROXY_TOKEN`, which the push script reads
  through `docker login --password-stdin`.
- Never invent the team id. Derive it strictly from the participant's Meesho email (part before `@`,
  lowercased, non-`[a-z0-9_-]` runs → `-`, trimmed).
- The zip must stay source-only and secret-free; the zip step refuses to build if it finds `.env`,
  keys, service-account JSON, or `*.pem`/`*.key`. Do not bypass it.
- If ports `9080` or `8090` are busy, stop and tell the participant which port to free — do not push
  an unverified image.
- Do not delete registry images or attempt direct login to the underlying registry.

## Memory

- If `.agent-memory/` exists, read `state.json`, `session.md`, and `handoff.md` before starting.
- The underlying push script records non-secret push metadata (`participant_email`, `team_id`,
  `registry_url`, `last_pushed_tag`, …) to `.agent-memory/` automatically. Never store the token.
- After go-live, note in `.agent-memory/activity.md` that the participant clicked Deploy Live and
  record the live link if they share it.

## Resources

- `scripts/deploy.sh`: macOS/Linux orchestrator — build → check → zip → push, then go-live instructions.
- `scripts/deploy.ps1`: Windows PowerShell orchestrator with the same flow.
- `references/deploy-flow.md`: the combined flow, defaults, and edge cases in one place.
