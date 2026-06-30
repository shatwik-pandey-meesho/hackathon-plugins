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

Builds and smoke-tests the final single image and scans project files for
obvious secrets. Zipping code for submission is handled by hackathon-zip-code.
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

# Scan project files (not git) for secret-looking files and content.
$skipDirs = @('node_modules', '.git', 'data', 'dist')
$secretFiles = Get-ChildItem -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
  $rel = $_.FullName.Substring((Get-Location).Path.Length).TrimStart('\','/')
  $top = ($rel -split '[\\/]')[0]
  if ($skipDirs -contains $top) { return $false }
  if ($_.Name -eq '.env.example') { return $false }
  ($_.Name -eq '.env' -or $_.Name -like '.env.*' -or $_.Name -like '*.pem' -or $_.Name -like '*.key' -or $_.Name -like '*service-account*.json')
}
if ($secretFiles) {
  Fail "secret-looking files present (keep these out of the uploaded zip): $($secretFiles.FullName -join ', ')"
} else {
  Pass "no secret-looking files in the project"
}

$secretPattern = 'BEGIN (RSA|OPENSSH) PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|password *= *[^ ]+'
$contentHits = Get-ChildItem -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
  $top = ($_.FullName.Substring((Get-Location).Path.Length).TrimStart('\','/') -split '[\\/]')[0]
  -not ($skipDirs -contains $top)
} | Select-String -Pattern $secretPattern -ErrorAction SilentlyContinue
if ($contentHits) {
  $contentHits | Out-File -FilePath "$env:TEMP\hackathon-secret-scan.txt" -Encoding utf8
  Fail "possible secret found in project files; inspect $env:TEMP\hackathon-secret-scan.txt"
} else {
  Pass "no obvious secret content found"
}

if ((Test-Path ".agent-memory/state.json") -and ((Get-Content -Raw ".agent-memory/state.json") -match '"code_zip"\s*:\s*"[^"]+"')) {
  Pass "code zip built (code_zip recorded) - remember to upload it to the organizer's folder by hand"
} else {
  Warn "no code zip built yet; run hackathon-zip-code, then upload the zip to the organizer's folder manually"
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
      curl.exe -fsS "http://localhost:$FrontendPort/api/health" | Out-Null
      Pass "backend responds through nginx at /api/health"
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
    Fail "app did not respond on frontend http://localhost:$FrontendPort/ and backend via nginx http://localhost:$FrontendPort/api/health (is nginx proxying /api to the backend?)"
    docker logs --tail=100 $container
  }
} finally {
  docker rm -f $container *> $null
}

Warn "Registry upload through the organizer proxy is handled by hackathon-deploy-by-pushing-image when the final image is ready"

if ($failed) { exit 1 }
