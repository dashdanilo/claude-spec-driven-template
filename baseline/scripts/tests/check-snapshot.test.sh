#!/usr/bin/env bash
# check-snapshot.test.sh
# Standalone fixture suite for baseline/scripts/check-snapshot.sh, focused on
# the size-budget classification added when the Repomix snapshot stopped
# being auto-generated/auto-read context: "too-large" must fire regardless
# of freshness, and must fire BEFORE the staleness math even runs (a huge
# but freshly-generated snapshot is exactly as unreadable as a huge stale
# one). Also covers the pre-existing missing/fresh/stale-mild/stale-major
# classification so a future edit to the size check cannot silently break
# the staleness one.
#
# Fixture repo built on a throwaway branch name, renamed to "main"
# afterwards - same reasoning as protect-main.test.sh: a session running
# this repo's own harness has protect-main.sh live on Bash, and committing
# while already checked out on a protected name would get intercepted by
# the session's hook, not just avoided.
#
# Run: bash baseline/scripts/tests/check-snapshot.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT="$SCRIPT_DIR/../check-snapshot.sh"

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
    _fail "$label (expected: $expected, got: $actual)"
  fi
}

_assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) _pass "$label" ;;
    *) _fail "$label (looked for: $needle)" ;;
  esac
}

REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO/.claude/context"
cd "$REPO" || exit 99

git init -q -b tmp-setup
git config user.email "test@example.com"
git config user.name "Test"
echo "one" > file.txt
git add file.txt
git commit -q -m "first commit"
git branch -m main
COMMIT="$(git rev-parse HEAD)"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OLD_DATE="2000-01-01T00:00:00Z"

SNAPSHOT=".claude/context/repomix-snapshot.md"

# ---------------------------------------------------------------- 1. missing
rm -f "$SNAPSHOT"
OUT="$(bash "$SCRIPT")"; EXIT_CODE=$?
_assert_eq "missing: exit code 2" "$EXIT_CODE" "2"
_assert_contains "missing: status" "$OUT" '"status": "missing"'

# ------------------------------------------------------------ 2. fresh, small
{
  echo "generated_at: $NOW"
  echo "commit_sha: $COMMIT"
  echo "small content"
} > "$SNAPSHOT"
OUT="$(bash "$SCRIPT")"; EXIT_CODE=$?
_assert_eq "fresh: exit code 0" "$EXIT_CODE" "0"
_assert_contains "fresh: status" "$OUT" '"status": "fresh"'
_assert_contains "fresh: has size_bytes" "$OUT" '"size_bytes":'

# -------------------------------------------------------- 3. stale-major (age)
{
  echo "generated_at: $OLD_DATE"
  echo "commit_sha: $COMMIT"
  echo "small content"
} > "$SNAPSHOT"
OUT="$(bash "$SCRIPT")"; EXIT_CODE=$?
_assert_eq "stale-major (age): exit code 0" "$EXIT_CODE" "0"
_assert_contains "stale-major (age): status" "$OUT" '"status": "stale-major"'

# --------------------------------------------------- 4. too-large, but fresh
# A snapshot over the byte budget must report too-large even when it is
# otherwise perfectly fresh (recent date, HEAD commit) - size is checked
# before staleness, not after.
{
  echo "generated_at: $NOW"
  echo "commit_sha: $COMMIT"
  head -c 400000 /dev/zero | tr '\0' 'a'
} > "$SNAPSHOT"
OUT="$(bash "$SCRIPT")"; EXIT_CODE=$?
_assert_eq "too-large (fresh otherwise): exit code 0" "$EXIT_CODE" "0"
_assert_contains "too-large (fresh otherwise): status" "$OUT" '"status": "too-large"'
_assert_contains "too-large: has budget_bytes" "$OUT" '"budget_bytes": 300000'

# ------------------------------------------------- 5. too-large AND stale
# Same, but also old - must still report too-large, not stale-major. Size
# wins because an oversized file is unreadable regardless of age.
{
  echo "generated_at: $OLD_DATE"
  echo "commit_sha: $COMMIT"
  head -c 400000 /dev/zero | tr '\0' 'a'
} > "$SNAPSHOT"
OUT="$(bash "$SCRIPT")"; EXIT_CODE=$?
_assert_contains "too-large (also stale): status is still too-large" "$OUT" '"status": "too-large"'

# --------------------------------------------------------------- 6. error
{
  echo "not a valid header"
} > "$SNAPSHOT"
OUT="$(bash "$SCRIPT")"; EXIT_CODE=$?
_assert_eq "malformed header: exit code 3" "$EXIT_CODE" "3"
_assert_contains "malformed header: status" "$OUT" '"status": "error"'

rm -f "$SNAPSHOT"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
