param(
  [string]$Agent,
  [string]$Dest,
  [string]$Skills = "all",
  [switch]$Force,
  [switch]$List,
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\scripts\install-skills.ps1 -Agent codex|claude [-Dest PATH] [-Skills all|skill1,skill2] [-Force] [-List]

Options:
  -Agent   Target agent. Use "codex" for native Codex install.
           Use "claude" to copy the skill folders into a destination directory.
  -Dest    Destination directory.
           For codex, default: `${CODEX_HOME:-$HOME/.codex}\skills
           For claude, required because no single native auto-discovery path is assumed.
  -Skills  "all" or a comma-separated list of skill folder names.
  -Force   Overwrite existing destination skill folders.
  -List    Print the installable skill names and exit.
"@
  exit 0
}

$ErrorActionPreference = "Stop"
$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DefaultCodexDest = if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "skills" } else { Join-Path $HOME ".codex\skills" }
$AllSkills = @(
  "hackathon-bootstrap",
  "hackathon-feature-builder",
  "hackathon-preview",
  "hackathon-bugfix",
  "hackathon-db-helper",
  "hackathon-single-image-build",
  "hackathon-gcp-push",
  "hackathon-github",
  "hackathon-submission-check",
  "hackathon-explainer"
)

if ($List) {
  $AllSkills | ForEach-Object { Write-Host $_ }
  exit 0
}

if (-not $Agent) {
  throw "-Agent is required."
}

switch ($Agent) {
  "codex" {
    if (-not $Dest) { $Dest = $DefaultCodexDest }
  }
  "claude" {
    if (-not $Dest) {
      throw "-Dest is required for claude installs. This script copies the skill folders for Claude to use, but does not assume a built-in Claude skills path."
    }
  }
  default {
    throw "Unsupported agent: $Agent"
  }
}

if (-not (Test-Path $Dest)) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
}

$SelectedSkills = if ($Skills -eq "all") {
  $AllSkills
} else {
  $Skills.Split(",") | ForEach-Object { $_.Trim() }
}

foreach ($skill in $SelectedSkills) {
  if ($AllSkills -notcontains $skill) {
    throw "Unknown skill: $skill"
  }
}

foreach ($skill in $SelectedSkills) {
  $src = Join-Path $RootDir $skill
  $dst = Join-Path $Dest $skill

  if (-not (Test-Path $src)) {
    throw "Missing source skill folder: $src"
  }

  if (Test-Path $dst) {
    if (-not $Force) {
      throw "Destination already exists: $dst. Use -Force to overwrite."
    }
    Remove-Item -Recurse -Force $dst
  }

  Copy-Item -Recurse -Force $src $dst
  Write-Host "Installed $skill -> $dst"
}

if ($Agent -eq "codex") {
  Write-Host "Restart Codex to pick up the new skills."
} else {
  Write-Host "Claude install copied the skill folders into: $Dest"
  Write-Host "Point your Claude agent workflow at that directory or import those folders into your Claude setup."
}
