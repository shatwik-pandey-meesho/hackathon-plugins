param(
  [string]$ProxyHost,
  [string]$LoginUser = "hackathon",
  [string]$Token = $env:HACKATHON_PROXY_TOKEN,
  [string]$LocalImage,
  [string]$GithubUser,
  [string]$Tag = "final",
  [string]$DataDir,
  [int]$FrontendPort = $(if ($env:FRONTEND_PORT) { [int]$env:FRONTEND_PORT } else { 9080 }),
  [int]$BackendPort = $(if ($env:BACKEND_PORT) { [int]$env:BACKEND_PORT } else { 8090 }),
  [switch]$SkipSmoke,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\push_to_proxy_registry.ps1 -ProxyHost HOST -Token TOKEN -LocalImage IMAGE [options]

Logs in to a token-authenticated Docker proxy, verifies the local image starts,
tags it as HOST/GITHUB_USER/GITHUB_USER:TAG, and pushes it.

Required:
  -ProxyHost HOST       Proxy registry host, for example hackathon-proxy-xxxxx.run.app
  -Token TOKEN          Registry token or password. Can also use HACKATHON_PROXY_TOKEN.
  -LocalImage IMAGE     Existing local image to push, for example hackathon-app:final

Options:
  -LoginUser USER       Docker login username. Default: hackathon
  -GithubUser USER      GitHub username. If omitted, the script tries gh, git config,
                        then the GitHub origin remote owner.
  -Tag TAG              Final image tag. Default: final
  -DataDir DIR          Optional host data dir to mount to /app/data during smoke test.
                        Final images should normally pass without this.
  -SkipSmoke            Skip local container health check. Use only if already checked.
  -Help                 Show this help text.

Final image URL:
  HOST/GITHUB_USER/GITHUB_USER:TAG
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

function Infer-GithubUser {
  if (Test-Command "gh") {
    try {
      $ghUser = (& gh api user --jq .login 2>$null)
      if (-not [string]::IsNullOrWhiteSpace($ghUser)) {
        return $ghUser.Trim()
      }
    } catch {}
  }

  try {
    $configUser = (& git config --get github.user 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($configUser)) {
      return $configUser.Trim()
    }
  } catch {}

  try {
    $remote = (& git remote get-url origin 2>$null)
    if ($remote -match "github\.com[:/]([^/]+)/") {
      return $Matches[1]
    }
  } catch {}

  return ""
}

if ([string]::IsNullOrWhiteSpace($ProxyHost)) { Fail "-ProxyHost is required." }
if ([string]::IsNullOrWhiteSpace($Token)) { Fail "-Token is required, or set HACKATHON_PROXY_TOKEN." }
if ([string]::IsNullOrWhiteSpace($LocalImage)) { Fail "-LocalImage is required." }
if ([string]::IsNullOrWhiteSpace($LoginUser)) { Fail "-LoginUser cannot be empty." }
if ([string]::IsNullOrWhiteSpace($Tag)) { Fail "-Tag cannot be empty." }

if (-not (Test-Command "docker")) { Fail "Docker is not installed or not on PATH." }
if (-not (Test-Command "curl")) { Fail "curl is required for the local health check." }
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Fail "Docker is installed, but the Docker daemon is not reachable. Start Docker Desktop or fix Docker permissions, then retry."
}

$ProxyHost = $ProxyHost -replace "^https?://", ""
$ProxyHost = $ProxyHost.TrimEnd("/")
if ($ProxyHost.Contains("/")) { Fail "-ProxyHost must be only the registry host, without a path." }

if ([string]::IsNullOrWhiteSpace($GithubUser)) {
  $GithubUser = Infer-GithubUser
}
if ([string]::IsNullOrWhiteSpace($GithubUser)) {
  Fail "Could not infer GitHub username. Pass -GithubUser."
}

$imageNamespace = $GithubUser.ToLowerInvariant()
$imageName = $imageNamespace

if ($imageNamespace -notmatch "^[a-z0-9]+([._-][a-z0-9]+)*$") {
  Fail "GitHub username '$GithubUser' becomes invalid Docker path '$imageNamespace'. Pass a Docker-safe -GithubUser."
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
        curl -fsS "http://localhost:$BackendPort/health" *> $null
        $backendOk = ($LASTEXITCODE -eq 0)
      } catch {}
      try {
        curl -fsS "http://localhost:$FrontendPort/" *> $null
        $frontendOk = ($LASTEXITCODE -eq 0)
      } catch {}

      if ($backendOk -and $frontendOk) {
        Write-Host "Local image health check passed."
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

$finalUrl = "$ProxyHost/$imageNamespace/${imageName}:$Tag"

Write-Host "Logging in to $ProxyHost as $LoginUser"
$Token | docker login $ProxyHost --username $LoginUser --password-stdin | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Docker login failed." }

docker tag $LocalImage $finalUrl
if ($LASTEXITCODE -ne 0) { Fail "Docker tag failed." }

docker push $finalUrl
if ($LASTEXITCODE -ne 0) { Fail "Docker push failed." }

Write-Host "Final image URL:"
Write-Host $finalUrl
