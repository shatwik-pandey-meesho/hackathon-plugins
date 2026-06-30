#!/usr/bin/env bash
set -euo pipefail

# Stores a GitHub token in a plain-text credential file so git push/pull never
# prompts for a password, and points git's "store" helper at that file in the
# global gitconfig. Run this AFTER `git` is installed and `gh auth login` has
# completed.
#
# Two ways to provide the token:
#   --method gh    (default) reuse the token gh created during `gh auth login`
#                  via `gh auth token`. Fully automatic, no browser PAT page.
#   --method pat   paste a classic Personal Access Token you created at
#                  https://github.com/settings/tokens (scope: repo). The script
#                  reads it without echoing and stores it the same way.
#
# Note: storing a token in plain text is a convenience tradeoff that is fine for
# a short-lived hackathon machine. Do not do this on a shared or long-lived
# account.

CRED_FILE="${GIT_CREDENTIALS_FILE:-$HOME/.git-credentials}"
HOST="github.com"
METHOD="gh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      METHOD="${2:-}"
      shift 2
      ;;
    --method=*)
      METHOD="${1#*=}"
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: setup_git_credentials.sh [--method gh|pat]

Stores your GitHub token in a plain-text file and configures git to use it,
so pushing to GitHub never asks for a password.

Methods:
  --method gh    (default) reuse the token from `gh auth login`. Run `gh auth login` first.
  --method pat   paste a classic PAT from https://github.com/settings/tokens (scope: repo).

Environment:
  GIT_CREDENTIALS_FILE   override the credential file path (default: ~/.git-credentials)
  GITHUB_PAT             if set, used as the token in --method pat (no prompt)
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1 (try --help)"
      exit 1
      ;;
  esac
done

if [[ "$METHOD" != "gh" && "$METHOD" != "pat" ]]; then
  echo "Invalid --method '$METHOD'. Use 'gh' or 'pat'."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed. Install it first (run check_and_install_tools.sh)."
  exit 1
fi

TOKEN=""
USERNAME=""

if [[ "$METHOD" == "gh" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI gh is not installed. Install it, or use --method pat."
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "You are not logged in to GitHub on this machine yet."
    echo "Starting the browser login. If you are already signed in to GitHub in your"
    echo "browser, this just shows a one-time code to paste, then a single 'Authorize' click."
    echo
    # Web flow: opens the browser the participant is already signed into.
    # The flags pre-answer gh's prompts so the only step is paste-code + Authorize.
    if ! gh auth login --hostname github.com --git-protocol https --web; then
      echo
      echo "Browser login did not finish. You can try again, or paste a classic PAT instead:"
      echo "  setup_git_credentials.sh --method pat"
      exit 1
    fi
  fi
  TOKEN="$(gh auth token 2>/dev/null || true)"
  if [[ -z "$TOKEN" ]]; then
    echo "Could not read a token from gh. Run 'gh auth login' again and grant access."
    exit 1
  fi
  USERNAME="$(gh api user --jq .login 2>/dev/null || true)"
else
  TOKEN="${GITHUB_PAT:-}"
  if [[ -z "$TOKEN" ]]; then
    echo "Create a classic Personal Access Token here (scope: repo):"
    echo "  https://github.com/settings/tokens/new?scopes=repo&description=hackathon"
    printf "Paste your classic PAT (input hidden): "
    read -r -s TOKEN
    echo
  fi
  if [[ -z "$TOKEN" ]]; then
    echo "No token entered. Nothing changed."
    exit 1
  fi
  # Try to discover the username so the credential line is accurate.
  if command -v gh >/dev/null 2>&1; then
    USERNAME="$(GH_TOKEN="$TOKEN" gh api user --jq .login 2>/dev/null || true)"
  fi
fi

if [[ -z "$USERNAME" ]]; then
  USERNAME="x-access-token"
fi

# Write the credential line, preserving entries for other hosts.
NEW_LINE="https://${USERNAME}:${TOKEN}@${HOST}"
touch "$CRED_FILE"
chmod 600 "$CRED_FILE"
if [[ -s "$CRED_FILE" ]]; then
  grep -v "@${HOST}\$" "$CRED_FILE" > "${CRED_FILE}.tmp" 2>/dev/null || true
  mv "${CRED_FILE}.tmp" "$CRED_FILE"
fi
printf '%s\n' "$NEW_LINE" >> "$CRED_FILE"
chmod 600 "$CRED_FILE"

# Point git at the plain-text store file in the global config.
git config --global credential.helper "store --file=${CRED_FILE}"

# Make sure git knows who is committing.
if [[ -z "$(git config --global user.name || true)" ]]; then
  if command -v gh >/dev/null 2>&1; then
    NAME="$(gh api user --jq '.name // .login' 2>/dev/null || true)"
    [[ -n "$NAME" && "$NAME" != "null" ]] && git config --global user.name "$NAME"
  fi
fi
if [[ -z "$(git config --global user.email || true)" ]]; then
  EMAIL=""
  if command -v gh >/dev/null 2>&1; then
    EMAIL="$(gh api user --jq '.email' 2>/dev/null || true)"
  fi
  if [[ -z "$EMAIL" || "$EMAIL" == "null" ]]; then
    EMAIL="${USERNAME}@users.noreply.github.com"
  fi
  git config --global user.email "$EMAIL"
fi

echo "Method: $METHOD"
echo "GitHub credentials saved for user: $USERNAME"
echo "Credential file: $CRED_FILE (plain text, permissions 600)"
echo "git is configured to use it automatically. Pushes will no longer ask for a password."
