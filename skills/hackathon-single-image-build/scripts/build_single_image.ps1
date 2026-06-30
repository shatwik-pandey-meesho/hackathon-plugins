param(
  [string]$Image = "hackathon-app:final",
  [int]$FrontendPort = $(if ($env:FRONTEND_PORT) { [int]$env:FRONTEND_PORT } else { 9080 }),
  [int]$BackendPort = $(if ($env:BACKEND_PORT) { [int]$env:BACKEND_PORT } else { 8090 }),
  [string]$DataDir = $(if ($env:DATA_DIR) { $env:DATA_DIR } else { Join-Path (Get-Location) "data" }),
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\build_single_image.ps1 [-Image hackathon-app:final] [-FrontendPort 9080] [-BackendPort 8090] [-DataDir .\data]

Builds the final single Docker image and smoke-tests it.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
$container = "hackathon-smoke-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host "Docker is not installed or not on PATH."
  exit 1
}

if (-not (Test-Path "Dockerfile")) {
  Write-Host "Dockerfile not found in current directory."
  exit 1
}

function Test-PortAvailable {
  param([int]$Port, [string]$Label)
  $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
  if ($connection) {
    Write-Host "$Label port $Port is already being used by another program."
    Write-Host "Close that program or move it to another port, then retry."
    exit 1
  }
}

Test-PortAvailable -Port $FrontendPort -Label "Frontend"
Test-PortAvailable -Port $BackendPort -Label "Backend"
New-Item -ItemType Directory -Force $DataDir | Out-Null

try {
  Write-Host "Building $Image"
  docker build -t $Image .

  Write-Host "Starting smoke test container"
  docker run -d --name $container -p "${FrontendPort}:9080" -p "${BackendPort}:8090" -v "${DataDir}:/app/data" $Image | Out-Null

  Write-Host "Waiting for frontend on http://localhost:$FrontendPort/ and backend via nginx on http://localhost:$FrontendPort/api/health"
  for ($i = 0; $i -lt 45; $i++) {
    try {
      curl.exe -fsS "http://localhost:$FrontendPort/" | Out-Null
      curl.exe -fsS "http://localhost:$FrontendPort/api/health" | Out-Null
      Write-Host "Frontend and backend-through-nginx (/api) checks passed."
      Write-Host "Image ready: $Image"
      Write-Host "Run command: docker run --rm -p 9080:9080 -p 8090:8090 -v ${PWD}/data:/app/data $Image"
      exit 0
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  Write-Host "Smoke test failed. Recent container logs:"
  docker logs --tail=200 $container
  exit 1
} finally {
  docker rm -f $container *> $null
}
