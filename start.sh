#!/usr/bin/env bash
# start.sh — set up an SVN repo + working copy at the repo root for the
# limits-of-merging experiment, with trunk holding C1-C5 and a release
# branch cut from C2.
#
# Layout in the repo:
#   /trunk         — receives C1, C2, C3, C4, C5 in that order
#   /branches      — release branch lives here, cut from /trunk@C2
#   /tags
#
# Revision map (deterministic):
#   r1 = layout (mkdir trunk + branches + tags)
#   r2 = C1 (initial Person CRUD app)
#   r3 = C2 (add hair_color string)
#   r4 = C3 (uppercase buttons)
#   r5 = C4 (hair_color INTEGER)
#   r6 = C5 (maintainer comment)
#   r7 = svn copy /trunk@r3 -> /branches/release  ("branch from C2")
#
# The scenario scripts call this first to guarantee a clean state.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO="$ROOT/svn-repo"
WC="$ROOT/svn-wc"
URL="file://$REPO"

if ! command -v svn >/dev/null || ! command -v svnadmin >/dev/null; then
  echo "error: svn / svnadmin not on PATH. Install with:" >&2
  echo "       sudo apt install subversion" >&2
  exit 1
fi

echo "==> Wiping any prior $REPO and $WC"
rm -rf "$REPO" "$WC"

echo "==> svnadmin create"
svnadmin create "$REPO"

echo "==> r1: create layout"
svn mkdir -q -m "layout: trunk + branches + tags" --parents \
  "$URL/trunk" "$URL/branches" "$URL/tags"

echo "==> Checkout working copy at repo root"
svn checkout -q "$URL" "$WC"

apply_and_commit() {
  local label="$1" patchfile="$2" msg="$3"
  echo "==> $label"
  ( cd "$WC/trunk"
    if [ -n "$patchfile" ]; then
      # Use 'patch -p1' (not 'git apply') because the working copy lives
      # inside the outer project's git worktree, and 'git apply' would
      # skip files it doesn't see in that index.
      patch -p1 --silent < "$ROOT/patches/$patchfile"
    fi
    svn commit -q -m "$msg"
  )
  svn update -q "$WC"
}

echo "==> r2: import C1 onto trunk"
cp "$ROOT/solution/Gemfile" "$ROOT/solution/app.rb" "$ROOT/solution/happy_path_test.rb" "$WC/trunk/"
( cd "$WC/trunk"
  svn add -q Gemfile app.rb happy_path_test.rb
  svn commit -q -m "C1: initial Person CRUD app, seeded Flintstones, Playwright happy-path test"
)
svn update -q "$WC"

apply_and_commit "r3: C2 — add hair_color (string)" \
  "c2-hair-color-string.patch" \
  "C2: add hair_color (string) — dropdown, JS validation, DB CHECK constraint"

apply_and_commit "r4: C3 — uppercase buttons" \
  "c3-uppercase-buttons.patch" \
  "C3: button text to UPPERCASE (NEW PERSON / EDIT / DELETE / SAVE / CANCEL)"

apply_and_commit "r5: C4 — hair_color INTEGER" \
  "c4-hair-color-int.patch" \
  "C4: hair_color stored as INTEGER (1..6), dropdown values become ints"

apply_and_commit "r6: C5 — maintainer comment" \
  "c5-maintainer-comment.patch" \
  "C5: add maintainer comment in header"

echo "==> r7: svn copy /trunk@r3 -> /branches/release  (branch from C2)"
svn copy -q -r3 "$URL/trunk" "$URL/branches/release" -m "branch release at C2 (trunk@r3)"
svn update -q "$WC"

echo
echo "=== repository log ==="
svn log -q "$URL" | grep '^r' | sort -n
echo
echo "Done. Use ./scenario-a-out-of-order.sh or ./scenario-b-in-order.sh next."
