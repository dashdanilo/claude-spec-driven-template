#!/usr/bin/env bash
# check-snapshot-on-session.test.sh
# Standalone fixture suite for baseline/hooks/check-snapshot-on-session.sh.
# The hook used to warn on stale-major; it now warns only on too-large,
# because nothing auto-reads the snapshot anymore (it is a manual, opt-in
# export - see the refresh-snapshot skill) so its staleness is nobody's
# problem until a human opens it, at which point refreshing is one command
# away. Covers: no snapshot (silent), fresh small snapshot (silent),
# stale-major-by-age small snapshot (silent - the behavior this hook
# deliberately dropped), and a too-large snapshot (warns, names the byte
# counts, points at the repo map, never blocks).
#
# Fixture repo built on a throwaway branch name, renamed to "main"
# afterwards - same reasoning as protect-main.test.sh: a session running
# this repo's own harness has protect-main.sh live on Bash, and committing
# while already checked out on a protected name would get intercepted by
# the session's hook, not just avoided.
#
# Run: bash baseline/hooks/tests/check-snapshot-on-session.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK_SRC="$SCRIPT_DIR/../check-snapshot-on-session.sh"
CHECK_SRC="$SCRIPT_DIR/../../scripts/check-snapshot.sh"

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

_assert_empty() {
  local label="$1" actual="$2"
  if [[ -z "$actual" ]]; then
    _pass "$label"
  else
    _fail "$label (expected empty, got: $actual)"
  fi
}

_assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) _pass "$label" ;;
    *) _fail "$label (looked for: $needle)" ;;
  esac
}

# The hook expects the check script at .claude/scripts/check-snapshot.sh
# relative to cwd - build the fixture repo with that exact layout, mirroring
# what install.sh actually produces in a real adopting repo (check-snapshot.sh
# is a REPO_SCRIPT, copied in directly, not symlinked).
REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO/.claude/context" "$REPO/.claude/scripts" "$REPO/.claude/hooks"
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

cp "$CHECK_SRC" .claude/scripts/check-snapshot.sh
chmod +x .claude/scripts/check-snapshot.sh
cp "$HOOK_SRC" .claude/hooks/check-snapshot-on-session.sh
chmod +x .claude/hooks/check-snapshot-on-session.sh
HOOK=".claude/hooks/check-snapshot-on-session.sh"

SNAPSHOT=".claude/context/repomix-snapshot.md"

# ------------------------------------------------------------- 1. no snapshot
rm -f "$SNAPSHOT"
OUT="$(bash "$HOOK" 2>&1)"; EXIT_CODE=$?
_assert_eq "no snapshot: exit 0" "$EXIT_CODE" "0"
_assert_empty "no snapshot: silent" "$OUT"

# --------------------------------------------------------- 2. fresh, small
{
  echo "generated_at: $NOW"
  echo "commit_sha: $COMMIT"
  echo "small content"
} > "$SNAPSHOT"
OUT="$(bash "$HOOK" 2>&1)"; EXIT_CODE=$?
_assert_eq "fresh small: exit 0" "$EXIT_CODE" "0"
_assert_empty "fresh small: silent" "$OUT"

# ------------------------------------------- 3. stale-major (age), but small
# This is the behavior the hook deliberately dropped: staleness alone no
# longer triggers a session-start warning.
{
  echo "generated_at: $OLD_DATE"
  echo "commit_sha: $COMMIT"
  echo "small content"
} > "$SNAPSHOT"
OUT="$(bash "$HOOK" 2>&1)"; EXIT_CODE=$?
_assert_eq "stale-major but small: exit 0" "$EXIT_CODE" "0"
_assert_empty "stale-major but small: silent (staleness alone no longer warns)" "$OUT"

# ------------------------------------------------------------- 4. too-large
{
  echo "generated_at: $NOW"
  echo "commit_sha: $COMMIT"
  head -c 400000 /dev/zero | tr '\0' 'a'
} > "$SNAPSHOT"
OUT="$(bash "$HOOK" 2>&1)"; EXIT_CODE=$?
_assert_eq "too-large: exit 0 (never blocks)" "$EXIT_CODE" "0"
_assert_contains "too-large: warns" "$OUT" "over the"
_assert_contains "too-large: names the byte count" "$OUT" "400088 bytes"
_assert_contains "too-large: points at the repo map" "$OUT" "repo-map.sh"
_assert_contains "too-large: says not context" "$OUT" "not context"

rm -f "$SNAPSHOT"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
