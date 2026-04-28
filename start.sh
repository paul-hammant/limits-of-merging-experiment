#!/usr/bin/env bash
# start.sh — flatten any existing git state and seed solution/ with a single
# starting commit (C1). Run this once after cloning to put the playground in
# a known state.
#
# WARNING: this deletes BOTH the outer ./.git (if any) and ./solution/.git.
# If you cloned this repo from GitHub to follow along, that means your clone
# loses its remote — that's intentional, the playground is local-only.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
SOL="$ROOT/solution"

echo "==> Removing outer .git (if present) and inner solution/.git"
rm -rf "$ROOT/.git" "$SOL/.git"

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
