#!/usr/bin/env bash
# block-secrets.sh
# PreToolUse hook for Bash. Blocks commands that try to read sensitive files
# or print secret-named environment variables.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher "Bash".

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the command with python3, falling back to `python` (some Windows
# shells only have `python` on PATH, where `python3` is missing or a broken
# alias). If neither is available, this guard cannot read the payload at all
# — warn loudly on stderr and let the command through rather than blocking
# every single Bash call on this machine, which is the failure that gets a
# guard disabled outright instead of fixed (see protect-main.sh's own note on
# false positives).
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: block-secrets.sh: no python3 or python on PATH — cannot read the tool payload, so this guard is DISABLED for this call. Install Python to restore it." >&2
  exit 0
fi

# Extract the command from the JSON (tool_input.command for the Bash tool)
command=$(printf '%s' "$input" | "$PYTHON_BIN" -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('command') or ti.get('command') or '')" 2>/dev/null || echo "")

# Forbidden patterns
# Anchored at a COMMAND POSITION - start of a line, or after ; && || | - so the
# guard fires on someone RUNNING the command, not on someone writing about it.
# The unanchored version matched any prose containing the words, which made it
# block a pull-request body that merely documented what the guard blocks.
CMD='(^|[;&|])[[:space:]]*'
forbidden_patterns=(
  "${CMD}(cat|less|more|head|tail|bat|strings)[[:space:]]+[^|;&]*\.env"
  "${CMD}(printenv|env)[[:space:]]*$"
  "${CMD}(curl|wget)[^|;&]*\.env"
  "${CMD}"'echo[[:space:]]+\$[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD)'
  '\\$\\([[:space:]]*cat[[:space:]]+[^)]*\\.env'
)

for pattern in "${forbidden_patterns[@]}"; do
  if echo "$command" | grep -qE "$pattern"; then
    echo "BLOCKED by block-secrets.sh: command matches forbidden pattern '$pattern'" >&2
    echo "If you need to read .env values, do it manually outside the agent session." >&2
    exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
  fi
done

exit 0
