param(
  [string]$OutDir = ".hackathon-diagnostics",
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\collect_diagnostics.ps1 [-OutDir .hackathon-diagnostics]

Collects local project, git, Docker, port, and HTTP diagnostics into text files.
"@
  exit 0
}

$ErrorActionPreference = "Continue"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Capture {
  param([string]$Name, [scriptblock]$Block)
  $path = Join-Path $OutDir "$Name.txt"
  & $Block *>&1 | Out-File -FilePath $path -Encoding utf8
}

Write-Host "Collecting diagnostics in $OutDir"
Capture "pwd" { Get-Location }
Capture "files" { Get-ChildItem -Recurse -File | Select-Object -First 500 -ExpandProperty FullName }

if (Get-Command git -ErrorAction SilentlyContinue) {
  Capture "git-status" { git status --short }
}

if (Get-Command docker -ErrorAction SilentlyContinue) {
  Capture "docker-version" { docker version }
  Capture "docker-ps" { docker ps -a }
  if ((Test-Path "docker-compose.yml") -or (Test-Path "compose.yml")) {
    Capture "docker-compose-logs" { docker compose logs --tail=200 }
  }
}

Capture "port-9080-frontend" { Get-NetTCPConnection -LocalPort 9080 -ErrorAction SilentlyContinue }
Capture "port-8090-backend" { Get-NetTCPConnection -LocalPort 8090 -ErrorAction SilentlyContinue }

if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
  Capture "backend-health-localhost-8090" { curl.exe -fsS http://localhost:8090/health }
  Capture "frontend-root-localhost-9080" { curl.exe -I http://localhost:9080/ }
}

Write-Host "Diagnostics collected. Read the files in $OutDir."
