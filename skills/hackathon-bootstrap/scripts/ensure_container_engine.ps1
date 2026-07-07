param(
  [switch]$Install,
  [switch]$PreferRancher,
  [int]$WaitSeconds = 180,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\ensure_container_engine.ps1 [-Install] [-PreferRancher] [-WaitSeconds 180]

Ensures a working 'docker' CLI with a reachable engine on Windows so the app image
can be built and pushed to the hackathon registry.

Windows uses Docker Desktop when it is present and running. If Docker is missing or the
daemon will not come up (for example because WSL2 is missing), -Install falls back to
Rancher Desktop configured with the 'dockerd (moby)' engine, which provides the same
'docker' command. Rancher Desktop requires WSL2 (Docker Desktop can use WSL2 or, on
Pro/Enterprise, Hyper-V), so this script enables WSL2 first. It works on all Windows
editions including Home; for a WSL-free setup on Pro/Enterprise, use Docker Desktop's
Hyper-V backend instead.

  (no flags)      Only report whether 'docker' works. Exit 0 if reachable, 1 if not.
  -Install        Attempt to make 'docker' work: start Docker Desktop if installed, else
                  ensure WSL2 and install the Rancher Desktop fallback (moby engine).
  -PreferRancher  Skip the Docker Desktop start attempt and go straight to Rancher.
  -WaitSeconds N  How long to wait for the engine to become reachable. Default: 180.

On macOS, use ensure_container_engine.sh instead (it verifies the engine and, if none
exists, points to Rancher Desktop via the iru self-service portal). Docker is never installed.
"@
  exit 0
}

$ErrorActionPreference = "Stop"

function Test-Cmd($Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# Rancher Desktop with the moby engine exposes docker.exe under %USERPROFILE%\.rd\bin.
# A freshly installed Rancher may not be on PATH for this session yet, so add it.
function Add-RancherBinToPath {
  $rdBin = Join-Path $env:USERPROFILE ".rd\bin"
  if ((Test-Path $rdBin) -and ($env:Path -notlike "*$rdBin*")) {
    $env:Path = "$rdBin;$env:Path"
  }
}

function Test-DockerReachable {
  Add-RancherBinToPath
  if (-not (Test-Cmd "docker")) { return $false }
  docker info *> $null
  return ($LASTEXITCODE -eq 0)
}

function Wait-ForDocker([int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-DockerReachable) { return $true }
    Start-Sleep -Seconds 5
  }
  return (Test-DockerReachable)
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WslReady {
  if (-not (Test-Cmd "wsl")) { return $false }
  wsl --status *> $null
  return ($LASTEXITCODE -eq 0)
}

# Ensure WSL2 exists. The Rancher Desktop fallback requires it on Windows (Docker Desktop
# can use WSL2 or Hyper-V), so a "docker not working because WSL is missing" machine is
# fixed here first. WSL2 also works on Windows Home, where Hyper-V is unavailable.
function Ensure-Wsl {
  if (Test-WslReady) {
    Write-Host "OK      WSL2 is available"
    return $true
  }
  Write-Host "WSL2 is missing or not ready. The Rancher Desktop fallback engine needs it."
  if (-not (Test-IsAdmin)) {
    Write-Host "Enabling WSL2 needs an Administrator PowerShell. Open PowerShell as Administrator and run:"
    Write-Host "  wsl --install"
    Write-Host "Reboot if it asks you to, then rerun this deploy step."
    return $false
  }
  Write-Host "Enabling WSL2 (this may take a few minutes)..."
  # Native command: check the exit code (it will not throw). Older Windows builds do not
  # support --no-distribution, so retry with the plain form if the first call fails.
  wsl --install --no-distribution
  if ($LASTEXITCODE -ne 0) { wsl --install }
  if (-not (Test-WslReady)) {
    Write-Host "WSL2 was requested but is not ready yet. Windows usually needs a REBOOT to finish."
    Write-Host "Reboot the machine, then rerun this deploy step."
    return $false
  }
  Write-Host "OK      WSL2 enabled"
  return $true
}

function Find-Rdctl {
  if (Test-Cmd "rdctl") { return "rdctl" }
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Rancher Desktop\resources\resources\win32\bin\rdctl.exe"),
    (Join-Path ${env:ProgramFiles} "Rancher Desktop\resources\resources\win32\bin\rdctl.exe")
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}

# Install Rancher Desktop and switch it to the dockerd (moby) engine so 'docker' works.
function Install-Rancher {
  if (-not (Test-Cmd "winget")) {
    Write-Host "winget is not available, so Rancher Desktop cannot be installed automatically."
    Write-Host "Install Rancher Desktop from https://rancherdesktop.io, choose the 'dockerd (moby)'"
    Write-Host "engine during setup, then rerun this deploy step."
    return $false
  }

  Write-Host "Installing Rancher Desktop (free Docker alternative for Windows)..."
  winget install --id SUSE.RancherDesktop -e --accept-package-agreements --accept-source-agreements

  $rdctl = Find-Rdctl
  if (-not $rdctl) {
    Write-Host "Rancher Desktop was installed. Open it once from the Start menu, choose the"
    Write-Host "'dockerd (moby)' container engine in Preferences, then rerun this deploy step."
    return $false
  }

  Write-Host "Configuring Rancher Desktop to use the 'dockerd (moby)' engine..."
  # moby gives the real 'docker' command; disabling Kubernetes keeps it light on laptops.
  & $rdctl set --container-engine.name=moby --kubernetes.enabled=false *> $null
  try { & $rdctl start *> $null } catch {}
  return $true
}

# ---------------------------------------------------------------------------
if (Test-DockerReachable) {
  Write-Host "OK      docker engine is reachable"
  exit 0
}

if (-not $Install) {
  if (Test-Cmd "docker") {
    Write-Host "docker is installed but the engine is not reachable (Docker Desktop may be stopped,"
    Write-Host "or WSL2 may be missing). Start Docker Desktop, or rerun with -Install to set up the"
    Write-Host "Rancher Desktop fallback automatically."
  } else {
    Write-Host "docker is not installed. Rerun with -Install to set up a container engine"
    Write-Host "(Docker Desktop if present, otherwise the Rancher Desktop fallback)."
  }
  exit 1
}

# -Install: try the cheapest fix first (start an already-installed Docker Desktop),
# then fall back to installing/configuring Rancher Desktop.
if ((Test-Cmd "docker") -and (-not $PreferRancher)) {
  $dockerDesktop = Join-Path ${env:ProgramFiles} "Docker\Docker\Docker Desktop.exe"
  if (Test-Path $dockerDesktop) {
    Write-Host "docker is installed. Trying to start Docker Desktop..."
    try { Start-Process -FilePath $dockerDesktop | Out-Null } catch {}
    if (Wait-ForDocker 60) {
      Write-Host "OK      Docker Desktop is now reachable"
      exit 0
    }
    Write-Host "Docker Desktop did not come up (often WSL2 is missing). Falling back to Rancher Desktop."
  }
}

if (-not (Ensure-Wsl)) { exit 1 }

if (-not (Install-Rancher)) { exit 1 }

Write-Host "Waiting for the Rancher (moby) engine to become reachable (up to $WaitSeconds seconds)..."
if (Wait-ForDocker $WaitSeconds) {
  Write-Host "OK      docker engine is reachable via Rancher Desktop (moby)"
  Write-Host "Note: if a NEW terminal cannot find 'docker', make sure %USERPROFILE%\.rd\bin is on PATH."
  exit 0
}

Write-Host "The Rancher engine is not reachable yet. Open Rancher Desktop, confirm the engine is"
Write-Host "'dockerd (moby)' and that it finished starting, then rerun this deploy step."
exit 1
