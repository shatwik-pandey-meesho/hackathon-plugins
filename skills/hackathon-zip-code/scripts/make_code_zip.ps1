param(
  [string]$Name,
  [switch]$Help
)

# Build a clean, secret-free zip of the current project for MANUAL upload to the organizer's
# submission folder. Excludes dependency folders, build output, local database data, and secret
# files. Prints the zip path and size. Uses the built-in Compress-Archive (no extra install).
# It does not upload anything.

if ($Help) {
  @"
Usage: .\make_code_zip.ps1 [-Name NAME]

NAME is an optional base name for the zip (for example a team or project name). If omitted,
the current project folder name is used. The zip is written to dist\<name>.zip.

The participant uploads the resulting zip by hand to the organizer's submission folder.
"@
  exit 0
}

$ErrorActionPreference = "Stop"

$projectName = (Split-Path -Leaf (Get-Location)).ToLower() -replace '\s', '-'
if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $projectName }
# Sanitize the name into a safe filename.
$Name = ($Name.ToLower() -replace '\s', '-') -replace '[^a-z0-9._-]', ''
if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $projectName }

$outDir = "dist"
$outFile = Join-Path $outDir "$Name.zip"

# Refuse to package obvious secrets.
$secretPatterns = @('.env', '*.pem', '*.key', '*service-account*.json')
$skipDirs = @('node_modules', '.git', 'data', 'dist')
$secrets = Get-ChildItem -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
  $rel = $_.FullName.Substring((Get-Location).Path.Length).TrimStart('\','/')
  $top = ($rel -split '[\\/]')[0]
  if ($skipDirs -contains $top) { return $false }
  if ($_.Name -eq '.env.example') { return $false }
  foreach ($p in $secretPatterns) { if ($_.Name -like $p) { return $true } }
  if ($_.Name -like '.env.*') { return $true }
  return $false
}
if ($secrets) {
  Write-Error "Refusing to build the zip because secret-looking files are present:`n$($secrets.FullName -join "`n")`nRemove or rename these (an .env.example is allowed) before zipping for upload."
  exit 1
}

# Collect files to include, excluding heavy and secret paths.
$excludeExt = @('.db', '.sqlite', '.sqlite3', '.pem', '.key', '.log')
$items = Get-ChildItem -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
  $rel = $_.FullName.Substring((Get-Location).Path.Length).TrimStart('\','/')
  $parts = $rel -split '[\\/]'
  if ($skipDirs -contains $parts[0]) { return $false }
  if ($parts -contains 'build') { return $false }
  if ($excludeExt -contains $_.Extension.ToLower()) { return $false }
  if ($_.Name -eq '.DS_Store') { return $false }
  if ($_.Name -eq '.env' -or $_.Name -like '.env.*') { return ($_.Name -eq '.env.example') }
  if ($_.Name -like '*service-account*.json') { return $false }
  return $true
}

New-Item -ItemType Directory -Force $outDir | Out-Null
if (Test-Path $outFile) { Remove-Item $outFile -Force }

Compress-Archive -Path $items.FullName -DestinationPath $outFile -Force

$size = (Get-Item $outFile).Length
$absPath = (Resolve-Path $outFile).Path
Write-Host "Built zip: $absPath"
Write-Host "Size (bytes): $size"
Write-Host "Next step (manual): upload this zip to the organizer's submission folder yourself."
if ($size -gt 50000000) {
  Write-Warning "zip is larger than 50 MB. Trim heavy folders (node_modules\, data\, build output) before uploading."
}
