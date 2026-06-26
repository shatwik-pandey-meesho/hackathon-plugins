#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
MESSAGE="${COMMIT_MESSAGE:-Save hackathon project}"

if [[ "$TARGET" == "--help" || "$TARGET" == "-h" || -z "$TARGET" ]]; then
  cat <<'USAGE'
Usage: push_to_github.sh REPO_NAME_OR_REMOTE_URL

If REPO_NAME_OR_REMOTE_URL starts with http or git@, it is used as the origin.
Otherwise the GitHub CLI creates a private repo with that name.
Environment:
  COMMIT_MESSAGE="Save hackathon project"
USAGE
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed."
  exit 1
fi

if [[ ! -d .git ]]; then
  git init
fi

if [[ ! -f .gitignore ]]; then
  cat > .gitignore <<'EOF'
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
data/
EOF
fi

if git ls-files --others --exclude-standard | grep -E '(^|/)(\.env|.*service-account.*\.json|.*\.pem|.*\.key)$' >/dev/null 2>&1; then
  echo "Potential secret files are untracked but not ignored. Fix .gitignore before pushing."
  git ls-files --others --exclude-standard | grep -E '(^|/)(\.env|.*service-account.*\.json|.*\.pem|.*\.key)$' || true
  exit 1
fi

git add .

if git diff --cached --name-only | grep -E '(^|/)(\.env|.*service-account.*\.json|.*\.pem|.*\.key)$' >/dev/null 2>&1; then
  echo "Potential secret files are staged. Unstage them before pushing."
  git diff --cached --name-only | grep -E '(^|/)(\.env|.*service-account.*\.json|.*\.pem|.*\.key)$' || true
  exit 1
fi

if ! git diff --cached --quiet; then
  git commit -m "$MESSAGE"
fi

if git remote get-url origin >/dev/null 2>&1; then
  :
elif [[ "$TARGET" == http* || "$TARGET" == git@* ]]; then
  git remote add origin "$TARGET"
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI gh is required to create a repo by name. Pass a remote URL instead."
    exit 1
  fi
  gh repo create "$TARGET" --private --source=. --remote=origin --push
  echo "GitHub repo created and pushed."
  exit 0
fi

BRANCH="$(git branch --show-current)"
if [[ -z "$BRANCH" ]]; then
  BRANCH="main"
  git checkout -b "$BRANCH"
fi

git push -u origin "$BRANCH"
echo "GitHub remote: $(git remote get-url origin)"
echo "Latest commit: $(git rev-parse --short HEAD)"
