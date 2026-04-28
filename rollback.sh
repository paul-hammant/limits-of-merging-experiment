#!/usr/bin/env bash
# rollback.sh — reset solution/.git back to a single C1 commit on main,
# undoing whatever a scenario script left behind. Does NOT delete .git;
# for that, use start.sh.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
SOL="$ROOT/solution"

cd "$SOL"

C1=$(git rev-list --max-parents=0 main 2>/dev/null | head -1 || true)
if [ -z "$C1" ]; then
  echo "error: no commits found — run ./start.sh first" >&2
  exit 1
fi

echo "==> Resetting solution to C1 ($C1)"
git checkout -q -B main "$C1"
git reset --hard -q "$C1"

# Wipe scenario tags and the release branch.
for t in c2 c3 c4 c5; do git tag -d "$t" >/dev/null 2>&1 || true; done
git branch -D release >/dev/null 2>&1 || true

echo "==> Done."
git log --oneline
