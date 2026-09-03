#!/usr/bin/env bash
# protect-main.sh
# PreToolUse hook for Bash. Blocks commits, pushes, and force operations
# against the main/master branch when the agent is currently on it.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher "Bash".
#
# It also blocks `gh pr merge --admin`, anywhere, on any branch. That flag
# bypasses branch protection, which removes exactly the review that catches an
# unreviewed commit riding into a PR under someone else's title. Measured: it
# happened once, and the cost was paid by the repo, not by the agent that did it.
#
# Rationale: agents can accidentally commit directly to main. This is the classic
# "I forgot to create a feature branch" mistake. A cheap hook prevents it.

set -euo pipefail

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the command from JSON
command=$(printf '%s' "$input" | python3 -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('command') or ti.get('command') or '')" 2>/dev/null || echo "")

# --- gh pr merge --admin: blocked everywhere, on any branch -------------------
# Bypassing branch protection is never something to do on someone else's behalf.
# If protection is genuinely in the way, that is a decision for a human.
# Only at a COMMAND POSITION - start of a line, or after ; && || | - because
# matching anywhere fires on the words appearing inside a heredoc or a commit
# message, which is someone documenting the command, not running it. That
# false positive blocked the very commit that introduced this guard.
if echo "$command" | grep -qE '(^|[;&|])[[:space:]]*gh[[:space:]]+pr[[:space:]]+merge' \
   && echo "$command" | grep -qE '(^|[[:space:]])--admin([[:space:]]|$)'; then
  {
    echo "BLOCKED by protect-main.sh: 'gh pr merge --admin' bypasses branch protection."
    echo ""
    echo "That flag removes the review that catches an unreviewed commit riding into"
    echo "a PR under another change's title — which is how it has already gone wrong."
    echo ""
    echo "Check what the PR actually contains first:"
    echo "  gh pr view <n> --json files --jq '.files[].path'"
    echo ""
    echo "If the protection is genuinely in the way, say so and let a human decide."
  } >&2
  exit 2
fi

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
    exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
  fi
done

exit 0
