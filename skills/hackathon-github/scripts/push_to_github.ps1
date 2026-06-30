param(
  [string]$Target,
  [string]$CommitMessage = $(if ($env:COMMIT_MESSAGE) { $env:COMMIT_MESSAGE } else { "Save hackathon project" }),
  [switch]$Help
)

if ($Help -or -not $Target) {
  @"
Usage: .\push_to_github.ps1 -Target REPO_NAME_OR_REMOTE_URL

If Target starts with http or git@, it is used as the origin.
Otherwise the GitHub CLI creates a private repo with that name.
"@
  exit 0
}

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "git is not installed."
  exit 1
}

if (-not (Test-Path ".git")) {
  git init
}

if (-not (Test-Path ".gitignore")) {
  @"
.env
.env.*
!.env.example
*.pem
*.key
*service-account*.json
node_modules/
dist/
build/
.DS_Store
*.log
*.db
*.sqlite
*.sqlite3
data/*.db
data/*.sqlite
data/*.sqlite3
"@ | Set-Content -Path ".gitignore" -Encoding utf8
}

$untracked = git ls-files --others --exclude-standard
$secretPattern = '(^|/)(\.env|.*service-account.*\.json|.*\.pem|.*\.key)$'
if ($untracked | Select-String -Pattern $secretPattern -Quiet) {
  Write-Host "Potential secret files are untracked but not ignored. Fix .gitignore before pushing."
  $untracked | Select-String -Pattern $secretPattern
  exit 1
}

git add .

$staged = git diff --cached --name-only
if ($staged | Select-String -Pattern $secretPattern -Quiet) {
  Write-Host "Potential secret files are staged. Unstage them before pushing."
  $staged | Select-String -Pattern $secretPattern
  exit 1
}

git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -m $CommitMessage
}

git remote get-url origin *> $null
if ($LASTEXITCODE -ne 0) {
  if ($Target.StartsWith("http") -or $Target.StartsWith("git@")) {
    git remote add origin $Target
  } else {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
      Write-Host "GitHub CLI gh is required to create a repo by name. Pass a remote URL instead."
      exit 1
    }
    gh repo create $Target --private --source=. --remote=origin --push
    Write-Host "GitHub repo created and pushed."
    exit 0
  }
}

$branch = git branch --show-current
if (-not $branch) {
  $branch = "main"
  git checkout -b $branch
}

git push -u origin $branch
Write-Host "GitHub remote: $(git remote get-url origin)"
Write-Host "Latest commit: $(git rev-parse --short HEAD)"
