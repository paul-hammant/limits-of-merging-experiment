#!/usr/bin/env bash
# Scenario B — cherry-pick C3 (CL3) onto release BEFORE C4 (CL4),
# then sweep-merge //depot/trunk into //depot/branches/release.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
P4_DIR="$ROOT/p4"
WC="$P4_DIR/p4-wc"

export P4PORT="localhost:1667"
export P4USER="test"
export P4CLIENT="lom_test_client"
export P4TICKETS="$P4_DIR/.p4tickets"

"$P4_DIR/start.sh" >/dev/null

cd "$WC"

show_integrated() {
  local stage="$1"
  echo "    --- p4 integrated //depot/branches/release/... after $stage ---"
  p4 integrated //depot/branches/release/... 2>/dev/null | sed 's/^/      /'
  echo
}

echo "==> Cherry-pick C3 (trunk@CL3) onto release"
p4 integrate //depot/trunk/...@3,@3 //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null
p4 submit -d "cherry-pick C3 from trunk@CL3" >/dev/null
show_integrated "C3 cherry-pick"

echo "==> Cherry-pick C4 (trunk@CL4) onto release"
p4 integrate //depot/trunk/...@4,@4 //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null
p4 submit -d "cherry-pick C4 from trunk@CL4" >/dev/null
show_integrated "C4 cherry-pick"

echo "==> Sweep-merge //depot/trunk -> //depot/branches/release"
p4 integrate //depot/trunk/... //depot/branches/release/... >/dev/null
p4 resolve -am //depot/branches/release/... >/dev/null 2>&1 || true
p4 submit -d "sweep merge //depot/trunk into //depot/branches/release" >/dev/null
show_integrated "sweep merge"

echo "=== /branches/release changes ==="
p4 changes //depot/branches/release/...
echo
echo "=== diff //depot/trunk vs //depot/branches/release (should be empty) ==="
p4 diff2 //depot/trunk/... //depot/branches/release/...
