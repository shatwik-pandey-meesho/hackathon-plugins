---
name: hackathon-deploy
description: "One-shot hackathon deploy: build the final linux/amd64 single Docker image, run readiness checks, zip the source for manual upload, push the image through the organizer's token-authenticated proxy, and call the proxy's deploy API to start the live deployment — then hand the participant their live app link at <team-id>.buildathon.ltl.sh. Use when a participant says deploy, ship it, submit, go live, or 'do everything to get my app judged'. Combines single-image build, submission check, code zip, proxy push, and deploy trigger into one guided flow that works on macOS and Windows."
---

# Hackathon Deploy (all-in-one submission)

## Overview

This is the single, final step that takes a working app to a live, judge-ready deployment. It runs
five things in order so the participant does not have to invoke them separately:

1. **Build** the final `linux/amd64` single Docker image and smoke-test it.
2. **Check** readiness (no secrets, README present, image runs standalone with no bind mount).
3. **Zip** the source code into one clean file for manual upload.
4. **Push** the image through the organizer's Docker proxy using the default registry and login.
5. **Deploy** by calling the proxy's deploy API (`POST https://registry.buildathon.meesho.dev/admin/api/deploy`)
   with the pushed `image_tag`, which starts the live deployment automatically.

Then it hands the participant their **live application link**, which is always
`https://<team-id>.buildathon.ltl.sh` (the team id is derived from their Meesho email).

It works on **any device** — macOS/Linux use `scripts/deploy.sh`, Windows uses `scripts/deploy.ps1`.

## Container engine

Build and push need a working `docker` command with a reachable engine. The engine is
**Docker (Docker Desktop)** on every OS:

- **macOS:** use **Docker Desktop**. If it is not running, start it (`open -a Docker`) and retry.
- **Windows:** use **Docker Desktop with the Hyper-V backend** (the default). The orchestrator
  checks `docker` first. If it is missing or the daemon will not come up, `deploy.ps1` runs
  `hackathon-bootstrap/scripts/ensure_container_engine.ps1` to start an existing Docker Desktop,
  or — if Docker is missing — **enable the Hyper-V Windows feature and install Docker Desktop**
  configured for the Hyper-V backend. Pass `-SkipEngineInstall` to disable this. Enabling Hyper-V
  needs **Windows Pro/Enterprise/Education** and a **reboot** before the engine works — tell the
  participant to reboot and rerun. (Windows Home has no Hyper-V; there Docker Desktop must use its
  WSL2 backend instead.)

**Windows — always run docker commands in a fresh shell after any engine/config change.** After a
fresh Docker Desktop install (which changes `PATH`) or after the push step removes the
`"credsStore": "desktop"` line from `%USERPROFILE%\.docker\config.json`, the current shell can hold
a **stale `PATH` or stale credential state**. So:

- Run the next `docker` command (build/login/push) in a **new shell** — do not reuse the shell that
  ran the installer or the config edit.
- If `docker` is still "not found", or `docker login`/`push` still fails with a credential error in
  the **same** session, **stop retrying in that session**. A running process (including this
  Claude Code session and its child shells) inherits `PATH` at launch and cannot refresh it
  mid-run. Tell the participant to **close and reopen the terminal — or fully restart Claude Code —
  and rerun the deploy.** Retrying in the stale session will keep failing.

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
   - Everything else uses defaults: proxy host `registry.buildathon.meesho.dev`, login user `hackathon`,
     tag = UTC timestamp.
5. Run the orchestrator from the project root:
   - macOS/Linux: `scripts/deploy.sh --user <email>` with `HACKATHON_PROXY_TOKEN` set in the env.
   - Windows: `scripts\deploy.ps1 -User <email>` with `$env:HACKATHON_PROXY_TOKEN` set.
   The orchestrator runs build → check → zip → push → deploy in order and stops at the first failure.
6. When the push succeeds, report the final image URL (`registry.buildathon.meesho.dev/TEAM_ID:TAG`) and
   remind the participant to upload the printed `dist/<name>.zip` to the organizer's folder **by hand**.
7. The deploy step then calls `POST https://registry.buildathon.meesho.dev/admin/api/deploy` with the
   pushed `image_tag` (same registry token as a `Bearer` header) to start the live deployment. This is
   automatic — the participant does **not** click anything on a website. Equivalent curl:
   ```bash
   curl -X POST https://registry.buildathon.meesho.dev/admin/api/deploy \
     -H 'Authorization: Bearer <registry token>' \
     -H 'Content-Type: application/json' \
     -d '{"image_tag":"registry.buildathon.meesho.dev/<team-id>:<tag>"}'
   ```
8. **Give the participant their live application link:** `https://<team-id>.buildathon.ltl.sh`
   (for example `arnav.jose@meesho.com` → `arnav-jose` → `https://arnav-jose.buildathon.ltl.sh`).
   Tell them it may take a minute or two to come up; if it doesn't load yet, wait and refresh. If the
   deploy call fails, re-check the token and that the push reported success, then retry.

## Defaults (do not ask unless the participant overrides)

- Proxy host: `registry.buildathon.meesho.dev` (also the host of the deploy API).
- Login user: `hackathon`
- Image platform: **`linux/amd64` — always, no exception** (deployment supports only amd64 Linux).
- Local image tag: `hackathon-app:final`; pushed tag: UTC timestamp.
- Deploy API: `POST https://registry.buildathon.meesho.dev/admin/api/deploy` (`Authorization: Bearer <token>`, body `{"image_tag":"<pushed image URL>"}`).
- Live application link: `https://<team-id>.buildathon.ltl.sh`.

## Safety

- Never print the registry token. Pass it via `HACKATHON_PROXY_TOKEN`; the push script uses it for
  `docker login --password` (the token is office-IP-scoped, so CLI use is fine) and the deploy step
  sends it only as a `Bearer` header. Never echo the token to the console or write it to memory.
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
- After the deploy call succeeds, note in `.agent-memory/activity.md` that the deploy was started and
  record the live link `https://<team-id>.buildathon.ltl.sh`.

## Resources

- `scripts/deploy.sh`: macOS/Linux orchestrator — build → check → zip → push → deploy, then prints the live link. Requires a running Docker Desktop.
- `scripts/deploy.ps1`: Windows PowerShell orchestrator with the same flow, including the Windows container-engine setup (starts an existing Docker Desktop, otherwise enables Hyper-V and installs Docker Desktop with the Hyper-V backend).
- `references/deploy-flow.md`: the combined flow, defaults, and edge cases in one place.
- `../hackathon-bootstrap/scripts/ensure_container_engine.ps1`: Windows helper that guarantees a working `docker` engine — starts an existing Docker Desktop, or enables Hyper-V and installs Docker Desktop (Hyper-V backend).
- `../hackathon-bootstrap/scripts/ensure_container_engine.sh`: macOS/Linux helper that verifies Docker Desktop and, with `--install`, installs it (Homebrew on macOS, apt on Linux).
