# Installing Skills

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

## Codex

Codex can use these as native skills when they are copied into:

```text
${CODEX_HOME:-$HOME/.codex}/skills
```

### macOS/Linux

```bash
./scripts/install-skills.sh --agent codex
```

Install only a few skills:

```bash
./scripts/install-skills.sh --agent codex --skills hackathon-bootstrap,hackathon-preview
```

Overwrite an existing install:

```bash
./scripts/install-skills.sh --agent codex --force
```

### Windows PowerShell

```powershell
.\scripts\install-skills.ps1 -Agent codex
```

Install only a few skills:

```powershell
.\scripts\install-skills.ps1 -Agent codex -Skills hackathon-bootstrap,hackathon-preview
```

Overwrite an existing install:

```powershell
.\scripts\install-skills.ps1 -Agent codex -Force
```

After install, restart Codex.

## Claude

These skills are not a native Claude auto-discovery format in the same way they are for Codex. The practical method is to copy the skill folders into a directory you control, then point your Claude agent workflow at that directory.

### macOS/Linux

```bash
./scripts/install-skills.sh --agent claude --dest "$HOME/claude-skills"
```

### Windows PowerShell

```powershell
.\scripts\install-skills.ps1 -Agent claude -Dest "$HOME\claude-skills"
```

You can then configure your Claude workflow to read those skill folders, including `SKILL.md`, `references/`, and `scripts/`.

## List Available Skills

### macOS/Linux

```bash
./scripts/install-skills.sh --list
```

### Windows PowerShell

```powershell
.\scripts\install-skills.ps1 -List
```

## Notes

- `codex` mode has a default destination.
- `claude` mode requires `--dest` or `-Dest`.
- `--force` or `-Force` overwrites existing destination skill folders.
- The installer only copies the selected skill folders. It does not install Docker, Node.js, Go, SQLite, GitHub CLI, or GCP CLI.
