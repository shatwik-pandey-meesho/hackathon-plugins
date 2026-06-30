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

function Test-NpmScript {
  param([string]$Dir, [string]$Script)
  $packagePath = Join-Path $Dir "package.json"
  $package = Get-Content $packagePath -Raw | ConvertFrom-Json
  return ($package.scripts -and ($package.scripts.PSObject.Properties.Name -contains $Script))
}

function Get-NpmScript {
  param([string]$Dir, [string]$Label)
  if (Test-NpmScript -Dir $Dir -Script "dev") {
    return "dev"
  }
  if (Test-NpmScript -Dir $Dir -Script "start") {
    return "start"
  }
  Write-Host "$Label package.json does not define a dev or start script."
  exit 1
}

function Stop-BackendJob {
  param($Job)
  if ($Job -and $Job.State -eq "Running") {
    Stop-Job $Job | Out-Null
  }
}

function Start-NodeBackend {
  param([string]$Root)
  $backendDir = Join-Path $Root "backend"
  Write-Host "Installing backend dependencies..."
  Push-Location $backendDir
  npm install
  Pop-Location
  $script = Get-NpmScript -Dir $backendDir -Label "Backend"
  Write-Host "Starting Backend from backend with npm run $script"
  $job = Start-Job -ScriptBlock {
    param($Dir, $Port, $DataDir, $Script)
    Set-Location $Dir
    $env:PORT = "$Port"
    $env:BACKEND_PORT = "$Port"
    $env:DATA_DIR = $DataDir
    npm run $Script
  } -ArgumentList $backendDir, $BackendPort, $DataDir, $script
  Start-Sleep -Seconds 2
  if ($job.State -ne "Running") {
    Write-Host "Backend stopped before the frontend could start."
    Receive-Job $job
    exit 1
  }
  return $job
}

function Start-GoBackend {
  param([string]$Root)
  $backendDir = Join-Path $Root "backend"
  Write-Host "Starting Go backend from backend"
  $job = Start-Job -ScriptBlock {
    param($Dir, $Port, $DataDir)
    Set-Location $Dir
    $env:PORT = "$Port"
    $env:BACKEND_PORT = "$Port"
    $env:DATA_DIR = $DataDir
    go run .
  } -ArgumentList $backendDir, $BackendPort, $DataDir
  Start-Sleep -Seconds 2
  if ($job.State -ne "Running") {
    Write-Host "Backend stopped before the frontend could start."
    Receive-Job $job
    exit 1
  }
  return $job
}

function Start-Frontend {
  param([string]$Root)
  $frontendDir = Join-Path $Root "frontend"
  Write-Host "Installing frontend dependencies..."
  Push-Location $frontendDir
  npm install
  $script = Get-NpmScript -Dir $frontendDir -Label "Frontend"
  Write-Host "Starting Frontend from frontend with npm run $script"
  $env:PORT = "$FrontendPort"
  $env:FRONTEND_PORT = "$FrontendPort"
  $env:BACKEND_PORT = "$BackendPort"
  if ($script -eq "dev") {
    npm run $script -- --host 0.0.0.0 --port $FrontendPort
  } else {
    npm run $script
  }
  Pop-Location
}

if ((Get-Command docker -ErrorAction SilentlyContinue) -and (Test-Path "Dockerfile")) {
  Test-PortAvailable -Port $FrontendPort -Label "Frontend"
  Test-PortAvailable -Port $BackendPort -Label "Backend"
  New-Item -ItemType Directory -Force $DataDir | Out-Null
  Write-Host "Building Docker image: $Image"
  docker build -t $Image .
  Write-Host "Starting preview container:"
  Write-Host "  Frontend: http://localhost:$FrontendPort"
  Write-Host "  Backend:  http://localhost:$FrontendPort/api/health (through nginx / dev-server /api proxy)"
  Write-Host "  Data:     $DataDir mounted at /app/data"
  docker run --rm -p "${FrontendPort}:9080" -p "${BackendPort}:8090" -v "${DataDir}:/app/data" $Image
  exit 0
}

if ((Get-Command docker -ErrorAction SilentlyContinue) -and ((Test-Path "docker-compose.yml") -or (Test-Path "compose.yml"))) {
  Test-PortAvailable -Port $FrontendPort -Label "Frontend"
  Test-PortAvailable -Port $BackendPort -Label "Backend"
  Write-Host "Starting Docker Compose preview:"
  Write-Host "  Frontend: http://localhost:$FrontendPort"
  Write-Host "  Backend:  http://localhost:$FrontendPort/api/health (through nginx / dev-server /api proxy)"
  docker compose up --build
  exit 0
}

if ((Test-Path "frontend/package.json") -and ((Test-Path "backend/package.json") -or (Test-Path "backend/go.mod")) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
  Test-PortAvailable -Port $FrontendPort -Label "Frontend"
  Test-PortAvailable -Port $BackendPort -Label "Backend"
  New-Item -ItemType Directory -Force $DataDir | Out-Null
  Write-Host "Starting source preview:"
  Write-Host "  Frontend: http://localhost:$FrontendPort"
  Write-Host "  Backend:  http://localhost:$FrontendPort/api/health (through nginx / dev-server /api proxy)"
  Write-Host "  Data:     $DataDir"
  $root = (Get-Location).Path
  $backendJob = $null
  try {
    if (Test-Path "backend/package.json") {
      $backendJob = Start-NodeBackend -Root $root
    } elseif (Get-Command go -ErrorAction SilentlyContinue) {
      $backendJob = Start-GoBackend -Root $root
    } else {
      Write-Host "backend/go.mod exists, but Go is not installed or not on PATH."
      exit 1
    }
    Start-Frontend -Root $root
  } finally {
    Stop-BackendJob -Job $backendJob
  }
  exit 0
}

if ((Test-Path "package.json") -and (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Host "Starting npm preview. Check the terminal output for the URL."
  npm install
  npm run dev --if-present
  exit 0
}

Write-Host "Could not find a Dockerfile, Compose file, root npm project, or frontend/ plus backend/ project to preview."
exit 1
