#!/usr/bin/env bash
# Scenario C — release branched from C1 (not C2). The merge meister
# cherry-picks C2 (the wanted feature), cherry-picks C4 (the bugfix on
# top of C2), and explicitly *blocks* C3 with `git merge -s ours c3`
# (records the merge node, applies none of the diff). Then sweep-merges
# main.
#
# This is the "we considered C3 and chose not to ship it" workflow.
# In git: `git merge -s ours <commit>` makes <commit> a parent of the
# current branch but the resulting tree is exactly "ours" — none of the
# other commit's diff is applied. The merge-base machinery then sees
# <commit> as an ancestor on subsequent merges and skips it, the same
# way SVN's --record-only or P4's `resolve -ay` work.
#
# Usage:  ./scenario-c-block-c3.sh
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

show_integration() {
  local stage="$1"
  echo "    --- merge nodes reachable from release after $stage ---"
  local merges
  merges=$(git log --merges --oneline release 2>/dev/null)
  if [ -z "$merges" ]; then
    echo "      (none yet)"
  else
    echo "$merges" | sed 's/^/      /'
  fi
  echo "    --- trunk-tag reachability from release ---"
  for tag in c2 c3 c4 c5; do
    if git merge-base --is-ancestor "$tag" release 2>/dev/null; then
      printf "      %s: yes (in ancestry)\n" "$tag"
    else
      printf "      %s: no (cherry-picked → different SHA, or unmerged)\n" "$tag"
    fi
  done
  echo
}

T_START=$(date +%s.%N)

echo "==> Cut release at C1"
git checkout -q -B release "$C1"

echo "==> Cherry-pick C2 onto release"
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git cherry-pick --no-edit c2 >/dev/null
show_integration "C2 cherry-pick"

echo "==> Cherry-pick C4 onto release"
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git cherry-pick --no-edit c4 >/dev/null
show_integration "C4 cherry-pick"

echo "==> Block C3: git merge -s ours c3 (record, no diff applied)"
# `-s ours` records c3 as a parent of release without applying any of c3's
# diff. After this, c3 is in release's ancestry via the merge node, so the
# next `git merge main` sees c3 as already integrated and skips it.
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git merge -s ours --no-edit \
  -m "block C3: merge -s ours (record without applying diff)" c3 >/dev/null
show_integration "C3 -s ours block"

echo "==> Sweep-merge main into release"
GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" git merge --no-edit main >/dev/null
show_integration "sweep merge"

T_END=$(date +%s.%N)

echo
echo "=== release graph ==="
git log --oneline --graph --decorate -n 12
echo
echo "release tip tree   = $(git rev-parse release^{tree})"
echo "main tip tree      = $(git rev-parse main^{tree})"
echo "release tip commit = $(git rev-parse release)"
echo
echo "diff release vs main:"
echo "(should differ only by C3's button-text change — UPPERCASE on main, mixed-case on release)"
git diff --stat release main || true
echo
echo "[scenario-only elapsed (cut + cherry-picks + block + sweep): $(awk -v s="$T_START" -v e="$T_END" 'BEGIN { printf "%.3f", e - s }')s]"
