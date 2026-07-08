param(
  [string]$ProxyHost = "registry.buildathon.meesho.dev",
  [string]$LoginUser = "hackathon",
  [string]$Token = $env:HACKATHON_PROXY_TOKEN,
  [string]$LocalImage,
  [string]$User = $env:MEESHO_EMAIL,
  [string]$Tag,
  [string]$DataDir,
  [int]$FrontendPort = $(if ($env:FRONTEND_PORT) { [int]$env:FRONTEND_PORT } else { 9080 }),
  [int]$BackendPort = $(if ($env:BACKEND_PORT) { [int]$env:BACKEND_PORT } else { 8090 }),
  [switch]$SkipSmoke,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\push_to_proxy_registry.ps1 -Token TOKEN -LocalImage IMAGE [options]

Logs in to a token-authenticated Docker proxy, verifies the local image starts,
tags it as HOST/TEAM_ID:TAG, and pushes it.

Required:
  -Token TOKEN          Registry token or password. Can also use HACKATHON_PROXY_TOKEN.
  -LocalImage IMAGE     Existing local image to push, for example hackathon-app:final
  -User EMAIL           Participant's Meesho email. Can also use MEESHO_EMAIL.

Options:
  -ProxyHost HOST       Proxy registry host. Default: registry.buildathon.meesho.dev
  -LoginUser USER       Docker login username. Default: hackathon
  -Tag TAG              Final image tag. Default: UTC timestamp, e.g. 20260701-053012
  -DataDir DIR          Optional host data dir to mount to /app/data during smoke test.
                        Final images should normally pass without this.
  -SkipSmoke            Skip local container health check. Use only if already checked.
  -Help                 Show this help text.

Final image URL:
  HOST/TEAM_ID:TAG
"@
  exit 0
}

$ErrorActionPreference = "Stop"

function Fail($Message) {
  Write-Error $Message
  exit 1
}

function Test-Command($Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Docker Desktop on Windows writes "credsStore": "desktop" into %USERPROFILE%\.docker\config.json.
# That credential helper very commonly breaks 'docker login'/'docker push' to the proxy. Remove
# the entry (backing the file up first) so credentials are written directly to config.json.
function Repair-DockerCredsStore {
  $configPath = Join-Path $env:USERPROFILE ".docker\config.json"
  if (-not (Test-Path $configPath)) { return }
  try {
    $config = Get-Content -Raw $configPath | ConvertFrom-Json
    if (($config.PSObject.Properties.Name -contains "credsStore") -and ($config.credsStore -eq "desktop")) {
      Copy-Item $configPath "$configPath.bak" -Force
      $config.PSObject.Properties.Remove("credsStore")
      $config | ConvertTo-Json -Depth 20 | Set-Content -Path $configPath -Encoding ascii
      Write-Host "Removed 'credsStore: desktop' from $configPath (backup at config.json.bak) to fix Windows Docker login."
      Write-Host "IMPORTANT: run the login/push from a NEW shell so the change is picked up cleanly."
      Write-Host "If this push fails right after the edit, open a fresh terminal (or restart Claude Code) and rerun."
    }
  } catch {
    Write-Warning "Could not adjust $configPath automatically: $($_.Exception.Message)."
    Write-Warning "If login fails, remove the '`"credsStore`": `"desktop`",' line from that file and retry."
  }
}

if ([string]::IsNullOrWhiteSpace($Token)) { Fail "-Token is required, or set HACKATHON_PROXY_TOKEN." }
if ([string]::IsNullOrWhiteSpace($LocalImage)) { Fail "-LocalImage is required." }
if ([string]::IsNullOrWhiteSpace($LoginUser)) { Fail "-LoginUser cannot be empty." }
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss") }

if (-not (Test-Command "docker")) {
  Fail "Docker is not installed or not on PATH. On Windows, set up the engine with ..\..\hackathon-bootstrap\scripts\ensure_container_engine.ps1 -Install (enables Hyper-V and installs Docker Desktop), then retry."
}
if (-not (Test-Command "curl")) { Fail "curl is required for the local health check." }
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Fail "Docker is installed, but the Docker daemon is not reachable. Start Docker Desktop, or on Windows run ..\..\hackathon-bootstrap\scripts\ensure_container_engine.ps1 -Install to enable Hyper-V and install Docker Desktop, then retry."
}

$ProxyHost = $ProxyHost -replace "^https?://", ""
$ProxyHost = $ProxyHost.TrimEnd("/")
if ($ProxyHost.Contains("/")) { Fail "-ProxyHost must be only the registry host, without a path." }

if ([string]::IsNullOrWhiteSpace($User) -and (Test-Path ".agent-memory/state.json")) {
  try {
    $state = Get-Content -Raw ".agent-memory/state.json" | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace($state.participant_email)) {
      $User = $state.participant_email
    } elseif (-not [string]::IsNullOrWhiteSpace($state.team_id)) {
      $User = $state.team_id
    }
  } catch {}
}

if ([string]::IsNullOrWhiteSpace($User)) {
  Fail "Could not determine the participant email. Pass -User, or set MEESHO_EMAIL."
}

function ConvertTo-TeamId($EmailOrSlug) {
  $prefix = ($EmailOrSlug -split "@")[0].ToLowerInvariant()
  $slug = [regex]::Replace($prefix, "[^a-z0-9_-]+", "-")
  $slug = $slug.Trim("-")
  return $slug
}

$teamId = ConvertTo-TeamId $User

if ([string]::IsNullOrWhiteSpace($teamId) -or ($teamId -notmatch "^([a-z0-9]|[a-z0-9][a-z0-9_-]*[a-z0-9])$")) {
  Fail "Email '$User' becomes invalid team id '$teamId'. Use a Meesho email with letters or numbers before @."
}
if ($Tag -notmatch "^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$") {
  Fail "Invalid Docker tag '$Tag'. Use letters, numbers, underscores, dots, or dashes."
}

docker image inspect $LocalImage *> $null
if ($LASTEXITCODE -ne 0) {
  Fail "Local image '$LocalImage' does not exist. Build it before pushing."
}

function Test-PortAvailable($Port, $Label) {
  $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
  if ($connection) {
    Fail "$Label port $Port is already being used. Close that program or set FRONTEND_PORT/BACKEND_PORT to free ports."
  }
}

function Smoke-TestImage {
  $container = "hackathon-proxy-smoke-$([System.Random]::new().Next(100000, 999999))"
  $runArgs = @("run", "-d", "--name", $container, "-p", "${FrontendPort}:9080", "-p", "${BackendPort}:8090")

  if (-not [string]::IsNullOrWhiteSpace($DataDir)) {
    New-Item -ItemType Directory -Force $DataDir | Out-Null
    $runArgs += @("-v", "${DataDir}:/app/data")
  }

  $runArgs += $LocalImage

  try {
    docker @runArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "Local smoke test container failed to start." }

    for ($i = 0; $i -lt 45; $i++) {
      $backendOk = $false
      $frontendOk = $false
      try {
        curl -fsS "http://localhost:$FrontendPort/api/health" *> $null
        $backendOk = ($LASTEXITCODE -eq 0)
      } catch {}
      try {
        curl -fsS "http://localhost:$FrontendPort/" *> $null
        $frontendOk = ($LASTEXITCODE -eq 0)
      } catch {}

      if ($backendOk -and $frontendOk) {
        Write-Host "Local image health check passed (frontend and backend via nginx /api)."
        return
      }

      Start-Sleep -Seconds 2
    }

    Write-Host "Local smoke test failed. Recent container logs:"
    docker logs --tail=200 $container
    exit 1
  } finally {
    docker rm -f $container *> $null
  }
}

if (-not $SkipSmoke) {
  Test-PortAvailable $FrontendPort "Frontend"
  Test-PortAvailable $BackendPort "Backend"
  Smoke-TestImage
} else {
  Write-Host "Skipping local smoke test because -SkipSmoke was provided."
}

$finalUrl = "$ProxyHost/${teamId}:$Tag"

# Fix the common Windows credsStore issue before logging in (Docker Desktop's "desktop" helper).
Repair-DockerCredsStore

Write-Host "Logging in to $ProxyHost as $LoginUser"
$Token | docker login $ProxyHost --username $LoginUser --password-stdin | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Docker login failed. On Windows, if this is a credential-store error, the '`"credsStore`": `"desktop`",' line was removed from %USERPROFILE%\.docker\config.json just now — open a NEW terminal (or restart Claude Code so it inherits the updated PATH/credentials) and rerun the deploy. If 'docker' itself was not found, that also means the shell has a stale PATH from a fresh Docker Desktop install: reopen the terminal / restart Claude Code and try again." }

docker tag $LocalImage $finalUrl
if ($LASTEXITCODE -ne 0) { Fail "Docker tag failed." }

docker push $finalUrl
if ($LASTEXITCODE -ne 0) { Fail "Docker push failed." }

function Update-AgentMemory {
  $memoryDir = ".agent-memory"
  $statePath = Join-Path $memoryDir "state.json"
  if (-not (Test-Path $statePath)) { return }

  try {
    $state = Get-Content -Raw $statePath | ConvertFrom-Json
    $state | Add-Member -NotePropertyName participant_email -NotePropertyValue $User -Force
    $state | Add-Member -NotePropertyName team_id -NotePropertyValue $teamId -Force
    $state | Add-Member -NotePropertyName registry_proxy_host -NotePropertyValue $ProxyHost -Force
    $state | Add-Member -NotePropertyName registry_login_user -NotePropertyValue $LoginUser -Force
    $state | Add-Member -NotePropertyName registry_url -NotePropertyValue $finalUrl -Force
    $state | Add-Member -NotePropertyName last_pushed_image -NotePropertyValue $finalUrl -Force
    $state | Add-Member -NotePropertyName last_pushed_tag -NotePropertyValue $Tag -Force
    $state | Add-Member -NotePropertyName last_successful_step -NotePropertyValue "pushed image through registry proxy" -Force
    $state | Add-Member -NotePropertyName current_status -NotePropertyValue "image pushed" -Force
    $state | Add-Member -NotePropertyName current_blocker -NotePropertyValue "" -Force
    $state | Add-Member -NotePropertyName next_action -NotePropertyValue "run final submission check" -Force
    $state | Add-Member -NotePropertyName last_updated -NotePropertyValue ([DateTimeOffset]::UtcNow.ToString("o")) -Force
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath -Encoding utf8

    $activityPath = Join-Path $memoryDir "activity.md"
    "`n## $([DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))`nPushed final image for team_id $teamId to $finalUrl." |
      Add-Content -Path $activityPath -Encoding utf8
  } catch {
    Write-Warning "Could not update .agent-memory: $($_.Exception.Message)"
  }
}

Update-AgentMemory

Write-Host "Final image URL:"
Write-Host $finalUrl
