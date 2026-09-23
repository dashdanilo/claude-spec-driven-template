#!/usr/bin/env bash
# repo-map.test.sh
# Standalone fixture suite for baseline/scripts/repo-map.sh. Builds a
# throwaway git repo in a mktemp dir with a shape deliberately chosen to
# exercise the parts that grew from real bugs found while building this
# script against njord-back: an intermediate directory with no direct files
# of its own (only nested subfolders), a spec-driven `specs/` folder that
# must NOT be reported as a test location, a `spec/` (singular) folder that
# SHOULD be, files ignored via .gitignore that must not appear anywhere in
# the output, and an AGENTS.md with a fenced command block to extract.
#
# Fixture repo is built on a throwaway branch name and renamed onto "main"
# afterwards (`git branch -m`), same reasoning as protect-main.test.sh: a
# session running this repo's own harness has protect-main.sh live on Bash,
# and a real `git commit` issued while already checked out on a protected
# name would get intercepted by the session's hook, not just avoided.
#
# Run: bash baseline/scripts/tests/repo-map.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT="$SCRIPT_DIR/../repo-map.sh"

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
    _fail "$label (expected: $expected, got: $actual)"
  fi
}

# --------------------------------------------------------------- build fixture
REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO"
cd "$REPO" || exit 99

git init -q -b tmp-setup
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p src/modules/brands src/modules/orders src/main-nested spec/unit test/cases specs/2026-01-01-example node_modules/left-pad dist
echo "console.log(1)" > src/main.ts
echo "export const brands = 1" > src/modules/brands/index.ts
echo "export const orders = 1" > src/modules/orders/index.ts
echo "some junk" > node_modules/left-pad/index.js
echo "built output" > dist/bundle.js
echo "unit test" > spec/unit/brands.spec.ts
echo "legacy test" > test/cases/legacy.test.js
echo "# feature spec, not test code" > specs/2026-01-01-example/spec.md
echo "node_modules/
dist/" > .gitignore

cat > AGENTS.md <<'EOF'
# fixture

## Build, test, lint

Some prose before the fence.

```bash
run-the-build
run-the-tests
```

## Structure
EOF

git add AGENTS.md .gitignore src spec test specs
git commit -q -m "fixture commit"
git branch -m main

# --------------------------------------------------------------------- run it
OUT="$TMPDIR_ROOT/out.md"
STDERR="$TMPDIR_ROOT/stderr.txt"
bash "$SCRIPT" --output "$OUT" 2> "$STDERR"
EXIT_CODE=$?

_assert_eq "exits 0" "$EXIT_CODE" "0"

# ----------------------------------------------------------------- assertions
_assert_contains "header has generated_at" "$OUT" "generated_at:"
_assert_contains "header has commit_sha" "$OUT" "commit_sha:"
_assert_contains "header has tracked_files count" "$OUT" "tracked_files: 8"

# gitignored content must never appear
_assert_not_contains "node_modules excluded" "$OUT" "left-pad"
_assert_not_contains "dist excluded" "$OUT" "bundle.js"

# an intermediate directory with only nested subfolders (no direct files of
# its own) must still show up in the tree, with a bubbled-up recursive count
_assert_contains "intermediate dir (src/modules) shows up with recursive count" "$OUT" "modules/ (2)"
_assert_contains "leaf module dir shown individually" "$OUT" "brands/ (1)"
_assert_contains "leaf module dir shown individually (2)" "$OUT" "orders/ (1)"

# entry point: main.ts yes, barrel index.ts no (would be all noise in a
# repo with one module per feature folder)
_assert_contains "main.ts recognized as entry point" "$OUT" "src/main.ts"
_assert_not_contains "barrel index.ts NOT listed as an entry point" "$OUT" "src/modules/brands/index.ts"

# test locations: singular spec/ yes, specs/ (plural, this template's own
# feature-spec convention) must NOT be reported as a test location
_assert_contains "singular spec/ reported as a test location" "$OUT" "spec/unit"
_assert_not_contains "plural specs/ NOT reported as a test location" "$OUT" "specs/2026-01-01-example"
_assert_contains "test/cases reported as a test location" "$OUT" "test/cases"

# commands lifted from AGENTS.md's fenced block under the matching heading
_assert_contains "command block extracted from AGENTS.md" "$OUT" "run-the-build"
_assert_not_contains "prose before the fence is not included" "$OUT" "Some prose before the fence"

# --------------------------------------------------------- stdout mode (no --output)
STDOUT_OUT="$TMPDIR_ROOT/stdout-capture.md"
bash "$SCRIPT" > "$STDOUT_OUT" 2>/dev/null
_assert_contains "stdout mode (no --output) still prints the map" "$STDOUT_OUT" "# Repo map"

# --------------------------------------------------------------- not a git repo
NOTGIT="$TMPDIR_ROOT/not-a-repo"
mkdir -p "$NOTGIT"
NOTGIT_EXIT=0
(cd "$NOTGIT" && bash "$SCRIPT" >/dev/null 2>&1) || NOTGIT_EXIT=$?
_assert_eq "exits 3 outside a git repository" "$NOTGIT_EXIT" "3"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
