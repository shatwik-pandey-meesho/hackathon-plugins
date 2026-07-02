param(
  [string]$User = $env:MEESHO_EMAIL,
  [string]$Token = $env:HACKATHON_PROXY_TOKEN,
  [string]$Image = "hackathon-app:final",
  [string]$Name,
  [string]$Tag,
  [string]$ProxyHost = "registry.buildathon.meesho.dev",
  [string]$LoginUser = "hackathon",
  [int]$FrontendPort = $(if ($env:FRONTEND_PORT) { [int]$env:FRONTEND_PORT } else { 9080 }),
  [int]$BackendPort = $(if ($env:BACKEND_PORT) { [int]$env:BACKEND_PORT } else { 8090 }),
  [switch]$SkipZip,
  [switch]$SkipPush,
  [switch]$SkipDeploy,
  [switch]$Help
)

# Live apps are served under this base domain as https://<team-id>.<LiveSiteBase>
$LiveSiteBase = "buildathon.ltl.sh"

if ($Help) {
  @"
Usage: .\deploy.ps1 [options]

One-shot deploy: build the linux/amd64 single image, run readiness checks, zip the
source, and push through the organizer proxy. Then follow the printed go-live steps.

Options:
  -User EMAIL        Meesho org email (derives the image team id). Or set MEESHO_EMAIL.
  -Token TOKEN       Registry token. Prefer setting HACKATHON_PROXY_TOKEN so it is not
                     stored in history. Prompted for if not provided.
  -Image IMAGE       Local image tag to build/push. Default: hackathon-app:final
  -Name NAME         Base name for the source zip. Default: project folder name.
  -Tag TAG           Pushed image tag. Default: UTC timestamp.
  -ProxyHost HOST    Proxy registry host. Default: registry.buildathon.meesho.dev
  -LoginUser USER    Docker login username. Default: hackathon
  -SkipZip           Skip building the source zip.
  -SkipPush          Build and check only; do not log in or push.
  -SkipDeploy        Push only; do not call the deploy API to start the live deployment.
  -Help              Show this help.
"@
  exit 0
}

$ErrorActionPreference = "Stop"

function Fail($Message) { Write-Error $Message; exit 1 }
function Test-Cmd($Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# Derive the team id from a Meesho email exactly like push_to_proxy_registry.ps1 does:
# part before @, lowercased, non-[a-z0-9_-] runs -> '-', trimmed. Keep the two in sync.
function ConvertTo-TeamId($EmailOrSlug) {
  $prefix = ($EmailOrSlug -split "@")[0].ToLowerInvariant()
  $slug = [regex]::Replace($prefix, "[^a-z0-9_-]+", "-")
  return $slug.Trim("-")
}

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$buildScript = Join-Path $skillsRoot "hackathon-single-image-build\scripts\build_single_image.ps1"
$zipScript   = Join-Path $skillsRoot "hackathon-zip-code\scripts\make_code_zip.ps1"
$pushScript  = Join-Path $skillsRoot "hackathon-deploy-by-pushing-image\scripts\push_to_proxy_registry.ps1"

foreach ($s in @($buildScript, $zipScript, $pushScript)) {
  if (-not (Test-Path $s)) { Fail "Required helper script not found: $s" }
}

if (-not (Test-Cmd "docker")) { Fail "Docker is not installed or not on PATH." }
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Fail "Docker is installed, but the daemon is not reachable. Start Docker Desktop, then retry."
}
if (-not (Test-Path "Dockerfile")) {
  Fail "Dockerfile not found in current directory. Package your app first, then deploy."
}

# ---------------------------------------------------------------------------
Write-Host "==> Step 1/5  Build the linux/amd64 single image and smoke-test it"
$env:FRONTEND_PORT = "$FrontendPort"
$env:BACKEND_PORT  = "$BackendPort"
& $buildScript -Image $Image -FrontendPort $FrontendPort -BackendPort $BackendPort
if ($LASTEXITCODE -ne 0) { Fail "Image build/smoke test failed." }

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Step 2/5  Readiness checks"

if (Test-Path "README.md") {
  Write-Host "PASS  README.md present"
} else {
  Write-Host "WARN  README.md missing (recommended for judges)"
}

$secretHit = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch "\\(node_modules|\.git|data|dist)\\" } |
  Select-String -Pattern 'BEGIN (RSA|OPENSSH) PRIVATE KEY', 'AIza[0-9A-Za-z_\-]{35}', 'password *= *\S+' -List -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($secretHit) { Fail "Possible secret content found in project files. Remove it before deploying." }
Write-Host "PASS  no obvious secret content"

Write-Host "Verifying the image runs standalone (no bind mount, as judges will run it)"
foreach ($p in @(@($FrontendPort, "Frontend"), @($BackendPort, "Backend"))) {
  $conn = Get-NetTCPConnection -LocalPort $p[0] -ErrorAction SilentlyContinue
  if ($conn) { Fail "$($p[1]) port $($p[0]) is busy. Free it, then retry." }
}
$standalone = "deploy-standalone-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
docker run -d --platform linux/amd64 --name $standalone -p "${FrontendPort}:9080" -p "${BackendPort}:8090" $Image | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Standalone container failed to start." }

$standaloneOk = $false
try {
  for ($i = 0; $i -lt 45; $i++) {
    $frontendOk = $false; $backendOk = $false
    try { curl.exe -fsS "http://localhost:$FrontendPort/" *> $null; $frontendOk = ($LASTEXITCODE -eq 0) } catch {}
    try { curl.exe -fsS "http://localhost:$FrontendPort/api/health" *> $null; $backendOk = ($LASTEXITCODE -eq 0) } catch {}
    if ($frontendOk -and $backendOk) { $standaloneOk = $true; break }
    Start-Sleep -Seconds 2
  }
  if (-not $standaloneOk) {
    Write-Host "Recent container logs:"
    docker logs --tail=100 $standalone
  }
} finally {
  docker rm -f $standalone *> $null
}
if (-not $standaloneOk) { Fail "Standalone image did not serve http://localhost:$FrontendPort/ and /api/health." }
Write-Host "PASS  standalone image serves the frontend and backend via nginx /api"

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Step 3/5  Zip the source for manual upload"
if ($SkipZip) {
  Write-Host "Skipping zip (-SkipZip)."
} elseif (-not [string]::IsNullOrWhiteSpace($Name)) {
  & $zipScript $Name
} else {
  & $zipScript
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Step 4/5  Push the image through the organizer proxy"
$finalUrl = ""
$teamId = ""
if ($SkipPush) {
  Write-Host "Skipping push (-SkipPush)."
} else {
  if ([string]::IsNullOrWhiteSpace($User)) {
    $User = Read-Host "Your Meesho organization email (used only to name the image)"
  }
  if ([string]::IsNullOrWhiteSpace($User)) { Fail "A Meesho email is required. Pass -User or set MEESHO_EMAIL." }

  if ([string]::IsNullOrWhiteSpace($Token)) {
    $secure = Read-Host "Organizer registry token (input hidden)" -AsSecureString
    $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
      [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  }
  if ([string]::IsNullOrWhiteSpace($Token)) { Fail "A registry token is required to push." }

  # Compute the team id and tag here so we know the exact pushed image_tag the deploy
  # API needs. Default the tag to a UTC timestamp and pass it explicitly to the push.
  $teamId = ConvertTo-TeamId $User
  if ([string]::IsNullOrWhiteSpace($teamId)) { Fail "Email '$User' produces an empty team id. Use a Meesho email with letters or numbers before @." }
  if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss") }
  $finalUrl = "$ProxyHost/${teamId}:$Tag"

  $pushArgs = @("-ProxyHost", $ProxyHost, "-LoginUser", $LoginUser,
                "-LocalImage", $Image, "-User", $User, "-Tag", $Tag, "-SkipSmoke")

  # Pass the token via env (read through docker login --password-stdin), never in argv.
  $env:HACKATHON_PROXY_TOKEN = $Token
  & $pushScript @pushArgs
  if ($LASTEXITCODE -ne 0) { Fail "Push failed." }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Step 5/5  Start the live deployment"
$liveLink = ""
if ($SkipPush) {
  Write-Host "Skipping deploy because the image was not pushed (-SkipPush)."
} elseif ($SkipDeploy) {
  Write-Host "Skipping deploy (-SkipDeploy). Image is pushed at $finalUrl."
} else {
  $deployApi = "https://$ProxyHost/admin/api/deploy"
  Write-Host "Requesting deploy of $finalUrl"
  # Send the pushed image_tag to the proxy's deploy API. The token is the same registry
  # token, sent as a Bearer header. Never print the token.
  $headers = @{ Authorization = "Bearer $Token" }
  $body = (@{ image_tag = $finalUrl } | ConvertTo-Json -Compress)
  try {
    Invoke-RestMethod -Method Post -Uri $deployApi -Headers $headers `
      -ContentType 'application/json' -Body $body | Out-Null
  } catch {
    Fail "Deploy API call to $deployApi failed: $($_.Exception.Message). Re-check the token and that the image pushed successfully, then retry."
  }
  Write-Host "PASS  deploy started"
  $liveLink = "https://$teamId.$LiveSiteBase"
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================"
Write-Host "Deploy finished."
if (-not [string]::IsNullOrWhiteSpace($liveLink)) {
  Write-Host ""
  Write-Host "Your live application link (give this to the judges):"
  Write-Host ""
  Write-Host "  $liveLink"
  Write-Host ""
  Write-Host "It can take a minute or two to come up after the deploy starts."
  Write-Host "If it does not load yet, wait a moment and refresh."
} elseif ($SkipDeploy -and -not [string]::IsNullOrWhiteSpace($finalUrl)) {
  Write-Host ""
  Write-Host "Image pushed but deploy was skipped. Start it later by POSTing"
  Write-Host "the image_tag `"$finalUrl`" to https://$ProxyHost/admin/api/deploy,"
  Write-Host "then open https://$teamId.$LiveSiteBase."
}
Write-Host ""
Write-Host "Also upload the printed dist\<name>.zip to the organizer's"
Write-Host "submission folder by hand if you have not already."
Write-Host "============================================================"
