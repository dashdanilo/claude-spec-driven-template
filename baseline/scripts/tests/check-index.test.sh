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
# symlink), which a flat glob used to report as "listed but not on disk",
# and hook/script test fixtures under a `tests/` directory
# (`baseline/hooks/tests/*.test.sh`, `baseline/scripts/tests/*.test.sh`),
# whose made-up `.claude/...` paths are input data for the thing under
# test, not prose pointing an agent at something to read.
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
cat > "$REPO/${DC}/rules/tracked-rule.md" <<EOF
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

cat > "$REPO_CLEAN/${DC}/rules/tracked-rule.md" <<'EOF'
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

cat > "$REPO_NO_GIT/${DC}/rules/tracked-rule.md" <<'EOF'
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

# ---------------------------------------------------------------- repo D
# A nested git checkout parked under .claude/worktrees/ — the shape of a
# real spec-worktree session left behind, or a `git worktree add` gone
# stale. Its own .git makes it a separate repository; the broken pointer
# inside it belongs to that repository, not to this scan, and must never
# surface here regardless of whether it is tracked, ignored, or untracked
# in the nested checkout itself.
REPO_NESTED="$TMPDIR_ROOT/repo-nested-checkout"
mkdir -p "$REPO_NESTED/.claude/rules" "$REPO_NESTED/.claude/worktrees/other-session/.claude"

git -C "$REPO_NESTED" init -q -b test
git -C "$REPO_NESTED" config user.email "test@example.com"
git -C "$REPO_NESTED" config user.name "Test"

cat > "$REPO_NESTED/${DC}/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

cat > "$REPO_NESTED/CLAUDE.md" <<'EOF'
# Test project

## Rules

- tracked-rule.md - a clean rule, no dangling pointer
EOF

git -C "$REPO_NESTED" add CLAUDE.md .claude/rules
git -C "$REPO_NESTED" commit -q -m "fixture"

# The nested checkout itself: a second, independent repository living
# inside the first one's .claude/worktrees/.
git -C "$REPO_NESTED/.claude/worktrees/other-session" init -q -b nested
git -C "$REPO_NESTED/.claude/worktrees/other-session" config user.email "test@example.com"
git -C "$REPO_NESTED/.claude/worktrees/other-session" config user.name "Test"

cat > "$REPO_NESTED/.claude/worktrees/other-session/.claude/broken.md" <<EOF
See ${DC}/scripts/does-not-exist-nested-checkout.sh for details.
EOF

OUT_NESTED="$TMPDIR_ROOT/out-nested.txt"
(cd "$REPO_NESTED" && bash "$SCRIPT" --strict) > "$OUT_NESTED" 2>&1
EXIT_NESTED=$?

_assert_not_contains "nested git checkout: broken pointer inside it is not reported" \
  "$OUT_NESTED" "does-not-exist-nested-checkout.sh"

_assert_eq "nested git checkout: --strict exits 0 (the only dangling pointer is inside it)" \
  "$EXIT_NESTED" "0"

# ---------------------------------------------------------------- repo E
# node_modules under .claude/ with a broken pointer, left untracked (as a
# real node_modules tree normally is) so the prune cannot be relying on git
# to skip it.
REPO_NM="$TMPDIR_ROOT/repo-node-modules"
mkdir -p "$REPO_NM/.claude/rules" "$REPO_NM/.claude/node_modules/some-pkg"

git -C "$REPO_NM" init -q -b test
git -C "$REPO_NM" config user.email "test@example.com"
git -C "$REPO_NM" config user.name "Test"

cat > "$REPO_NM/${DC}/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

cat > "$REPO_NM/CLAUDE.md" <<'EOF'
# Test project

## Rules

- tracked-rule.md - a clean rule, no dangling pointer
EOF

git -C "$REPO_NM" add CLAUDE.md .claude/rules
git -C "$REPO_NM" commit -q -m "fixture"

cat > "$REPO_NM/.claude/node_modules/some-pkg/README.md" <<EOF
See ${DC}/scripts/does-not-exist-node-modules.sh for details.
EOF

OUT_NM="$TMPDIR_ROOT/out-node-modules.txt"
(cd "$REPO_NM" && bash "$SCRIPT" --strict) > "$OUT_NM" 2>&1
EXIT_NM=$?

_assert_not_contains "node_modules: broken pointer inside it is not reported" \
  "$OUT_NM" "does-not-exist-node-modules.sh"

_assert_eq "node_modules: --strict exits 0 (the only dangling pointer is inside it)" \
  "$EXIT_NM" "0"

# ---------------------------------------------------------------- repo F
# Performance regression lock: a gitignored directory with several thousand
# files, each carrying a broken pointer. Before the fix, check-index.sh
# shelled out to `git check-ignore` once per candidate file; on a real
# checkout with a stray worktree's node_modules (112k files) that took over
# two minutes. This directory is NOT node_modules and NOT a nested
# checkout, so it is not pruned by name or by an embedded .git — it can
# only be skipped through the batched `git check-ignore --stdin` call, so
# this is the case that actually exercises the fix rather than the prune.
#
# The ceiling is measured, not guessed: on this machine, 3000 files took
# ~32s with the old one-git-process-per-file approach and ~0.02s batched
# (see the PR description for the raw numbers). 30s gives wide margin for a
# slower CI machine while still being far below what the old approach would
# need for the same file count.
REPO_PERF="$TMPDIR_ROOT/repo-perf"
mkdir -p "$REPO_PERF/.claude/rules" "$REPO_PERF/.claude/big-ignored-dir"

git -C "$REPO_PERF" init -q -b test
git -C "$REPO_PERF" config user.email "test@example.com"
git -C "$REPO_PERF" config user.name "Test"

cat > "$REPO_PERF/.gitignore" <<'EOF'
big-ignored-dir/
EOF

cat > "$REPO_PERF/${DC}/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

cat > "$REPO_PERF/CLAUDE.md" <<'EOF'
# Test project

## Rules

- tracked-rule.md - a clean rule, no dangling pointer
EOF

git -C "$REPO_PERF" add .gitignore CLAUDE.md .claude/rules
git -C "$REPO_PERF" commit -q -m "fixture"

PERF_FILE_COUNT=3000
i=1
while [[ "$i" -le "$PERF_FILE_COUNT" ]]; do
  echo "See ${DC}/scripts/does-not-exist-perf-$i.sh for details." \
    > "$REPO_PERF/.claude/big-ignored-dir/file-$i.md"
  i=$((i + 1))
done

PERF_CEILING_SECONDS=30
PERF_START=$(date +%s)
OUT_PERF="$TMPDIR_ROOT/out-perf.txt"
(cd "$REPO_PERF" && bash "$SCRIPT" --strict) > "$OUT_PERF" 2>&1
EXIT_PERF=$?
PERF_END=$(date +%s)
PERF_ELAPSED=$((PERF_END - PERF_START))

_assert_not_contains "large gitignored dir: broken pointers are not reported" \
  "$OUT_PERF" "does-not-exist-perf-1.sh"

_assert_eq "large gitignored dir: --strict exits 0" "$EXIT_PERF" "0"

if [[ "$PERF_ELAPSED" -le "$PERF_CEILING_SECONDS" ]]; then
  _pass "large gitignored dir ($PERF_FILE_COUNT files) scanned in ${PERF_ELAPSED}s (ceiling ${PERF_CEILING_SECONDS}s)"
else
  _fail "large gitignored dir ($PERF_FILE_COUNT files) took ${PERF_ELAPSED}s, over the ${PERF_CEILING_SECONDS}s ceiling"
fi

# ---------------------------------------------------------------- repo G
# A symlinked directory whose target lives OUTSIDE the repo — exactly the
# shape of a project that linked the harness (.claude/agents ->
# baseline/agents in a different checkout). `git check-ignore` refuses a
# pathspec that goes "beyond a symbolic link" like that: it prints a fatal
# for that one line and the whole `--stdin` invocation exits non-zero, even
# though every other line in the same batch is still evaluated correctly.
# A genuinely gitignored file elsewhere in the same repo must still be
# suppressed — proving the fix trusts the batch's stdout, not its exit
# code, so one unrelated symlink doesn't undo the gitignore filtering for
# everything else in the run.
REPO_SYM="$TMPDIR_ROOT/repo-symlink"
EXT_TARGET="$TMPDIR_ROOT/external-agents-target"
mkdir -p "$REPO_SYM/.claude/rules" "$EXT_TARGET"

git -C "$REPO_SYM" init -q -b test
git -C "$REPO_SYM" config user.email "test@example.com"
git -C "$REPO_SYM" config user.name "Test"

cat > "$EXT_TARGET/some-agent.md" <<'EOF'
---
name: some-agent
description: lives outside the repo, reached only through a symlink
---
EOF

ln -s "$EXT_TARGET" "$REPO_SYM/.claude/agents"

cat > "$REPO_SYM/.gitignore" <<'EOF'
ignored-elsewhere.md
EOF

cat > "$REPO_SYM/${DC}/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

cat > "$REPO_SYM/CLAUDE.md" <<'EOF'
# Test project

## Rules

- tracked-rule.md - a clean rule, no dangling pointer

## Agents

- `some-agent` - lives outside the repo, reached only through a symlink
EOF

git -C "$REPO_SYM" add .gitignore CLAUDE.md .claude/rules
git -C "$REPO_SYM" commit -q -m "fixture"

# Gitignored, with a broken pointer, sitting alongside the symlinked dir in
# the same scan.
cat > "$REPO_SYM/.claude/ignored-elsewhere.md" <<EOF
See ${DC}/scripts/does-not-exist-past-symlink.sh for details.
EOF

OUT_SYM="$TMPDIR_ROOT/out-symlink.txt"
(cd "$REPO_SYM" && bash "$SCRIPT" --strict) > "$OUT_SYM" 2>&1
EXIT_SYM=$?

_assert_not_contains "gitignored file is still suppressed alongside a symlink pointing outside the repo" \
  "$OUT_SYM" "does-not-exist-past-symlink.sh"

_assert_eq "--strict exits 0 despite a symlink pointing outside the repo" \
  "$EXIT_SYM" "0"

# ---------------------------------------------------------------- repo H
# A fourth pointer category beyond docs/scripts: rules, skills and agents are
# the other three paths a consumer gets from linking the harness (rules
# namespaced under harness/, skills/agents linked one item at a time). A
# dangling pointer to any of the three used to survive --strict silently
# because the old regex only looked at the docs and scripts categories. One
# rule file carries a broken pointer into each of the three, plus a
# resolving one, to prove real hits still pass through.
REPO_RSA="$TMPDIR_ROOT/repo-rules-skills-agents"
mkdir -p "$REPO_RSA/.claude/rules"

git -C "$REPO_RSA" init -q -b test
git -C "$REPO_RSA" config user.email "test@example.com"
git -C "$REPO_RSA" config user.name "Test"

cat > "$REPO_RSA/${DC}/rules/other-real-rule.md" <<'EOF'
---
paths: "**"
---

A second real rule, referenced from pointer-check.md below to prove a
resolving .claude/rules/... pointer is not flagged.
EOF

cat > "$REPO_RSA/${DC}/rules/pointer-check.md" <<EOF
---
paths: "**"
---

Broken: see ${DC}/rules/does-not-exist-rule.md, ${DC}/skills/does-not-exist-skill
and ${DC}/agents/does-not-exist-agent.md for details.

Resolves fine: see ${DC}/rules/other-real-rule.md (a real file, above).
EOF

cat > "$REPO_RSA/CLAUDE.md" <<'EOF'
# Test project

## Rules

- pointer-check.md - a rule whose pointers are checked, some broken, some not
- other-real-rule.md - the rule pointer-check.md points at, which resolves
EOF

git -C "$REPO_RSA" add CLAUDE.md .claude/rules
git -C "$REPO_RSA" commit -q -m "fixture"

OUT_RSA="$TMPDIR_ROOT/out-rules-skills-agents.txt"
(cd "$REPO_RSA" && bash "$SCRIPT" --strict) > "$OUT_RSA" 2>&1
EXIT_RSA=$?

_assert_contains "rules pointer: broken .claude/rules/... is reported" \
  "$OUT_RSA" "does-not-exist-rule.md"

_assert_contains "skills pointer: broken .claude/skills/... is reported" \
  "$OUT_RSA" "does-not-exist-skill"

_assert_contains "agents pointer: broken .claude/agents/... is reported" \
  "$OUT_RSA" "does-not-exist-agent.md"

_assert_not_contains "rules pointer: a resolving .claude/rules/... is not flagged" \
  "$OUT_RSA" "— ${DC}/rules/other-real-rule.md"

_assert_eq "--strict exits 1 with three real dangling pointers present" \
  "$EXIT_RSA" "1"

# ---------------------------------------------------------------- repo I
# An agent referenced by name, not by file: an agents pointer with no `.md`
# extension (the file on disk always carries one). Reproduces a real rule in
# a consumer project (njord-front) that writes such a pointer inside a bold,
# backtick-quoted span. Written to avoid a literal, contiguous pointer-shaped
# path in this comment itself, for the same reason explained near the top of
# this file: check-index.sh's own scan would flag it against THIS repo. A
# genuinely broken agent pointer (no matching file either with or without
# `.md`) is the positive control.
REPO_AGENT="$TMPDIR_ROOT/repo-agent-name-pointer"
mkdir -p "$REPO_AGENT/.claude/agents" "$REPO_AGENT/.claude/rules"

git -C "$REPO_AGENT" init -q -b test
git -C "$REPO_AGENT" config user.email "test@example.com"
git -C "$REPO_AGENT" config user.name "Test"

cat > "$REPO_AGENT/.claude/agents/code-reviewer.md" <<'EOF'
---
name: code-reviewer
description: reviews implementation against spec, plan and conventions
---

Real agent, referenced elsewhere without its .md extension.
EOF

cat > "$REPO_AGENT/${DC}/rules/agent-name-pointer.md" <<EOF
---
paths: "**"
---

Referenced by name, no extension: **\`${DC}/agents/code-reviewer\`**.

Broken, no extension and no matching file either way:
${DC}/agents/does-not-exist-agent-noext for details.
EOF

cat > "$REPO_AGENT/CLAUDE.md" <<'EOF'
# Test project

## Agents

- `code-reviewer` - reviews implementation against spec, plan and conventions

## Rules

- agent-name-pointer.md - agent pointer without .md extension
EOF

git -C "$REPO_AGENT" add CLAUDE.md .claude/agents .claude/rules
git -C "$REPO_AGENT" commit -q -m "fixture"

OUT_AGENT="$TMPDIR_ROOT/out-agent-name-pointer.txt"
(cd "$REPO_AGENT" && bash "$SCRIPT" --strict) > "$OUT_AGENT" 2>&1
EXIT_AGENT=$?

_assert_not_contains "agent pointer without .md extension resolves, not flagged" \
  "$OUT_AGENT" "— ${DC}/agents/code-reviewer"

_assert_contains "agent pointer with no matching file at all is still reported (positive control)" \
  "$OUT_AGENT" "does-not-exist-agent-noext"

_assert_eq "--strict exits 1 with the positive control present" "$EXIT_AGENT" "1"

# ---------------------------------------------------------------- repo J
# Hook and script test fixtures write `.claude/...`-shaped strings as INPUT
# DATA for whatever they are testing, not as prose pointing an agent at
# something to read, and several of those strings are deliberately made up
# because the test needs a path that resolves to nothing. A file living
# under a directory literally named `tests` (.claude/hooks/tests/*.test.sh,
# .claude/scripts/tests/*.test.sh, mirroring baseline/hooks/tests and
# baseline/scripts/tests in the real harness repo) must never have its
# embedded pointers scanned. Positive control: a made-up pointer inside each
# tests/ fixture, must not surface. Negative control: the identical
# made-up pointer one directory up, outside tests/, so it is ordinary
# content rather than a fixture, and must still be reported — otherwise the
# exemption could just be disabling the pointer scan for hooks/scripts
# wholesale and this test would never notice.
REPO_TESTDIR="$TMPDIR_ROOT/repo-test-fixtures"
mkdir -p "$REPO_TESTDIR/.claude/rules" "$REPO_TESTDIR/.claude/hooks/tests" \
  "$REPO_TESTDIR/.claude/scripts/tests"

git -C "$REPO_TESTDIR" init -q -b test
git -C "$REPO_TESTDIR" config user.email "test@example.com"
git -C "$REPO_TESTDIR" config user.name "Test"

cat > "$REPO_TESTDIR/${DC}/rules/tracked-rule.md" <<'EOF'
---
paths: "**"
---

No dangling pointer here.
EOF

# Positive control: a hook test fixture, under .claude/hooks/tests/, using a
# made-up pointer as input data for the hook it tests. Must NOT surface.
cat > "$REPO_TESTDIR/.claude/hooks/tests/fake-hook.test.sh" <<EOF
#!/usr/bin/env bash
# Fixture path fed to the hook under test; deliberately does not resolve.
TARGET="${DC}/rules/does-not-exist-hook-fixture.md"
EOF

# Positive control: same shape, under .claude/scripts/tests/, covering the
# second tests/ location the fix must also exempt.
cat > "$REPO_TESTDIR/.claude/scripts/tests/fake-script.test.sh" <<EOF
#!/usr/bin/env bash
TARGET="${DC}/rules/does-not-exist-script-fixture.md"
EOF

# Negative control: the identical broken pointer, one directory up from
# tests/, so it is ordinary content rather than a test fixture. Must still
# surface.
cat > "$REPO_TESTDIR/.claude/hooks/not-a-test.sh" <<EOF
#!/usr/bin/env bash
TARGET="${DC}/rules/does-not-exist-nontests-fixture.md"
EOF
chmod +x "$REPO_TESTDIR/.claude/hooks/not-a-test.sh"

cat > "$REPO_TESTDIR/CLAUDE.md" <<'EOF'
# Test project

## Rules

- tracked-rule.md - a clean rule, no dangling pointer
EOF

git -C "$REPO_TESTDIR" add CLAUDE.md .claude/rules .claude/hooks .claude/scripts
git -C "$REPO_TESTDIR" commit -q -m "fixture"

OUT_TESTDIR="$TMPDIR_ROOT/out-test-fixtures.txt"
(cd "$REPO_TESTDIR" && bash "$SCRIPT" --strict) > "$OUT_TESTDIR" 2>&1
EXIT_TESTDIR=$?

_assert_not_contains "hooks/tests fixture pointer is not reported" \
  "$OUT_TESTDIR" "does-not-exist-hook-fixture.md"

_assert_not_contains "scripts/tests fixture pointer is not reported" \
  "$OUT_TESTDIR" "does-not-exist-script-fixture.md"

_assert_contains "same pointer outside tests/ is still reported (negative control)" \
  "$OUT_TESTDIR" "does-not-exist-nontests-fixture.md"

_assert_eq "--strict exits 1 with only the negative control present" "$EXIT_TESTDIR" "1"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
