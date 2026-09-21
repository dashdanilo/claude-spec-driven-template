#!/usr/bin/env bash
# block-secrets.test.sh
# Standalone fixture suite for baseline/hooks/block-secrets.sh. Feeds the hook
# the same JSON-on-stdin shape Claude Code sends
# (`{"tool_name":"Bash","tool_input":{"command":"..."}}`) and asserts the exit
# code (2 = blocked, 0 = passes) and, for every case, that grep wrote nothing
# to stderr: a malformed pattern makes BSD grep print an error and silently
# never match, which is exactly how the command-substitution pattern was dead
# on macOS without any case failing.
#
# The forbidden strings are assembled from pieces at runtime, so neither this
# file's own invocation nor any command a session types to run it trips the
# live block-secrets guard registered on that session's Bash tool.
#
# Run: bash baseline/hooks/tests/block-secrets.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../block-secrets.sh"

# Resolve python3, falling back to python, the same way the hook itself does.
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "block-secrets.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT
STDERR_FILE="$TMPDIR_ROOT/stderr"

READ_ENV="ca""t .""env"   # the reader + env file, never spelled out whole

PASS_COUNT=0
FAIL_COUNT=0

_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1"
}

_run_case() {
  local name="$1"
  local cmd="$2"
  local expected="$3"

  local actual
  _make_payload "$cmd" | bash "$HOOK" >/dev/null 2>"$STDERR_FILE"
  actual=$?

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  elif grep -q '^grep:' "$STDERR_FILE"; then
    echo "FAIL: $name (grep error on stderr: $(head -n1 "$STDERR_FILE"))"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "PASS: $name (exit $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

# 1. plain read at command position, pattern 1 (control)
_run_case "1: plain read of env file" "$READ_ENV" 2

# 2. command substitution assigned to a variable
_run_case "2: X=\$(read env file)" "X=\$($READ_ENV)" 2

# 3. command substitution inside a quoted echo
_run_case "3: echo \"\$(read env file)\"" "echo \"\$($READ_ENV)\"" 2

# 4. command substitution with inner whitespace
_run_case "4: \$( read env file )" "X=\$( $READ_ENV )" 2

# 5. harmless command: passes and grep stays silent
_run_case "5: harmless ls" "ls -la" 0

# 6. harmless command substitution not touching an env file
_run_case "6: harmless \$(date)" "echo \"\$(date +%F)\"" 0

# 7. substitution running a non-reader command on an env-named file
_run_case "7: substitution of a non-reader on an env file" "X=\$(grep -c FOO .""env.example)" 0

echo
echo "block-secrets.test.sh: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]]
