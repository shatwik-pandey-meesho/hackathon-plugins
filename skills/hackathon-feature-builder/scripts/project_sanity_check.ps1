param(
  [string]$ProjectRoot = ".",
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\project_sanity_check.ps1 [-ProjectRoot .]

Checks the expected hackathon project structure and runs available frontend/backend tests.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot
$failed = $false

function Check-Path {
  param([string]$Path)
  if (Test-Path $Path) {
    Write-Host "OK      $Path"
  } else {
    Write-Host "MISSING $Path"
    $script:failed = $true
  }
}

Write-Host "Checking hackathon project shape..."
Check-Path "frontend"
Check-Path "backend"
Check-Path "db"
Check-Path "Dockerfile"

if (Test-Path "frontend/package.json") {
  Write-Host "OK      frontend/package.json"
} elseif (Test-Path "package.json") {
  Write-Host "OK      package.json"
} else {
  Write-Host "MISSING frontend/package.json or package.json"
  $failed = $true
}

if (Test-Path "db/init.sql") {
  Write-Host "OK      db/init.sql"
} else {
  Write-Host "WARN    db/init.sql not found; ensure SQLite schema is initialized another way"
}

if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Test-Path "frontend/package.json")) {
  Push-Location frontend
  npm run build --if-present
  Pop-Location
}

if ((Get-Command go -ErrorAction SilentlyContinue) -and (Test-Path "backend/go.mod")) {
  Push-Location backend
  go test ./...
  Pop-Location
}

if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Test-Path "backend/package.json")) {
  Push-Location backend
  npm test --if-present
  Pop-Location
}

if ($failed) { exit 1 }
