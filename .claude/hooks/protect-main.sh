#!/usr/bin/env bash
# protect-main.sh
# PreToolUse hook for Bash. Blocks commits, pushes, and force operations
# against the main/master branch when the agent is currently on it.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher "Bash".
#
# Rationale: agents can accidentally commit directly to main. This is the classic
# "I forgot to create a feature branch" mistake. A cheap hook prevents it.

set -euo pipefail

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the command from JSON
command=$(echo "$input" | grep -oP '"command"\s*:\s*"\K[^"]*' || echo "")

# Only inspect git commands
if ! echo "$command" | grep -qE '^\s*git\s'; then
  exit 0
fi

# Protected branches
protected_branches="main master trunk develop production release"

# Determine current branch (silent, don't fail if not a repo)
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [[ -z "$current_branch" ]]; then
  # Not in a git repo or detached HEAD, let it pass
  exit 0
fi

# Only enforce on protected branches
is_protected="false"
for b in $protected_branches; do
  if [[ "$current_branch" == "$b" ]]; then
    is_protected="true"
    break
  fi
done

if [[ "$is_protected" != "true" ]]; then
  exit 0
fi

# Patterns that are dangerous on a protected branch
dangerous_patterns=(
  'git\s+commit'
  'git\s+push'
  'git\s+merge'
  'git\s+rebase'
  'git\s+reset\s+--hard'
  'git\s+cherry-pick'
)

for pattern in "${dangerous_patterns[@]}"; do
  if echo "$command" | grep -qE "$pattern"; then
    echo "BLOCKED by protect-main.sh: dangerous git operation on protected branch '$current_branch'" >&2
    echo "" >&2
    echo "Create a feature branch first:" >&2
    echo "  git switch -c feature/<slug>" >&2
    echo "" >&2
    echo "Then repeat the operation." >&2
    echo "" >&2
    echo "Protected branches: $protected_branches" >&2
    exit 1
  fi
done

exit 0
