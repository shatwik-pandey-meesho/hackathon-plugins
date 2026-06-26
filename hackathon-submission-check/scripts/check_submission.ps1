param(
  [string]$Image = "hackathon-app:final",
  [int]$FrontendPort = $(if ($env:FRONTEND_PORT) { [int]$env:FRONTEND_PORT } else { 9080 }),
  [int]$BackendPort = $(if ($env:BACKEND_PORT) { [int]$env:BACKEND_PORT } else { 8090 }),
  [string]$DataDir = $(if ($env:DATA_DIR) { $env:DATA_DIR } else { Join-Path (Get-Location) "data" }),
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\check_submission.ps1 [-Image hackathon-app:final] [-FrontendPort 9080] [-BackendPort 8090] [-DataDir .\data]

Builds and smoke-tests the final single image, checks GitHub remote status,
and scans committed files for obvious secrets.
"@
  exit 0
}

$ErrorActionPreference = "Continue"
$failed = $false

function Pass($msg) { Write-Host "PASS  $msg" }
function Fail($msg) { Write-Host "FAIL  $msg"; $script:failed = $true }
function Warn($msg) { Write-Host "WARN  $msg" }

if (Test-Path "Dockerfile") { Pass "Dockerfile exists" } else { Fail "Dockerfile missing" }
if (Test-Path "README.md") { Pass "README exists" } else { Warn "README missing" }
if (Test-Path ".git") { Pass "git repo exists" } else { Warn "git repo missing" }

if (Test-Path ".git") {
  git remote get-url origin *> $null
  if ($LASTEXITCODE -eq 0) {
    Pass "GitHub remote configured: $(git remote get-url origin)"
  } else {
    Warn "GitHub remote not configured"
  }

  $secretPattern = 'BEGIN (RSA|OPENSSH) PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z_]{30,}|password *= *[^ ]+'
  $matches = git grep -n -E $secretPattern HEAD -- . 2>$null
  if ($matches) {
    $matches | Out-File -FilePath "$env:TEMP\hackathon-secret-scan.txt" -Encoding utf8
    Fail "possible secret found in committed files; inspect $env:TEMP\hackathon-secret-scan.txt"
  } else {
    Pass "no obvious committed secrets found"
  }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Fail "Docker missing"
  if ($failed) { exit 1 }
}

function Test-PortAvailable {
  param([int]$Port, [string]$Label)
  $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
  if ($connection) {
    Fail "$Label port $Port is already being used by another program. Close that program or move it to another port, then retry."
  }
}

Test-PortAvailable -Port $FrontendPort -Label "Frontend"
Test-PortAvailable -Port $BackendPort -Label "Backend"
if ($failed) { exit 1 }
New-Item -ItemType Directory -Force $DataDir | Out-Null

if (Test-Path "Dockerfile") {
  Write-Host "Building image $Image"
  docker build -t $Image .
  if ($LASTEXITCODE -eq 0) { Pass "image builds" } else { Fail "image build failed"; exit 1 }
}

$container = "hackathon-final-check-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
try {
  docker run -d --name $container -p "${FrontendPort}:9080" -p "${BackendPort}:8090" -v "${DataDir}:/app/data" $Image | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Pass "container starts"
    Pass "repo-local SQLite data directory mounted: $DataDir -> /app/data"
  } else {
    Fail "container failed to start"
    exit 1
  }

  $ready = $false
  for ($i = 0; $i -lt 45; $i++) {
    try {
      curl.exe -fsS "http://localhost:$BackendPort/health" | Out-Null
      Pass "health endpoint responds"
      try {
        curl.exe -fsS "http://localhost:$FrontendPort/" | Out-Null
        Pass "frontend responds"
        $ready = $true
        break
      } catch {
        Start-Sleep -Seconds 2
      }
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  if (-not $ready) {
    Fail "app did not respond on frontend http://localhost:$FrontendPort and backend http://localhost:$BackendPort/health"
    docker logs --tail=100 $container
  }
} finally {
  docker rm -f $container *> $null
}

if (Get-Command gcloud -ErrorAction SilentlyContinue) {
  Warn "gcloud is installed; registry URL still needs to be confirmed from push output"
} else {
  Warn "gcloud missing; cannot verify Artifact Registry push from this machine"
}

if ($failed) { exit 1 }
