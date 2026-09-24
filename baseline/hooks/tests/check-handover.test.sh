#!/usr/bin/env bash
# check-handover.test.sh
# Standalone fixture suite for baseline/hooks/check-handover.sh.
#
# Covers: silence with nothing to point at, a single handover, picking the
# newest of several by filename date, a filename-date tie broken by mtime,
# silence on source=compact, tolerance of an empty/missing payload, the
# tasks.md "## Handover" fallback when .claude/handovers/ has nothing, both
# sources present at once (the newer one wins, a same-day tie goes to the
# spec, the loser is cited in exactly one line), the spec side comparing by
# the section's own "Updated:" line or an mtime fallback instead of the
# spec folder's creation date, a title containing a tab and a CRLF line
# ending still producing valid JSON, an "Updated:" line itself ending in
# CRLF still parsing as its literal date instead of silently dropping to
# the mtime fallback, and a genuinely BLANK CRLF line (a lone \r, not the
# empty string) between the heading and the "Updated:" line not being
# mistaken for content in its place - a narrower case than a CRLF line
# ending, and the one that actually exercises awk's emptiness check rather
# than just its end-of-line anchor.
#
# Every fixture whose comparable date matters for an assertion pins it
# literally (a filename date, or an explicit "Updated:" line) rather than
# relying on mtime/the `date` command's notion of "today" - the one
# exception is the mtime-fallback test itself, which by definition has
# nothing to pin, and instead computes its own expectation from the
# written file's real mtime. Every "X wins" assertion is anchored on the
# "File:  " prefix, never a bare path: a bare path also appears inside the
# LOSER's "Also present, not chosen: <path>" line, so an unanchored check
# can report PASS while the hook actually picked the other source - this
# is what let two clock-dependent regressions (a spec review round found
# both) ship green.
#
# The hook never shells out to git (it only reads the filesystem relative to
# cwd), so unlike protect-main.test.sh or check-snapshot-on-session.test.sh
# this fixture does not need a git repo at all - just a plain directory tree.
#
# Run: bash baseline/hooks/tests/check-handover.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../check-handover.sh"

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

_assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) _fail "$label (should not contain: $needle)" ;;
    *) _pass "$label" ;;
  esac
}

REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO"
cd "$REPO" || exit 99

# Used by the "Updated:"-line and mtime-fallback tests below, so their
# expectations do not depend on which day the suite happens to run.
TODAY="$(date +%Y-%m-%d)"

run_hook() {
  local payload="$1"
  if [[ -z "$payload" ]]; then
    bash "$HOOK" < /dev/null 2>&1
  else
    printf '%s' "$payload" | bash "$HOOK" 2>&1
  fi
}

# -------------------------------------------------- 1. nothing to point at
rm -rf .claude specs
OUT="$(run_hook '{"source":"startup"}')"; EXIT_CODE=$?
_assert_eq "nothing on disk: exit 0" "$EXIT_CODE" "0"
_assert_empty "nothing on disk: silent" "$OUT"

# -------------------------------------------------------- 2. one handover
mkdir -p .claude/handovers
cat > .claude/handovers/2026-09-01-only.md << 'EOF'
# Handover: only one

Body text.
EOF
OUT="$(run_hook '{"source":"startup"}')"; EXIT_CODE=$?
_assert_eq "one handover: exit 0" "$EXIT_CODE" "0"
_assert_contains "one handover: cites the path" "$OUT" ".claude/handovers/2026-09-01-only.md"
_assert_contains "one handover: cites the title" "$OUT" "Handover: only one"
_assert_not_contains "one handover: no older-count line for a single file" "$OUT" "older handover"
rm -rf .claude/handovers

# ------------------------------------------------- 3. three, newest by date
mkdir -p .claude/handovers
cat > .claude/handovers/2026-08-01-first.md << 'EOF'
# Handover: first
EOF
cat > .claude/handovers/2026-09-15-second.md << 'EOF'
# Handover: second
EOF
cat > .claude/handovers/2026-09-24-third.md << 'EOF'
# Handover: third and newest
EOF
OUT="$(run_hook '{"source":"startup"}')"; EXIT_CODE=$?
_assert_eq "three handovers: exit 0" "$EXIT_CODE" "0"
_assert_contains "three handovers: cites the newest" "$OUT" "2026-09-24-third.md"
_assert_not_contains "three handovers: does not cite the oldest path" "$OUT" "2026-08-01-first.md"
_assert_not_contains "three handovers: does not cite the middle path" "$OUT" "2026-09-15-second.md"
_assert_contains "three handovers: says 2 older exist" "$OUT" "2 older handover"
rm -rf .claude/handovers

# --------------------------------------------- 4. filename date tie, by mtime
mkdir -p .claude/handovers
cat > .claude/handovers/2026-09-20-older-write.md << 'EOF'
# Handover: written first
EOF
sleep 1.1
cat > .claude/handovers/2026-09-20-newer-write.md << 'EOF'
# Handover: written second, same date
EOF
OUT="$(run_hook '{"source":"startup"}')"; EXIT_CODE=$?
_assert_eq "date tie: exit 0" "$EXIT_CODE" "0"
_assert_contains "date tie: picks the later mtime" "$OUT" "2026-09-20-newer-write.md"
_assert_not_contains "date tie: not the earlier mtime" "$OUT" "2026-09-20-older-write.md"
rm -rf .claude/handovers

# ------------------------------------------------------- 5. source=compact
mkdir -p .claude/handovers
cat > .claude/handovers/2026-09-24-third.md << 'EOF'
# Handover: third and newest
EOF
OUT="$(run_hook '{"source":"compact"}')"; EXIT_CODE=$?
_assert_eq "compact: exit 0" "$EXIT_CODE" "0"
_assert_empty "compact: silent even with a handover on disk" "$OUT"
rm -rf .claude/handovers

# ------------------------------------------------ 6. empty / missing payload
rm -rf .claude specs
OUT="$(run_hook '')"; EXIT_CODE=$?
_assert_eq "empty payload: exit 0" "$EXIT_CODE" "0"
_assert_empty "empty payload: silent with nothing on disk" "$OUT"

OUT="$(printf '' | bash "$HOOK" 2>&1)"; EXIT_CODE=$?
_assert_eq "closed stdin: exit 0" "$EXIT_CODE" "0"

# --------------------------------------- 7. spec's tasks.md ## Handover section
rm -rf .claude specs
mkdir -p specs/2026-09-10-dark-mode
cat > specs/2026-09-10-dark-mode/tasks.md << 'EOF'
# Tasks

- [x] task one

## Handover

Dark mode theming is implemented; tests are not started.
EOF
OUT="$(run_hook '{"source":"startup"}')"; EXIT_CODE=$?
_assert_eq "spec handover: exit 0" "$EXIT_CODE" "0"
_assert_contains "spec handover: cites the spec's tasks.md" "$OUT" "specs/2026-09-10-dark-mode/tasks.md"
_assert_contains "spec handover: cites the Handover section" "$OUT" "## Handover"
rm -rf specs

# ------------------------ 8. both sources present, spec newer: spec wins, loose file cited
# Both dates are pinned literals (2026-09-24 via the section's own Updated:
# line, 2026-01-01 via the loose file's name) - neither comes from mtime or
# the `date` command, so the outcome cannot depend on which day, timezone,
# or clock the suite happens to run under. The "spec wins" assertion is
# anchored on the "File:  " prefix, not the bare path: the bare path alone
# also appears inside the loser's "Also present, not chosen: <path>" line,
# so an unanchored check would pass even if the hook picked the wrong
# winner (this is exactly the F6 bug, applied here defensively).
mkdir -p .claude/handovers specs/2026-09-24-nova
cat > .claude/handovers/2026-01-01-velho.md << 'EOF'
# Velho
EOF
cat > specs/2026-09-24-nova/tasks.md << 'EOF'
# Tasks

- [x] task

## Handover
Updated: 2026-09-24

Nova is in progress.
EOF
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "spec newer than handover: exit 0" "$EXIT_CODE" "0"
_assert_contains "spec newer than handover: spec wins" "$OUT" "File:  specs/2026-09-24-nova/tasks.md (section: ## Handover)"
_assert_contains "spec newer than handover: spec date shown" "$OUT" "Date:  2026-09-24"
_assert_contains "spec newer than handover: loose file cited, one line" "$OUT" "Also present, not chosen: .claude/handovers/2026-01-01-velho.md"
_assert_not_contains "spec newer than handover: loser's title not restated" "$OUT" "Velho"
rm -rf .claude specs

# ------------------------ 9. both sources present, handover newer: handover wins, spec cited
# The spec's own "Updated:" line pins its comparable date to 2026-01-01 -
# without it, mtime fallback would make "now" (today) the comparable date
# instead, since the fixture file is written during this very test run, and
# the whole point of this case (the spec is the OLD one) would be lost.
mkdir -p .claude/handovers specs/2026-01-01-antiga
cat > .claude/handovers/2026-09-24-recente.md << 'EOF'
# Recente
EOF
cat > specs/2026-01-01-antiga/tasks.md << 'EOF'
# Tasks

- [x] task

## Handover
Updated: 2026-01-01

Antiga finished months ago.
EOF
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "handover newer than spec: exit 0" "$EXIT_CODE" "0"
_assert_contains "handover newer than spec: handover wins" "$OUT" "File:  .claude/handovers/2026-09-24-recente.md"
_assert_contains "handover newer than spec: handover date shown" "$OUT" "Date:  2026-09-24"
_assert_contains "handover newer than spec: spec cited, one line" "$OUT" "Also present, not chosen: specs/2026-01-01-antiga/tasks.md (section: ## Handover)"
_assert_not_contains "handover newer than spec: loser's title not restated" "$OUT" "Antiga finished months ago"
rm -rf .claude specs

# --------------------------------------------- 10. same-day tie: spec wins
# The spec's date is pinned via its own Updated: line, matching the loose
# file's filename date exactly - without the pin, the spec side would fall
# back to mtime (real "now"), which is only accidentally 2026-09-24 on the
# day this suite happens to run, and stops being a same-day tie the moment
# a day passes or the timezone shifts the calendar date. The "spec wins"
# assertion is anchored on "File:  ", not the bare path: without the
# anchor, the exact same substring also appears in the LOSER's "Also
# present, not chosen: <path>" line when the loose file wins instead, so an
# unanchored assertion would report PASS while silently no longer
# exercising the spec_date == newest_date tie branch at all (F6).
mkdir -p .claude/handovers specs/2026-09-24-tied
cat > .claude/handovers/2026-09-24-loose.md << 'EOF'
# Loose, same day
EOF
cat > specs/2026-09-24-tied/tasks.md << 'EOF'
# Tasks

- [x] task

## Handover
Updated: 2026-09-24

Tied spec, same day as the loose file.
EOF
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "same-day tie: exit 0" "$EXIT_CODE" "0"
_assert_contains "same-day tie: spec wins" "$OUT" "File:  specs/2026-09-24-tied/tasks.md (section: ## Handover)"
_assert_contains "same-day tie: loose file cited, one line" "$OUT" "Also present, not chosen: .claude/handovers/2026-09-24-loose.md"
rm -rf .claude specs

# ---------- 11. F1 regression: old spec FOLDER, recent "## Handover" section,
# beats an intermediate loose file. The folder date (2026-09-01) is older
# than the loose file's date (2026-09-10); only reading the section's own
# "Updated:" line, not the folder name, gets this right.
mkdir -p .claude/handovers specs/2026-09-01-active-feature
cat > .claude/handovers/2026-09-10-old.md << 'EOF'
# Old, unrelated
EOF
cat > specs/2026-09-01-active-feature/tasks.md << EOF
# Tasks

- [x] task

## Handover
Updated: $TODAY

Active feature is in progress; written today despite the September 1st
folder name.
EOF
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "F1 reviewer repro: exit 0" "$EXIT_CODE" "0"
_assert_contains "F1 reviewer repro: spec section wins despite the older folder date" "$OUT" "File:  specs/2026-09-01-active-feature/tasks.md (section: ## Handover)"
_assert_contains "F1 reviewer repro: comparable date is the Updated: line" "$OUT" "Date:  $TODAY"
_assert_not_contains "F1 reviewer repro: comparable date is not the folder date" "$OUT" "Date:  2026-09-01"
_assert_contains "F1 reviewer repro: intermediate loose file cited, not chosen" "$OUT" "Also present, not chosen: .claude/handovers/2026-09-10-old.md"
rm -rf .claude specs

# --------------------------- 12. mtime fallback, no "Updated:" line at all
# The spec folder is dated 2026-01-01 - far older than the loose file's
# 2026-09-20 - yet the spec still wins, because its tasks.md was written
# (mtime) after the loose file and carries no Updated: line to override
# that. Proves the fallback reads mtime, not the folder name, when the line
# is absent.
#
# The expected "Date:" value is computed here from the file's own real
# mtime, with the identical two-command fallback the hook itself uses
# (date -d @epoch, then date -r epoch) - not from the $TODAY captured once
# at the top of this script. A value captured earlier only agrees with
# what the hook computes moments later if both calls see the same "now";
# reading the file's own mtime and converting it right here removes that
# assumption, so the test cannot be fooled by a clock that advances, or a
# `date` shim that answers "now" and "convert this epoch" differently,
# between the two reads.
mkdir -p .claude/handovers specs/2026-01-01-legacy-folder
cat > .claude/handovers/2026-09-20-loose.md << 'EOF'
# Loose, dated before today
EOF
cat > specs/2026-01-01-legacy-folder/tasks.md << 'EOF'
# Tasks

- [x] task

## Handover

No Updated: line in this section - recency has to come from mtime, not
this 2026-01-01 folder name.
EOF
tf_mtime="$(stat -f %m specs/2026-01-01-legacy-folder/tasks.md 2>/dev/null || stat -c %Y specs/2026-01-01-legacy-folder/tasks.md 2>/dev/null)"
expected_date="$(date -d "@$tf_mtime" +%Y-%m-%d 2>/dev/null || date -r "$tf_mtime" +%Y-%m-%d 2>/dev/null)"
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "mtime fallback: exit 0" "$EXIT_CODE" "0"
_assert_contains "mtime fallback: spec wins via mtime despite the 2026-01-01 folder name" "$OUT" "File:  specs/2026-01-01-legacy-folder/tasks.md (section: ## Handover)"
_assert_contains "mtime fallback: comparable date matches the file's own mtime" "$OUT" "Date:  $expected_date"
_assert_not_contains "mtime fallback: not the folder's own date" "$OUT" "Date:  2026-01-01"
rm -rf .claude specs

# ------------------------- 13. F2 regression: tab and CRLF in a title still
# produce valid JSON. A raw tab or carriage return in additionalContext
# used to break Claude Code's own JSON parse ("Invalid control character"),
# silently discarding the hook's context.
mkdir -p .claude/handovers
printf '# Weird\tTab\r\n\r\nBody line with a CRLF ending.\r\n' > .claude/handovers/2026-09-24-control-chars.md
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "control chars in title: exit 0" "$EXIT_CODE" "0"
if printf '%s' "$OUT" | python3 -m json.tool > /dev/null 2>&1; then
  _pass "control chars in title: output is valid JSON"
else
  _fail "control chars in title: output is valid JSON (got: $OUT)"
fi
rm -rf .claude/handovers

# ------------------------------- 14. F7 regression: CRLF "Updated:" line
# A tasks.md saved with CRLF line endings leaves a trailing \r attached to
# the "Updated:" line's captured text (awk/grep split records on \n only).
# Before F7 the regex anchored the date immediately before end-of-line, so
# that \r broke the match and silently dropped to the mtime fallback - the
# same failure shape F2 fixed for the title, just one line up. This asserts
# the CRLF line still parses as the literal date, not today's mtime, and
# that the title extraction correctly skips it rather than showing it as
# prose.
mkdir -p specs/2026-01-01-crlf-spec
printf '# Tasks\r\n\r\n- [x] task\r\n\r\n## Handover\r\nUpdated: 2026-03-15\r\n\r\nWritten with CRLF line endings throughout.\r\n' > specs/2026-01-01-crlf-spec/tasks.md
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "CRLF Updated: line: exit 0" "$EXIT_CODE" "0"
_assert_contains "CRLF Updated: line: parses the pinned date, not mtime" "$OUT" "Date:  2026-03-15"
_assert_not_contains "CRLF Updated: line: does not fall back to mtime" "$OUT" "Date:  $TODAY"
_assert_contains "CRLF Updated: line: title skips the Updated: line" "$OUT" "Title: Written with CRLF line endings throughout."
_assert_not_contains "CRLF Updated: line: Updated: line not shown as the title" "$OUT" "Title: Updated:"
if printf '%s' "$OUT" | python3 -m json.tool > /dev/null 2>&1; then
  _pass "CRLF Updated: line: output is valid JSON"
else
  _fail "CRLF Updated: line: output is valid JSON (got: $OUT)"
fi
rm -rf specs

# --------------------- 15. F9 regression: CRLF blank line before "Updated:"
# Test 14's fixture puts "Updated:" immediately after the "## Handover"
# heading, with no blank line between them - that shape happens to pass
# even with awk's default NF emptiness check, because NF only misclassifies
# a genuinely BLANK CRLF line (a lone \r) as non-empty, and test 14 never
# has one. This fixture does: a blank line separates the heading from
# Updated:, matching how the `handover` skill's own example in SKILL.md is
# formatted (heading, then the Updated: line - but a human or an editor
# routinely leaves a blank line there too, and CRLF turns that blank line
# into a lone \r, not the empty string). Under the old `f && NF` check, that
# \r reads as one non-empty field and gets returned as the "first non-empty
# line" in place of the real Updated: line, which falls back to mtime -
# silently, with no error. Proof this fixture actually exercises the fix
# (not just re-confirms test 14): reverting check-handover.sh's emptiness
# check from `$0 !~ /^[ \t\r]*$/` back to `f && NF` turns this fixture's
# "Date:" into today's mtime-derived date instead of the pinned 2026-03-15,
# while test 14 alone stays green either way.
mkdir -p specs/2026-01-01-crlf-blank-spec
printf '# Tasks\r\n\r\n- [x] task\r\n\r\n## Handover\r\n\r\nUpdated: 2026-03-15\r\n\r\nWritten with a blank CRLF line before Updated:.\r\n' > specs/2026-01-01-crlf-blank-spec/tasks.md
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "CRLF blank line before Updated:: exit 0" "$EXIT_CODE" "0"
_assert_contains "CRLF blank line before Updated:: parses the pinned date, not mtime" "$OUT" "Date:  2026-03-15"
_assert_not_contains "CRLF blank line before Updated:: does not fall back to mtime" "$OUT" "Date:  $TODAY"
_assert_contains "CRLF blank line before Updated:: title skips both the blank line and the Updated: line" "$OUT" "Title: Written with a blank CRLF line before Updated:."
rm -rf specs

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
