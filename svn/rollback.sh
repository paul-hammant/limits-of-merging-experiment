#!/usr/bin/env bash
# rollback.sh — wipe the SVN repo and working copy entirely.
# (SVN is append-only, so "reset" means delete and rebuild from start.sh.)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SVN_DIR="$ROOT/svn"

rm -rf "$SVN_DIR/svn-repo" "$SVN_DIR/svn-wc"
echo "Wiped $SVN_DIR/svn-repo and $SVN_DIR/svn-wc"
echo "Run ./svn/start.sh to rebuild."
