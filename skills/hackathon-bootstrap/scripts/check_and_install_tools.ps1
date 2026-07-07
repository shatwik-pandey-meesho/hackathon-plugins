param(
  [switch]$Install,
  [switch]$PreferRancher,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\check_and_install_tools.ps1 [-Install] [-PreferRancher]

Checks tools needed for the core hackathon stack:
git, docker, docker compose, node, npm, go, and sqlite3.
(Zipping code for submission uses the built-in Compress-Archive.)

Default mode only reports missing tools. -Install attempts best-effort installs
on Windows with winget.

Container engine: on Windows the engine is set up by ensure_container_engine.ps1.
If Docker is missing or its daemon will not run (for example because WSL2 is
missing), it enables WSL2 and installs the Rancher Desktop fallback with the
'dockerd (moby)' engine so 'docker' works. -PreferRancher skips Docker Desktop
entirely and goes straight to Rancher.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
$missing = @()

function Test-Command {
  param([string]$Name, [string]$Command)
  $found = Get-Command $Command -ErrorAction SilentlyContinue
  if ($found) {
    Write-Host "OK      $Name"
  } else {
    Write-Host "MISSING $Name"
    $script:missing += $Name
  }
}

Write-Host "Detected OS: Windows"
Test-Command "git" "git"
Test-Command "node" "node"
Test-Command "npm" "npm"
Test-Command "go" "go"
Test-Command "sqlite3" "sqlite3"

# Container engine: report whether 'docker' works. On Windows this may be Docker Desktop
# or the Rancher Desktop (moby) fallback; ensure_container_engine.ps1 owns the setup.
$dockerReachable = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
  docker info *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "OK      docker engine"
    $dockerReachable = $true
    try {
      docker compose version | Out-Null
      Write-Host "OK      docker compose"
    } catch {
      Write-Host "MISSING docker compose"
      $missing += "docker compose"
    }
  } else {
    Write-Host "MISSING docker engine (docker is installed but the daemon is not reachable)"
    $missing += "docker engine"
  }
} else {
  Write-Host "MISSING docker"
  $missing += "docker"
}

if ($missing.Count -eq 0) {
  Write-Host "All core tools are available."
  exit 0
}

Write-Host ""
Write-Host "Missing tools: $($missing -join ', ')"

if (-not $Install) {
  Write-Host "Run with -Install to attempt installation."
  exit 1
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "winget is not available. Install missing tools manually."
  exit 1
}

# Language/tooling installs (not the container engine).
if ($missing -contains "git")     { winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements }
if ($missing -contains "node" -or $missing -contains "npm") { winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements }
if ($missing -contains "go")      { winget install --id GoLang.Go -e --accept-package-agreements --accept-source-agreements }
if ($missing -contains "sqlite3") { winget install --id SQLite.SQLite -e --accept-package-agreements --accept-source-agreements }

# Container engine: hand off to the dedicated helper. On Windows this starts Docker
# Desktop if it is present and working, and otherwise enables WSL2 and installs the
# Rancher Desktop fallback (moby engine) so 'docker' works for building and pushing.
if (-not $dockerReachable) {
  $ensureScript = Join-Path $PSScriptRoot "ensure_container_engine.ps1"
  if (Test-Path $ensureScript) {
    Write-Host ""
    Write-Host "==> Setting up the container engine (Docker, or the Rancher Desktop fallback)"
    if ($PreferRancher) {
      & $ensureScript -Install -PreferRancher
    } else {
      & $ensureScript -Install
    }
  } else {
    Write-Host "Could not find ensure_container_engine.ps1 next to this script."
    Write-Host "Install Rancher Desktop (with the 'dockerd (moby)' engine) manually, then retry. Do not install Docker."
  }
}
