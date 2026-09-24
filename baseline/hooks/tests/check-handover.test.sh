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
# spec folder's creation date, and a title containing a tab and a CRLF line
# ending still producing valid JSON.
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
mkdir -p .claude/handovers specs/2026-09-24-nova
cat > .claude/handovers/2026-01-01-velho.md << 'EOF'
# Velho
EOF
cat > specs/2026-09-24-nova/tasks.md << 'EOF'
# Tasks

- [x] task

## Handover

Nova is in progress.
EOF
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "spec newer than handover: exit 0" "$EXIT_CODE" "0"
_assert_contains "spec newer than handover: spec wins" "$OUT" "specs/2026-09-24-nova/tasks.md"
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
_assert_contains "handover newer than spec: handover wins" "$OUT" ".claude/handovers/2026-09-24-recente.md"
_assert_contains "handover newer than spec: handover date shown" "$OUT" "Date:  2026-09-24"
_assert_contains "handover newer than spec: spec cited, one line" "$OUT" "Also present, not chosen: specs/2026-01-01-antiga/tasks.md (section: ## Handover)"
_assert_not_contains "handover newer than spec: loser's title not restated" "$OUT" "Antiga finished months ago"
rm -rf .claude specs

# --------------------------------------------- 10. same-day tie: spec wins
mkdir -p .claude/handovers specs/2026-09-24-tied
cat > .claude/handovers/2026-09-24-loose.md << 'EOF'
# Loose, same day
EOF
cat > specs/2026-09-24-tied/tasks.md << 'EOF'
# Tasks

- [x] task

## Handover

Tied spec, same day as the loose file.
EOF
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "same-day tie: exit 0" "$EXIT_CODE" "0"
_assert_contains "same-day tie: spec wins" "$OUT" "specs/2026-09-24-tied/tasks.md"
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
_assert_contains "F1 reviewer repro: spec section wins despite the older folder date" "$OUT" "specs/2026-09-01-active-feature/tasks.md"
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
OUT="$(run_hook '{"source":"clear"}')"; EXIT_CODE=$?
_assert_eq "mtime fallback: exit 0" "$EXIT_CODE" "0"
_assert_contains "mtime fallback: spec wins via mtime despite the 2026-01-01 folder name" "$OUT" "specs/2026-01-01-legacy-folder/tasks.md"
_assert_contains "mtime fallback: comparable date is today's mtime" "$OUT" "Date:  $TODAY"
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

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
