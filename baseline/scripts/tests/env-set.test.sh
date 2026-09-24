#!/usr/bin/env bash
# env-set.test.sh
# Standalone fixture suite for baseline/scripts/env-set.sh: upserts a single
# KEY in a .env-style file without ever printing its contents. Covers the
# guarantees documented at the top of env-set.sh — append, upsert, values
# containing "=", "#" and spaces, a key that is a literal prefix of another
# key (FOO vs FOOBAR — the wrong match pattern would clobber the wrong
# line), missing-file creation, the never-shrink guard (proven with a
# deliberately mutated COPY of the script, since the real script cannot
# shrink a file through its own public behavior — the guard exists for
# exactly that reason), that the value never reaches stdout/stderr, that a
# backup is written, and that the backup is refused when it would not be
# gitignored.
#
# Fixture files are named "fixture.env", never literally ".env" — this
# repo's own block-secrets.sh / Read(.env) deny rules key off that exact
# filename anywhere it appears, including inside a scratch fixture dir, so a
# file actually named ".env" here would trip this repo's own guardrails
# instead of exercising the script under test.
#
# Fixture repo built on a throwaway branch name and renamed onto "main"
# afterwards (`git branch -m`), same reasoning as repo-map.test.sh: a
# session running this repo's own harness has protect-main.sh live on Bash,
# and a real `git commit` issued while already checked out on a protected
# name would get intercepted by the session's hook, not just avoided.
#
# Run: bash baseline/scripts/tests/env-set.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT="$SCRIPT_DIR/../env-set.sh"

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
  fi
}

_assert_not_contains() {
  local label="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file"; then
    _fail "$label (should not contain: $needle)"
  else
    _pass "$label"
  fi
}

_assert_file_exists() {
  local label="$1" file="$2"
  if [[ -e "$file" ]]; then
    _pass "$label"
  else
    _fail "$label ($file does not exist)"
  fi
}

# --------------------------------------------------------------- build fixture
REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO"
cd "$REPO" || exit 99

git init -q -b tmp-setup
git config user.email "test@example.com"
git config user.name "Test"
printf '*.bak\n' > .gitignore
git add .gitignore
git commit -q -m "fixture commit"
git branch -m main

FIXTURE="$REPO/fixture.env"

# ------------------------------------------------------------- 1. missing file
if [[ -e "$FIXTURE" ]]; then
  _fail "sanity: fixture.env should not pre-exist"
else
  _pass "sanity: fixture.env does not pre-exist"
fi

OUT1="$TMPDIR_ROOT/out1.txt"
printf 'v1' | bash "$SCRIPT" "$FIXTURE" FOO > "$OUT1" 2>&1
EXIT1=$?
_assert_eq "append: exit 0" "$EXIT1" "0"
_assert_file_exists "append: file created" "$FIXTURE"
_assert_contains "append: line written" "$FIXTURE" "FOO=v1"

# ------------------------------------------------------------- 2. upsert
printf 'v2' | bash "$SCRIPT" "$FIXTURE" FOO > /dev/null 2>&1
_assert_contains "upsert: value replaced" "$FIXTURE" "FOO=v2"
_assert_not_contains "upsert: old value gone" "$FIXTURE" "FOO=v1"
LINES_AFTER_UPSERT=$(awk 'END{print NR}' "$FIXTURE")
_assert_eq "upsert: still exactly one line" "$LINES_AFTER_UPSERT" "1"

# ----------------------------------------------------- 3. FOO vs FOOBAR prefix
printf 'barval' | bash "$SCRIPT" "$FIXTURE" FOOBAR > /dev/null 2>&1
_assert_contains "prefix: FOOBAR added as its own line" "$FIXTURE" "FOOBAR=barval"
_assert_contains "prefix: FOO untouched by the FOOBAR write" "$FIXTURE" "FOO=v2"

printf 'v3' | bash "$SCRIPT" "$FIXTURE" FOO > /dev/null 2>&1
_assert_contains "prefix: upserting FOO changes only FOO" "$FIXTURE" "FOO=v3"
_assert_contains "prefix: FOOBAR untouched by the FOO write" "$FIXTURE" "FOOBAR=barval"
LINES_AFTER_PREFIX=$(awk 'END{print NR}' "$FIXTURE")
_assert_eq "prefix: exactly two lines (no line lost or duplicated)" "$LINES_AFTER_PREFIX" "2"

# ------------------------------------------------------- 4. value with =, #, spaces
printf 'a=b #c d' | bash "$SCRIPT" "$FIXTURE" WEIRD > /dev/null 2>&1
_assert_contains "weird value: written verbatim" "$FIXTURE" "WEIRD=a=b #c d"

# --------------------------------------------------------------- 5. backup
_assert_file_exists "backup: fixture.env.bak exists after a write" "$FIXTURE.bak"

# ---------------------------------------------------- 6. value never leaks
OUT6="$TMPDIR_ROOT/out6.txt"
ERR6="$TMPDIR_ROOT/err6.txt"
printf 'SUPERSECRET-VALUE-XYZ' | bash "$SCRIPT" "$FIXTURE" SECRETKEY > "$OUT6" 2> "$ERR6"
_assert_not_contains "no leak: stdout never contains the value" "$OUT6" "SUPERSECRET-VALUE-XYZ"
_assert_not_contains "no leak: stderr never contains the value" "$ERR6" "SUPERSECRET-VALUE-XYZ"
_assert_contains "the key itself in stdout is fine (not the secret)" "$OUT6" "SECRETKEY"

# --------------------------------------------------------- 7. invalid key
OUT7="$TMPDIR_ROOT/out7.txt"
printf 'v' | bash "$SCRIPT" "$FIXTURE" "BAD-KEY" > /dev/null 2> "$OUT7"
EXIT7=$?
_assert_eq "invalid key: non-zero exit" "$EXIT7" "2"
_assert_contains "invalid key: error message" "$OUT7" "invalid key"
_assert_not_contains "invalid key: BAD-KEY not written to file" "$FIXTURE" "BAD-KEY"

# ------------------------------------------------------ 8. newline in value
OUT8="$TMPDIR_ROOT/out8.txt"
printf 'line1\nline2' | bash "$SCRIPT" "$FIXTURE" MULTILINE > /dev/null 2> "$OUT8"
EXIT8=$?
_assert_eq "newline in value: non-zero exit" "$EXIT8" "2"
_assert_contains "newline in value: refusal message" "$OUT8" "newline"
_assert_not_contains "newline in value: MULTILINE not written" "$FIXTURE" "MULTILINE"

# ----------------------------------- 9. missing trailing newline on last line
# A real bug class this guard defends against: `wc -l` undercounts a file
# whose last line has no trailing newline, which would fool a `wc -l`-based
# guard. env-set.sh counts with `awk 'END{print NR}'` instead. This proves
# the upsert still succeeds correctly on such a file (not fooled in the safe
# direction either).
NONL="$TMPDIR_ROOT/no-trailing-newline.env"
printf 'A=1\nB=2\nC=3' > "$NONL" # deliberately no trailing newline
BEFORE_WC=$(wc -l < "$NONL" | tr -d ' ')
BEFORE_AWK=$(awk 'END{print NR}' "$NONL")
_assert_eq "sanity: wc -l undercounts the no-trailing-newline fixture" "$BEFORE_WC" "2"
_assert_eq "sanity: awk NR counts it correctly as 3 lines" "$BEFORE_AWK" "3"

printf 'newC' | bash "$SCRIPT" "$NONL" C > /dev/null 2>&1
EXIT9=$?
_assert_eq "no-trailing-newline: upsert still succeeds" "$EXIT9" "0"
_assert_contains "no-trailing-newline: A preserved" "$NONL" "A=1"
_assert_contains "no-trailing-newline: B preserved" "$NONL" "B=2"
_assert_contains "no-trailing-newline: C replaced" "$NONL" "C=newC"
LINES_NONL=$(awk 'END{print NR}' "$NONL")
_assert_eq "no-trailing-newline: still exactly 3 lines" "$LINES_NONL" "3"

# --------------------------------------------- 10. refusal when result shrinks
# The real script cannot shrink a file through its own public behavior (an
# upsert only replaces one line or appends one) — that is exactly why this
# is a load-bearing safety net rather than a reachable code path. To prove
# it actually fires, this runs a deliberately mutated COPY of env-set.sh
# that drops the last line of its own rewrite buffer right before the
# never-shrink check, simulating the class of bug the guard exists to catch,
# and asserts: non-zero exit, a refusal message, and — the property that
# actually matters — the ORIGINAL file is untouched.
DROP_HELPER="$TMPDIR_ROOT/drop_last_line.sh"
cat > "$DROP_HELPER" <<'HELPER'
#!/usr/bin/env bash
f="$1"
awk 'NR>1{print prev} {prev=$0}' "$f" > "$f.dropped_tmp" && mv "$f.dropped_tmp" "$f"
HELPER

MARKER='after_lines=$(count_lines "$tmp")'
INJECT='bash "'"$DROP_HELPER"'" "$tmp"'
BROKEN="$TMPDIR_ROOT/env-set-broken.sh"
awk -v inject="$INJECT" -v marker="$MARKER" '
  $0 == marker { print inject }
  { print }
' "$SCRIPT" > "$BROKEN"

if ! grep -qF "$INJECT" "$BROKEN"; then
  _fail "shrink-guard fixture: injection marker not found — env-set.sh's guard line moved, update this test"
else
  SHRINK_FIXTURE="$TMPDIR_ROOT/shrink.env"
  printf 'ONE=1\nTWO=2\nTHREE=3\n' > "$SHRINK_FIXTURE"
  BEFORE_CONTENT_HASH=$(cksum < "$SHRINK_FIXTURE")

  OUT10="$TMPDIR_ROOT/out10.txt"
  printf 'newval' | bash "$BROKEN" "$SHRINK_FIXTURE" TWO > /dev/null 2> "$OUT10"
  EXIT10=$?
  AFTER_CONTENT_HASH=$(cksum < "$SHRINK_FIXTURE")

  _assert_eq "shrink guard (broken copy): non-zero exit" "$EXIT10" "1"
  _assert_contains "shrink guard (broken copy): refusal message" "$OUT10" "refusing"
  _assert_contains "shrink guard (broken copy): mentions the backup" "$OUT10" "backup"
  _assert_eq "shrink guard (broken copy): original file untouched" "$AFTER_CONTENT_HASH" "$BEFORE_CONTENT_HASH"

  # Same broken copy, but the SOURCE file also lacks a trailing newline on its
  # last line. This is the combination that actually discriminates a
  # `wc -l`-based guard from an `awk 'END{print NR}'`-based one: with `wc -l`,
  # the undercounted "before" (N-1, real lines N) and the reduced "after"
  # produced by the broken copy's drop (also N-1, since every line the
  # rewrite prints ends in a real newline) come out EQUAL — not less than —
  # so a `wc -l` guard would wrongly let the drop through. `awk 'END{print
  # NR}'` counts "before" as the true N, so the drop is still caught. This is
  # the scenario that would have let the original `wc -l` version of this
  # script silently accept a lost line.
  SHRINK_FIXTURE_NONL="$TMPDIR_ROOT/shrink-no-trailing-newline.env"
  printf 'ONE=1\nTWO=2\nTHREE=3' > "$SHRINK_FIXTURE_NONL" # no trailing newline
  BEFORE_NONL_HASH=$(cksum < "$SHRINK_FIXTURE_NONL")

  OUT10B="$TMPDIR_ROOT/out10b.txt"
  printf 'newval' | bash "$BROKEN" "$SHRINK_FIXTURE_NONL" TWO > /dev/null 2> "$OUT10B"
  EXIT10B=$?
  AFTER_NONL_HASH=$(cksum < "$SHRINK_FIXTURE_NONL")

  _assert_eq "shrink guard (broken copy, no trailing newline in source): non-zero exit" "$EXIT10B" "1"
  _assert_contains "shrink guard (no trailing newline): refusal message" "$OUT10B" "refusing"
  _assert_eq "shrink guard (no trailing newline): original file untouched" "$AFTER_NONL_HASH" "$BEFORE_NONL_HASH"
fi

# ---------------------------------------- 11. backup refused when not ignored
UNIGNORED_REPO="$TMPDIR_ROOT/unignored-repo"
mkdir -p "$UNIGNORED_REPO"
(
  cd "$UNIGNORED_REPO" || exit 99
  git init -q -b tmp-setup
  git config user.email "test@example.com"
  git config user.name "Test"
  # deliberately no .gitignore for *.bak
  echo "placeholder" > README.md
  git add README.md
  git commit -q -m "fixture commit"
  git branch -m main
)
UNIGNORED_FIXTURE="$UNIGNORED_REPO/fixture.env"
OUT11="$TMPDIR_ROOT/out11.txt"
printf 'v' | bash "$SCRIPT" "$UNIGNORED_FIXTURE" FOO > /dev/null 2> "$OUT11"
EXIT11=$?
_assert_eq "backup safety: refuses when .bak would not be gitignored" "$EXIT11" "1"
_assert_contains "backup safety: refusal message" "$OUT11" "not be gitignored"
if [[ -e "$UNIGNORED_FIXTURE.bak" ]]; then
  _fail "backup safety: no backup file actually written"
else
  _pass "backup safety: no backup file actually written"
fi

# override still allows the write, with a loud warning
OUT11B="$TMPDIR_ROOT/out11b.txt"
ENV_SET_ALLOW_UNIGNORED_BACKUP=1 bash "$SCRIPT" "$UNIGNORED_FIXTURE" FOO > /dev/null 2> "$OUT11B" <<< "v"
EXIT11B=$?
_assert_eq "backup safety override: succeeds with the env var set" "$EXIT11B" "0"
_assert_contains "backup safety override: warns loudly" "$OUT11B" "WARNING"
_assert_file_exists "backup safety override: backup written this time" "$UNIGNORED_FIXTURE.bak"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
