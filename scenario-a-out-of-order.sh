#!/usr/bin/env bash
# Scenario A — cherry-pick C4 (r5) onto release BEFORE C3 (r4),
# then sweep-merge ^/trunk into release. Show svn:mergeinfo at each step.
#
# Equivalent to git's scenario-a-out-of-order.sh but in SVN, where
# svn:mergeinfo is recorded automatically on the branch root.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WC="$ROOT/svn-wc"
REL="$WC/branches/release"
URL="file://$ROOT/svn-repo"

"$ROOT/start.sh" >/dev/null

show_mergeinfo() {
  local stage="$1"
  echo "    --- svn:mergeinfo on /branches/release after $stage ---"
  ( cd "$REL" && svn propget svn:mergeinfo . 2>/dev/null ) | sed 's/^/      /' \
    || echo "      (none)"
  echo
}

echo "==> Cherry-pick C4 (trunk@r5) onto release"
( cd "$REL"
  svn merge -c5 ^/trunk .
  svn commit -q -m "cherry-pick C4 from trunk@r5"
)
svn update -q "$WC"
show_mergeinfo "C4 cherry-pick"

echo "==> Cherry-pick C3 (trunk@r4) onto release"
( cd "$REL"
  svn merge -c4 ^/trunk .
  svn commit -q -m "cherry-pick C3 from trunk@r4"
)
svn update -q "$WC"
show_mergeinfo "C3 cherry-pick"

echo "==> Sweep-merge ^/trunk into release"
( cd "$REL"
  # SVN consults svn:mergeinfo and applies only eligible (un-merged) revisions.
  # Should pull in only r6 (C5); r4 and r5 are already in mergeinfo.
  svn merge ^/trunk .
  svn commit -q -m "sweep merge ^/trunk into release"
)
svn update -q "$WC"
show_mergeinfo "sweep merge"

echo "=== /branches/release log ==="
svn log -q "$URL/branches/release" | grep '^r' | sort -n
echo
echo "=== diff /trunk vs /branches/release (should be empty) ==="
svn diff "$URL/trunk" "$URL/branches/release" || true
