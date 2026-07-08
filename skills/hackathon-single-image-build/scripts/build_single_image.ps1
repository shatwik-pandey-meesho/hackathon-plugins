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
  Write-Host "On Windows, set up the engine with:"
  Write-Host "  ..\..\hackathon-bootstrap\scripts\ensure_container_engine.ps1 -Install"
  Write-Host "(enables Hyper-V and installs Docker Desktop with the Hyper-V backend)."
  exit 1
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Docker is installed but the engine is not reachable."
  Write-Host "Start Docker Desktop, or on Windows run:"
  Write-Host "  ..\..\hackathon-bootstrap\scripts\ensure_container_engine.ps1 -Install"
  Write-Host "then retry."
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
  # Deployment supports only linux/amd64. Force it so ARM hosts never produce an
  # arm64 image that fails at judging.
  $env:DOCKER_DEFAULT_PLATFORM = "linux/amd64"
  docker build --platform linux/amd64 -t $Image .

  $builtArch = (docker image inspect $Image --format '{{.Os}}/{{.Architecture}}' 2>$null)
  if ($builtArch -ne "linux/amd64") {
    Write-Host "Built image platform is '$builtArch', but deployment requires 'linux/amd64'."
    Write-Host "Ensure your Docker engine (Docker Desktop) supports amd64 emulation and retry."
    exit 1
  }
  Write-Host "Verified image platform: linux/amd64"

  Write-Host "Starting smoke test container"
  docker run -d --platform linux/amd64 --name $container -p "${FrontendPort}:9080" -p "${BackendPort}:8090" -v "${DataDir}:/app/data" $Image | Out-Null

  Write-Host "Waiting for frontend on http://localhost:$FrontendPort/ and backend via nginx on http://localhost:$FrontendPort/api/health"
  for ($i = 0; $i -lt 45; $i++) {
    try {
      curl.exe -fsS "http://localhost:$FrontendPort/" | Out-Null
      curl.exe -fsS "http://localhost:$FrontendPort/api/health" | Out-Null
      Write-Host "Frontend and backend-through-nginx (/api) checks passed."
      Write-Host "Image ready: $Image"
      Write-Host "Run command: docker run --rm --platform linux/amd64 -p 9080:9080 -p 8090:8090 -v ${PWD}/data:/app/data $Image"
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
