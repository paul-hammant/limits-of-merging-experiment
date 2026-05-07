#!/usr/bin/env bash
# Scenario C — release branched from C1 (not C2). The merge meister
# cherry-picks C2 (the wanted feature), cherry-picks C4 (the bugfix on
# top of C2), and explicitly *blocks* C3 by recording it as integrated
# without applying its diff. Then sweep-merges trunk.
#
# This is the "we considered C3 and chose not to ship it" workflow.
# In Perforce: `p4 integrate //src/...@CL,@CL //dst/...` opens a pending
# integration; `p4 resolve -ay //dst/...` accepts the *target's* version
# (i.e. ignores the source diff) while still recording the integration
# in the per-file integration database. The subsequent block-merge then
# skips the blocked CL because the database says it's already done.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WC="$ROOT/p4-wc"

export P4PORT="localhost:1667"
export P4USER="test"
export P4CLIENT="lom_test_client"
export P4TICKETS="$ROOT/.p4tickets"

# Branch the release from C1 (CL1) instead of the default C2 (CL2),
# so that C2 itself is a cherry-pick onto the release branch.
BRANCH_FROM_CL=1 "$ROOT/start.sh" >/dev/null

cd "$WC"

T_START=$(date +%s.%N)

show_integrated() {
  local stage="$1"
  echo "    --- p4 integrated //depot/branches/release/... after $stage ---"
  p4 integrated //depot/branches/release/... 2>/dev/null | sed 's/^/      /'
  echo
}

echo "==> Cherry-pick C2 (trunk@CL2) onto release"
p4 integrate //depot/trunk/...@2,@2 //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null
p4 submit -d "cherry-pick C2 from trunk@CL2" >/dev/null
show_integrated "C2 cherry-pick"

echo "==> Cherry-pick C4 (trunk@CL4) onto release"
p4 integrate //depot/trunk/...@4,@4 //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null
p4 submit -d "cherry-pick C4 from trunk@CL4" >/dev/null
show_integrated "C4 cherry-pick"

echo "==> Block C3 (trunk@CL3): integrate + 'resolve -ay' (accept yours), no diff applied"
p4 integrate //depot/trunk/...@3,@3 //depot/branches/release/... >/dev/null
# -ay = accept yours = keep target content, ignore source's edits.
# Records the integration so future block-merges skip CL3.
p4 resolve -ay //depot/branches/release/... >/dev/null
p4 submit -d "block C3: integrate + accept-yours of trunk@CL3 (no diff)" >/dev/null
show_integrated "C3 accept-yours block"

echo "==> Sweep-merge //depot/trunk -> //depot/branches/release"
p4 integrate //depot/trunk/... //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null 2>&1 || true
p4 submit -d "sweep merge //depot/trunk into //depot/branches/release" >/dev/null
show_integrated "sweep merge"

T_END=$(date +%s.%N)

echo "=== /branches/release changes ==="
p4 changes //depot/branches/release/...
echo
echo "=== diff //depot/trunk vs //depot/branches/release ==="
echo "(should differ only by C3's button-text change — UPPERCASE on trunk, mixed-case on release)"
p4 diff2 //depot/trunk/... //depot/branches/release/...
echo
echo "[scenario-only elapsed (excluding start.sh): $(awk -v s="$T_START" -v e="$T_END" 'BEGIN { printf "%.3f", e - s }')s]"
