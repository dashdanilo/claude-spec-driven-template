#!/usr/bin/env bash
# verify-gate.test.sh
# Standalone fixture suite for baseline/scripts/verify-gate.py: a report
# either shows its work (a `## Commands` section with real exit codes, a
# `## Claims` section where every claim carries evidence) or the gate
# refuses it. Covers the documented contract at the top of verify-gate.py:
# pass, missing evidence, a non-zero exit code, a missing section, an empty
# report, a malformed exit line, and the --json shape.
#
# Writes fixture reports into a mktemp dir (NEVER this checkout's own
# files) and asserts on verify-gate.py's stdout text and exit code.
#
# Run: bash baseline/scripts/tests/verify-gate.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT="$SCRIPT_DIR/../verify-gate.py"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "verify-gate.test.sh: no python3 or python on PATH, cannot run the gate" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

_assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    _pass "$label"
  else
    _fail "$label (expected [$expected], got [$actual])"
  fi
}

_assert_contains() {
  local label="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file"; then
    _pass "$label"
  else
    _fail "$label (looked for: $needle)"
    echo "----- $file"; cat "$file"; echo "-----"
  fi
}

_run() {
  # Runs the gate on $1, writes stdout to $2, and sets EXIT_CODE.
  "$PYTHON_BIN" "$SCRIPT" "$1" > "$2" 2>&1
  EXIT_CODE=$?
}

# ---------------------------------------------------------------- 1. pass
# A well-formed report: two green commands, two claims each with valid
# evidence (a file:line citation, and a reference to a listed command).
REPORT="$TMPDIR_ROOT/pass.md"
cat > "$REPORT" <<'EOF'
# Verification report

## Commands

- `yarn test` -> exit 0
- `yarn typecheck` -> exit 0

## Claims

- phone normalizes to E.164 before submit (evidence: src/lead-form.ts:88)
- the test suite is green (evidence: `yarn test`)
EOF
OUT="$TMPDIR_ROOT/out-pass.txt"
_run "$REPORT" "$OUT"
_assert_eq "pass: exit 0" "$EXIT_CODE" "0"
_assert_contains "pass: reports 2 commands, 2 claims" "$OUT" "OK: 2 commands, 2 claims"

# ---------------------------------------------------------- 2. missing evidence
# A claim with no "(evidence: ...)" at all must fail, and be named.
REPORT="$TMPDIR_ROOT/missing-evidence.md"
cat > "$REPORT" <<'EOF'
## Commands

- `yarn test` -> exit 0

## Claims

- phone normalizes fine
EOF
OUT="$TMPDIR_ROOT/out-missing-evidence.txt"
_run "$REPORT" "$OUT"
_assert_eq "missing evidence: exit 1" "$EXIT_CODE" "1"
_assert_contains "missing evidence: claim without evidence is named" "$OUT" "phone normalizes fine"
_assert_contains "missing evidence: zero valid claims is flagged" "$OUT" "## Claims has no valid claims recorded"

# ------------------------------------------------------ 3. non-zero exit code
# A command that failed fails the gate, and the report names it, even
# though the report otherwise "looks" complete.
REPORT="$TMPDIR_ROOT/nonzero.md"
cat > "$REPORT" <<'EOF'
## Commands

- `yarn test` -> exit 1

## Claims

- the suite is green (evidence: `yarn test`)
EOF
OUT="$TMPDIR_ROOT/out-nonzero.txt"
_run "$REPORT" "$OUT"
_assert_eq "non-zero exit: exit 1" "$EXIT_CODE" "1"
_assert_contains "non-zero exit: the failing command is named" "$OUT" "command exited non-zero (1): \`yarn test\`"

# -------------------------------------------------------- 4. missing section
# ## Claims never shows up at all.
REPORT="$TMPDIR_ROOT/missing-section.md"
cat > "$REPORT" <<'EOF'
## Commands

- `yarn test` -> exit 0
EOF
OUT="$TMPDIR_ROOT/out-missing-section.txt"
_run "$REPORT" "$OUT"
_assert_eq "missing section: exit 1" "$EXIT_CODE" "1"
_assert_contains "missing section: names the missing ## Claims section" "$OUT" "missing section: ## Claims"

# -------------------------------------------------------------- 5. empty report
REPORT="$TMPDIR_ROOT/empty.md"
: > "$REPORT"
OUT="$TMPDIR_ROOT/out-empty.txt"
_run "$REPORT" "$OUT"
_assert_eq "empty report: exit 1" "$EXIT_CODE" "1"
_assert_contains "empty report: names it as empty" "$OUT" "report is empty"

# ------------------------------------------------------- 6. malformed exit line
# A command bullet that does not match the documented format (exit code is
# not an integer) must fail, and be distinguished from a real non-zero exit.
REPORT="$TMPDIR_ROOT/malformed.md"
cat > "$REPORT" <<'EOF'
## Commands

- `yarn test` -> exit green

## Claims

- the suite is green (evidence: `yarn test`)
EOF
OUT="$TMPDIR_ROOT/out-malformed.txt"
_run "$REPORT" "$OUT"
_assert_eq "malformed exit line: exit 1" "$EXIT_CODE" "1"
_assert_contains "malformed exit line: named as malformed, not as a real exit code" \
  "$OUT" "malformed command line"

# ------------------------------------------------------------------ 7. --json
REPORT="$TMPDIR_ROOT/pass.md"
OUT="$TMPDIR_ROOT/out-json.txt"
"$PYTHON_BIN" "$SCRIPT" "$REPORT" --json > "$OUT" 2>&1
EXIT_CODE=$?
_assert_eq "--json: exit 0 on a passing report" "$EXIT_CODE" "0"
"$PYTHON_BIN" - "$OUT" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data == {"ok": True, "commands": 2, "claims": 2, "violations": []}, data
PY
if [[ $? -eq 0 ]]; then
  _pass "--json: shape matches {ok, commands, claims, violations} on a pass"
else
  _fail "--json: shape did not match on a pass"
fi

REPORT="$TMPDIR_ROOT/missing-evidence.md"
OUT="$TMPDIR_ROOT/out-json-fail.txt"
"$PYTHON_BIN" "$SCRIPT" "$REPORT" --json > "$OUT" 2>&1
EXIT_CODE=$?
_assert_eq "--json: exit 1 on a failing report" "$EXIT_CODE" "1"
"$PYTHON_BIN" - "$OUT" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["ok"] is False, data
assert isinstance(data["violations"], list) and len(data["violations"]) > 0, data
assert set(data.keys()) == {"ok", "commands", "claims", "violations"}, data
PY
if [[ $? -eq 0 ]]; then
  _pass "--json: shape matches on a fail, violations non-empty"
else
  _fail "--json: shape did not match on a fail"
fi

# --------------------------------------------------------------- 8. stdin
OUT="$TMPDIR_ROOT/out-stdin.txt"
"$PYTHON_BIN" "$SCRIPT" - < "$TMPDIR_ROOT/pass.md" > "$OUT" 2>&1
EXIT_CODE=$?
_assert_eq "stdin: exit 0 reading a passing report from -" "$EXIT_CODE" "0"
_assert_contains "stdin: same summary as reading the file" "$OUT" "OK: 2 commands, 2 claims"

# --------------------------------------------------------- 9. report not found
OUT="$TMPDIR_ROOT/out-notfound.txt"
_run "$TMPDIR_ROOT/does-not-exist.md" "$OUT"
_assert_eq "not found: exit 1" "$EXIT_CODE" "1"
_assert_contains "not found: names the missing path" "$OUT" "report not found:"

# ----------------------------------------------- 10. claim references unknown command
# Evidence that quotes a command never declared under ## Commands must fail
# even though the evidence LOOKS like the right shape.
REPORT="$TMPDIR_ROOT/unknown-ref.md"
cat > "$REPORT" <<'EOF'
## Commands

- `yarn test` -> exit 0

## Claims

- the build is green (evidence: `yarn build`)
EOF
OUT="$TMPDIR_ROOT/out-unknown-ref.txt"
_run "$REPORT" "$OUT"
_assert_eq "unknown command reference: exit 1" "$EXIT_CODE" "1"
_assert_contains "unknown command reference: named" "$OUT" "references a command not listed"

# ----------------------------------------------------------- 11. default path
# No argument at all resolves to .claude/verification/latest.md, relative
# to the current working directory.
WORKDIR="$TMPDIR_ROOT/workdir"
mkdir -p "$WORKDIR/.claude/verification"
cat > "$WORKDIR/.claude/verification/latest.md" <<'EOF'
## Commands

- `yarn test` -> exit 0

## Claims

- the suite is green (evidence: `yarn test`)
EOF
OUT="$TMPDIR_ROOT/out-default-path.txt"
(cd "$WORKDIR" && "$PYTHON_BIN" "$SCRIPT") > "$OUT" 2>&1
EXIT_CODE=$?
_assert_eq "default path: exit 0 reading .claude/verification/latest.md" "$EXIT_CODE" "0"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
