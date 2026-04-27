#!/bin/bash
# fab-gate.sh — PreToolUse hook that enforces fab pipeline gates.
#
# Wired into Claude Code via ~/.claude/settings.json:
#
#   "hooks": {
#     "PreToolUse": [
#       { "matcher": "Bash",
#         "hooks": [{ "type": "command",
#                     "command": "bash ~/.claude/hooks/fab-gate.sh",
#                     "timeout": 5 }] }
#     ]
#   }
#
# The hook is silent unless the worktree contains a `.fab` file (written by
# fab-init.sh). When `.fab` is present, it blocks `git commit` until both
# `codex_standard=done` and `codex_adversarial=done` are recorded, and blocks
# `gh pr create` until `committed=` is recorded.
#
# Customize the FAB_PATH_PATTERN regex below if you want a "safety net" that
# still blocks commits when `.fab` is missing in worktrees that *look* like fab
# worktrees (e.g. paths matching your team's ticket-id naming convention).
# The default pattern is permissive — it only triggers when `.fab` exists.

# Optional safety-net pattern. If $PWD matches this regex AND `.fab` is
# missing, git commit / gh pr create are blocked with a pointer to fab-init.sh.
# Default: empty (disabled). Set to something like
#   FAB_PATH_PATTERN='.*/dev/[a-z]+-[0-9]+-.*'
# to mirror the convention for ~/dev/{team}-{number}-{slug}-shaped worktrees.
FAB_PATH_PATTERN="${FAB_PATH_PATTERN:-}"

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "$INPUT")

if [ -f .fab ]; then
  if echo "$CMD" | grep -qE '^\s*git\s+commit|&&\s*git\s+commit'; then
    missing=()
    grep -q '^codex_standard=' .fab || missing+=("Standard code review")
    grep -q '^codex_adversarial=' .fab || missing+=("Adversarial code review")
    if [ ${#missing[@]} -gt 0 ]; then
      echo "FAB GATE BLOCKED: git commit requires completed reviews."
      for m in "${missing[@]}"; do echo "  ✗ $m — not recorded in .fab"; done
      exit 2
    fi
  fi
  if echo "$CMD" | grep -qE '^\s*gh\s+pr\s+create|&&\s*gh\s+pr\s+create'; then
    if ! grep -q '^committed=' .fab; then
      echo "FAB GATE BLOCKED: gh pr create requires a commit first."
      exit 2
    fi
  fi
  exit 0
fi

# No .fab here. If the path looks like a fab worktree but .fab is missing,
# block commits/PRs so the agent can't silently skip pipeline init.
if [ -n "$FAB_PATH_PATTERN" ] && echo "$PWD" | grep -qE "$FAB_PATH_PATTERN"; then
  if echo "$CMD" | grep -qE '^\s*(git\s+commit|gh\s+pr\s+create)|&&\s*(git\s+commit|gh\s+pr\s+create)'; then
    echo "FAB GATE BLOCKED: this looks like a fab worktree but .fab is missing."
    echo "  Run: bash <fab-skill-dir>/fab-init.sh \"\$PWD\" <TICKET-ID>"
    exit 2
  fi
fi

exit 0
