#!/usr/bin/env bash
# protect-critical-harness-equivalence.test.sh
# The proof the protect-critical.sh / protect-harness.sh split did not change
# observable behavior. protect-critical.sh USED TO carry both the
# critical-file guard and the governance guard in one script (see
# `git show origin/main:baseline/hooks/protect-critical.sh`, the "oracle"
# below). It was split into two hooks, each registered separately in
# .claude/settings.json's PreToolUse "Edit|Write|MultiEdit|NotebookEdit"
# group. Claude Code runs every hook in a matcher group and blocks the tool
# call if ANY of them exits 2 — so the pair's COMBINED decision (block if
# either hook blocks, otherwise pass) is what has to match the old monolith's
# single decision, payload for payload.
#
# This suite fetches the pre-split hook straight from origin/main (never a
# local copy that could have drifted) and replays every payload from both
# protect-critical.test.sh and protect-harness.test.sh against it, comparing
# the oracle's exit code to the new pair's combined exit code.
#
# Run: bash baseline/hooks/tests/protect-critical-harness-equivalence.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CRITICAL_HOOK="$SCRIPT_DIR/../protect-critical.sh"
HARNESS_HOOK="$SCRIPT_DIR/../protect-harness.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "protect-critical-harness-equivalence.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "protect-critical-harness-equivalence.test.sh: no git on PATH, cannot fetch the origin/main oracle" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

ORACLE="$TMPDIR_ROOT/oracle-protect-critical.sh"
if ! git -C "$SCRIPT_DIR" show origin/main:baseline/hooks/protect-critical.sh > "$ORACLE" 2>/dev/null; then
  echo "protect-critical-harness-equivalence.test.sh: could not read origin/main:baseline/hooks/protect-critical.sh — is origin/main fetched?" >&2
  exit 1
fi
chmod +x "$ORACLE"

# --- disposable git repos, same shape as protect-harness.test.sh's fixtures ---

REPO_A="$TMPDIR_ROOT/repo-a"
REPO_B="$TMPDIR_ROOT/repo-b"
NO_GIT_CWD="$TMPDIR_ROOT/no-git-cwd"

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

REPO_A_WT="$TMPDIR_ROOT/repo-a-worktree"
git -C "$REPO_A" worktree add -q -b wt-branch "$REPO_A_WT" >/dev/null 2>&1

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

_run_hook() {
  # $1 = hook path, $2 = cwd, $3 = payload, $4 = optional PATH override
  local hook="$1" cwd="$2" payload="$3" path_override="${4:-}"
  (
    cd "$cwd" || exit 99
    [[ -n "$path_override" ]] && export PATH="$path_override"
    printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
    echo $?
  )
}

# $1 = name, $2 = cwd, $3 = file_path, $4 = optional PATH override
_run_case() {
  local name="$1" cwd="$2" file_path="$3" path_override="${4:-}"

  local payload
  payload="$(_make_payload "$file_path")"

  local oracle_exit
  oracle_exit="$(_run_hook "$ORACLE" "$cwd" "$payload" "$path_override")"

  local crit_exit
  crit_exit="$(_run_hook "$CRITICAL_HOOK" "$cwd" "$payload" "$path_override")"

  # Claude Code runs every hook in the matcher group; the call is blocked if
  # ANY of them exits 2. Only pay for the second hook when the first did not
  # already decide the outcome, same as the real PreToolUse chain would.
  local combined_exit
  if [[ "$crit_exit" == "2" ]]; then
    combined_exit=2
  else
    combined_exit="$(_run_hook "$HARNESS_HOOK" "$cwd" "$payload" "$path_override")"
  fi

  if [[ "$combined_exit" == "$oracle_exit" ]]; then
    echo "PASS: $name (oracle $oracle_exit, pair $combined_exit)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (oracle $oracle_exit, pair $combined_exit)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- every payload from protect-critical.test.sh ---

_run_case "1: .env"                                "$TMPDIR_ROOT" ".env"
_run_case "2: .env.local"                          "$TMPDIR_ROOT" ".env.local"
_run_case "3: pnpm-lock.yaml"                       "$TMPDIR_ROOT" "pnpm-lock.yaml"
_run_case "4: package-lock.json"                    "$TMPDIR_ROOT" "package-lock.json"
_run_case "5: applied migration"                    "$TMPDIR_ROOT" "db/migrations/2026_applied.sql"
_run_case "6: generated code"                       "$TMPDIR_ROOT" "src/schema.generated.ts"
_run_case "7: .env.example"                         "$TMPDIR_ROOT" ".env.example"
_run_case "8: .env.test.example"                    "$TMPDIR_ROOT" ".env.test.example"
_run_case "9: nested .env.example"                  "$TMPDIR_ROOT" "apps/api/.env.example"

# --- every payload from protect-harness.test.sh ---

_run_case "10: settings.json, same repo"            "$REPO_A" "$REPO_A/.claude/settings.json"
_run_case "11: settings.json, cross repo"           "$REPO_B" "$REPO_A/.claude/settings.json"
_run_case "12: settings.local.json, cross repo"     "$REPO_B" "$REPO_A/.claude/settings.local.json"
_run_case "13: baseline/hooks/*.sh, same repo"      "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case "14: baseline/hooks/*.sh, cross repo"     "$REPO_B" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case "15: .claude/hooks/*.sh, same repo"       "$REPO_A" "$REPO_A/.claude/hooks/some-hook.sh"
_run_case "16: .claude/hooks/*.sh, cross repo"      "$REPO_B" "$REPO_A/.claude/hooks/some-hook.sh"
_run_case "17: baseline/rules/**, same repo"        "$REPO_A" "$REPO_A/baseline/rules/git-workflow.md"
_run_case "18: baseline/rules/**, cross repo"       "$REPO_B" "$REPO_A/baseline/rules/git-workflow.md"
_run_case "19: .claude/rules/**, same repo"         "$REPO_A" "$REPO_A/.claude/rules/harness/delegation.md"
_run_case "20: .claude/rules/**, cross repo"        "$REPO_B" "$REPO_A/.claude/rules/harness/delegation.md"
_run_case "21: cwd in worktree, target in main"     "$REPO_A_WT" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case "22: cwd in main, target in worktree"     "$REPO_A" "$REPO_A_WT/baseline/rules/git-workflow.md"
_run_case "23: [degradation: no git]"               "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" "$NO_GIT_PATH_DIR"
_run_case "24: [degradation: cwd outside any repo]" "$NO_GIT_CWD" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case "25: [degradation: target dir missing]"   "$REPO_A" "$REPO_A/baseline/hooks/not-yet-created/x.sh"
_run_case "26: settings.json outside .claude/"      "$TMPDIR_ROOT" "config/settings.json"
_run_case "27: non-hook .sh under scripts/"         "$TMPDIR_ROOT" "scripts/build.sh"
_run_case "28: .claude/settings.json.example"       "$REPO_A" "$REPO_A/.claude/settings.json.example"

# --- payload without file_path must not block, on either side ---

payload_missing="$("$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Edit", "tool_input": {}}))')"
oracle_missing="$(_run_hook "$ORACLE" "$TMPDIR_ROOT" "$payload_missing")"
crit_missing="$(_run_hook "$CRITICAL_HOOK" "$TMPDIR_ROOT" "$payload_missing")"
if [[ "$crit_missing" == "2" ]]; then
  pair_missing=2
else
  pair_missing="$(_run_hook "$HARNESS_HOOK" "$TMPDIR_ROOT" "$payload_missing")"
fi
if [[ "$pair_missing" == "$oracle_missing" ]]; then
  echo "PASS: 29: payload missing file_path (oracle $oracle_missing, pair $pair_missing)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 29: payload missing file_path (oracle $oracle_missing, pair $pair_missing)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "Results: $PASS_COUNT payloads matched the origin/main oracle, $FAIL_COUNT diverged (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
