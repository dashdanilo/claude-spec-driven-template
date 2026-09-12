#!/usr/bin/env bash
# protect-critical.sh
# PreToolUse hook for Edit and Write. Blocks modifications to files that are
# either sensitive (env, secrets) or would cause silent damage if edited without
# explicit approval (approved migrations, package-lock files, generated code).
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher "Edit|Write".
#
# Rationale: agents can inadvertently modify committed lockfiles, applied migrations,
# or generated code, causing hard-to-debug drift. A cheap hook prevents it.

set -euo pipefail

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the file_path with python3, falling back to `python` (some Windows
# shells only have `python` on PATH, where `python3` is missing or a broken
# alias). If neither is available, this guard cannot read the payload at all
# — warn loudly on stderr and let the edit through rather than blocking every
# single Edit/Write call on this machine, which is the failure that gets a
# guard disabled outright instead of fixed.
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: protect-critical.sh: no python3 or python on PATH — cannot read the tool payload, so this guard is DISABLED for this call. Install Python to restore it." >&2
  exit 0
fi

# Extract the file_path from JSON (Edit and Write both have file_path in tool_input)
file_path=$(printf '%s' "$input" | "$PYTHON_BIN" -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('file_path') or ti.get('file_path') or '')" 2>/dev/null || echo "")

if [[ -z "$file_path" ]]; then
  exit 0
fi

# .env.example / .env.test.example / etc are templates whose entire purpose is
# to hold NO secret — that is what makes them safe to commit. They are exempted
# by FILENAME (must end in the literal ".example"), matched and let through
# before the critical_patterns loop below ever sees them, so the '\.env\..*'
# pattern a few lines down does not treat a template the same as a real env
# file. This hook only pattern-matches the path; it never reads file content,
# so it cannot tell a genuine template from a secret pasted into a file that
# happens to be named "*.example" — renaming a real secrets file to
# ".env.production.example" would sail through this exemption exactly like a
# legitimate template does. That risk is accepted deliberately: catching it
# would require content scanning, which is a different guard's job, not this
# one's.
if echo "$file_path" | grep -qE '\.example$'; then
  exit 0
fi

# Critical paths that should not be edited without explicit human approval
critical_patterns=(
  '\.env$'
  '\.env\..*'
  '/secrets/'
  'pnpm-lock\.yaml$'
  'package-lock\.json$'
  'yarn\.lock$'
  'Cargo\.lock$'
  'poetry\.lock$'
  'Pipfile\.lock$'
  'go\.sum$'
  '/migrations/.*_applied\.'
  '/db/migrations/.*_committed\.'
  '\.generated\.'
  '\.g\.dart$'
  '/dist/'
  '/build/'
  '/\.next/'
  '/node_modules/'
)

for pattern in "${critical_patterns[@]}"; do
  if echo "$file_path" | grep -qE "$pattern"; then
    echo "BLOCKED by protect-critical.sh: '$file_path' matches critical pattern '$pattern'" >&2
    echo "" >&2
    echo "Critical files include: env files, secrets, lockfiles, applied migrations, generated code." >&2
    echo "" >&2
    echo "If you truly need to modify this file:" >&2
    echo "  1. Confirm with the user explicitly (not just infer intent)" >&2
    echo "  2. If it's a lockfile, run the package manager instead (pnpm install, cargo update, etc)" >&2
    echo "  3. If it's a migration, create a new migration instead of editing" >&2
    echo "  4. If it's generated code, regenerate from source" >&2
    exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
  fi
done

# The governance machinery itself: the hooks, the config that registers them,
# and the rules an agent is supposed to be following. None of this is covered
# above, which means an agent can currently edit baseline/hooks/protect-main.sh
# or .claude/settings.json and quietly disarm the very guard watching it — the
# supervised does not turn off the supervisor. These are matched separately
# from critical_patterns because the fix is never "regenerate" or "use the
# package manager": it is a change for the human operator to make outside the
# agent session, deliberately, with their own judgment about the tradeoff —
# not something this hook can hand back a self-service recipe for.
#
# Scoped narrowly on purpose: baseline/hooks/*.sh and .claude/hooks/*.sh (not
# every .sh in the repo — a build script under scripts/ is untouched), and
# .claude/settings*.json anchored to the .claude/ directory (not any
# settings.json anywhere, e.g. a project's own config/settings.json), and
# .claude/rules/** / baseline/rules/** (not agents/ or skills/, which this
# task did not ask to lock down).
governance_patterns=(
  '(^|/)baseline/hooks/.*\.sh$'
  '(^|/)\.claude/hooks/.*\.sh$'
  '(^|/)\.claude/settings\.json$'
  '(^|/)\.claude/settings\.local\.json$'
  '(^|/)\.claude/rules/'
  '(^|/)baseline/rules/'
)

for pattern in "${governance_patterns[@]}"; do
  if echo "$file_path" | grep -qE "$pattern"; then
    echo "BLOCKED by protect-critical.sh: '$file_path' matches governance pattern '$pattern'" >&2
    echo "" >&2
    echo "This is part of the harness's own governance surface: a hook, the config" >&2
    echo "that registers hooks, or a rule agents are held to. An agent editing it" >&2
    echo "would let the supervised session disarm its own supervisor." >&2
    echo "" >&2
    echo "This change is for the human operator to make outside this agent session," >&2
    echo "not something to route around from inside it. If it genuinely needs to" >&2
    echo "change, stop and ask the human to make the edit themselves." >&2
    exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
  fi
done

exit 0
