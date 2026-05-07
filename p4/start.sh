#!/usr/bin/env bash
# start.sh — set up a local p4d server + workspace under ./p4 for the
# limits-of-merging experiment, with //depot/trunk holding C1-C5 and a
# //depot/branches/release branch cut from trunk@CL2.
#
# Changelist map (deterministic):
#   CL1 = C1 (initial Person CRUD app)
#   CL2 = C2 (add hair_color string)
#   CL3 = C3 (UPPERCASE buttons)
#   CL4 = C4 (hair_color INTEGER)
#   CL5 = C5 (maintainer comment)
#   CL6 = p4 populate //depot/trunk/...@2 -> //depot/branches/release/...
#
# Sandbox: runs p4d on port 1667 (not the default 1666) without SSL and
# without security level set, so no passwords. Server lives in p4/p4-server,
# workspace in p4/p4-wc; both are wiped on every run.
#
# Server-side primer: ../fast_perforce_setup/README.md
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
P4_DIR="$ROOT/p4"
SERVER="$P4_DIR/p4-server"
WC="$P4_DIR/p4-wc"

export P4PORT="localhost:1667"
export P4USER="test"
export P4CLIENT="lom_test_client"
# Keep tickets/config out of the user's home so this is fully self-contained.
export P4TICKETS="$P4_DIR/.p4tickets"
unset P4CONFIG 2>/dev/null || true

if ! command -v p4 >/dev/null || ! command -v p4d >/dev/null; then
  echo "error: p4/p4d not on PATH. See ../fast_perforce_setup/README.md" >&2
  exit 1
fi

# Stop any p4d we previously launched on 1667.
pkill -f "p4d -r $SERVER" 2>/dev/null || true
sleep 0.3

echo "==> Wiping $SERVER and $WC"
rm -rf "$SERVER" "$WC"
mkdir -p "$SERVER" "$WC"

echo "==> Starting p4d (no SSL, no security) on $P4PORT"
p4d -r "$SERVER" -p "$P4PORT" -L "$SERVER/log" -d >/dev/null 2>&1

# Wait for the server to start listening.
for _ in $(seq 1 30); do
  if p4 info >/dev/null 2>&1; then break; fi
  sleep 0.1
done
if ! p4 info >/dev/null 2>&1; then
  echo "error: p4d failed to come up — see $SERVER/log" >&2
  exit 1
fi

echo "==> Creating user '$P4USER' and client '$P4CLIENT'"
p4 user -i -f >/dev/null <<EOF
User: $P4USER
Email: $P4USER@example.com
FullName: Test User
EOF

p4 client -i >/dev/null <<EOF
Client: $P4CLIENT
Owner: $P4USER
Root: $WC
View:
	//depot/... //$P4CLIENT/...
EOF

cd "$WC"

echo "==> CL1: import C1 onto trunk"
mkdir -p trunk
cp "$ROOT/solution/Gemfile" "$ROOT/solution/app.rb" "$ROOT/solution/happy_path_test.rb" trunk/
( cd trunk
  p4 add Gemfile app.rb happy_path_test.rb >/dev/null
  p4 submit -d "C1: initial Person CRUD app, seeded Flintstones, Playwright happy-path test" >/dev/null
)

apply_and_submit() {
  local cl="$1" patchfile="$2" msg="$3"
  echo "==> CL$cl: $msg"
  ( cd "$WC/trunk"
    p4 edit app.rb happy_path_test.rb >/dev/null
    patch -p1 --silent < "$ROOT/patches/$patchfile"
    p4 submit -d "$msg" >/dev/null
  )
}

apply_and_submit 2 "c2-hair-color-string.patch" \
  "C2: add hair_color (string) — dropdown, JS validation, DB CHECK constraint"
apply_and_submit 3 "c3-uppercase-buttons.patch" \
  "C3: button text to UPPERCASE (NEW PERSON / EDIT / DELETE / SAVE / CANCEL)"
apply_and_submit 4 "c4-hair-color-int.patch" \
  "C4: hair_color stored as INTEGER (1..6), dropdown values become ints"
apply_and_submit 5 "c5-maintainer-comment.patch" \
  "C5: add maintainer comment in header"

echo "==> CL6: p4 populate //depot/trunk/...@2 -> //depot/branches/release/..."
p4 populate -d "branch release at C2 (trunk@CL2)" \
  //depot/trunk/...@2 //depot/branches/release/... >/dev/null

p4 sync //depot/branches/release/... >/dev/null

echo
echo "=== changes ==="
p4 changes -m 10
echo
echo "Done. Use ./p4/scenario-a-out-of-order.sh or ./p4/scenario-b-in-order.sh next."
