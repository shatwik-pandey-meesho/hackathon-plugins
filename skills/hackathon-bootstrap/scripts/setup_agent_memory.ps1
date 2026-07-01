param(
  [string]$ProjectRoot = ".",
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\setup_agent_memory.ps1 [-ProjectRoot .]

Creates the durable .agent-memory files used to resume the project in later sessions.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
$memoryDir = Join-Path $ProjectRoot ".agent-memory"
New-Item -ItemType Directory -Force -Path $memoryDir | Out-Null

$statePath = Join-Path $memoryDir "state.json"
if (-not (Test-Path $statePath)) {
  @'
{
  "project_name": "",
  "app_idea": "",
  "frontend_port": 9080,
  "backend_port": 8090,
  "frontend_framework": "react",
  "backend_language": "",
  "database": "sqlite",
  "participant_email": "",
  "team_id": "",
  "image_tag": "",
  "registry_url": "",
  "registry_proxy_host": "registry.buildathon.ltl.sh",
  "registry_login_user": "hackathon",
  "last_pushed_image": "",
  "last_pushed_tag": "",
  "code_zip": "",
  "last_successful_step": "",
  "current_status": "bootstrapping",
  "current_blocker": "",
  "next_action": "",
  "last_updated": ""
}
'@ | Set-Content -Path $statePath -Encoding utf8
}

$sessionPath = Join-Path $memoryDir "session.md"
if (-not (Test-Path $sessionPath)) {
  @'
# Session Memory

## Current State

- Project idea:
- Stack:
- Frontend URL: http://localhost:9080
- Backend health URL (through nginx /api): http://localhost:9080/api/health
- What works:
- What is blocked:
- Most recent changes:
'@ | Set-Content -Path $sessionPath -Encoding utf8
}

$handoffPath = Join-Path $memoryDir "handoff.md"
if (-not (Test-Path $handoffPath)) {
  @'
# Handoff

## Current Blocker

- None recorded.

## Next Action

- None recorded.

## Expected Result

- None recorded.
'@ | Set-Content -Path $handoffPath -Encoding utf8
}

$activityPath = Join-Path $memoryDir "activity.md"
if (-not (Test-Path $activityPath)) {
  @'
# Activity Log

'@ | Set-Content -Path $activityPath -Encoding utf8
}

Write-Host "Agent memory is ready at $memoryDir"
