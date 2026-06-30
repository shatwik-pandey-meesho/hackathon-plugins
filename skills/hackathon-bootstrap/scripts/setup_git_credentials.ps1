<#
.SYNOPSIS
Stores a GitHub token in a plain-text credential file and configures git's
"store" helper to use it, so git push/pull never prompts for a password.

.DESCRIPTION
Run this AFTER git is installed and `gh auth login` has completed.

Two ways to provide the token:
  -Method gh    (default) reuse the token gh created during `gh auth login`.
  -Method pat   paste a classic Personal Access Token from
                https://github.com/settings/tokens (scope: repo).

Note: storing a token in plain text is a convenience tradeoff that is fine for a
short-lived hackathon machine. Do not do this on a shared or long-lived account.
#>

param(
  [ValidateSet('gh', 'pat')]
  [string]$Method = 'gh',
  [switch]$Help
)

if ($Help) {
  @"
Usage: .\setup_git_credentials.ps1 [-Method gh|pat]

Stores your GitHub token in a plain-text file and configures git to use it,
so pushing to GitHub never asks for a password.

Methods:
  -Method gh    (default) reuse the token from gh auth login. Starts browser login if needed.
  -Method pat   paste a classic PAT from https://github.com/settings/tokens (scope: repo).

Environment:
  GIT_CREDENTIALS_FILE   override the credential file path (default: ~/.git-credentials)
  GITHUB_PAT             if set, used as the token in -Method pat without prompting
"@
  exit 0
}

$ErrorActionPreference = 'Stop'

$Host_ = 'github.com'
$CredFile = if ($env:GIT_CREDENTIALS_FILE) { $env:GIT_CREDENTIALS_FILE } else { Join-Path $HOME '.git-credentials' }

function Have-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

if (-not (Have-Cmd git)) {
  Write-Host "git is not installed. Install it first (run check_and_install_tools.ps1)."
  exit 1
}

$token = ''
$username = ''

if ($Method -eq 'gh') {
  if (-not (Have-Cmd gh)) {
    Write-Host "GitHub CLI gh is not installed. Install it, or use -Method pat."
    exit 1
  }
  & gh auth status *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "You are not logged in to GitHub on this machine yet."
    Write-Host "Starting the browser login. If you are already signed in to GitHub in your"
    Write-Host "browser, this just shows a one-time code to paste, then a single 'Authorize' click."
    Write-Host ""
    # Web flow: opens the browser the participant is already signed into.
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) {
      Write-Host ""
      Write-Host "Browser login did not finish. Try again, or paste a classic PAT instead:"
      Write-Host "  setup_git_credentials.ps1 -Method pat"
      exit 1
    }
  }
  $token = (& gh auth token 2>$null)
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Could not read a token from gh. Run 'gh auth login' again and grant access."
    exit 1
  }
  $username = (& gh api user --jq .login 2>$null)
}
else {
  if ($env:GITHUB_PAT) {
    $token = $env:GITHUB_PAT
  }
  else {
    Write-Host "Create a classic Personal Access Token here (scope: repo):"
    Write-Host "  https://github.com/settings/tokens/new?scopes=repo&description=hackathon"
    $secure = Read-Host -AsSecureString "Paste your classic PAT (input hidden)"
    $token = [System.Net.NetworkCredential]::new('', $secure).Password
  }
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "No token entered. Nothing changed."
    exit 1
  }
  if (Have-Cmd gh) {
    $env:GH_TOKEN = $token
    $username = (& gh api user --jq .login 2>$null)
    Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
  }
}

if ([string]::IsNullOrWhiteSpace($username)) { $username = 'x-access-token' }

# Write the credential line, preserving entries for other hosts.
$newLine = "https://${username}:${token}@${Host_}"
$existing = @()
if (Test-Path $CredFile) {
  $existing = Get-Content $CredFile | Where-Object { $_ -notmatch "@$([regex]::Escape($Host_))$" }
}
$all = @($existing) + @($newLine)
Set-Content -Path $CredFile -Value $all -Encoding ascii

# Point git at the plain-text store file in the global config.
& git config --global credential.helper "store --file=$CredFile"

# Make sure git knows who is committing.
$haveName = (& git config --global user.name)
if ([string]::IsNullOrWhiteSpace($haveName) -and (Have-Cmd gh)) {
  $name = (& gh api user --jq '.name // .login' 2>$null)
  if ($name -and $name -ne 'null') { & git config --global user.name "$name" }
}
$haveEmail = (& git config --global user.email)
if ([string]::IsNullOrWhiteSpace($haveEmail)) {
  $email = ''
  if (Have-Cmd gh) { $email = (& gh api user --jq '.email' 2>$null) }
  if ([string]::IsNullOrWhiteSpace($email) -or $email -eq 'null') {
    $email = "$username@users.noreply.github.com"
  }
  & git config --global user.email "$email"
}

Write-Host "Method: $Method"
Write-Host "GitHub credentials saved for user: $username"
Write-Host "Credential file: $CredFile (plain text)"
Write-Host "git is configured to use it automatically. Pushes will no longer ask for a password."
