param(
  [switch]$Install,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\check_and_install_tools.ps1 [-Install]

Checks tools needed for the core hackathon stack:
git, docker, docker compose, node, npm, go, sqlite3, and gh.

Default mode only reports missing tools. -Install attempts best-effort installs
on Windows with winget.
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
Test-Command "docker" "docker"
Test-Command "node" "node"
Test-Command "npm" "npm"
Test-Command "go" "go"
Test-Command "sqlite3" "sqlite3"
Test-Command "GitHub CLI gh" "gh"

if (Get-Command docker -ErrorAction SilentlyContinue) {
  try {
    docker compose version | Out-Null
    Write-Host "OK      docker compose"
  } catch {
    Write-Host "MISSING docker compose"
    $missing += "docker compose"
  }
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

winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
winget install --id GoLang.Go -e --accept-package-agreements --accept-source-agreements
winget install --id SQLite.SQLite -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
Write-Host "Docker Desktop may need to be opened once before Docker commands work."
