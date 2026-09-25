#!/usr/bin/env bash
# protect-critical.test.sh
# Standalone fixture suite for baseline/hooks/protect-critical.sh. Feeds the
# hook synthetic JSON-on-stdin payloads shaped like Claude Code's Edit/Write
# PreToolUse calls (`{"tool_input":{"file_path":"..."}}`) and asserts the exit
# code (2 = blocked, 0 = passes).
#
# This suite covers only what protect-critical.sh still owns after the
# governance split: files that are sensitive (env, secrets) or would cause
# silent damage if edited without explicit approval (lockfiles, applied
# migrations, generated code), plus the `.example` template exemption and the
# payload-without-file_path no-op. None of these cases need a real git repo.
#
# The governance cases (the harness's own hooks, hook config, and rules —
# .claude/settings.json, baseline/hooks/*.sh, baseline/rules/**, etc.) moved
# to protect-harness.test.sh alongside the hook that now owns them.
#
# Run: bash baseline/hooks/tests/protect-critical.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../protect-critical.sh"

# Resolve python3, falling back to python, the same way the hook itself does
# (some Windows shells only have `python` on PATH) rather than hardcoding
# python3 and failing this suite on exactly the machines the hook's own
# fallback was written for.
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "protect-critical.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1]}}))' "$1"
}

_make_payload_no_file_path() {
  "$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Edit", "tool_input": {}}))'
}

# $1 = name, $2 = cwd, $3 = file_path, $4 = expected exit code,
# $5 = optional PATH override (defaults to the ambient PATH)
_run_case() {
  local name="$1" cwd="$2" file_path="$3" expected="$4" path_override="${5:-}"

  local payload
  payload="$(_make_payload "$file_path")"

  local actual
  actual=$(
    cd "$cwd" || exit 99
    [[ -n "$path_override" ]] && export PATH="$path_override"
    printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
    echo $?
  )

  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (exit $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- Bash coverage: the same critical_patterns, reached through a Bash
# write instead of Edit/Write.

_make_bash_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$2"
}

# $1 = name, $2 = cwd (also the payload cwd), $3 = command, $4 = expected
# exit code.
_run_bash_case() {
  local name="$1" cwd="$2" command_str="$3" expected="$4"

  local payload
  payload="$(_make_bash_payload "$command_str" "$cwd")"

  local actual
  actual=$(
    cd "$cwd" || exit 99
    printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
    echo $?
  )

  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (exit $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- pre-existing behavior: must not regress ---

_run_case "1: .env is blocked" \
  "$TMPDIR_ROOT" ".env" 2

_run_case "2: .env.local is blocked" \
  "$TMPDIR_ROOT" ".env.local" 2

_run_case "3: pnpm-lock.yaml is blocked" \
  "$TMPDIR_ROOT" "pnpm-lock.yaml" 2

_run_case "4: package-lock.json is blocked" \
  "$TMPDIR_ROOT" "package-lock.json" 2

_run_case "5: applied migration is blocked" \
  "$TMPDIR_ROOT" "db/migrations/2026_applied.sql" 2

_run_case "6: generated code is blocked" \
  "$TMPDIR_ROOT" "src/schema.generated.ts" 2

# --- change 1: .example templates are the fix for the original false positive ---

_run_case "7: .env.example passes (regression check)" \
  "$TMPDIR_ROOT" ".env.example" 0

_run_case "8: .env.test.example passes (regression check)" \
  "$TMPDIR_ROOT" ".env.test.example" 0

_run_case "9: nested .env.example passes" \
  "$TMPDIR_ROOT" "apps/api/.env.example" 0

# --- payload without file_path must not block ---

actual_missing=$(cd "$TMPDIR_ROOT" && printf '%s' "$(_make_payload_no_file_path)" | bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ "$actual_missing" == "0" ]]; then
  echo "PASS: 10: payload missing file_path exits 0 (exit $actual_missing)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 10: payload missing file_path exits 0 (expected 0, got $actual_missing)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# ===================================================================
# Bash coverage: the exact same critical_patterns, reached through a write
# performed via Bash (redirect, sed -i, tee, cp, mv, python3 -c, a python
# heredoc) instead of Edit/Write. Before this hook learned about Bash, every
# one of these sailed straight through it.
# ===================================================================

_run_bash_case "11: Bash redirect into .env is blocked" \
  "$TMPDIR_ROOT" "echo hi > .env" 2

_run_bash_case "12: Bash sed -i into pnpm-lock.yaml is blocked" \
  "$TMPDIR_ROOT" "sed -i s/a/b/ pnpm-lock.yaml" 2

_run_bash_case "13: Bash tee into a secrets/ file is blocked" \
  "$TMPDIR_ROOT" "echo hi | tee secrets/token.txt" 2

_run_bash_case "14: Bash cp into package-lock.json is blocked" \
  "$TMPDIR_ROOT" "cp foo.json package-lock.json" 2

_run_bash_case "15: Bash mv into an applied migration is blocked" \
  "$TMPDIR_ROOT" "mv foo.sql db/migrations/2026_applied.sql" 2

# --- the mandatory case: this is the one that motivated pulling the Bash
# write parser out into its own shared file. A `python3 -c "...open(path,
# 'w')..."` (or the equivalent heredoc) writing into a critical file used to
# sail straight through this hook. ---

_run_bash_case "16: [MANDATORY] python3 -c writing to .env is blocked" \
  "$TMPDIR_ROOT" "python3 -c \"open('.env','w').write('x')\"" 2

_run_bash_case "17: [MANDATORY] python3 heredoc writing to .env is blocked" \
  "$TMPDIR_ROOT" "python3 - <<'PY'
open('.env', 'w').write('x')
PY" 2

# --- the other mandatory case: the SAME shapes, targeting an ordinary
# repo-owned file instead of a critical one, must still pass ---

_run_bash_case "18: [MANDATORY] python3 -c writing to a common file passes" \
  "$TMPDIR_ROOT" "python3 -c \"open('README.md','w').write('x')\"" 0

_run_bash_case "19: python3 heredoc writing to a common file passes" \
  "$TMPDIR_ROOT" "python3 - <<'PY'
open('README.md', 'w').write('x')
PY" 0

# --- the .example exemption applies through Bash too ---

_run_bash_case "20: Bash redirect into .env.example passes (exemption)" \
  "$TMPDIR_ROOT" "echo hi > .env.example" 0

# --- a target this parser cannot resolve to a literal path must be SKIPPED,
# never blocked — a guard that blocks on "could not tell" gets disabled
# outright instead of fixed ---

_run_bash_case "21: Bash redirect target built from a shell variable is not blocked (unresolvable, skipped)" \
  "$TMPDIR_ROOT" 'echo hi > "$SOME_UNSET_VAR"' 0

# --- a command that writes to MULTIPLE targets: one critical, one ordinary
# -> blocked, because one match is enough ---

_run_bash_case "22: Bash command with two targets, one critical one ordinary, is blocked" \
  "$TMPDIR_ROOT" "cp foo.txt ordinary.txt && cp foo.txt pnpm-lock.yaml" 2

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
