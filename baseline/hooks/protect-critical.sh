#!/usr/bin/env bash
# protect-critical.sh
# PreToolUse hook for Edit/Write AND for Bash. Blocks modifications to files
# that are either sensitive (env, secrets) or would cause silent damage if
# edited without explicit approval (approved migrations, package-lock files,
# generated code).
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Edit|Write" and with matcher "Bash".
#
# Rationale: agents can inadvertently modify committed lockfiles, applied migrations,
# or generated code, causing hard-to-debug drift. A cheap hook prevents it.
#
# This hook is deliberately excluded from install-harness.sh's portable set:
# it knows about lockfiles and applied migrations, which belong to a
# repository's own settings, not to something linked over it. The harness's
# OWN governance surface (hooks, hook config, rules) is a separate concern —
# see protect-harness.sh, which install-harness.sh registers everywhere for
# exactly the opposite reason: that guard has to hold in every adopting
# project, not just this one.
#
# Bash coverage, added after the fact: this hook originally only looked at
# Edit/Write payloads, so a critical file edited through Bash — a redirect,
# `sed -i`, `tee`, `cp`, `mv`, or a `python3 -c`/heredoc `open(..., "w")`
# call — was invisible to it. Detection is shared with log-edit.sh and
# protect-harness.sh: lib/bash-write-targets.py, next to this hook, is the
# ONE implementation of "what does this Bash command write to". See that
# file's header for the lexer's exact rules and its declared gaps. A target
# it cannot resolve to a literal path is skipped here, not blocked — a guard
# that blocks on "I could not tell" gets disabled outright instead of fixed,
# and this hook has no log to record the gap in (unlike log-edit.sh, whose
# whole job is to record it).
#
# Same critical_patterns, same .example exemption, whichever tool performed
# the write — the verdict is about the PATH, not about which tool touched
# it. A command can write to MULTIPLE targets (e.g. `cp a b && mv c d`);
# every one of them is checked, and blocking stops at the first match.

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

# $1 = file_path, $2 = extra context appended to the block message (may be
# empty). Exits 2 (blocks) on the first matching pattern; returns normally
# (falls through, caller continues) when nothing matches.
_check_path() {
  local file_path="$1" context="${2:-}" pattern
  [[ -n "$file_path" ]] || return 0

  # .env.example / .env.test.example / etc are templates whose entire purpose
  # is to hold NO secret — that is what makes them safe to commit. Matched and
  # let through before the critical_patterns loop below ever sees them, so
  # the '\.env\..*' pattern does not treat a template the same as a real env
  # file. This hook only pattern-matches the path; it never reads file
  # content, so it cannot tell a genuine template from a secret pasted into a
  # file that happens to be named "*.example" — that risk is accepted
  # deliberately: catching it would require content scanning, a different
  # guard's job, not this one's.
  if echo "$file_path" | grep -qE '\.example$'; then
    return 0
  fi

  for pattern in "${critical_patterns[@]}"; do
    if echo "$file_path" | grep -qE "$pattern"; then
      echo "BLOCKED by protect-critical.sh: '$file_path' matches critical pattern '$pattern'$context" >&2
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
  return 0
}

# NUL-separated, not line-separated: a Bash command handed to this hook can
# itself contain embedded newlines (a multi-line command, a heredoc), so a
# newline is not a safe field separator here. NUL bytes cannot live in a bash
# VARIABLE at all (command substitution strips them), so these are read
# directly off the python process's stdout via process substitution instead
# of being captured into one variable first.
tool_name=""; file_path=""; command=""
{
  IFS= read -r -d '' tool_name || true
  IFS= read -r -d '' file_path || true
  IFS= read -r -d '' command || true
} < <(printf '%s' "$input" | "$PYTHON_BIN" -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
ti = d.get('tool_input') or {}
for v in (d.get('tool_name') or '', d.get('file_path') or ti.get('file_path') or '', ti.get('command') or ''):
    sys.stdout.write(v)
    sys.stdout.write(chr(0))
" 2>/dev/null)

if [[ "$tool_name" == "Bash" ]]; then
  [[ -n "$command" ]] || exit 0
  LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib/bash-write-targets.py"
  if [[ ! -f "$LIB" ]]; then
    # Same posture as the missing-python case above: warn loudly and let
    # this call through, rather than let a missing file turn into a SILENT
    # no-op. "$PYTHON_BIN $LIB 2>/dev/null || echo ''" below would otherwise
    # swallow the failure completely -- no warning, no exit code that says
    # anything went wrong -- and the Bash branch of this guard would just
    # stop protecting anything, with nothing in the transcript to explain
    # why. Edit/Write is unaffected either way: this only disables the
    # BASH branch for this one call.
    echo "WARNING: protect-critical.sh: shared parser lib/bash-write-targets.py not found next to this hook -- the Bash write-detection branch is DISABLED for this call. Edit/Write is still protected." >&2
    exit 0
  fi
  targets=$(printf '%s' "$input" | "$PYTHON_BIN" "$LIB" 2>/dev/null || echo "")
  while IFS=$'\t' read -r kind target; do
    [[ -n "$kind" ]] || continue
    [[ "$target" != "?" ]] || continue  # unresolvable: skip, never block on "could not tell"
    _check_path "$target" " (found via Bash: $kind)"
  done <<< "$targets"
  exit 0
fi

_check_path "$file_path"
exit 0
