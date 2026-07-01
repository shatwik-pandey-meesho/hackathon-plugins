# Hackathon Skill Pack

This repo contains agent skills for a restricted-stack hackathon where teams build one final Docker image.

Allowed stack:

- React.js frontend
- Node.js or Go backend
- SQLite database
- One final Docker image for judging

Required local ports:

- Frontend React app: `9080`
- Backend Node.js or Go API: `8090`

Claude or another agent should handle these ports during setup. If either port is already used by another program, that program must be closed or moved before the prototype can run correctly.

SQLite data is stored as a repo-local file, normally `data/hackathon.db`. Docker runs mount
the repo's ignored `data/` directory into the container at `/app/data`, so saved records
survive container restarts while `.db` files stay out of the uploaded zip.

## Submitting code

Source code is submitted as a **zip the participant uploads by hand** — no GitHub, no git, and
no cloud connector. `hackathon-zip-code` builds a clean, source-only zip (secrets and `node_modules/`
excluded) and tells the participant to upload that single file to the organizer's designated
submission folder themselves.

Separately, when pushing the judging image, `hackathon-deploy-by-pushing-image` **always asks for
the participant's Meesho organization email** unless it is already in local `.agent-memory/`, then
uses the email-derived team ID to name the image (`registry.buildathon.ltl.sh/TEAM_ID:TIMESTAMP`).
The team ID is the lowercase email prefix with non `a-z`, `0-9`, `_`, or `-` characters collapsed
to hyphens, so `priya.sharma@meesho.com` becomes `priya-sharma`.

## Skills

- `hackathon-bootstrap`: set up tools and create/repair the starter app.
- `hackathon-feature-builder`: add features from plain-language requests.
- `hackathon-preview`: run the app locally and provide a browser URL.
- `hackathon-bugfix`: diagnose and fix common app, Docker, and database failures.
- `hackathon-db-helper`: make safe SQLite schema and data changes.
- `hackathon-single-image-build`: build and smoke-test the final image.
- `hackathon-deploy-by-pushing-image`: verify the image locally, then push it through the organizer Docker proxy.
- `hackathon-zip-code`: zip the source code into one clean file for the participant to upload by hand to the organizer's folder.
- `hackathon-submission-check`: run the final judging readiness checklist.
- `hackathon-explainer`: explain technical results in non-technical language.

## Script Safety

Scripts default to checks where possible. Installing packages and pushing images should be run only after the participant or organizer confirms the action.

## Agent Compatibility

These skills are usable by Codex, Claude, Gemini, or another terminal-capable agent because the important instructions live in plain Markdown and the automation lives in Bash and PowerShell scripts.

- Codex: can use each `SKILL.md` as a native skill folder. `agents/openai.yaml` provides Codex UI metadata.
- Claude or Gemini: can use the same folders when their agent runner is told to read the relevant `SKILL.md`, follow linked `references/`, and run scripts from `scripts/`.
- Any terminal agent: should be given the repo path, the relevant skill folder, and permission rules for installs and Docker.

The only Codex-specific file is `agents/openai.yaml`. The workflows, references, and scripts are tool-agnostic.

Windows participants can use the PowerShell scripts in each `scripts/` folder. macOS and Linux participants can use the Bash scripts.

## Installing

### Claude Code marketplace (recommended)

This repo is a Claude Code plugin marketplace. From inside Claude Code, run:

```
/plugin marketplace add shatwik-pandey-meesho/hackathon-plugins
/plugin install hackathon-skills@hackathon-plugins
```

All ten skills install at once and load automatically, namespaced as
`hackathon-skills:hackathon-bootstrap`, `hackathon-skills:hackathon-bugfix`, etc.
No clone or copy step is needed. To update later, run
`/plugin marketplace update hackathon-plugins`. The repo is public, so no token is required.

You can also do this without typing commands — see the **plugin UI** method in
[INSTALLING.md](./INSTALLING.md) (`/plugin` → *Manage plugins* → add the
`https://github.com/shatwik-pandey-meesho/hackathon-plugins` marketplace, then install).

### Script install (Codex, or copy into `.claude`)

From a terminal in this repo, install the skills with these steps.

macOS/Linux for Codex:

```bash
cd /path/to/skills
chmod +x scripts/install-skills.sh
./scripts/install-skills.sh --list
./scripts/install-skills.sh --agent codex
```

macOS/Linux for Claude Code:

```bash
cd /path/to/skills
chmod +x scripts/install-skills.sh
./scripts/install-skills.sh --list
./scripts/install-skills.sh --agent claude
```

Windows PowerShell for Codex:

```powershell
Set-Location C:\path\to\skills
.\scripts\install-skills.ps1 -List
.\scripts\install-skills.ps1 -Agent codex
```

Windows PowerShell for Claude Code:

```powershell
Set-Location C:\path\to\skills
.\scripts\install-skills.ps1 -List
.\scripts\install-skills.ps1 -Agent claude
```

Restart the agent after installing so it re-scans the skills directory.

See [INSTALLING.md](./INSTALLING.md) for all install methods (automated script, manual copy into `.claude`, use-from-repo, Codex).

## Using the Skills

See [USAGE.md](./USAGE.md) for how the skills work together, the guardrails they enforce, and a full worked example that takes a non-technical team from an empty laptop to a judge-ready image.
