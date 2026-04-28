#!/usr/bin/env bash
# start.sh — set up solution/ as a fresh git playground at C1.
#
# The outer ./.git (the GitHub clone) is moved aside to ./.git.disabled so
# the playground's commits don't accidentally land on your GitHub clone.
# Restore it later with:  mv .git.disabled .git
#
# The inner ./solution/.git is deleted outright — it's recreated fresh here.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
SOL="$ROOT/solution"

if [ -d "$ROOT/.git" ]; then
  if [ -e "$ROOT/.git.disabled" ]; then
    echo "error: $ROOT/.git.disabled already exists — refusing to overwrite" >&2
    echo "       (move or remove it, then re-run)" >&2
    exit 1
  fi
  echo "==> Renaming outer $ROOT/.git -> $ROOT/.git.disabled"
  echo "    (restore later with:  mv .git.disabled .git)"
  mv "$ROOT/.git" "$ROOT/.git.disabled"
fi

if [ -d "$SOL/.git" ]; then
  echo "==> Removing existing $SOL/.git"
  rm -rf "$SOL/.git"
fi

echo "==> Initialising fresh repo inside solution/"
cd "$SOL"

export GIT_AUTHOR_NAME="Test"      GIT_AUTHOR_EMAIL="t@e"
export GIT_COMMITTER_NAME="Test"   GIT_COMMITTER_EMAIL="t@e"
export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z"
export GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"

git init -q -b main
git add Gemfile app.rb happy_path_test.rb
git -c commit.gpgsign=false commit -q -m "start"

echo "==> Done."
git log --oneline
