# Installing the Hackathon Skills

This repo contains 10 skill folders:

- `hackathon-bootstrap`
- `hackathon-feature-builder`
- `hackathon-preview`
- `hackathon-bugfix`
- `hackathon-db-helper`
- `hackathon-single-image-build`
- `hackathon-gcp-push`
- `hackathon-github`
- `hackathon-submission-check`
- `hackathon-explainer`

A "skill" is just a folder with a `SKILL.md` plus optional `references/` and `scripts/`.
Installing means **putting these folders where your agent looks for skills**. Nothing is
compiled and nothing runs during install — it is a plain folder copy.

> The installer copies skill folders only. It does **not** install Docker, Node.js, Go,
> SQLite, the GitHub CLI, or the GCP CLI. Those are installed later by the
> `hackathon-bootstrap` skill itself.

---

## Where skills go

| Agent | Personal (all projects) | One project only |
| --- | --- | --- |
| **Claude Code** | `~/.claude/skills/` | `<project>/.claude/skills/` |
| **Codex** | `${CODEX_HOME:-~/.codex}/skills/` | n/a |

Pick **personal** if you want the skills available everywhere. Pick **project** if you only
want them inside one hackathon repo (this is what this repo already does — see
`BUILDATHON/.claude/skills/`).

After any install method, the folder layout must look like this:

```text
.claude/skills/
├── hackathon-bootstrap/
│   ├── SKILL.md
│   ├── references/
│   └── scripts/
├── hackathon-preview/
│   └── SKILL.md
└── ... (one folder per skill)
```

The `SKILL.md` must sit **directly inside** each skill folder. A common mistake is nesting
an extra folder (e.g. `.claude/skills/skills/hackathon-bootstrap/`) — the agent will not find it.

---

## Quick terminal install

Run these commands from the terminal after this repo is on your machine.

### macOS / Linux — Codex

```bash
cd /path/to/skills
chmod +x scripts/install-skills.sh
./scripts/install-skills.sh --list
./scripts/install-skills.sh --agent codex
ls "${CODEX_HOME:-$HOME/.codex}/skills" | grep hackathon
```

### macOS / Linux — Claude Code

```bash
cd /path/to/skills
chmod +x scripts/install-skills.sh
./scripts/install-skills.sh --list
./scripts/install-skills.sh --agent claude
ls "$HOME/.claude/skills" | grep hackathon
```

For a single project only, install into that project's `.claude/skills` directory:

```bash
cd /path/to/skills
./scripts/install-skills.sh --agent claude --dest /path/to/hackathon-project/.claude/skills
```

### Windows PowerShell — Codex

```powershell
Set-Location C:\path\to\skills
.\scripts\install-skills.ps1 -List
.\scripts\install-skills.ps1 -Agent codex
Get-ChildItem "$HOME\.codex\skills" -Directory | Where-Object Name -Like "hackathon-*"
```

### Windows PowerShell — Claude Code

```powershell
Set-Location C:\path\to\skills
.\scripts\install-skills.ps1 -List
.\scripts\install-skills.ps1 -Agent claude
Get-ChildItem "$HOME\.claude\skills" -Directory | Where-Object Name -Like "hackathon-*"
```

If PowerShell blocks local scripts for this terminal session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

After installing, restart Codex or Claude Code so it re-scans the skills directory.

---

## Method 1 — Automated script (recommended)

The script copies every skill folder into the right place and refuses to clobber an existing
install unless you pass `--force`.

### Claude Code

macOS / Linux:

```bash
cd /path/to/skills
chmod +x scripts/install-skills.sh

# Personal (default destination: ~/.claude/skills)
./scripts/install-skills.sh --agent claude

# This project only
./scripts/install-skills.sh --agent claude --dest /path/to/hackathon-project/.claude/skills
```

Windows PowerShell:

```powershell
Set-Location C:\path\to\skills

# Personal (default destination: ~\.claude\skills)
.\scripts\install-skills.ps1 -Agent claude

# This project only
.\scripts\install-skills.ps1 -Agent claude -Dest C:\path\to\hackathon-project\.claude\skills
```

### Codex

macOS / Linux:

```bash
cd /path/to/skills
chmod +x scripts/install-skills.sh
./scripts/install-skills.sh --agent codex
```

Windows PowerShell:

```powershell
Set-Location C:\path\to\skills
.\scripts\install-skills.ps1 -Agent codex
```

### Common options (both scripts)

| Option | Effect |
| --- | --- |
| `--skills a,b,c` / `-Skills a,b,c` | Install only the named skills instead of all 10. |
| `--force` / `-Force` | Overwrite skill folders that already exist at the destination. |
| `--list` / `-List` | Print the installable skill names and exit. |
| `--dest PATH` / `-Dest PATH` | Override the destination directory. |

Examples:

```bash
cd /path/to/skills

# Just the two you need right now
./scripts/install-skills.sh --agent claude --skills hackathon-bootstrap,hackathon-preview

# Re-install on top of an older copy
./scripts/install-skills.sh --agent claude --force
```

---

## Method 2 — Manual copy/paste into `.claude`

No script needed. Copy the skill folders yourself.

macOS / Linux (personal install):

```bash
mkdir -p ~/.claude/skills
cp -R hackathon-* ~/.claude/skills/
```

macOS / Linux (one project only):

```bash
mkdir -p /path/to/your/project/.claude/skills
cp -R hackathon-* /path/to/your/project/.claude/skills/
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse hackathon-* "$HOME\.claude\skills\"
```

Or just drag the `hackathon-*` folders into `.claude/skills/` in your file manager. That is
literally all the "install" is.

---

## Method 3 — Use straight from this repo (no copy)

If an agent has been pointed directly at this `skills/` folder, it can read and use the
skill folders in place. Use this only when your agent workflow explicitly supports loading
skills from the current repo without copying them.

To reuse them in a different project without copying, point that project's
`.claude/skills/` at this repo with a symlink:

```bash
ln -s /Users/you/Projects/BUILDATHON/skills/hackathon-bootstrap \
      /path/to/other-project/.claude/skills/hackathon-bootstrap
```

---

## Method 4 — Codex native folder

Codex auto-discovers skills under `${CODEX_HOME:-~/.codex}/skills`. The automated script
(Method 1) targets this path by default for `--agent codex`. To do it by hand:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R hackathon-* "${CODEX_HOME:-$HOME/.codex}/skills/"
```

The only Codex-specific file in each skill is `agents/openai.yaml` (UI metadata). It is
harmless to other agents.

---

## Verify the install

List what is installed:

```bash
# Claude personal
ls ~/.claude/skills

# Claude project
ls .claude/skills
```

You should see the 10 `hackathon-*` folders, each containing a `SKILL.md`.

Then **restart the agent** (or start a new session) so it re-scans the skills directory.
In Claude Code you can confirm by typing `/` and looking for the `hackathon-*` skills in
the list, or by asking: *"start a new hackathon project"* — it should trigger
`hackathon-bootstrap`.

---

## Updating to a newer version

Pull the latest changes in this repo, then re-run the installer with overwrite:

```bash
git pull
./scripts/install-skills.sh --agent claude --force
```

Manual method: delete the old `hackathon-*` folders in your skills directory and re-copy.

---

## Uninstall

Delete the skill folders from your skills directory:

```bash
rm -rf ~/.claude/skills/hackathon-*
```

Nothing else is left behind — there is no global config to clean up.

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Agent does not see the skills | Confirm `SKILL.md` is **directly** inside each `hackathon-*` folder, not double-nested. Then restart the agent. |
| `Destination already exists` | An older copy is there. Re-run with `--force` / `-Force`, or delete it first. |
| `--dest is required` (older script) | Update this repo; `--agent claude` now defaults to `~/.claude/skills`. |
| Scripts won't run on Windows | Use the `.ps1` versions, and if blocked run `Set-ExecutionPolicy -Scope Process Bypass` first. |
| Permission denied on `.sh` | `chmod +x scripts/install-skills.sh`. |

For what to do **after** installing, see [USAGE.md](./USAGE.md).
