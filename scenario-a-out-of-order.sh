#!/usr/bin/env bash
# Scenario A — cherry-pick C4 (CL4) onto release BEFORE C3 (CL3),
# then sweep-merge //depot/trunk into //depot/branches/release.
# Print p4's integration records after each step — these are P4's
# equivalent of svn:mergeinfo and what git lacks.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WC="$ROOT/p4-wc"

export P4PORT="localhost:1667"
export P4USER="test"
export P4CLIENT="lom_test_client"
export P4TICKETS="$ROOT/.p4tickets"

"$ROOT/start.sh" >/dev/null

cd "$WC"

T_START=$(date +%s.%N)

show_integrated() {
  local stage="$1"
  echo "    --- p4 integrated //depot/branches/release/... after $stage ---"
  p4 integrated //depot/branches/release/... 2>/dev/null | sed 's/^/      /'
  echo
}

echo "==> Cherry-pick C4 (trunk@CL4) onto release"
p4 integrate //depot/trunk/...@4,@4 //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null
p4 submit -d "cherry-pick C4 from trunk@CL4" >/dev/null
show_integrated "C4 cherry-pick"

echo "==> Cherry-pick C3 (trunk@CL3) onto release"
p4 integrate //depot/trunk/...@3,@3 //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null
p4 submit -d "cherry-pick C3 from trunk@CL3" >/dev/null
show_integrated "C3 cherry-pick"

echo "==> Sweep-merge //depot/trunk -> //depot/branches/release"
# No rev range — p4 consults integration records and only re-applies
# revisions that haven't already been credited. Should pull in just C5.
p4 integrate //depot/trunk/... //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null 2>&1 || true
p4 submit -d "sweep merge //depot/trunk into //depot/branches/release" >/dev/null
show_integrated "sweep merge"

T_END=$(date +%s.%N)

echo "=== /branches/release changes ==="
p4 changes //depot/branches/release/...
echo
echo "=== diff //depot/trunk vs //depot/branches/release (should be empty) ==="
p4 diff2 //depot/trunk/... //depot/branches/release/...
echo
echo "[scenario-only elapsed (excluding start.sh): $(awk -v s="$T_START" -v e="$T_END" 'BEGIN { printf "%.3f", e - s }')s]"
