#!/usr/bin/env bash
# rollback.sh — wipe the SVN repo and working copy entirely.
# (SVN is append-only, so "reset" means delete and rebuild from start.sh.)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)

rm -rf "$ROOT/svn-repo" "$ROOT/svn-wc"
echo "Wiped $ROOT/svn-repo and $ROOT/svn-wc"
echo "Run ./start.sh to rebuild."
