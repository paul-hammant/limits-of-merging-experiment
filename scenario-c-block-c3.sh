#!/usr/bin/env bash
# Scenario C — release branched from C1 (not C2). The merge meister
# cherry-picks C2 (the wanted feature), cherry-picks C4 (the bugfix on
# top of C2), and explicitly *blocks* C3 by recording it as merged
# without applying its diff. Then sweep-merges trunk.
#
# This is the "we considered C3 and chose not to ship it" workflow.
# In SVN: `svn merge --record-only -c REV ^/trunk .`  records the
# revision in svn:mergeinfo without touching files. The subsequent
# sweep merge then skips it because mergeinfo says it's already done.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WC="$ROOT/svn-wc"
REL="$WC/branches/release"
URL="file://$ROOT/svn-repo"

# Branch the release from C1 (r2) instead of the default C2 (r3),
# so that C2 itself is a cherry-pick onto the release branch.
BRANCH_FROM_REV=2 "$ROOT/start.sh" >/dev/null

T_START=$(date +%s.%N)

show_mergeinfo() {
  local stage="$1"
  echo "    --- svn:mergeinfo on /branches/release after $stage ---"
  ( cd "$REL" && svn propget svn:mergeinfo . 2>/dev/null ) | sed 's/^/      /' \
    || echo "      (none)"
  echo
}

echo "==> Cherry-pick C2 (trunk@r3) onto release"
( cd "$REL"
  svn merge -c3 ^/trunk .
  svn commit -q -m "cherry-pick C2 from trunk@r3"
)
svn update -q "$WC"
show_mergeinfo "C2 cherry-pick"

echo "==> Cherry-pick C4 (trunk@r5) onto release"
( cd "$REL"
  svn merge -c5 ^/trunk .
  svn commit -q -m "cherry-pick C4 from trunk@r5"
)
svn update -q "$WC"
show_mergeinfo "C4 cherry-pick"

echo "==> Block C3 (trunk@r4): record-only merge, no diff applied"
( cd "$REL"
  svn merge --record-only -c4 ^/trunk .
  svn commit -q -m "block C3: record-only merge of trunk@r4 (no diff)"
)
svn update -q "$WC"
show_mergeinfo "C3 record-only block"

echo "==> Sweep-merge ^/trunk into release"
( cd "$REL"
  # mergeinfo already names r3, r4, r5 — sweep should only apply r6 (C5).
  svn merge ^/trunk .
  svn commit -q -m "sweep merge ^/trunk into release"
)
svn update -q "$WC"
show_mergeinfo "sweep merge"

T_END=$(date +%s.%N)

echo "=== /branches/release log ==="
svn log -q "$URL/branches/release" | grep '^r' | sort -n
echo
echo "=== diff /trunk vs /branches/release ==="
echo "(should differ only by C3's button-text change — UPPERCASE on trunk, mixed-case on release)"
svn diff "$URL/trunk" "$URL/branches/release" || true
echo
echo "[scenario-only elapsed (excluding start.sh): $(awk -v s="$T_START" -v e="$T_END" 'BEGIN { printf "%.3f", e - s }')s]"
