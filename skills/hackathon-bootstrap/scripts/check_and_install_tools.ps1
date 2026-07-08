param(
  [switch]$Install,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\check_and_install_tools.ps1 [-Install]

Checks tools needed for the core hackathon stack:
git, docker, docker compose, node, npm, go, and sqlite3.
(Zipping code for submission uses the built-in Compress-Archive.)

Default mode only reports missing tools. -Install attempts best-effort installs
on Windows with winget.

Container engine: on Windows the engine is Docker Desktop with the Hyper-V backend,
set up by ensure_container_engine.ps1. If Docker is missing, it enables the Hyper-V
Windows feature, installs Docker Desktop, and configures the Hyper-V backend so
'docker' works. (Hyper-V needs Windows Pro/Enterprise/Education and a reboot.)
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

# Container engine: report whether 'docker' works. On Windows the engine is Docker Desktop
# with the Hyper-V backend; ensure_container_engine.ps1 owns the setup.
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
# Desktop if it is present, and otherwise enables Hyper-V and installs Docker Desktop
# configured for the Hyper-V backend so 'docker' works for building and pushing.
if (-not $dockerReachable) {
  $ensureScript = Join-Path $PSScriptRoot "ensure_container_engine.ps1"
  if (Test-Path $ensureScript) {
    Write-Host ""
    Write-Host "==> Setting up the container engine (Docker Desktop with the Hyper-V backend)"
    & $ensureScript -Install
  } else {
    Write-Host "Could not find ensure_container_engine.ps1 next to this script."
    Write-Host "Install Docker Desktop from https://www.docker.com/products/docker-desktop/ (Hyper-V backend) manually."
  }
}
