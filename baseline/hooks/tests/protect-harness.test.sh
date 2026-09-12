#!/usr/bin/env bash
# protect-harness.test.sh
# Standalone fixture suite for baseline/hooks/protect-harness.sh. Feeds the
# hook synthetic JSON-on-stdin payloads shaped like Claude Code's Edit/Write
# PreToolUse calls (`{"tool_input":{"file_path":"..."}}`) and asserts the exit
# code (2 = blocked, 0 = passes).
#
# Split out of protect-critical.test.sh alongside the governance logic itself
# — these are the cases that used to live there under "Group A" / "Group B".
#
# Two groups of cases need real git fixtures (built under a mktemp dir,
# removed on exit via trap — never inside a real repo):
#
#   Group A (config: .claude/settings.json, .claude/settings.local.json) —
#   blocked unconditionally, so these cases don't need real repos, just any
#   cwd/file_path pairing.
#
#   Group B (governance source: baseline/hooks/*.sh, .claude/hooks/*.sh,
#   baseline/rules/**, .claude/rules/**) — blocked only when the session's
#   cwd and the edited file resolve to DIFFERENT git repositories, so these
#   cases build two disposable repos (REPO_A, REPO_B) plus a worktree of
#   REPO_A, to prove: same-repo passes, cross-repo blocks, and a worktree of
#   the SAME repo counts as the same repo (not a different one) even though
#   `git rev-parse --show-toplevel` would report a different path for it —
#   which is exactly the scenario this suite's own author was invoked under.
#
# Degradation cases (no git on PATH, cwd outside any repo, target directory
# that does not exist) construct their own minimal environment per case
# rather than relying on the ambient one, so the suite's own result does not
# depend on whether git happens to be installed on the machine running it.
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

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# --- disposable git repos for the Group B same-repo / cross-repo cases ---

REPO_A="$TMPDIR_ROOT/repo-a"          # simulates "this harness checkout"
REPO_B="$TMPDIR_ROOT/repo-b"          # simulates a different consuming project (e.g. njord-back)
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
  printf '{}\n' > "$dir/.claude/settings.local.json"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "init"
}

_init_repo "$REPO_A"
_init_repo "$REPO_B"
mkdir -p "$NO_GIT_CWD"

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

# --- Group A (config): blocked unconditionally, same-repo or cross-repo ---

_run_case "1: .claude/settings.json blocked, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/settings.json" 2

_run_case "2: .claude/settings.json blocked, cwd in a DIFFERENT repo" \
  "$REPO_B" "$REPO_A/.claude/settings.json" 2

_run_case "3: .claude/settings.local.json blocked, cwd in a DIFFERENT repo" \
  "$REPO_B" "$REPO_A/.claude/settings.local.json" 2

# --- Group B (governance source): same-repo passes, cross-repo blocks ---

_run_case "4: baseline/hooks/*.sh passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" 0

_run_case "5: baseline/hooks/*.sh blocked, cwd in a DIFFERENT repo" \
  "$REPO_B" "$REPO_A/baseline/hooks/protect-main.sh" 2

_run_case "6: .claude/hooks/*.sh passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/hooks/some-hook.sh" 0

_run_case "7: .claude/hooks/*.sh blocked, cwd in a DIFFERENT repo" \
  "$REPO_B" "$REPO_A/.claude/hooks/some-hook.sh" 2

_run_case "8: baseline/rules/** passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/baseline/rules/git-workflow.md" 0

_run_case "9: baseline/rules/** blocked, cwd in a DIFFERENT repo" \
  "$REPO_B" "$REPO_A/baseline/rules/git-workflow.md" 2

_run_case "10: .claude/rules/** passes, cwd in SAME repo as target" \
  "$REPO_A" "$REPO_A/.claude/rules/harness/delegation.md" 0

_run_case "11: .claude/rules/** blocked, cwd in a DIFFERENT repo" \
  "$REPO_B" "$REPO_A/.claude/rules/harness/delegation.md" 2

# --- worktrees of the SAME repo must count as the same repo ---
# (the scenario this suite's own author was invoked under: a worktree's
# `git rev-parse --show-toplevel` differs from the main checkout's, but they
# share one common git dir, which is what the hook compares on)

_run_case "12: cwd in a WORKTREE, target in the main checkout of the SAME repo -> passes" \
  "$REPO_A_WT" "$REPO_A/baseline/hooks/protect-main.sh" 0

_run_case "13: cwd in the main checkout, target in a WORKTREE of the SAME repo -> passes" \
  "$REPO_A" "$REPO_A_WT/baseline/rules/git-workflow.md" 0

# --- degradation: cannot positively confirm same-repo -> fail closed ---

_run_case "14: [degradation: no git] git missing from PATH -> blocked" \
  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" 2 "$NO_GIT_PATH_DIR"

_run_case "15: [degradation: cwd outside any repo] -> blocked" \
  "$NO_GIT_CWD" "$REPO_A/baseline/hooks/protect-main.sh" 2

_run_case "16: [degradation: target directory does not exist] -> blocked" \
  "$REPO_A" "$REPO_A/baseline/hooks/not-yet-created/x.sh" 2

# --- must not be wider than intended: similarly-shaped, legit paths ---

_run_case "17: settings.json outside .claude/ is NOT blocked" \
  "$TMPDIR_ROOT" "config/settings.json" 0

_run_case "18: a .sh under scripts/ that is not a hook is NOT blocked" \
  "$TMPDIR_ROOT" "scripts/build.sh" 0

# --- the .example exemption applies to governance-shaped paths too ---

_run_case "19: .claude/settings.json.example passes (exemption, not Group A)" \
  "$REPO_A" "$REPO_A/.claude/settings.json.example" 0

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
