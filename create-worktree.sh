#!/bin/bash
# create-worktree.sh — generic git worktree bootstrapper for fab.
#
# Usage:
#   create-worktree.sh <worktree-name>
#   create-worktree.sh <branch-name> <worktree-name>
#
# Creates ~/dev/<worktree-name>, copies env/config files, optionally assigns a
# dev-server slot when the repo uses overmind (Procfile.dev), and installs JS
# dependencies. Auto-detects the package manager (yarn/npm/pnpm).
#
# This script is intentionally generic. It contains no team- or product-specific
# hardcoding. If you want richer behavior (e.g. fetching ticket details from a
# task tracker before naming the worktree, or recording the worktree in a team
# coordinator), call this script from a wrapper that handles those concerns.

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# -----------------------------------------------------------------------------
# Auto-detect repo features
# -----------------------------------------------------------------------------

if [ -f "yarn.lock" ]; then
  PKG_INSTALL="yarn install --silent"
elif [ -f "pnpm-lock.yaml" ]; then
  PKG_INSTALL="pnpm install --silent"
elif [ -f "package-lock.json" ]; then
  PKG_INSTALL="npm install --silent"
else
  PKG_INSTALL=""
fi

HAS_SLOTS=false
if [ -f "Procfile.dev" ]; then
  HAS_SLOTS=true
fi

# Overmind / tmux socket path limit. Only enforced when slots are active.
MAX_WORKTREE_NAME_LENGTH=40

# -----------------------------------------------------------------------------
# Slot Management (only when Procfile.dev is present)
# -----------------------------------------------------------------------------

SLOT_LOCK_DIR="/tmp/dev-slot-lock"
if [ -d "$SLOT_LOCK_DIR" ]; then
  if find "$SLOT_LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null | grep -q .; then
    rmdir "$SLOT_LOCK_DIR" 2>/dev/null || true
  fi
fi

find_next_available_slot() {
  local used_slots=()
  local slot_files
  slot_files=$(find "$HOME/dev" -maxdepth 2 -name ".dev-slot" 2>/dev/null || true)
  for slot_file in $slot_files; do
    if [ -f "$slot_file" ]; then
      used_slots+=("$(cat "$slot_file")")
    fi
  done
  if [ -f "$REPO_ROOT/.dev-slot" ]; then
    used_slots+=($(cat "$REPO_ROOT/.dev-slot"))
  fi
  for slot in {1..9}; do
    local is_used=false
    for used in "${used_slots[@]}"; do
      if [ "$slot" -eq "$used" ]; then is_used=true; break; fi
    done
    if [ "$is_used" = false ]; then echo "$slot"; return; fi
  done
  echo "1"
}

assign_slot() {
  local worktree_path="$1"
  while ! mkdir "$SLOT_LOCK_DIR" 2>/dev/null; do sleep 0.1; done
  local slot=$(find_next_available_slot)
  echo "$slot" > "$worktree_path/.dev-slot"
  rmdir "$SLOT_LOCK_DIR"
  echo "$slot"
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

is_protected_branch() {
  case "$1" in
    master|main|develop|production|staging) return 0 ;;
    *) return 1 ;;
  esac
}

remove_submodule_gitfiles() {
  local worktree_path="$1"
  for gitfile in $(find "$worktree_path/.claude" -name .git -type f 2>/dev/null); do
    rm "$gitfile"
    echo "  Removed submodule gitlink: $(dirname "$gitfile" | sed "s|$worktree_path/||")"
  done
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------

original_branch=$(git branch --show-current)

if [ "$#" -eq 0 ]; then
  current_branch=$(git branch --show-current)
  worktree_name=$(echo "$current_branch" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
elif [ "$#" -eq 1 ]; then
  worktree_name="$1"
  current_branch=$(git branch --show-current)
elif [ "$#" -eq 2 ]; then
  branch_name="$1"
  worktree_name="$2"
  if is_protected_branch "$branch_name"; then
    echo "Error: Cannot create worktree for protected branch '$branch_name'"
    exit 1
  fi
  echo "Creating branch: $branch_name"
  git checkout -b "$branch_name" 2>/dev/null || {
    echo "Branch $branch_name already exists, switching to it"
    git checkout "$branch_name"
  }
  current_branch="$branch_name"
else
  echo "Usage: $0 [worktree-name] or $0 [branch-name] [worktree-name]"
  exit 1
fi

if [ "$HAS_SLOTS" = true ]; then
  if [ ${#worktree_name} -gt "$MAX_WORKTREE_NAME_LENGTH" ]; then
    echo "Error: worktree name '$worktree_name' is ${#worktree_name} chars (max $MAX_WORKTREE_NAME_LENGTH)."
    echo "overmind/tmux Unix sockets cap path length at ~104 chars on macOS."
    exit 1
  fi
fi

worktree_path="$HOME/dev/$worktree_name"

if is_protected_branch "$current_branch"; then
  echo "CRITICAL: refusing to create worktree of protected branch '$current_branch'"
  exit 1
fi

if [ -d "$worktree_path" ]; then
  echo "Error: worktree already exists at $worktree_path"
  exit 1
fi

# -----------------------------------------------------------------------------
# Create the worktree
# -----------------------------------------------------------------------------

if git worktree add "$worktree_path" "$current_branch" 2>/dev/null; then
  echo "Created worktree."
else
  echo "Branch is checked out elsewhere; using --force"
  git worktree add --force "$worktree_path" "$current_branch"
fi

git push -u origin "$current_branch" 2>/dev/null && echo "Pushed branch to remote" || true

if [ "$original_branch" != "$current_branch" ]; then
  echo "Switching main repo back to $original_branch..."
  git checkout "$original_branch"
fi

# -----------------------------------------------------------------------------
# Copy config files
# -----------------------------------------------------------------------------

env_copied=0
while IFS= read -r envfile; do
  relpath="${envfile#./}"
  reldir="$(dirname "$relpath")"
  if [ "$reldir" != "." ]; then
    mkdir -p "$worktree_path/$reldir"
  fi
  cp "$envfile" "$worktree_path/$relpath"
  env_copied=$((env_copied + 1))
done < <(find . -name ".env" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.claude/*")
[ "$env_copied" -gt 0 ] && echo "Copied $env_copied .env file(s)"

if [ -d ".claude" ]; then
  rm -rf "$worktree_path/.claude"
  cp -a .claude "$worktree_path/"
  echo "Copied .claude directory"
  remove_submodule_gitfiles "$worktree_path"
fi

[ -f ".claude/settings.local.json" ] && cp .claude/settings.local.json "$worktree_path/.claude/"
[ -f ".mcp.json" ] && cp .mcp.json "$worktree_path/" && echo "Copied .mcp.json"

# -----------------------------------------------------------------------------
# Slots + deps
# -----------------------------------------------------------------------------

if [ "$HAS_SLOTS" = true ]; then
  assigned_slot=$(assign_slot "$worktree_path")
  echo "Assigned dev slot: $assigned_slot"
fi

cd "$worktree_path"
echo "Switched to $worktree_path (branch: $(git branch --show-current))"

if [ -n "$PKG_INSTALL" ]; then
  echo "Installing dependencies..."
  $PKG_INSTALL
  echo "Dependencies installed."
fi

if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
  echo "Installing frontend deps..."
  cd frontend
  if [ -f "yarn.lock" ]; then yarn install --silent
  elif [ -f "pnpm-lock.yaml" ]; then pnpm install --silent
  else npm install --silent; fi
  cd ..
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo "Worktree ready!"
echo "---"
echo "Location: $worktree_path"
echo "Branch:   $(git branch --show-current)"
[ "$HAS_SLOTS" = true ] && echo "Dev slot: $assigned_slot"
