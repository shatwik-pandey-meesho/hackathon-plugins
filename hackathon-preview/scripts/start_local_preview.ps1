param(
  [string]$Image = $env:IMAGE,
  [int]$FrontendPort = $(if ($env:FRONTEND_PORT) { [int]$env:FRONTEND_PORT } else { 9080 }),
  [int]$BackendPort = $(if ($env:BACKEND_PORT) { [int]$env:BACKEND_PORT } else { 8090 }),
  [string]$DataDir = $(if ($env:DATA_DIR) { $env:DATA_DIR } else { Join-Path (Get-Location) "data" }),
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\start_local_preview.ps1 [-Image hackathon-app:local] [-FrontendPort 9080] [-BackendPort 8090] [-DataDir .\data]

Runs the current project locally and prints the browser URL.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
if (-not $Image) { $Image = "hackathon-app:local" }

function Test-PortAvailable {
  param([int]$Port, [string]$Label)
  $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
  if ($connection) {
    Write-Host "$Label port $Port is already being used by another program."
    Write-Host "Close that program or move it to another port, then retry."
    exit 1
  }
}

if ((Get-Command docker -ErrorAction SilentlyContinue) -and (Test-Path "Dockerfile")) {
  Test-PortAvailable -Port $FrontendPort -Label "Frontend"
  Test-PortAvailable -Port $BackendPort -Label "Backend"
  New-Item -ItemType Directory -Force $DataDir | Out-Null
  Write-Host "Building Docker image: $Image"
  docker build -t $Image .
  Write-Host "Starting preview container:"
  Write-Host "  Frontend: http://localhost:$FrontendPort"
  Write-Host "  Backend:  http://localhost:$BackendPort/health"
  Write-Host "  Data:     $DataDir mounted at /app/data"
  docker run --rm -p "${FrontendPort}:9080" -p "${BackendPort}:8090" -v "${DataDir}:/app/data" $Image
  exit 0
}

if ((Test-Path "docker-compose.yml") -or (Test-Path "compose.yml")) {
  Test-PortAvailable -Port $FrontendPort -Label "Frontend"
  Test-PortAvailable -Port $BackendPort -Label "Backend"
  Write-Host "Starting Docker Compose preview:"
  Write-Host "  Frontend: http://localhost:$FrontendPort"
  Write-Host "  Backend:  http://localhost:$BackendPort/health"
  docker compose up --build
  exit 0
}

if ((Test-Path "package.json") -and (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Host "Starting npm preview. Check the terminal output for the URL."
  npm install
  npm run dev --if-present
  exit 0
}

Write-Host "Could not find a Dockerfile, Compose file, or npm project to preview."
exit 1
