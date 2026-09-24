#!/usr/bin/env bash
# protect-unpushed.test.sh
# Standalone fixture suite for baseline/hooks/protect-unpushed.sh. Builds one
# throwaway git repo in a mktemp dir with a real bare "remote" (so pushed vs.
# unpushed is a real distinction, not a stand-in), feeds the hook the same
# JSON-on-stdin shape Claude Code sends, and asserts the exit code (2 =
# blocked, 0 = passes).
#
# The hook resolves paths from the payload's own "cwd", never from the
# process's own directory (see the hook's header for why: a real session
# runs it from an arbitrary feature worktree, not from wherever the hook
# happens to execute). Every case below runs the hook's PROCESS from
# $OUTSIDE_DIR, a directory that is neither a git repo nor any fixture,
# and carries the actual target only through the payload's "cwd" field —
# on purpose, so a bug that resolves against the process cwd instead of
# the payload's cannot hide behind the two happening to be the same
# directory, which is exactly how an earlier version of this hook read
# its own harness checkout instead of the fixture and passed uninspected.
# The ONE case that puts the process inside a fixture on purpose (to prove
# the fallback used when a payload omits "cwd" entirely still works) says
# so explicitly in its name, it is not the suite's default shape.
#
# Same precaution as protect-main.test.sh: the fixture repo is built on a
# throwaway branch name and renamed onto "main" (`git branch -m`) rather than
# created directly on it, because a session running this repo's own harness
# registers protect-main.sh live on Bash — committing on a branch already
# named "main" would risk being intercepted by that guard, not just by the
# hook under test here. See
# .claude/agent-memory/implementer/feedback_hook-testing-in-harness-worktrees.md.
# Invoking this whole file as `bash protect-unpushed.test.sh` (one Bash tool
# call) keeps every git command inside it off the outer session's radar
# either way, this just matches the sibling suite's belt-and-suspenders style.
#
# Run: bash baseline/hooks/tests/protect-unpushed.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../protect-unpushed.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "protect-unpushed.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
# Canonicalize: on macOS, mktemp -d returns a /var/folders path that is
# itself a symlink to /private/var/folders. Bash's cd doesn't resolve it,
# but a subprocess doing its own path resolution might, so every fixture
# path built below starts from the resolved form.
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

REMOTE="$TMPDIR_ROOT/remote.git"
MAIN_REPO="$TMPDIR_ROOT/main-repo"
OUTSIDE_DIR="$TMPDIR_ROOT"

git init -q --bare "$REMOTE"

mkdir -p "$MAIN_REPO"
git -C "$MAIN_REPO" init -q -b tmp-setup
git -C "$MAIN_REPO" config user.email "test@example.com"
git -C "$MAIN_REPO" config user.name "Test"
git -C "$MAIN_REPO" remote add origin "$REMOTE"
echo "one" > "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -q -m "first commit"
git -C "$MAIN_REPO" branch -m tmp-setup main
git -C "$MAIN_REPO" push -q -u origin main

# feat/unpushed-danger: real commit, never pushed, content nowhere else.
git -C "$MAIN_REPO" checkout -q -b feat/unpushed-danger
echo "danger" >> "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -q -m "unpushed danger"
git -C "$MAIN_REPO" checkout -q main

# feat/fully-pushed: committed AND pushed.
git -C "$MAIN_REPO" checkout -q -b feat/fully-pushed
echo "pushed" >> "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -q -m "fully pushed work"
git -C "$MAIN_REPO" push -q -u origin feat/fully-pushed
git -C "$MAIN_REPO" checkout -q main

# feat/squashed-orphan: squash-merged into main, its own commits are now
# orphaned (never reachable from main), but its content already landed.
git -C "$MAIN_REPO" checkout -q -b feat/squashed-orphan
echo "squashed" >> "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -q -m "squashed work"
git -C "$MAIN_REPO" checkout -q main
git -C "$MAIN_REPO" merge -q --squash feat/squashed-orphan >/dev/null
git -C "$MAIN_REPO" commit -q -m "feat: squashed work (#1)"
git -C "$MAIN_REPO" push -q origin main

# feat/wt-target: pushed branch used to back two worktrees below.
git -C "$MAIN_REPO" branch feat/wt-target main
git -C "$MAIN_REPO" push -q -u origin feat/wt-target

WT_DIRTY="$TMPDIR_ROOT/wt-dirty"
git -C "$MAIN_REPO" worktree add -q "$WT_DIRTY" feat/wt-target
echo "not committed" > "$WT_DIRTY/dirty.txt"

WT_CLEAN="$TMPDIR_ROOT/wt-clean"
git -C "$MAIN_REPO" branch feat/wt-clean main
git -C "$MAIN_REPO" push -q -u origin feat/wt-clean
git -C "$MAIN_REPO" worktree add -q "$WT_CLEAN" feat/wt-clean

# WT_FEATURE: D4 fixture. A real worktree, distinct from the main checkout
# (MAIN_REPO), carrying a commit made and left INSIDE the worktree itself,
# never pushed, and reachable from no other ref. The real harness shape:
# one worktree per feature, an agent working from inside it.
WT_FEATURE="$TMPDIR_ROOT/wt-feature"
git -C "$MAIN_REPO" branch feat/wt-only-commit main
git -C "$MAIN_REPO" worktree add -q "$WT_FEATURE" feat/wt-only-commit
echo "wt exclusive" >> "$WT_FEATURE/file.txt"
git -C "$WT_FEATURE" add file.txt
git -C "$WT_FEATURE" commit -q -m "wt exclusive work"

# NOREMOTE_REPO: no origin at all, and "rascunho" branched off "trabalho"
# shares trabalho's own commit as a common ancestor. D1/D2/D3 fixture: the
# only commit that is actually exclusive to rascunho is its own, "base" on
# trabalho stays reachable there regardless of the delete, and the repo has
# nowhere to push to at all.
NOREMOTE_REPO="$TMPDIR_ROOT/noremote-repo"
mkdir -p "$NOREMOTE_REPO"
git -C "$NOREMOTE_REPO" init -q -b tmp-setup
git -C "$NOREMOTE_REPO" config user.email "test@example.com"
git -C "$NOREMOTE_REPO" config user.name "Test"
echo "base" > "$NOREMOTE_REPO/file.txt"
git -C "$NOREMOTE_REPO" add file.txt
git -C "$NOREMOTE_REPO" commit -q -m "base"
git -C "$NOREMOTE_REPO" branch -m tmp-setup trabalho
git -C "$NOREMOTE_REPO" checkout -q -b rascunho
echo "draft" >> "$NOREMOTE_REPO/file.txt"
git -C "$NOREMOTE_REPO" add file.txt
git -C "$NOREMOTE_REPO" commit -q -m "rascunho descartavel"
git -C "$NOREMOTE_REPO" checkout -q trabalho

# F1 fixtures: three shapes that produce a numstat line of "0<TAB>0<TAB>path"
# (nothing added, nothing removed) despite the branch genuinely holding a
# change nowhere else: a pure rename, a newly added empty file, and a
# mode-only chmod. Never pushed. rename-only and chmod-only get their OWN
# dedicated baseline files (rename-src.txt, chmod-target.txt), committed and
# pushed to main before either branch exists: sharing file.txt with the F2
# fixtures below (which push further, unrelated commits to main afterward)
# would otherwise contaminate the "pure 0/0" property this test needs, since
# git diff would then also see the unrelated later content drift on that
# same path and stop reporting a clean 0/0 (reproduced while building this
# fixture: feat/chmod-only's own numstat came back as "0 1 file.txt" once F2
# pushed a change to file.txt after this branch already existed).
echo "rename me" > "$MAIN_REPO/rename-src.txt"
echo "chmod me" > "$MAIN_REPO/chmod-target.txt"
git -C "$MAIN_REPO" add rename-src.txt chmod-target.txt
git -C "$MAIN_REPO" commit -q -m "add F1 baseline files"
git -C "$MAIN_REPO" push -q origin main

git -C "$MAIN_REPO" checkout -q -b feat/rename-only main
git -C "$MAIN_REPO" mv rename-src.txt rename-dst.txt
git -C "$MAIN_REPO" commit -q -m "rename rename-src.txt"
git -C "$MAIN_REPO" checkout -q main

git -C "$MAIN_REPO" checkout -q -b feat/empty-file main
touch "$MAIN_REPO/empty.txt"
git -C "$MAIN_REPO" add empty.txt
git -C "$MAIN_REPO" commit -q -m "add empty file"
git -C "$MAIN_REPO" checkout -q main

git -C "$MAIN_REPO" checkout -q -b feat/chmod-only main
chmod +x "$MAIN_REPO/chmod-target.txt"
git -C "$MAIN_REPO" add chmod-target.txt
git -C "$MAIN_REPO" commit -q -m "chmod +x chmod-target.txt"
git -C "$MAIN_REPO" checkout -q main

# F2 fixture 1: one-commit branch, squash-merged, then integration advances
# on the EXACT line the branch touched. numstat alone false-positives here
# (compares current tips, sees the later integration edit as "missing"
# branch content); cherry must catch it, since a patch-id is fixed to the
# historical commit and does not move when integration advances afterward.
git -C "$MAIN_REPO" checkout -q -b feat/f2-one main
echo "f2 one work" >> "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -q -m "f2 one work"
git -C "$MAIN_REPO" checkout -q main
git -C "$MAIN_REPO" merge -q --squash feat/f2-one >/dev/null
git -C "$MAIN_REPO" commit -q -m "feat: f2 one work (#3)"
python3 - "$MAIN_REPO/file.txt" <<'PY'
import sys
p = sys.argv[1]
with open(p) as f:
    lines = f.readlines()
lines[-1] = "f2 one work, edited later on integration\n"
with open(p, "w") as f:
    f.writelines(lines)
PY
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -q -m "integration edits the line feat/f2-one touched"
git -C "$MAIN_REPO" push -q origin main

# F2 fixture 2: three commits squashed into one. The squash commit's single
# combined patch-id matches none of the three original commits' individual
# patch-ids, so cherry alone false-positives here; numstat (content, not
# per-commit patches) must catch it instead.
git -C "$MAIN_REPO" checkout -q -b feat/f2-three main
echo "f2c1" >> "$MAIN_REPO/g.txt"
git -C "$MAIN_REPO" add g.txt
git -C "$MAIN_REPO" commit -q -m "f2 c1"
echo "f2c2" >> "$MAIN_REPO/g.txt"
git -C "$MAIN_REPO" add g.txt
git -C "$MAIN_REPO" commit -q -m "f2 c2"
echo "f2c3" >> "$MAIN_REPO/g.txt"
git -C "$MAIN_REPO" add g.txt
git -C "$MAIN_REPO" commit -q -m "f2 c3"
git -C "$MAIN_REPO" checkout -q main
git -C "$MAIN_REPO" merge -q --squash feat/f2-three >/dev/null
git -C "$MAIN_REPO" commit -q -m "feat: f2 three work squashed (#4)"
git -C "$MAIN_REPO" push -q origin main

# F3 fixture: a separate, isolated repo whose origin/HEAD is a symref
# pointing at a remote-tracking ref that does not exist (the real shape of
# an upstream default branch renamed or deleted after clone, not
# hypothetical). A genuinely safe, squash-merged branch must still resolve
# the integration branch via the main/master/trunk/develop fallback and
# pass, not block on a dangling ref it cannot diff against.
F3_REMOTE="$TMPDIR_ROOT/f3-remote.git"
git init -q --bare "$F3_REMOTE"
F3_REPO="$TMPDIR_ROOT/f3-repo"
mkdir -p "$F3_REPO"
git -C "$F3_REPO" init -q -b tmp-setup
git -C "$F3_REPO" config user.email "test@example.com"
git -C "$F3_REPO" config user.name "Test"
git -C "$F3_REPO" remote add origin "$F3_REMOTE"
echo "one" > "$F3_REPO/f.txt"
git -C "$F3_REPO" add f.txt
git -C "$F3_REPO" commit -q -m "first commit"
git -C "$F3_REPO" branch -m tmp-setup main
git -C "$F3_REPO" push -q -u origin main
git -C "$F3_REPO" checkout -q -b feat/f3-safe
echo "two" >> "$F3_REPO/f.txt"
git -C "$F3_REPO" add f.txt
git -C "$F3_REPO" commit -q -m "f3 safe work"
git -C "$F3_REPO" checkout -q main
git -C "$F3_REPO" merge -q --squash feat/f3-safe >/dev/null
git -C "$F3_REPO" commit -q -m "feat: f3 safe work (#5)"
git -C "$F3_REPO" push -q origin main
git -C "$F3_REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/gone-branch

PASS_COUNT=0
FAIL_COUNT=0

# The payload's own "cwd" carries the target directory; this is the only
# channel the hook is supposed to read it from (see file header).
_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$2"
}

# For the one explicit case that exercises the fallback used when a real
# payload omits "cwd" entirely.
_make_payload_no_cwd() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1"
}

# The hook's PROCESS always runs from $OUTSIDE_DIR here, never from
# $payload_cwd: only the payload's "cwd" field carries the target. See the
# file header for why running the process itself inside the fixture would
# defeat the point of this suite.
_run_case() {
  local name="$1"
  local payload_cwd="$2"
  local cmd="$3"
  local expected="$4"

  local payload
  payload="$(_make_payload "$cmd" "$payload_cwd")"

  local actual
  actual=$(
    cd "$OUTSIDE_DIR" || exit 99
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

# Same as _run_case but also asserts the blocked message (stderr) contains a
# substring, so "the message cites the commits" is pinned, not just the
# exit code.
_run_case_msg() {
  local name="$1"
  local payload_cwd="$2"
  local cmd="$3"
  local expected="$4"
  local must_contain="$5"

  local payload
  payload="$(_make_payload "$cmd" "$payload_cwd")"

  local stderr_out actual
  stderr_out=$(cd "$OUTSIDE_DIR" && printf '%s' "$payload" | bash "$HOOK" 2>&1 >/dev/null)
  actual=$(cd "$OUTSIDE_DIR" && printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>/dev/null; echo $?)

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $name (expected exit $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if [[ "$expected" == "2" ]] && ! printf '%s' "$stderr_out" | grep -qF "$must_contain"; then
    echo "FAIL: $name (exit ok, but message missing '$must_contain')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  echo "PASS: $name (exit $actual)"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# 1. branch with unpushed commits, content absent from main -> blocked, and
# the message cites the actual commit.
_run_case_msg "1: git branch -D on unpushed-danger cites the commit" \
  "$MAIN_REPO" "git branch -D feat/unpushed-danger" 2 "unpushed danger"

# 2. branch entirely pushed -> passes.
_run_case "2: git branch -D on fully-pushed branch" \
  "$MAIN_REPO" "git branch -D feat/fully-pushed" 0

# 3. branch already squash-merged, orphan commits -> passes. This is the
# case that matters most: if it blocks, the guard is noise on every merged
# PR in a squash-merge repo.
_run_case "3: git branch -D on squash-merged orphan branch" \
  "$MAIN_REPO" "git branch -D feat/squashed-orphan" 0

# 4. same dangerous scenario as 1, lowercase -d.
_run_case "4: git branch -d (lowercase) on unpushed-danger" \
  "$MAIN_REPO" "git branch -d feat/unpushed-danger" 2

# 5. -r/--remotes: deleting a local remote-tracking ref never loses work.
# Deliberately targets feat/unpushed-danger, a branch that genuinely fails
# the safety check (case 1 blocks it), so this exercises the -r exemption
# itself: without it, this would block; passing here is not a coincidence
# of the target not existing (F4, a mutant removing the -r exemption
# entirely used to survive against "origin/does-not-exist", which the
# pre-existing "branch must exist locally" check already skips on its own).
_run_case "5: git branch -r -d feat/unpushed-danger (exemption, not existence)" \
  "$MAIN_REPO" "git branch -r -d feat/unpushed-danger" 0

# 6. worktree with uncommitted changes -> blocked.
_run_case "6: git worktree remove, dirty worktree" \
  "$MAIN_REPO" "git worktree remove $WT_DIRTY" 2

# 7. same, --force -> still blocked, force is exactly what would lose it.
_run_case "7: git worktree remove --force, dirty worktree" \
  "$MAIN_REPO" "git worktree remove --force $WT_DIRTY" 2

# 8. clean worktree, branch pushed -> passes.
_run_case "8: git worktree remove, clean worktree" \
  "$MAIN_REPO" "git worktree remove $WT_CLEAN" 0

# 9. not a delete at all. 9a and 9b deliberately carry a positional token
# that IS an existing, genuinely unsafe branch name (feat/unpushed-danger),
# so a mutant that forces _bd_is_delete=1 regardless of the actual flags
# would try to safety-check it and block (F4: the previous "git branch"/
# "git branch -a" commands had no branch-name positional at all, so
# _bd_branches stayed empty and such a mutant survived undetected — forcing
# the delete flag on an empty list is a no-op either way, the test wasn't
# exercising the flag at all).
_run_case "9a: git branch <existing-branch> (no delete flag)" \
  "$MAIN_REPO" "git branch feat/unpushed-danger" 0
_run_case "9b: git branch -a <existing-branch> (no delete flag)" \
  "$MAIN_REPO" "git branch -a feat/unpushed-danger" 0
_run_case "9c: git status" \
  "$MAIN_REPO" "git status" 0

# 10. malformed / unresolvable input never blocks.
actual_10a=$(cd "$OUTSIDE_DIR" && echo '{"tool_name":"Bash","tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ "$actual_10a" == "0" ]]; then
  echo "PASS: 10a: malformed payload, no command key (exit 0)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 10a: malformed payload, no command key (expected 0, got $actual_10a)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

actual_10b=$(cd "$OUTSIDE_DIR" && printf '' | bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ "$actual_10b" == "0" ]]; then
  echo "PASS: 10b: closed/empty stdin (exit 0)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 10b: closed/empty stdin (expected 0, got $actual_10b)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

_run_case "10c: outside any git repo" \
  "$OUTSIDE_DIR" "git branch -D feat/unpushed-danger" 0

# 11 (D1). rascunho's "base" commit stays reachable from trabalho after the
# delete, only its own commit is exclusive. The message must cite that one
# commit and must NOT cite "base".
stderr_11=$(cd "$OUTSIDE_DIR" && printf '%s' "$(_make_payload "git branch -D rascunho" "$NOREMOTE_REPO")" | bash "$HOOK" 2>&1 >/dev/null)
exit_11=$(cd "$OUTSIDE_DIR" && printf '%s' "$(_make_payload "git branch -D rascunho" "$NOREMOTE_REPO")" | bash "$HOOK" >/dev/null 2>/dev/null; echo $?)
if [[ "$exit_11" == "2" ]] && printf '%s' "$stderr_11" | grep -qF "rascunho descartavel" \
   && ! printf '%s' "$stderr_11" | grep -qE '\bbase$'; then
  echo "PASS: 11 (D1): message cites only the commit exclusive to rascunho"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 11 (D1): expected exit 2 citing only 'rascunho descartavel', got exit $exit_11"
  echo "$stderr_11"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 12 (D2). No remote configured: the message must not suggest a push (there
# is no "origin" to push to) and must offer the tag-archive alternative.
if printf '%s' "$stderr_11" | grep -qF "no remote configured" \
   && printf '%s' "$stderr_11" | grep -qF "git -C $NOREMOTE_REPO tag archive/rascunho rascunho" \
   && ! printf '%s' "$stderr_11" | grep -qF "push -u origin"; then
  echo "PASS: 12 (D2): no-remote message offers tag-archive, not an impossible push"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 12 (D2): no-remote message did not offer the right alternative"
  echo "$stderr_11"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 13 (D3, side A). Without the escape hatch, the same genuinely-local-only
# delete is still blocked.
_run_case "13 (D3 side A): rascunho delete blocked without the escape hatch" \
  "$NOREMOTE_REPO" "git branch -D rascunho" 2

# 14 (D3, side B). With the escape hatch inline, it passes.
_run_case "14 (D3 side B): HARNESS_ALLOW_UNPUSHED_DELETE=1 inline passes" \
  "$NOREMOTE_REPO" "HARNESS_ALLOW_UNPUSHED_DELETE=1 git branch -D rascunho" 0

# 15 (D3, side B variant). As its own segment earlier in the command, same
# as a literal cd, it persists for the git invocation that follows.
_run_case "15 (D3 side B, standalone segment): escape hatch persists like cd" \
  "$NOREMOTE_REPO" 'HARNESS_ALLOW_UNPUSHED_DELETE=1 && git branch -D rascunho' 0

# 16 (D3 control). HARNESS_ALLOW_UNPUSHED_DELETE=0 does NOT count as opted in.
_run_case "16 (D3 control): HARNESS_ALLOW_UNPUSHED_DELETE=0 still blocks" \
  "$NOREMOTE_REPO" "HARNESS_ALLOW_UNPUSHED_DELETE=0 git branch -D rascunho" 2

# 17. Reflog reassurance line: present, and its recovery command carries the
# branch's real tip SHA.
tip_sha_17=$(git -C "$NOREMOTE_REPO" rev-parse rascunho)
if printf '%s' "$stderr_11" | grep -qF "does not destroy these commits right away" \
   && printf '%s' "$stderr_11" | grep -qF "through the reflog until garbage collection" \
   && printf '%s' "$stderr_11" | grep -qF "git -C $NOREMOTE_REPO branch rascunho $tip_sha_17"; then
  echo "PASS: 17: reflog reassurance line carries the real recovery SHA"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 17: reflog reassurance line missing or wrong SHA"
  echo "$stderr_11"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 18 (D4). The real harness scenario: the process runs from OUTSIDE_DIR
# (neither the main checkout nor the worktree), and the payload's "cwd"
# points at a feature WORKTREE that is not the main checkout. Only a commit
# made inside that worktree, and reachable from no other ref, should block.
_run_case "18 (D4): payload cwd targets a worktree, not the main checkout" \
  "$WT_FEATURE" "git branch -D feat/wt-only-commit" 2

# 19 (D4, explicit fallback case). The ONE case in this suite that puts the
# hook's process INSIDE a fixture on purpose: a payload that omits "cwd"
# entirely (an old or malformed one) must still fall back to the process's
# own directory rather than passing everything uninspected.
payload_19="$(_make_payload_no_cwd "git branch -D rascunho")"
actual_19=$(cd "$NOREMOTE_REPO" && printf '%s' "$payload_19" | bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ "$actual_19" == "2" ]]; then
  echo "PASS: 19 (D4 explicit fallback): payload without cwd falls back to process cwd (exit 2)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 19 (D4 explicit fallback): expected exit 2, got $actual_19"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 20-22 (F1). A delta-zero numstat line (rename, new empty file, chmod)
# must still block: each of these branches genuinely holds a change nowhere
# else, and the old "added -gt 0" check alone let all three through.
_run_case "20 (F1): rename-only branch, numstat shows 0/0" \
  "$MAIN_REPO" "git branch -D feat/rename-only" 2
_run_case "21 (F1): new empty file branch, numstat shows 0/0" \
  "$MAIN_REPO" "git branch -D feat/empty-file" 2
_run_case "22 (F1): chmod-only branch, numstat shows 0/0" \
  "$MAIN_REPO" "git branch -D feat/chmod-only" 2

# 23 (F2, side A). One-commit branch, squash-merged, integration later edits
# the exact line the branch touched. numstat alone would false-positive
# (blocked); cherry must catch it since patch-id doesn't move.
_run_case "23 (F2 side A): squash-merged, integration edits the same line later" \
  "$MAIN_REPO" "git branch -D feat/f2-one" 0

# 24 (F2, side B). Three commits squashed into one: cherry alone would
# false-positive (each original patch-id differs from the combined squash
# commit's), numstat (content-based) must still resolve it.
_run_case "24 (F2 side B): three commits squashed into one" \
  "$MAIN_REPO" "git branch -D feat/f2-three" 0

# 25 (F3). origin/HEAD dangling at a remote-tracking ref that does not
# exist: a genuinely safe, squash-merged branch must still resolve the
# integration branch via the fallback and pass, not block on a ref it
# cannot diff against.
_run_case "25 (F3): dangling origin/HEAD falls back, safe branch passes" \
  "$F3_REPO" "git branch -D feat/f3-safe" 0

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
