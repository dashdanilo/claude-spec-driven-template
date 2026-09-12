#!/usr/bin/env bash
# harness-report.test.sh
# Standalone fixture suite for baseline/scripts/harness-report.sh's instrument-
# epoch and approximate-metric handling. Builds a throwaway project directory
# in a mktemp dir with a synthetic .claude/agent-log.txt and a synthetic
# .claude/docs/harness/harness-baseline.md carrying an
# `<!-- instrument-epoch: YYYY-MM-DD --> ` marker (NEVER the real logs of this
# checkout), runs the script with `--json`, and asserts on the parsed numbers —
# not just the exit code, since this script always exits 0.
#
# Covers three behaviours added alongside log-agent.sh's dedup fix:
#   - a line timestamped before the instrument epoch is excluded from every
#     headline dispatch number and counted separately instead
#   - an approx=1 line's tokens are excluded from the headline "reliable"
#     total and reported on their own, so a guessed metric never reads as
#     an exact one
#   - a dup=1 line (no tokens= field at all, see log-agent.sh) contributes
#     nothing to any total — proving the fix on the write side actually pays
#     off on the read side
#
# Run: bash baseline/scripts/tests/harness-report.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT="$SCRIPT_DIR/../harness-report.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "harness-report.test.sh: no python3 or python on PATH, cannot parse output" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO/.claude/docs/harness"

cat > "$REPO/.claude/docs/harness/harness-baseline.md" <<'EOF'
## 2026-09-09 — the instrument was broken

<!-- instrument-epoch: 2026-09-09 -->
EOF

cat > "$REPO/.claude/agent-log.txt" <<'EOF'
[2026-09-05 10:00:00] subagent_stop  agent=?  session=aaaaaaaa
[2026-09-05 10:00:01] subagent_stop  agent=?  session=aaaaaaaa
[2026-09-10 11:00:00] subagent_stop  agent=implementer  tokens=1000  cached=200  dur=5s  tools=3  session=bbbbbbbb
[2026-09-10 11:00:05] subagent_stop  agent=tester  tokens=2000  cached=100  dur=3s  tools=2  session=bbbbbbbb
[2026-09-10 11:00:10] subagent_stop  agent=implementer  tokens=500  dur=2s  approx=1  session=bbbbbbbb
[2026-09-10 11:00:11] subagent_stop  agent=implementer  approx=1  dup=1  session=bbbbbbbb
[2026-09-10 11:00:12] subagent_stop  agent=implementer  approx=1  dup=1  session=bbbbbbbb
EOF

PASS_COUNT=0
FAIL_COUNT=0

_assert_field() {
  # $1 = field name in the JSON output, $2 = expected value (as Python literal)
  local field="$1" expected="$2" actual
  actual=$("$PYTHON_BIN" -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d[sys.argv[2]])
' "$OUT_JSON" "$field")
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $field == $expected"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $field — expected $expected, got $actual"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

OUT_JSON="$TMPDIR_ROOT/out.json"
( cd "$REPO" && bash "$SCRIPT" --json > "$OUT_JSON" )

_assert_field "instrument_epoch" "2026-09-09"
_assert_field "pre_epoch_lines_excluded" "2"
_assert_field "dispatches" "5"
_assert_field "subagent_tokens" "3000"
_assert_field "subagent_cache_reads" "300"
_assert_field "approximate_attribution" "3"
_assert_field "approximate_attribution_tokens" "500"
_assert_field "dup_dispatches" "2"
_assert_field "unattributed_dispatches" "0"

# The plain-text report must state the exclusion reason rather than silently
# dropping the pre-epoch lines or the approx=1 tokens.
OUT_TXT="$TMPDIR_ROOT/out.txt"
( cd "$REPO" && bash "$SCRIPT" > "$OUT_TXT" )

_assert_contains() {
  local label="$1" needle="$2"
  if grep -qF "$needle" "$OUT_TXT"; then
    echo "PASS: text report mentions $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: text report missing $label (looked for: $needle)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

_assert_contains "pre-epoch exclusion with reason" "before 2026-09-09 instrument fix"
_assert_contains "reliable token total" "subagent tokens (reliable)         3,000"
_assert_contains "approximate share out of the total" "500 tokens — out of the total"
_assert_contains "dup collision note" "no metric at all (dup=1"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
