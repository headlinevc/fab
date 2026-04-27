#!/bin/bash
# fab-init.sh — initialize a fab worktree's .fab state file.
#
# Usage:
#   fab-init.sh <worktree-path> <ticket-id>
#
# Writes .fab to the worktree root with:
#   ticket=<ticket-id>
#   fabricated_at=<ISO-8601 UTC timestamp>
#
# Idempotent: if .fab already exists, prints its current contents and exits 0
# without modification. Run this immediately after creating the worktree and
# before any implementation work — the fab-gate hook depends on .fab.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <worktree-path> <ticket-id>" >&2
  echo "Example: $0 ~/dev/abc-123-feature-name ABC-123" >&2
  exit 1
fi

WORKTREE="$1"
TICKET="$2"

if [ ! -d "$WORKTREE" ]; then
  echo "Error: worktree path does not exist: $WORKTREE" >&2
  exit 1
fi

if [ ! -d "$WORKTREE/.git" ] && ! git -C "$WORKTREE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: $WORKTREE is not a git worktree" >&2
  exit 1
fi

FAB_FILE="$WORKTREE/.fab"

if [ -f "$FAB_FILE" ]; then
  echo "fab-init: .fab already exists at $FAB_FILE — leaving as-is."
  echo "Current state:"
  sed 's/^/  /' "$FAB_FILE"
  exit 0
fi

cat > "$FAB_FILE" <<EOF
ticket=$TICKET
fabricated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# Ensure .fab is gitignored locally (don't pollute the repo .gitignore).
GITIGNORE_LOCAL="$WORKTREE/.git/info/exclude"
if [ -f "$GITIGNORE_LOCAL" ] && ! grep -qxF '.fab' "$GITIGNORE_LOCAL"; then
  echo '.fab' >> "$GITIGNORE_LOCAL"
fi

echo "fab-init: wrote $FAB_FILE"
echo "  ticket=$TICKET"
echo "  fabricated_at=$(grep '^fabricated_at=' "$FAB_FILE" | cut -d= -f2)"
