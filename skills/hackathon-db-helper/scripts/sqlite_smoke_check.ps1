param(
  [string]$Database = $(if ($env:SQLITE_DATABASE) { $env:SQLITE_DATABASE } else { "data/hackathon.db" }),
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\sqlite_smoke_check.ps1 [-Database data/hackathon.db]

Checks SQLite database accessibility and lists tables.
"@
  exit 0
}

$ErrorActionPreference = "Stop"

if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
  Write-Host "sqlite3 is not installed."
  exit 1
}

if (-not (Test-Path $Database)) {
  Write-Host "SQLite database file not found: $Database"
  Write-Host "If this is a new project, initialize it from db/init.sql first."
  exit 1
}

sqlite3 $Database "SELECT 'sqlite_ok' AS status; SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
