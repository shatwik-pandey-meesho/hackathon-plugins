param(
  [string]$ProjectRoot = ".",
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\recontextualize_agent_memory.ps1 [-ProjectRoot .]

Prints the durable memory files so a new session can rebuild project context.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
$memoryDir = Join-Path $ProjectRoot ".agent-memory"

if (-not (Test-Path $memoryDir)) {
  Write-Host "No .agent-memory directory found at $memoryDir"
  exit 1
}

foreach ($file in @("state.json", "session.md", "handoff.md", "activity.md")) {
  $path = Join-Path $memoryDir $file
  if (Test-Path $path) {
    Write-Host "===== $file ====="
    Get-Content $path
    Write-Host ""
  }
}
