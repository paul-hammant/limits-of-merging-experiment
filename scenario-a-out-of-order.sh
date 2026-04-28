#!/usr/bin/env bash
# Scenario A — release branch cherry-picks C4 BEFORE C3 (out of trunk order),
# then trunk gets C5, then we sweep-merge main into release.
#
# Demonstrates: even with cherry-picks landed in the "wrong" order on release,
# once trunk is merged in the resulting tree converges to identical content.
#
# Usage:  ./scenario-a-out-of-order.sh
# Prereq: run ./start.sh first to seed ./solution with the C1 commit.
# Resets: hard-resets ./solution back to C1 before running.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
SOL="$ROOT/solution"
PATCHES="$ROOT/patches"
# C1 is whatever the start commit is on main right now. We don't hard-code
# its SHA because start.sh recreates the playground freshly each time.
C1=$(cd "$SOL" && git rev-list --max-parents=0 main 2>/dev/null | head -1)
if [ -z "$C1" ]; then
  echo "error: no commits in $SOL — run ./start.sh first" >&2
  exit 1
fi

# Pin every input that feeds a SHA so re-runs are deterministic.
export GIT_AUTHOR_NAME="Test"      GIT_AUTHOR_EMAIL="t@e"
export GIT_COMMITTER_NAME="Test"   GIT_COMMITTER_EMAIL="t@e"
export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z"
export GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"

cd "$SOL"

echo "==> Reset solution to C1"
git checkout -q main 2>/dev/null || git checkout -q -B main "$C1"
git reset --hard -q "$C1"
git tag -d c2 c3 c4 c5 2>/dev/null || true
git branch -D release 2>/dev/null || true

echo "==> Build trunk: apply C2, C3, C4, C5"
git am --quiet "$PATCHES/c2-hair-color-string.patch"
git tag c2
git am --quiet "$PATCHES/c3-uppercase-buttons.patch"
git tag c3
git am --quiet "$PATCHES/c4-hair-color-int.patch"
git tag c4
git am --quiet "$PATCHES/c5-maintainer-comment.patch"
git tag c5

echo "==> Cut release at C2, cherry-pick C4 then C3 (out of order)"
git checkout -q -B release c2
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git cherry-pick --no-edit c4 >/dev/null
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git cherry-pick --no-edit c3 >/dev/null

echo "==> Sweep-merge main into release"
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git merge --no-edit main >/dev/null

echo
echo "=== release graph ==="
git log --oneline --graph --decorate -n 8
echo
echo "release tip tree   = $(git rev-parse release^{tree})"
echo "main tip tree      = $(git rev-parse main^{tree})"
echo "release tip commit = $(git rev-parse release)"
echo
echo "diff release vs main:"
git diff --stat release main || true
