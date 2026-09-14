#!/usr/bin/env bash
# check-index.test.sh
# Standalone fixture suite for baseline/scripts/check-index.sh's handling of
# an adopted-but-not-yet-migrated repo: `install-harness.sh --adopt` renames
# the old skills/agents dirs to `*.pre-harness/` and the adopting guide says
# to keep them on disk until the migration PR merges, and a repo's own
# `.claude/` commonly holds gitignored generated files (a Repomix snapshot,
# for instance). Neither is authored content whose stale cross-references
# should ever surface. Also covers docs nested under a subdirectory
# (`docs/harness/*.md`, reachable through a consumer's `.claude/docs/harness`
# symlink), which a flat glob used to report as "listed but not on disk".
#
# Builds throwaway git repos in a mktemp dir (NEVER this checkout's own
# files) and asserts on check-index.sh's stderr text and exit code, since
# findings live in the text, not just the exit code.
#
# Run: bash baseline/scripts/tests/check-index.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT="$SCRIPT_DIR/../check-index.sh"

TMPDIR_ROOT="$(mktemp -d)"
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

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

_assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    _pass "$label"
  else
    _fail "$label (expected exit $expected, got $actual)"
  fi
}

# Fixture content below writes fake, deliberately-broken script pointers
# into throwaway files under $TMPDIR_ROOT, so check-index.sh's own pointer
# scan has something dangling to find inside those fixtures. Assembled from
# this variable inside unquoted heredocs, rather than spelled out as one
# contiguous literal, so this test FILE itself (a real .sh file living in
# this repo) never contains the joined path check-index.sh's own pointer
# regex looks for — which would otherwise make this repo's own
# `check-index.sh --strict` misreport these fixtures as real dangling
# pointers.
DC=".claude"

# ---------------------------------------------------------------- repo A
# Exhaustive fixture: one instance of every case the two defects covered,
# plus the positive control (a broken pointer in a tracked file) that must
# keep surfacing — proving the fix scopes the exemption to .pre-harness
# paths and gitignored files, not "any dangling pointer under .claude/".
REPO="$TMPDIR_ROOT/repo-full"
mkdir -p "$REPO/.claude/rules" "$REPO/.claude/skills.pre-harness" "$REPO/.claude/docs/harness"

git -C "$REPO" init -q -b test
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"

cat > "$REPO/.gitignore" <<'EOF'
ignored-notes.md
EOF

# Positive control: tracked rule, broken pointer. Must be reported.
cat > "$REPO/.claude/rules/tracked-rule.md" <<EOF
---
paths: "**"
---

See ${DC}/scripts/does-not-exist-tracked.sh for details.
EOF

# Pre-migration copy install-harness.sh --adopt leaves on disk. Its broken
# pointer must be invisible.
cat > "$REPO/.claude/skills.pre-harness/old-skill.md" <<EOF
---
name: old-skill
description: pre-adoption copy, kept on disk until the migration PR merges
---

See ${DC}/scripts/does-not-exist-preharness.sh for details.
EOF

# Gitignored generated file inside .claude/ (stand-in for the real
# repomix-snapshot.md). Its broken pointer must also be invisible.
cat > "$REPO/.claude/ignored-notes.md" <<EOF
See ${DC}/scripts/does-not-exist-ignored.sh for details.
EOF

# Doc nested under docs/harness/, exactly like the harness's own AI-only
# docs land in a consumer repo through the .claude/docs/harness symlink.
cat > "$REPO/.claude/docs/harness/context-engineering.md" <<'EOF'
# context engineering doc
EOF

cat > "$REPO/CLAUDE.md" <<'EOF'
# Test project

## Docs

- `context-engineering.md` - nested doc that exists on disk
- `does-not-exist.md` - listed but never shipped

## Rules

- tracked-rule.md - a rule with a broken pointer, kept as the positive control
EOF

git -C "$REPO" add .gitignore CLAUDE.md .claude/rules .claude/docs
git -C "$REPO" commit -q -m "fixture"
# skills.pre-harness/ and ignored-notes.md are deliberately left out of the
# commit — they must never enter the scan at all, tracked or not.

OUT_FULL="$TMPDIR_ROOT/out-full.txt"
(cd "$REPO" && bash "$SCRIPT" --strict) > "$OUT_FULL" 2>&1
EXIT_FULL=$?

_assert_not_contains "pre-harness broken pointer is not reported" \
  "$OUT_FULL" "does-not-exist-preharness.sh"

_assert_not_contains "gitignored-file broken pointer is not reported" \
  "$OUT_FULL" "does-not-exist-ignored.sh"

_assert_contains "tracked-file broken pointer is still reported (positive control)" \
  "$OUT_FULL" "does-not-exist-tracked.sh"

_assert_not_contains "nested doc that exists is not flagged stale" \
  "$OUT_FULL" "context-engineering.md"

_assert_contains "doc listed but missing everywhere is still stale" \
  "$OUT_FULL" "does-not-exist.md"

_assert_eq "--strict exits 1 with the positive control present" "$EXIT_FULL" "1"

# ---------------------------------------------------------------- repo B
# Same suppressions (pre-harness dir, gitignored file), but nothing else is
# wrong: no broken tracked pointer, no missing doc. Proves the suppressions
# alone do not leave the scan red, and that --strict is 0 on a genuinely
# clean, adopted repo.
REPO_CLEAN="$TMPDIR_ROOT/repo-clean"
mkdir -p "$REPO_CLEAN/.claude/rules" "$REPO_CLEAN/.claude/skills.pre-harness" "$REPO_CLEAN/.claude/docs/harness"

git -C "$REPO_CLEAN" init -q -b test
git -C "$REPO_CLEAN" config user.email "test@example.com"
git -C "$REPO_CLEAN" config user.name "Test"

cat > "$REPO_CLEAN/.gitignore" <<'EOF'
ignored-notes.md
EOF

cat > "$REPO_CLEAN/.claude/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

cat > "$REPO_CLEAN/.claude/skills.pre-harness/old-skill.md" <<EOF
---
name: old-skill
description: pre-adoption copy, kept on disk until the migration PR merges
---

See ${DC}/scripts/does-not-exist-preharness.sh for details.
EOF

cat > "$REPO_CLEAN/.claude/ignored-notes.md" <<EOF
See ${DC}/scripts/does-not-exist-ignored.sh for details.
EOF

cat > "$REPO_CLEAN/.claude/docs/harness/context-engineering.md" <<'EOF'
# context engineering doc
EOF

cat > "$REPO_CLEAN/CLAUDE.md" <<'EOF'
# Test project

## Docs

- `context-engineering.md` - nested doc that exists on disk

## Rules

- tracked-rule.md - a clean rule, no dangling pointer
EOF

git -C "$REPO_CLEAN" add .gitignore CLAUDE.md .claude/rules .claude/docs
git -C "$REPO_CLEAN" commit -q -m "fixture"

OUT_CLEAN="$TMPDIR_ROOT/out-clean.txt"
(cd "$REPO_CLEAN" && bash "$SCRIPT" --strict) > "$OUT_CLEAN" 2>&1
EXIT_CLEAN=$?

_assert_eq "--strict exits 0 on a genuinely clean adopted repo" "$EXIT_CLEAN" "0"

_assert_not_contains "clean repo: pre-harness broken pointer still not reported" \
  "$OUT_CLEAN" "does-not-exist-preharness.sh"

_assert_not_contains "clean repo: gitignored-file broken pointer still not reported" \
  "$OUT_CLEAN" "does-not-exist-ignored.sh"

# ---------------------------------------------------------------- repo C
# No .git at all. Locks in the documented fallback: when check-index.sh
# cannot ask git whether a file is ignored, it must not hide anything — a
# file that WOULD be gitignored in a real repo is reported here, and the
# .pre-harness suppression (path-based, not git-based) still holds on its own.
REPO_NO_GIT="$TMPDIR_ROOT/repo-no-git"
mkdir -p "$REPO_NO_GIT/.claude/rules" "$REPO_NO_GIT/.claude/skills.pre-harness"

cat > "$REPO_NO_GIT/.claude/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

cat > "$REPO_NO_GIT/.claude/skills.pre-harness/old-skill.md" <<EOF
---
name: old-skill
description: pre-adoption copy, kept on disk until the migration PR merges
---

See ${DC}/scripts/does-not-exist-preharness.sh for details.
EOF

# Would be gitignored in a real repo, but there is no .git here at all.
cat > "$REPO_NO_GIT/.claude/would-be-ignored.md" <<EOF
See ${DC}/scripts/does-not-exist-no-git.sh for details.
EOF

cat > "$REPO_NO_GIT/CLAUDE.md" <<'EOF'
# Test project (no git)

## Rules

- tracked-rule.md - a clean rule, no dangling pointer
EOF

OUT_NO_GIT="$TMPDIR_ROOT/out-no-git.txt"
(cd "$REPO_NO_GIT" && bash "$SCRIPT" --strict) > "$OUT_NO_GIT" 2>&1
EXIT_NO_GIT=$?

_assert_contains "no-git fallback: an unverifiable pointer is reported, not hidden" \
  "$OUT_NO_GIT" "does-not-exist-no-git.sh"

_assert_not_contains "no-git: pre-harness suppression still holds without git" \
  "$OUT_NO_GIT" "does-not-exist-preharness.sh"

_assert_eq "--strict exits 1 when the no-git fallback surfaces a real dangling pointer" \
  "$EXIT_NO_GIT" "1"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
