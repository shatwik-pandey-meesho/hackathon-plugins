#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$Output = "",
  [string]$Name = "hackathon-skills",
  [switch]$Force,
  [switch]$List
)

# Bundle the hackathon skill folders, docs, and install scripts into a single
# distributable zip. The zip extracts to a top-level "hackathon-skills/" folder
# so a participant can unzip and immediately run scripts/install-skills.ps1.

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot

$Skills = @(
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

$Docs = @(
  "README.md",
  "USAGE.md",
  "INSTALLING.md"
)

$InstallScripts = @(
  "scripts/install-skills.sh",
  "scripts/install-skills.ps1"
)

if ($List) {
  Write-Host "Skills:";          $Skills          | ForEach-Object { Write-Host "  $_" }
  Write-Host "Docs:";            $Docs            | ForEach-Object { Write-Host "  $_" }
  Write-Host "Install scripts:"; $InstallScripts  | ForEach-Object { Write-Host "  $_" }
  exit 0
}

if ([string]::IsNullOrEmpty($Output)) {
  $Output = Join-Path $RootDir "dist/$Name.zip"
}

if ((Test-Path $Output) -and (-not $Force)) {
  Write-Error "Output already exists: $Output`nUse -Force to overwrite."
  exit 1
}

$OutDir = Split-Path -Parent $Output
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }

$StageDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$BundleRoot = Join-Path $StageDir $Name
try {
  New-Item -ItemType Directory -Force (Join-Path $BundleRoot "scripts") | Out-Null

  # Copy skill folders.
  foreach ($skill in $Skills) {
    $src = Join-Path $RootDir $skill
    if (-not (Test-Path $src -PathType Container)) { Write-Error "Missing skill folder: $src"; exit 1 }
    Copy-Item -Recurse -Force $src (Join-Path $BundleRoot $skill)
  }

  # Copy docs.
  foreach ($doc in $Docs) {
    $src = Join-Path $RootDir $doc
    if (-not (Test-Path $src -PathType Leaf)) { Write-Error "Missing doc: $src"; exit 1 }
    Copy-Item -Force $src (Join-Path $BundleRoot $doc)
  }

  # Copy install scripts.
  foreach ($script in $InstallScripts) {
    $src = Join-Path $RootDir $script
    if (-not (Test-Path $src -PathType Leaf)) { Write-Error "Missing install script: $src"; exit 1 }
    Copy-Item -Force $src (Join-Path $BundleRoot $script)
  }

  # Strip junk that should never ship in the bundle.
  Get-ChildItem -Path $BundleRoot -Recurse -Force -Directory `
    | Where-Object { $_.Name -in @(".git", "node_modules", ".agent-memory", "data", "dist") } `
    | ForEach-Object { Remove-Item -Recurse -Force $_.FullName }
  Get-ChildItem -Path $BundleRoot -Recurse -Force -File `
    | Where-Object { $_.Name -eq ".DS_Store" -or $_.Extension -in @(".db", ".sqlite", ".sqlite3") } `
    | ForEach-Object { Remove-Item -Force $_.FullName }

  if (Test-Path $Output) { Remove-Item -Force $Output }
  Compress-Archive -Path $BundleRoot -DestinationPath $Output -Force

  $size = "{0:N0} KB" -f ((Get-Item $Output).Length / 1KB)
  Write-Host "Created bundle: $Output ($size)"
  Write-Host "Extracts to:    $Name/"
  Write-Host "Next:           Expand-Archive '$Output'; cd $Name; .\scripts\install-skills.ps1 -Agent claude"
}
finally {
  if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
}
