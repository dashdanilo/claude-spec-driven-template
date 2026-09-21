#!/usr/bin/env bash
# protect-main.test.sh
# Standalone fixture suite for baseline/hooks/protect-main.sh. Builds two
# throwaway git repos in a mktemp dir (one on main, one on feature/x, each
# with two commits so `git merge-base --is-ancestor` has real revisions),
# feeds the hook the same JSON-on-stdin shape Claude Code sends
# (`{"tool_name":"Bash","tool_input":{"command":"..."}}`, per CONTRIBUTING.md),
# and asserts the exit code (2 = blocked, 0 = passes). 20 cases. Self-contained:
# no dependency on the developer's cwd, fixtures live under a mktemp dir
# removed on exit via trap.
#
# Each fixture repo is built on a throwaway branch name and renamed onto its
# final name (`git branch -m`) rather than created directly on `main`,
# because a session running this repo's own harness registers this very hook
# live on Bash — a real `git commit`/`git push` issued while building a
# fixture already checked out on `main` would get intercepted by the session's
# hook, not just by the copy under test. `git branch -m` is not in the
# dangerous-pattern list, so it passes. See
# .claude/agent-memory/implementer/feedback_hook-testing-in-harness-worktrees.md.
#
# Run: bash baseline/hooks/tests/protect-main.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../protect-main.sh"

# Resolve python3, falling back to python, the same way the hook itself does
# (some Windows shells only have `python` on PATH) rather than hardcoding
# python3 and failing this suite on exactly the machines the hook's own
# fallback was written for.
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "protect-main.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

MAIN_REPO="$TMPDIR_ROOT/repo-main"
FEATURE_REPO="$TMPDIR_ROOT/repo-feature"
MISSING_REPO="$TMPDIR_ROOT/does-not-exist"
NEUTRAL_CWD="$TMPDIR_ROOT"

_init_fixture_repo() {
  local dir="$1"
  local final_branch="$2"
  mkdir -p "$dir"
  git -C "$dir" init -q -b tmp-setup
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "one" > "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "first commit"
  echo "two" >> "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "second commit"
  git -C "$dir" branch -m tmp-setup "$final_branch"
}

_init_fixture_repo "$MAIN_REPO" "main"
_init_fixture_repo "$FEATURE_REPO" "feature/x"

MAIN_SHA1="$(git -C "$MAIN_REPO" rev-list --max-parents=0 HEAD)"
MAIN_SHA2="$(git -C "$MAIN_REPO" rev-parse HEAD)"

PASS_COUNT=0
FAIL_COUNT=0

_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1"
}

_run_case() {
  local name="$1"
  local cwd="$2"
  local cmd="$3"
  local expected="$4"

  local payload
  payload="$(_make_payload "$cmd")"

  local actual
  actual=$(
    cd "$cwd" || exit 99
    printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
    echo $?
  )

  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (exit $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# 1. git commit in a repo on main (cwd = that repo)
_run_case "1: git commit, cwd on main" \
  "$MAIN_REPO" 'git commit -m "x"' 2

# 2. git commit in a repo on feature/x
_run_case "2: git commit, cwd on feature/x" \
  "$FEATURE_REPO" 'git commit -m "x"' 0

# 3. cd <main-repo> && git commit -m "x"
_run_case "3: cd main-repo && git commit" \
  "$NEUTRAL_CWD" "cd $MAIN_REPO && git commit -m \"x\"" 2

# 4. multi-line cd <feature-repo> / git commit
_run_case "4: cd feature-repo (multi-line) then git commit" \
  "$NEUTRAL_CWD" "cd $FEATURE_REPO"$'\n''git commit -m "x"' 0

# 5. git -C <main-repo> commit
_run_case "5: git -C main-repo commit" \
  "$NEUTRAL_CWD" "git -C $MAIN_REPO commit -m \"x\"" 2

# 6. git -C <feature-repo> commit
_run_case "6: git -C feature-repo commit" \
  "$NEUTRAL_CWD" "git -C $FEATURE_REPO commit -m \"x\"" 0

# 7. git status in the repo on main
_run_case "7: git status, cwd on main" \
  "$MAIN_REPO" "git status" 0

# 8. gh pr merge --admin
_run_case "8: gh pr merge --admin" \
  "$NEUTRAL_CWD" "gh pr merge 1 --admin" 2

# 9. git -C <path-that-does-not-exist> commit
_run_case "9: git -C missing path commit" \
  "$NEUTRAL_CWD" "git -C $MISSING_REPO commit -m \"x\"" 0

# 10. accepted gap: from feature repo cwd, W=<main-repo>; cd $W && git commit
# Documented gap, NOT correct protection: the unresolved `cd $W` falls back
# to the hook's own cwd (feature/x, unprotected), so the real target (main)
# is never checked.
_run_case "10: [accepted gap, undetected] cwd feature, W=main-repo, cd \$W && commit" \
  "$FEATURE_REPO" "W=$MAIN_REPO"$'\n''cd $W && git commit -m "x"' 0

# 11. mirror of 10: from main repo cwd, W=<feature-repo>; cd $W && git commit
# Same documented gap, conservative direction: falls back to hook's own cwd
# (main, protected), so it blocks even though the real target is feature/x.
_run_case "11: [accepted gap, conservative] cwd main, W=feature-repo, cd \$W && commit" \
  "$MAIN_REPO" "W=$FEATURE_REPO"$'\n''cd $W && git commit -m "x"' 2

# 12. git push in the repo on main
_run_case "12: git push, cwd on main" \
  "$MAIN_REPO" "git push" 2

# 13. git reset --hard in the repo on main
_run_case "13: git reset --hard, cwd on main" \
  "$MAIN_REPO" "git reset --hard HEAD~1" 2

# 14. defect 1: merge-base is not merge
_run_case "14: [defect 1] git -C main-repo merge-base --is-ancestor" \
  "$NEUTRAL_CWD" "git -C $MAIN_REPO merge-base --is-ancestor $MAIN_SHA1 $MAIN_SHA2" 0

# 15. defect 1 control: git merge still blocked (anchoring didn't disarm it)
_run_case "15: [defect 1 control] git -C main-repo merge <sha>" \
  "$NEUTRAL_CWD" "git -C $MAIN_REPO merge $MAIN_SHA2" 2

# 16. defect 2, order A: read-only first git on main, then cd into feature
# and push there with a bare `git push` (no -C). This is the shape that
# actually reproduces the false positive on the old hook: the old hook
# resolves ONE target from the first git invocation (main, via -C) and
# ignores the `cd` that follows a git line entirely, then matches the
# dangerous patterns against the whole command text, where the bare "git
# push" on the last line matches unconditionally, blocking a push that
# actually targets the unprotected feature repo.
_run_case "16: [defect 2, order A] rev-parse on main, cd to feature, bare push" \
  "$NEUTRAL_CWD" "git -C $MAIN_REPO rev-parse HEAD"$'\n'"cd $FEATURE_REPO"$'\n'"git push" 0

# 17. defect 2, order B: read-only first git on feature, then push to main
_run_case "17: [defect 2, order B] status on feature then push on main" \
  "$NEUTRAL_CWD" "git -C $FEATURE_REPO status"$'\n'"git -C $MAIN_REPO push" 2

# 18. per-invocation cd: cd feature, commit a, cd main, commit b -> retargeted
_run_case "18: [per-invocation cd] feature commit then main commit" \
  "$NEUTRAL_CWD" "cd $FEATURE_REPO"$'\n''git commit -m "a"'$'\n'"cd $MAIN_REPO"$'\n''git commit -m "b"' 2

# 19. reverse of 18: cd main, status, cd feature, commit -> retargeted, clean
_run_case "19: [per-invocation cd] main status then feature commit" \
  "$NEUTRAL_CWD" "cd $MAIN_REPO"$'\n''git status'$'\n'"cd $FEATURE_REPO"$'\n''git commit -m "b"' 0

# 20. defect 2, order A, explicit-C shape. NOT a reproduction: the old hook's
# whole-command regex never saw this either, because only the FIRST git
# line's `-C` was stripped before matching, so 'git\s+push' could not match
# 'git -C <feature-repo> push' (after "git" comes " -C", not "push") on the
# old hook any more than on the new one. Asserted here so the per-invocation
# walk is proven to keep this explicit-C shape passing, not to catch a
# regression that never existed for it.
_run_case "20: [defect 2, order A, explicit -C shape, not a reproduction] rev-parse on main then -C push on feature" \
  "$NEUTRAL_CWD" "git -C $MAIN_REPO rev-parse HEAD"$'\n'"git -C $FEATURE_REPO push" 0

# 21-29: defect 3, ff-only merge of a protected branch's own upstream. The
# hook never runs `git merge`, only inspects the command text, so none of
# these need a real `origin` remote configured on the fixture repos.

# 21. the reported bug: --ff-only update from the branch's own upstream is
# exactly what `git pull --ff-only` does and cannot create a commit. Now
# exempted.
_run_case "21: [defect 3] git merge --ff-only origin/main, cwd on main" \
  "$MAIN_REPO" "git merge --ff-only origin/main" 0

# 22. control: same target, no --ff-only. Still blocked — --ff-only is the
# part of the exemption that guarantees no commit can be created.
_run_case "22: [defect 3 control] git merge origin/main (no --ff-only), cwd on main" \
  "$MAIN_REPO" "git merge origin/main" 2

# 23. control: --ff-only, but the target is NOT the branch's own upstream.
# Still blocked — the exemption is upstream-only, not any ff-only merge.
_run_case "23: [defect 3 control] git merge --ff-only feature/x, cwd on main" \
  "$MAIN_REPO" "git merge --ff-only feature/x" 2

# 24. @{u} shorthand for the current branch's upstream.
_run_case "24: [defect 3] git merge --ff-only @{u}, cwd on main" \
  "$MAIN_REPO" 'git merge --ff-only @{u}' 0

# 25. @{upstream}, the long form of the same shorthand.
_run_case "25: [defect 3] git merge --ff-only @{upstream}, cwd on main" \
  "$MAIN_REPO" 'git merge --ff-only @{upstream}' 0

# 26. octopus shape: two targets. Still blocked — "the single merge target"
# is part of the exemption, not any --ff-only merge that happens to include
# the upstream among several refs.
_run_case "26: [defect 3 control] git merge --ff-only origin/main origin/other, cwd on main" \
  "$MAIN_REPO" "git merge --ff-only origin/main origin/other" 2

# 27. explicit -C shape: the exemption applies after -C is stripped, same as
# every other pattern.
_run_case "27: [defect 3] git -C main-repo merge --ff-only origin/main" \
  "$NEUTRAL_CWD" "git -C $MAIN_REPO merge --ff-only origin/main" 0

# 28. compound command: the exempted merge does not clear a later, real
# merge in the same command — each invocation is still checked on its own.
_run_case "28: [defect 3] compound: ff-only upstream merge, then a real merge" \
  "$MAIN_REPO" 'git merge --ff-only origin/main && git merge feature/x' 2

# 29. git pull --ff-only itself was never in the dangerous-pattern list and
# always passed; asserted here next to 21 so the contrast the bug report
# drew (pull allowed, equivalent merge blocked) is pinned as a regression
# test, not just prose.
_run_case "29: [defect 3, contrast] git pull --ff-only, cwd on main" \
  "$MAIN_REPO" "git pull --ff-only" 0

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
