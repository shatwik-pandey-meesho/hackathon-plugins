param(
  [switch]$Install,
  [int]$WaitSeconds = 180,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\ensure_container_engine.ps1 [-Install] [-WaitSeconds 180]

Ensures a working 'docker' CLI with a reachable engine on Windows so the app image
can be built and pushed to the hackathon registry.

Windows uses Docker Desktop with the Hyper-V backend. If Docker is present it is started;
if it is missing, -Install enables the Hyper-V and Containers Windows features, installs
Docker Desktop (via winget), configures it to use the Hyper-V backend (not WSL2), and
starts it.

Hyper-V is available on Windows Pro, Enterprise, and Education. Windows Home has no
Hyper-V; there, Docker Desktop must use its WSL2 backend instead.

  (no flags)      Only report whether 'docker' works. Exit 0 if reachable, 1 if not.
  -Install        Make 'docker' work: start Docker Desktop if installed, else enable
                  Hyper-V and install Docker Desktop (Hyper-V backend).
  -WaitSeconds N  How long to wait for the engine to become reachable. Default: 180.

On macOS, use ensure_container_engine.sh instead (Docker Desktop there).
"@
  exit 0
}

$ErrorActionPreference = "Stop"

function Test-Cmd($Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Test-DockerReachable {
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

# Hyper-V (and the required Windows containers feature) exist only on Windows Pro,
# Enterprise, and Education. Windows Home cannot enable Hyper-V.
function Test-HyperVEdition {
  try {
    $caption = (Get-CimInstance Win32_OperatingSystem).Caption
  } catch {
    $caption = ""
  }
  return ($caption -match "Pro|Enterprise|Education")
}

function Test-HyperVEnabled {
  try {
    $f = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    return ($f.State -eq "Enabled")
  } catch {
    return $false
  }
}

# Enable the Hyper-V backend Docker Desktop needs. Requires Administrator; a fresh enable
# needs a reboot before the hypervisor is usable.
function Enable-HyperV {
  if (Test-HyperVEnabled) {
    Write-Host "OK      Hyper-V is enabled"
    return $true
  }
  if (-not (Test-HyperVEdition)) {
    Write-Host "This Windows edition (likely Home) does not support Hyper-V. Docker Desktop must use"
    Write-Host "its WSL2 backend here instead: run 'wsl --install' in an Administrator PowerShell,"
    Write-Host "reboot, then install Docker Desktop and leave the default WSL2 engine enabled."
    return $false
  }
  Write-Host "Hyper-V is not enabled. Enabling the Hyper-V and Containers Windows features..."
  if (-not (Test-IsAdmin)) {
    Write-Host "Enabling Hyper-V needs an Administrator PowerShell. Open PowerShell as Administrator and run:"
    Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart"
    Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart"
    Write-Host "Reboot, then rerun this deploy step."
    return $false
  }
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart | Out-Null
  Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart | Out-Null
  Write-Host "Hyper-V was enabled but Windows needs a REBOOT to finish."
  Write-Host "Reboot the machine, then rerun this deploy step."
  return $false
}

# Point Docker Desktop at the Hyper-V backend (disable the WSL2 engine) by editing its
# settings file. Best-effort: if the file is absent (Docker not launched yet), Docker
# Desktop defaults are used and the user can set it in Settings -> General.
function Set-DockerHyperVBackend {
  $candidates = @(
    (Join-Path $env:APPDATA "Docker\settings-store.json"),
    (Join-Path $env:APPDATA "Docker\settings.json")
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) {
      try {
        $settings = Get-Content -Raw $path | ConvertFrom-Json
        $settings | Add-Member -NotePropertyName wslEngineEnabled -NotePropertyValue $false -Force
        $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $path -Encoding utf8
        Write-Host "Configured Docker Desktop to use the Hyper-V backend (wslEngineEnabled=false)."
      } catch {
        Write-Host "Could not edit Docker settings automatically. In Docker Desktop, open Settings ->"
        Write-Host "General and UNCHECK 'Use the WSL 2 based engine' so it uses the Hyper-V backend."
      }
      return
    }
  }
  Write-Host "Note: after Docker Desktop first starts, open Settings -> General and UNCHECK"
  Write-Host "'Use the WSL 2 based engine' so it runs on the Hyper-V backend."
}

function Get-DockerDesktopExe {
  $candidates = @(
    (Join-Path ${env:ProgramFiles} "Docker\Docker\Docker Desktop.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Docker\Docker\Docker Desktop.exe")
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}

function Start-DockerDesktop {
  $exe = Get-DockerDesktopExe
  if ($exe) {
    Write-Host "Starting Docker Desktop..."
    try { Start-Process -FilePath $exe | Out-Null } catch {}
    return $true
  }
  return $false
}

function Install-Docker {
  if (-not (Test-Cmd "winget")) {
    Write-Host "winget is not available, so Docker Desktop cannot be installed automatically."
    Write-Host "Install Docker Desktop from https://www.docker.com/products/docker-desktop/, choose the"
    Write-Host "Hyper-V backend during setup, then rerun this deploy step."
    return $false
  }
  Write-Host "Installing Docker Desktop..."
  winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
  return $true
}

# ---------------------------------------------------------------------------
if (Test-DockerReachable) {
  Write-Host "OK      docker engine is reachable"
  exit 0
}

if (-not $Install) {
  if (Test-Cmd "docker") {
    Write-Host "docker is installed but the engine is not reachable (Docker Desktop may be stopped)."
    Write-Host "Start Docker Desktop, or rerun with -Install to start/set up the Hyper-V backend."
  } else {
    Write-Host "docker is not installed. Rerun with -Install to enable Hyper-V and install Docker Desktop."
  }
  exit 1
}

# -Install: try the cheapest fix first (start an already-installed Docker Desktop), then
# ensure Hyper-V and install Docker Desktop configured for the Hyper-V backend.
if (Test-Cmd "docker") {
  if (Start-DockerDesktop) {
    if (Wait-ForDocker 60) {
      Write-Host "OK      Docker Desktop is now reachable"
      exit 0
    }
    Write-Host "Docker Desktop did not come up. Ensuring the Hyper-V backend is set up..."
  }
}

if (-not (Enable-HyperV)) { exit 1 }

if (-not (Test-Cmd "docker") -and -not (Get-DockerDesktopExe)) {
  if (-not (Install-Docker)) { exit 1 }
}

Set-DockerHyperVBackend
Start-DockerDesktop | Out-Null

Write-Host "Waiting for the Docker engine to become reachable (up to $WaitSeconds seconds)..."
if (Wait-ForDocker $WaitSeconds) {
  Write-Host "OK      docker engine is reachable via Docker Desktop (Hyper-V backend)"
  exit 0
}

Write-Host "The Docker engine is not reachable yet. If Hyper-V was just enabled, REBOOT and rerun."
Write-Host "Otherwise open Docker Desktop, confirm Settings -> General has 'Use the WSL 2 based engine'"
Write-Host "UNCHECKED (Hyper-V backend), wait for it to finish starting, then rerun this deploy step."
exit 1
