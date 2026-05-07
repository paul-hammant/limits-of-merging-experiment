#!/usr/bin/env bash
# rollback.sh — stop the sandbox p4d and wipe the server + workspace dirs.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
P4_DIR="$ROOT/p4"
SERVER="$P4_DIR/p4-server"
WC="$P4_DIR/p4-wc"

# Try a graceful admin stop first (works because our sandbox has no security).
if command -v p4 >/dev/null; then
  P4PORT=localhost:1667 P4USER=test p4 admin stop 2>/dev/null || true
fi
# Belt-and-braces: kill anything still bound to our server dir.
pkill -f "p4d -r $SERVER" 2>/dev/null || true
sleep 0.3

rm -rf "$SERVER" "$WC" "$P4_DIR/.p4tickets"
echo "Stopped p4d on 1667 and wiped $SERVER and $WC."
echo "Run ./p4/start.sh to rebuild."
