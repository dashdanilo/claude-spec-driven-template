#!/usr/bin/env bash
# block-secrets.sh
# PreToolUse hook for Bash. Blocks commands that try to read sensitive files
# or print secret-named environment variables.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher "Bash".

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the command from the JSON (tool_input.command for the Bash tool)
command=$(echo "$input" | grep -oP '"command"\s*:\s*"\K[^"]*' || echo "")

# Forbidden patterns
forbidden_patterns=(
  'cat\s+\.env'
  'cat\s+.*\.env'
  '\.env.*\|'
  'printenv'
  'env\s*$'
  'echo\s+\$[A-Z_]*TOKEN'
  'echo\s+\$[A-Z_]*KEY'
  'echo\s+\$[A-Z_]*SECRET'
  'echo\s+\$[A-Z_]*PASSWORD'
  'curl.*\.env'
)

for pattern in "${forbidden_patterns[@]}"; do
  if echo "$command" | grep -qE "$pattern"; then
    echo "BLOCKED by block-secrets.sh: command matches forbidden pattern '$pattern'" >&2
    echo "If you need to read .env values, do it manually outside the agent session." >&2
    exit 1
  fi
done

exit 0
