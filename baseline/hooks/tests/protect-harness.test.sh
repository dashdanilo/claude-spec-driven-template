#!/usr/bin/env bash
# protect-harness.test.sh
# Standalone fixture suite for baseline/hooks/protect-harness.sh. Feeds the
# hook synthetic JSON-on-stdin payloads shaped like Claude Code's Edit/Write
# PreToolUse calls (`{"tool_input":{"file_path":"..."}}`) and asserts the exit
# code (2 = blocked, 0 = passes).
#
# The hook judges every governance path (`.claude/settings*.json`,
# `baseline/hooks/*.sh`, `.claude/hooks/*.sh`, `baseline/rules/**`,
# `.claude/rules/**`) by ONE rule, not two:
#
#   1. cwd repo != target repo AND the target is inside a HARNESS CHECKOUT
#      (a repo root with both install-harness.sh and a baseline/ directory)
#      -> blocked, regardless of which repo the session started in — that
#      one repo is live everywhere it is linked, with no commit and no
#      reviewer, the moment it is edited
#   2. cwd repo != target repo AND the target is an ORDINARY consuming
#      project's own tracked governance file -> passes — it is reviewable
#      exactly like a same-repo edit, in THAT project's own diff and PR
#   3. the target is gitignored in its own repo (same-repo or cross-repo) ->
#      blocked (invisible to any reviewer — never shows up in `git diff` or
#      a PR there)
#   4. otherwise -> passes (tracked, or new-and-not-yet-ignored: either way
#      it lands in a commit and a diff someone reviews)
#
# That collapsed an earlier two-group split (config blocked unconditionally,
# source blocked only cross-repo) that was judging reviewability by WHICH
# FILE it was rather than whether a human would ever see the change, and
# later loosened the cross-repo rule again: it used to block ANY cross-repo
# edit, which also caught a consuming project's own tracked governance file
# edited from a session rooted elsewhere — reviewable, just not same-repo.
# Fixture repos build an explicit per-repo `.gitignore` for
# `.claude/settings.local.json` rather than relying on any ignore rule
# inherited from outside the disposable repo, since the whole point of the
# rule is that gitignore status is resolved with `git check-ignore`, not
# guessed.
#
# Real git fixtures (built under a mktemp dir, removed on exit via trap —
# never inside a real repo): REPO_A/REPO_D are harness checkouts (each has
# its own install-harness.sh + baseline/), REPO_B is an ordinary consuming
# project (no install-harness.sh), a worktree of REPO_A (a worktree of the
# SAME repo must count as the same repo, not a different one, even though
# `git rev-parse --show-toplevel` would report a different path for it), a
# PATH with no `git` (degradation), and a PATH whose `git` shim makes
# `check-ignore` fail with exit 128 (degradation).
#
# Run: bash baseline/hooks/tests/protect-harness.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../protect-harness.sh"

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
  echo "protect-harness.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

REAL_GIT="$(command -v git 2>/dev/null)"
if [[ -z "$REAL_GIT" ]]; then
  echo "protect-harness.test.sh: no git on PATH, cannot build fixture repos" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# --- disposable git repos ---

REPO_A="$TMPDIR_ROOT/repo-a"          # a harness checkout (gets install-harness.sh below)
REPO_B="$TMPDIR_ROOT/repo-b"          # an ORDINARY consuming project (e.g. njord-back) — no install-harness.sh
REPO_D="$TMPDIR_ROOT/repo-d"          # a SECOND, unrelated harness checkout — proves detection is structural, not "whichever repo happens to be REPO_A"
NO_GIT_CWD="$TMPDIR_ROOT/no-git-cwd"  # plain dir, never git-initialized

_init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  mkdir -p "$dir/baseline/hooks" "$dir/.claude/hooks" "$dir/.claude/rules/harness" "$dir/baseline/rules"
  printf '#!/usr/bin/env bash\n' > "$dir/baseline/hooks/protect-main.sh"
  printf '#!/usr/bin/env bash\n' > "$dir/.claude/hooks/some-hook.sh"
  printf '# rule\n' > "$dir/.claude/rules/harness/delegation.md"
  printf '# rule\n' > "$dir/baseline/rules/git-workflow.md"
  printf '{}\n' > "$dir/.claude/settings.json"
  # .claude/settings.local.json is gitignored in a real adopting project
  # (install-harness.sh appends it to .git/info/exclude). Replicated here
  # with an explicit, per-repo .gitignore — not inherited from anywhere
  # outside this disposable repo — so `git add -A` leaves it untracked and
  # `git check-ignore` reports it ignored, exactly like the real thing.
  printf '.claude/settings.local.json\n' > "$dir/.gitignore"
  printf '{}\n' > "$dir/.claude/settings.local.json"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "init"
}

_init_repo "$REPO_A"
_init_repo "$REPO_B"
_init_repo "$REPO_D"
mkdir -p "$NO_GIT_CWD"

# Mark REPO_A and REPO_D as harness checkouts: the hook's structural test is
# `install-harness.sh` + `baseline/` at the repo root (baseline/ already
# exists from _init_repo). Committed, not just written to disk, so the
# fixture's own git state — tracked file at HEAD — matches what
# `_is_harness_checkout` reads via `git rev-parse --show-toplevel` on a real
# checkout. REPO_B is deliberately left WITHOUT install-harness.sh: it is the
# "ordinary consuming project" fixture the loosened cross-repo rule now
# passes.
_mark_as_harness_checkout() {
  local dir="$1"
  printf '#!/usr/bin/env bash\n# harness installer (fixture stand-in)\n' > "$dir/install-harness.sh"
  git -C "$dir" add install-harness.sh
  git -C "$dir" commit -q -m "add install-harness.sh (harness checkout marker)"
}
_mark_as_harness_checkout "$REPO_A"
_mark_as_harness_checkout "$REPO_D"

# A worktree of REPO_A, on its own branch, in its own directory — proves a
# worktree of the SAME repo is treated as the same repo, not a different one.
REPO_A_WT="$TMPDIR_ROOT/repo-a-worktree"
git -C "$REPO_A" worktree add -q -b wt-branch "$REPO_A_WT" >/dev/null 2>&1

# A PATH with everything the hook needs EXCEPT git, to simulate "no git on
# PATH" without depending on the real machine's PATH layout (which may or may
# not have git early/late in it — this must work the same everywhere).
NO_GIT_PATH_DIR="$TMPDIR_ROOT/no-git-path"
mkdir -p "$NO_GIT_PATH_DIR"
for tool in bash cat "$PYTHON_BIN" grep dirname; do
  src=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$src" "$NO_GIT_PATH_DIR/$(basename "$src")"
done

# A PATH whose `git` is a shim: every subcommand except `check-ignore` is
# forwarded to the real git, `check-ignore` always exits 128 (git's own code
# for "error", distinct from 0=ignored/1=not-ignored). Proves the hook fails
# CLOSED when it cannot determine ignore status, the same policy already
# applied to the other two degradations.
GIT_CHECK_IGNORE_ERRORS_DIR="$TMPDIR_ROOT/git-check-ignore-errors"
mkdir -p "$GIT_CHECK_IGNORE_ERRORS_DIR"
for tool in bash cat "$PYTHON_BIN" grep dirname; do
  src=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$src" "$GIT_CHECK_IGNORE_ERRORS_DIR/$(basename "$src")"
done
cat > "$GIT_CHECK_IGNORE_ERRORS_DIR/git" <<EOF
#!/usr/bin/env bash
# The hook invokes this as \`git -C <dir> check-ignore -q -- <path>\`, so the
# subcommand is not always \$1 — match it anywhere in the argument list.
for arg in "\$@"; do
  if [[ "\$arg" == "check-ignore" ]]; then
    exit 128
  fi
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_CHECK_IGNORE_ERRORS_DIR/git"

PASS_COUNT=0
FAIL_COUNT=0

_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1]}}))' "$1"
}

# $1 = name, $2 = cwd, $3 = file_path, $4 = expected exit code,
# $5 = optional PATH override (defaults to the ambient PATH)
_run_case() {
  local name="$1" cwd="$2" file_path="$3" expected="$4" path_override="${5:-}"

  local payload
  payload="$(_make_payload "$file_path")"

  local actual
  actual=$(
    cd "$cwd" || exit 99
    [[ -n "$path_override" ]] && export PATH="$path_override"
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

# --- Bash coverage: the same governance rule, reached through a Bash write
# instead of Edit/Write. $2 is the payload's own "cwd" field AND the process
# cwd the hook actually runs from — kept identical here so these cases
# exercise the governance/cross-repo logic, not the payload-cwd-vs-process-
# cwd fallback (that is covered by protect-unpushed.test.sh's own fixtures).

_make_bash_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$2"
}

# $1 = name, $2 = cwd (also the payload cwd), $3 = command, $4 = expected
# exit code, $5 = optional PATH override.
_run_bash_case() {
  local name="$1" cwd="$2" command_str="$3" expected="$4" path_override="${5:-}"

  local payload
  payload="$(_make_bash_payload "$command_str" "$cwd")"

  local actual
  actual=$(
    cd "$cwd" || exit 99
    [[ -n "$path_override" ]] && export PATH="$path_override"
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

# --- reviewability, not location: same-repo tracked config now PASSES ---
# (this is the verdict that changed: the old Group A blocked this unconditionally)

_run_case "1: .claude/settings.json (tracked) passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/settings.json" 0

# --- cross-repo into the HARNESS CHECKOUT itself stays blocked (REPO_A is
# marked as a harness checkout above) ---

_run_case "2: .claude/settings.json blocked, cwd in a DIFFERENT repo, target is a HARNESS CHECKOUT" \
  "$REPO_B" "$REPO_A/.claude/settings.json" 2

_run_case "3: .claude/settings.local.json blocked, cwd in a DIFFERENT repo, target is a HARNESS CHECKOUT" \
  "$REPO_B" "$REPO_A/.claude/settings.local.json" 2

# --- same-repo but gitignored: invisible to review -> blocked (new) ---

_run_case "4: .claude/settings.local.json (gitignored) blocked, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/settings.local.json" 2

# --- governance source: same-repo tracked passes; cross-repo into the
# HARNESS CHECKOUT (REPO_A) still blocks ---

_run_case "5: baseline/hooks/*.sh passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" 0

_run_case "6: baseline/hooks/*.sh blocked, cwd in a DIFFERENT repo, target is a HARNESS CHECKOUT" \
  "$REPO_B" "$REPO_A/baseline/hooks/protect-main.sh" 2

_run_case "7: .claude/hooks/*.sh passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/hooks/some-hook.sh" 0

_run_case "8: .claude/hooks/*.sh blocked, cwd in a DIFFERENT repo, target is a HARNESS CHECKOUT" \
  "$REPO_B" "$REPO_A/.claude/hooks/some-hook.sh" 2

_run_case "9: baseline/rules/** passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/baseline/rules/git-workflow.md" 0

_run_case "10: baseline/rules/** blocked, cwd in a DIFFERENT repo, target is a HARNESS CHECKOUT" \
  "$REPO_B" "$REPO_A/baseline/rules/git-workflow.md" 2

_run_case "11: .claude/rules/** passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/rules/harness/delegation.md" 0

_run_case "12: .claude/rules/** blocked, cwd in a DIFFERENT repo, target is a HARNESS CHECKOUT" \
  "$REPO_B" "$REPO_A/.claude/rules/harness/delegation.md" 2

# --- a brand-new governance file, not yet on disk and not gitignored -> passes (new) ---
# (the case that proves this is NOT a "must already be tracked" rule: a file
# that does not exist yet cannot be in the index, but it is also not matched
# by any .gitignore pattern, so it is reviewable the moment it is created —
# exactly the workflow that created protect-harness.sh itself)

_run_case "13: brand-new baseline/rules/*.md, not gitignored, passes" \
  "$REPO_A" "$REPO_A/baseline/rules/not-yet-created-rule.md" 0

# --- worktrees of the SAME repo must count as the same repo ---
# (the scenario this suite's own author was invoked under: a worktree's
# `git rev-parse --show-toplevel` differs from the main checkout's, but they
# share one common git dir, which is what the hook compares on)

_run_case "14: cwd in a WORKTREE, target in the main checkout of the SAME repo -> passes" \
  "$REPO_A_WT" "$REPO_A/baseline/hooks/protect-main.sh" 0

_run_case "15: cwd in the main checkout, target in a WORKTREE of the SAME repo -> passes" \
  "$REPO_A" "$REPO_A_WT/baseline/rules/git-workflow.md" 0

# --- degradation: cannot positively confirm same-repo -> fail closed ---

_run_case "16: [degradation: no git] git missing from PATH -> blocked" \
  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" 2 "$NO_GIT_PATH_DIR"

_run_case "17: [degradation: cwd outside any repo] -> blocked" \
  "$NO_GIT_CWD" "$REPO_A/baseline/hooks/protect-main.sh" 2

_run_case "18: [degradation: target directory does not exist] -> blocked" \
  "$REPO_A" "$REPO_A/baseline/hooks/not-yet-created/x.sh" 2

# --- degradation: cannot determine gitignore status -> fail closed (new) ---

_run_case "19: [degradation: check-ignore errors] git check-ignore exits 128 -> blocked" \
  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" 2 "$GIT_CHECK_IGNORE_ERRORS_DIR"

# --- must not be wider than intended: similarly-shaped, legit paths ---

_run_case "20: settings.json outside .claude/ is NOT blocked" \
  "$TMPDIR_ROOT" "config/settings.json" 0

_run_case "21: a .sh under scripts/ that is not a hook is NOT blocked" \
  "$TMPDIR_ROOT" "scripts/build.sh" 0

# --- the .example exemption applies to governance-shaped paths too ---

_run_case "22: .claude/settings.json.example passes (exemption)" \
  "$REPO_A" "$REPO_A/.claude/settings.json.example" 0

# --- the asymmetry that must survive the loosened cross-repo rule: editing a
# CONSUMING project's own tracked governance file, from a session rooted
# elsewhere, is reviewable in THAT project's own diff/PR — only the shared
# HARNESS CHECKOUT itself is special, no matter where the session started ---

_run_case "23: cross-repo, target is tracked .claude/settings.json in a NON-harness repo -> passes" \
  "$REPO_A" "$REPO_B/.claude/settings.json" 0

_run_case "24: cross-repo, target is tracked baseline/hooks/*.sh in a NON-harness repo -> passes" \
  "$REPO_A" "$REPO_B/baseline/hooks/protect-main.sh" 0

# --- the HARNESS CHECKOUT itself stays blocked cross-repo, from ANY cwd,
# including a session already rooted in a (different) harness checkout —
# proves the check classifies the TARGET, not whether the session "is
# already inside a harness" ---

_run_case "25: cross-repo, cwd is ALSO a harness checkout, target is a DIFFERENT harness checkout -> blocked" \
  "$REPO_A" "$REPO_D/baseline/hooks/protect-main.sh" 2

# --- cross-repo target gitignored in its own (non-harness) repo -> still blocked ---

_run_case "26: cross-repo, target gitignored in its own NON-harness repo -> blocked" \
  "$REPO_A" "$REPO_B/.claude/settings.local.json" 2

# ===================================================================
# Bash coverage: the exact same governance rule, reached through a write
# performed via Bash (redirect, sed -i, tee, cp, mv, python3 -c, a python
# heredoc) instead of Edit/Write. Before this hook learned about Bash, every
# one of these sailed straight through it.
# ===================================================================

_run_bash_case "27: Bash redirect into governance file, SAME repo (tracked) -> passes" \
  "$REPO_A" "echo hi > $REPO_A/.claude/settings.json" 0

_run_bash_case "28: Bash redirect into governance file, cross-repo, target is a HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "echo hi > $REPO_A/.claude/settings.json" 2

_run_bash_case "29: Bash sed -i into governance file, cross-repo HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "sed -i s/a/b/ $REPO_A/baseline/hooks/protect-main.sh" 2

_run_bash_case "30: Bash tee into governance file, cross-repo HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "echo hi | tee $REPO_A/.claude/hooks/some-hook.sh" 2

_run_bash_case "31: Bash cp into governance file, cross-repo HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "cp $REPO_B/.claude/settings.json $REPO_A/baseline/rules/git-workflow.md" 2

_run_bash_case "32: Bash mv into governance file, cross-repo HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "mv $REPO_B/.claude/settings.json $REPO_A/.claude/rules/harness/delegation.md" 2

# --- the mandatory case: this is the one that motivated pulling the Bash
# write parser out into its own shared file. A `python3 -c "...open(path,
# 'w')..."` (or the equivalent heredoc) writing into the harness's own
# .claude/settings.json used to sail straight through this hook. ---

_run_bash_case "33: [MANDATORY] python3 -c writing to .claude/settings.json, cross-repo HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "python3 -c \"import json; d=json.load(open('$REPO_A/.claude/settings.json')); json.dump(d, open('$REPO_A/.claude/settings.json','w'))\"" 2

_run_bash_case "34: [MANDATORY] python3 heredoc writing to .claude/settings.json, cross-repo HARNESS CHECKOUT -> blocked" \
  "$REPO_B" "python3 - <<'PY'
import json
d = json.load(open('$REPO_A/.claude/settings.json'))
json.dump(d, open('$REPO_A/.claude/settings.json', 'w'))
PY" 2

# --- the other mandatory case: the SAME shapes, targeting an ordinary
# repo-owned file instead of governance, must still pass ---

_run_bash_case "35: [MANDATORY] python3 -c writing to a common repo file -> passes" \
  "$REPO_B" "python3 -c \"open('$REPO_A/README.md','w').write('x')\"" 0

_run_bash_case "36: python3 heredoc writing to a common repo file, same repo -> passes" \
  "$REPO_A" "python3 - <<'PY'
open('$REPO_A/README.md', 'w').write('x')
PY" 0

# --- a target this parser cannot resolve to a literal path must be SKIPPED,
# never blocked — a guard that blocks on "could not tell" gets disabled
# outright instead of fixed ---

_run_bash_case "37: Bash redirect target built from a shell variable -> not blocked (unresolvable, skipped)" \
  "$REPO_A" 'echo hi > "$SOME_UNSET_VAR"' 0

# --- a command that writes to MULTIPLE targets: one governance (cross-repo
# harness checkout), one ordinary -> blocked, because one match is enough ---

_run_bash_case "38: Bash command with two targets, one governance one ordinary -> blocked" \
  "$REPO_B" "cp $REPO_B/.claude/settings.json $REPO_B/ordinary.txt && cp $REPO_B/.claude/settings.json $REPO_A/.claude/settings.json" 2

# --- session-side repo resolution must trust the payload's own "cwd", never
# the hook process's own $PWD (see the header note — protect-unpushed.sh
# once became a no-op from exactly this confusion). _run_bash_case always
# keeps both identical on purpose (see its own comment), so this case is
# built by hand: process cwd is REPO_A, but the payload says the session is
# in REPO_B. A write into REPO_A's own settings.json (an absolute-path
# target, so target resolution is not in question here) must be judged
# CROSS-repo — blocked, because REPO_A is a harness checkout — only if the
# session side is read from the payload's "cwd" and not from $PWD. ---

_payload_cwd_mismatch="$("$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' \
  "python3 -c \"open('$REPO_A/.claude/settings.json','w').write('x')\"" "$REPO_B")"

_actual_cwd_mismatch=$(
  cd "$REPO_A" || exit 99
  printf '%s' "$_payload_cwd_mismatch" | bash "$HOOK" >/dev/null 2>&1
  echo $?
)

if [[ "$_actual_cwd_mismatch" == "2" ]]; then
  echo "PASS: 39: session-side repo resolution reads the payload cwd, not the process \$PWD (exit $_actual_cwd_mismatch)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 39: session-side repo resolution reads the payload cwd, not the process \$PWD (expected 2, got $_actual_cwd_mismatch)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- an open() argument built from STRING CONCATENATION (a literal plus a
# variable, `'x' + repo_a + '/.claude/settings.json'`) must never be
# resolved to a path at all, even though the fragment text happens to spell
# out a governance-looking suffix. A naive "starts and ends with a matching
# quote" check is fooled by this: greedy backtracking finds the LAST quote
# character in the whole expression and treats everything before it as one
# literal, silently swallowing the embedded quotes and the "+" operators
# along the way. Caught by dogfooding this very hook mid-task (a test
# fixture heredoc containing exactly this shape tripped the live guard on
# this session's own Bash call). Regression case for
# lib/bash-write-targets.py's LITERAL_ARG_RE, exercised through the hook
# since that is the observable behavior: block vs pass. ---

_run_bash_case "40: python3 -c open() arg is string concatenation (literal + variable), not a literal -> not blocked (unresolvable, skipped)" \
  "$REPO_A" "python3 -c \"open('x' + repo_a + '/.claude/settings.json', 'w')\"" 0

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
