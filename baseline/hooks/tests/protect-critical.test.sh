#!/usr/bin/env bash
# protect-critical.test.sh
# Standalone fixture suite for baseline/hooks/protect-critical.sh. Feeds the
# hook synthetic JSON-on-stdin payloads shaped like Claude Code's Edit/Write
# PreToolUse calls (`{"tool_input":{"file_path":"..."}}`) and asserts the exit
# code (2 = blocked, 0 = passes). No git fixtures needed — this hook only
# pattern-matches a file_path string, so no throwaway repo is built and none
# of the protect-main.sh worktree caveats in
# .claude/agent-memory/implementer/feedback_hook-testing-in-harness-worktrees.md
# apply here.
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

PASS_COUNT=0
FAIL_COUNT=0

_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1]}}))' "$1"
}

_make_payload_no_file_path() {
  "$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Edit", "tool_input": {}}))'
}

_run_case() {
  local name="$1"
  local file_path="$2"
  local expected="$3"

  local payload
  payload="$(_make_payload "$file_path")"

  local actual
  actual=$(printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1; echo $?)

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
  ".env" 2

_run_case "2: .env.local is blocked" \
  ".env.local" 2

_run_case "3: pnpm-lock.yaml is blocked" \
  "pnpm-lock.yaml" 2

_run_case "4: package-lock.json is blocked" \
  "package-lock.json" 2

_run_case "5: applied migration is blocked" \
  "db/migrations/2026_applied.sql" 2

_run_case "6: generated code is blocked" \
  "src/schema.generated.ts" 2

# --- change 1: .example templates are the fix for today's false positive ---

_run_case "7: .env.example passes (regression check)" \
  ".env.example" 0

_run_case "8: .env.test.example passes (regression check)" \
  ".env.test.example" 0

_run_case "9: nested .env.example passes" \
  "apps/api/.env.example" 0

# --- change 2: the governance surface itself must not be self-disarmable ---

_run_case "10: baseline/hooks/protect-main.sh is blocked" \
  "baseline/hooks/protect-main.sh" 2

_run_case "11: .claude/hooks/protect-critical.sh is blocked" \
  ".claude/hooks/protect-critical.sh" 2

_run_case "12: .claude/settings.json is blocked" \
  ".claude/settings.json" 2

_run_case "13: .claude/settings.local.json is blocked" \
  ".claude/settings.local.json" 2

_run_case "14: a rule under .claude/rules/ is blocked" \
  ".claude/rules/harness/delegation.md" 2

_run_case "15: a rule under baseline/rules/ is blocked" \
  "baseline/rules/git-workflow.md" 2

# --- change 2 must not be wider than intended: similarly-shaped, legit paths ---

_run_case "16: settings.json outside .claude/ is NOT blocked" \
  "config/settings.json" 0

_run_case "17: a .sh under scripts/ that is not a hook is NOT blocked" \
  "scripts/build.sh" 0

# --- payload without file_path must not block ---

actual_missing=$(printf '%s' "$(_make_payload_no_file_path)" | bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ "$actual_missing" == "0" ]]; then
  echo "PASS: 18: payload missing file_path exits 0 (exit $actual_missing)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 18: payload missing file_path exits 0 (expected 0, got $actual_missing)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
