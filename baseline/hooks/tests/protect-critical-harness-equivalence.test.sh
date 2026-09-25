#!/usr/bin/env bash
# protect-critical-harness-equivalence.test.sh
# Compares the current protect-critical.sh / protect-harness.sh pair against
# the pre-split hook (the "oracle" — see ORACLE_REF below), payload by
# payload, for every case in both protect-critical.test.sh and
# protect-harness.test.sh.
#
# The oracle is pinned to an immutable commit, and that is the whole point.
# This suite first shipped reading it from `origin/main`, which held the
# pre-split hook at the time and stopped holding it the moment the split
# merged. From then on the suite compared the new pair against a copy of
# itself with the governance half removed, and reported 8 failures of the
# form `oracle 0, pair 2` — accusing correct code because the reference had
# moved out from under it. A moving ref is not an oracle.
#
# Two rounds of this hook exist:
#
#   Round 1 (pure split): the governance logic moved out of
#   protect-critical.sh into protect-harness.sh UNCHANGED. Every payload's
#   verdict matched the oracle, 29/29.
#
#   Round 2: the governance RULE itself changed. It used to judge safety by
#   WHICH FILE (config always blocked, source blocked only cross-repo); it
#   started judging by REVIEWABILITY (same-repo AND gitignored is blocked,
#   same-repo and not-gitignored passes, cross-repo was still always blocked
#   at this point). That is a deliberate behavior change, not a regression,
#   so this suite stopped claiming full equivalence — it claims equivalence
#   on every payload each round's change didn't touch, and documents exactly
#   which payloads diverge and why.
#
#   Round 3 (this one): the cross-repo half of the rule loosened further. It
#   is no longer "cross-repo always blocks" — it is "cross-repo blocks only
#   when the TARGET is a harness checkout (a repo root with both
#   install-harness.sh and a baseline/ directory); an ordinary consuming
#   project's own tracked governance file, reached cross-repo, now passes,
#   reviewable in THAT project's own diff and PR". This fixture's REPO_A was
#   never marked as a harness checkout (see protect-harness.test.sh for that
#   fixture, which added one on purpose), so under the new rule REPO_A reads
#   as an ordinary consuming project and every cross-repo TRACKED payload
#   against it now passes. Five more payloads move from "unchanged" to
#   "changed" here for exactly that reason (harness-2, 6, 8, 10, 12); the
#   gitignored cross-repo payload (harness-3) is untouched, since the
#   gitignore check runs regardless of harness-checkout status.
#
#   Round 4: Bash coverage. Both hooks gained an almost-identical Bash
#   dispatch block (unresolvable targets skipped, missing shared parser
#   warns and passes). This has no oracle to compare against — the oracle
#   predates Bash support entirely — so this round compares the two CURRENT
#   hooks against EACH OTHER instead, on payloads picked so a fix applied to
#   only one of them would fail here even though it would pass every other
#   suite (each hook's own test file only ever runs that one hook).
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

REAL_GIT="$(command -v git 2>/dev/null)"
if [[ -z "$REAL_GIT" ]]; then
  echo "protect-critical-harness-equivalence.test.sh: no git on PATH, cannot read the oracle" >&2
  exit 1
fi

# The last commit in which protect-critical.sh still held the governance half,
# i.e. the state this pair has to reproduce. Never a branch name: a branch
# moves, and this suite's only job is to compare against something that cannot.
ORACLE_REF="255818d"

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

ORACLE="$TMPDIR_ROOT/oracle-protect-critical.sh"
if ! git -C "$SCRIPT_DIR" show "$ORACLE_REF:baseline/hooks/protect-critical.sh" > "$ORACLE" 2>/dev/null; then
  echo "protect-critical-harness-equivalence.test.sh: could not read $ORACLE_REF:baseline/hooks/protect-critical.sh — is the full history present? (a shallow clone will not have it)" >&2
  exit 1
fi

# Guard against a hollow pass: if the oracle we just read has no governance
# logic in it, it is the wrong commit, and every governance payload would
# "agree" with it by both doing nothing. Fail loudly instead.
if ! grep -q 'governance_source_patterns' "$ORACLE"; then
  echo "protect-critical-harness-equivalence.test.sh: $ORACLE_REF does not contain the pre-split governance logic — the oracle ref is wrong, refusing to report a meaningless pass" >&2
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
  printf '.claude/settings.local.json\n' > "$dir/.gitignore"
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

GIT_CHECK_IGNORE_ERRORS_DIR="$TMPDIR_ROOT/git-check-ignore-errors"
mkdir -p "$GIT_CHECK_IGNORE_ERRORS_DIR"
for tool in bash cat "$PYTHON_BIN" grep dirname; do
  src=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$src" "$GIT_CHECK_IGNORE_ERRORS_DIR/$(basename "$src")"
done
cat > "$GIT_CHECK_IGNORE_ERRORS_DIR/git" <<EOF
#!/usr/bin/env bash
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

_pair_exit() {
  # $1 = cwd, $2 = payload, $3 = optional PATH override. Claude Code runs
  # every hook in the matcher group and blocks if ANY exits 2 — only pay for
  # the second hook when the first did not already decide the outcome.
  local cwd="$1" payload="$2" path_override="${3:-}"
  local crit_exit
  crit_exit="$(_run_hook "$CRITICAL_HOOK" "$cwd" "$payload" "$path_override")"
  if [[ "$crit_exit" == "2" ]]; then
    echo 2
  else
    _run_hook "$HARNESS_HOOK" "$cwd" "$payload" "$path_override"
  fi
}

# $1 = name, $2 = cwd, $3 = file_path, $4 = optional PATH override.
# Asserts the pair's combined verdict still matches the origin/main oracle.
_run_case_unchanged() {
  local name="$1" cwd="$2" file_path="$3" path_override="${4:-}"
  local payload; payload="$(_make_payload "$file_path")"
  local oracle_exit; oracle_exit="$(_run_hook "$ORACLE" "$cwd" "$payload" "$path_override")"
  local pair_exit; pair_exit="$(_pair_exit "$cwd" "$payload" "$path_override")"

  if [[ "$pair_exit" == "$oracle_exit" ]]; then
    echo "PASS: $name (oracle $oracle_exit, pair $pair_exit)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (oracle $oracle_exit, pair $pair_exit — expected these to MATCH)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# $1 = name, $2 = cwd, $3 = file_path, $4 = expected NEW pair exit code,
# $5 = reason the verdict changed, $6 = optional PATH override.
# Asserts the pair produces the documented new verdict — deliberately does
# NOT require matching the oracle, since the oracle is known-stale here.
_run_case_changed() {
  local name="$1" cwd="$2" file_path="$3" expected="$4" reason="$5" path_override="${6:-}"
  local payload; payload="$(_make_payload "$file_path")"
  local oracle_exit; oracle_exit="$(_run_hook "$ORACLE" "$cwd" "$payload" "$path_override")"
  local pair_exit; pair_exit="$(_pair_exit "$cwd" "$payload" "$path_override")"

  if [[ "$pair_exit" == "$expected" ]]; then
    echo "PASS: $name [VERDICT CHANGED] (oracle $oracle_exit, pair $pair_exit — $reason)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name [VERDICT CHANGED] (expected pair $expected, got $pair_exit; oracle $oracle_exit)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ==================================================================
# Unchanged: every payload from protect-critical.test.sh (round 1 and
# round 2 both leave protect-critical.sh's own patterns untouched)
# ==================================================================

_run_case_unchanged "critical-1: .env"                            "$TMPDIR_ROOT" ".env"
_run_case_unchanged "critical-2: .env.local"                      "$TMPDIR_ROOT" ".env.local"
_run_case_unchanged "critical-3: pnpm-lock.yaml"                  "$TMPDIR_ROOT" "pnpm-lock.yaml"
_run_case_unchanged "critical-4: package-lock.json"               "$TMPDIR_ROOT" "package-lock.json"
_run_case_unchanged "critical-5: applied migration"               "$TMPDIR_ROOT" "db/migrations/2026_applied.sql"
_run_case_unchanged "critical-6: generated code"                  "$TMPDIR_ROOT" "src/schema.generated.ts"
_run_case_unchanged "critical-7: .env.example"                    "$TMPDIR_ROOT" ".env.example"
_run_case_unchanged "critical-8: .env.test.example"               "$TMPDIR_ROOT" ".env.test.example"
_run_case_unchanged "critical-9: nested .env.example"             "$TMPDIR_ROOT" "apps/api/.env.example"

payload_missing="$("$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Edit", "tool_input": {}}))')"
oracle_missing="$(_run_hook "$ORACLE" "$TMPDIR_ROOT" "$payload_missing")"
pair_missing="$(_pair_exit "$TMPDIR_ROOT" "$payload_missing")"
if [[ "$pair_missing" == "$oracle_missing" ]]; then
  echo "PASS: critical-10: payload missing file_path (oracle $oracle_missing, pair $pair_missing)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: critical-10: payload missing file_path (oracle $oracle_missing, pair $pair_missing)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# ==================================================================
# Unchanged: governance payloads whose verdict the new rule preserves
# ==================================================================

_run_case_unchanged "harness-3: settings.local.json, cross repo"          "$REPO_B" "$REPO_A/.claude/settings.local.json"
_run_case_unchanged "harness-4: settings.local.json, same repo (gitignored on disk, blocked either way)" \
  "$REPO_A" "$REPO_A/.claude/settings.local.json"
_run_case_unchanged "harness-5: baseline/hooks/*.sh, same repo"           "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case_unchanged "harness-7: .claude/hooks/*.sh, same repo"            "$REPO_A" "$REPO_A/.claude/hooks/some-hook.sh"
_run_case_unchanged "harness-9: baseline/rules/**, same repo"             "$REPO_A" "$REPO_A/baseline/rules/git-workflow.md"
_run_case_unchanged "harness-11: .claude/rules/**, same repo"             "$REPO_A" "$REPO_A/.claude/rules/harness/delegation.md"
_run_case_unchanged "harness-13: brand-new rule file, not gitignored, same repo" \
  "$REPO_A" "$REPO_A/baseline/rules/not-yet-created-rule.md"
_run_case_unchanged "harness-14: cwd in worktree, target in main"         "$REPO_A_WT" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case_unchanged "harness-15: cwd in main, target in worktree"         "$REPO_A" "$REPO_A_WT/baseline/rules/git-workflow.md"
_run_case_unchanged "harness-16: [degradation: no git]"                  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" "$NO_GIT_PATH_DIR"
_run_case_unchanged "harness-17: [degradation: cwd outside any repo]"    "$NO_GIT_CWD" "$REPO_A/baseline/hooks/protect-main.sh"
_run_case_unchanged "harness-18: [degradation: target dir missing]"      "$REPO_A" "$REPO_A/baseline/hooks/not-yet-created/x.sh"
_run_case_unchanged "harness-20: settings.json outside .claude/"         "$TMPDIR_ROOT" "config/settings.json"
_run_case_unchanged "harness-21: non-hook .sh under scripts/"            "$TMPDIR_ROOT" "scripts/build.sh"
_run_case_unchanged "harness-22: .claude/settings.json.example"          "$REPO_A" "$REPO_A/.claude/settings.json.example"

# ==================================================================
# CHANGED: seven payloads diverge from the oracle, on purpose (two from
# round 2, five more from round 3 — see the header comment).
# ==================================================================

_run_case_changed "harness-1: settings.json (tracked), same repo" \
  "$REPO_A" "$REPO_A/.claude/settings.json" 0 \
  "old rule blocked ALL of .claude/settings.json unconditionally (Group A); new rule asks 'is it gitignored', and a TRACKED file is never gitignored — it shows up in a PR diff, so it is reviewable and now passes"

_run_case_changed "harness-19: [degradation] git check-ignore exits 128" \
  "$REPO_A" "$REPO_A/baseline/hooks/protect-main.sh" 2 \
  "the old hook never called check-ignore at all, so this PATH override does not affect it (oracle passes, same-repo, as usual); the new hook's same-repo branch depends on check-ignore succeeding, and fails closed when it cannot determine ignore status — a degradation the old rule had no concept of" \
  "$GIT_CHECK_IGNORE_ERRORS_DIR"

_round3_reason="round 3: cross-repo no longer blocks unconditionally, only when the TARGET is a harness checkout (install-harness.sh + baseline/ at its root); this fixture's REPO_A carries no install-harness.sh, so it reads as an ordinary consuming project and its own TRACKED governance file, reached cross-repo, is now reviewable in REPO_A's own diff/PR and passes (see protect-harness.test.sh cases 23-26 for the harness-checkout-vs-not distinction with a fixture built to carry it)"

_run_case_changed "harness-2: settings.json, cross repo (target not a harness checkout)" \
  "$REPO_B" "$REPO_A/.claude/settings.json" 0 "$_round3_reason"

_run_case_changed "harness-6: baseline/hooks/*.sh, cross repo (target not a harness checkout)" \
  "$REPO_B" "$REPO_A/baseline/hooks/protect-main.sh" 0 "$_round3_reason"

_run_case_changed "harness-8: .claude/hooks/*.sh, cross repo (target not a harness checkout)" \
  "$REPO_B" "$REPO_A/.claude/hooks/some-hook.sh" 0 "$_round3_reason"

_run_case_changed "harness-10: baseline/rules/**, cross repo (target not a harness checkout)" \
  "$REPO_B" "$REPO_A/baseline/rules/git-workflow.md" 0 "$_round3_reason"

_run_case_changed "harness-12: .claude/rules/**, cross repo (target not a harness checkout)" \
  "$REPO_B" "$REPO_A/.claude/rules/harness/delegation.md" 0 "$_round3_reason"

# ==================================================================
# Round 4: Bash coverage. protect-critical.sh:144-154 and
# protect-harness.sh's own Bash dispatch block are the SAME code, typed
# twice rather than shared (extracting a third .sh helper felt like more
# surface than the duplication itself, given both already share the one
# thing that actually needed sharing: lib/bash-write-targets.py). Nothing
# forces them to STAY identical, though: a fix applied to one and forgotten
# in the other would pass every existing suite, because each hook's own
# test file only ever runs that ONE hook. These cases run the EXACT SAME
# Bash payload through BOTH hooks and assert they still agree — not against
# the oracle, which predates Bash support by two rounds and has no opinion
# on it at all, but against EACH OTHER, on the mechanics that are supposed
# to be identical: skip an unresolvable target rather than block on it, and
# warn loudly and pass (never silently no-op) when the shared parser file
# is missing.
# ==================================================================

_make_bash_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$2"
}

# $1 = name, $2 = cwd, $3 = command, $4 = expected exit code (same for both
# hooks — this section is about the two hooks agreeing with EACH OTHER, not
# about what any specific pattern should do).
_run_bash_case_both() {
  local name="$1" cwd="$2" command_str="$3" expected="$4"
  local payload; payload="$(_make_bash_payload "$command_str" "$cwd")"
  local crit_exit harn_exit
  crit_exit="$(_run_hook "$CRITICAL_HOOK" "$cwd" "$payload")"
  harn_exit="$(_run_hook "$HARNESS_HOOK" "$cwd" "$payload")"
  if [[ "$crit_exit" == "$expected" && "$harn_exit" == "$expected" ]]; then
    echo "PASS: $name (both $expected)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (expected both $expected; protect-critical.sh gave $crit_exit, protect-harness.sh gave $harn_exit)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

_run_bash_case_both "bash-1: unresolvable target (shell variable) is skipped by BOTH hooks, never blocked" \
  "$TMPDIR_ROOT" 'echo hi > "$SOME_UNSET_VAR"' 0

_run_bash_case_both "bash-2: &> is recognized as a write by BOTH hooks (an ordinary target, so both pass)" \
  "$TMPDIR_ROOT" "echo hi &> ordinary.txt" 0

# Missing lib/bash-write-targets.py: both hooks must warn on stderr and
# pass, never silently no-op. Copies of each hook into a directory with no
# lib/ next to them, same technique each hook's OWN suite already uses.
_MISSING_LIB_BOTH_DIR="$TMPDIR_ROOT/missing-lib-both"
mkdir -p "$_MISSING_LIB_BOTH_DIR"
cp "$CRITICAL_HOOK" "$_MISSING_LIB_BOTH_DIR/protect-critical.sh"
cp "$HARNESS_HOOK" "$_MISSING_LIB_BOTH_DIR/protect-harness.sh"
_missing_both_payload="$("$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "echo hi > .env"}}))')"
_missing_both_crit_stderr=$(cd "$TMPDIR_ROOT" && printf '%s' "$_missing_both_payload" | bash "$_MISSING_LIB_BOTH_DIR/protect-critical.sh" 2>&1 >/dev/null)
_missing_both_crit_rc=$(cd "$TMPDIR_ROOT" && printf '%s' "$_missing_both_payload" | bash "$_MISSING_LIB_BOTH_DIR/protect-critical.sh" >/dev/null 2>&1; echo $?)
_missing_both_harn_stderr=$(cd "$TMPDIR_ROOT" && printf '%s' "$_missing_both_payload" | bash "$_MISSING_LIB_BOTH_DIR/protect-harness.sh" 2>&1 >/dev/null)
_missing_both_harn_rc=$(cd "$TMPDIR_ROOT" && printf '%s' "$_missing_both_payload" | bash "$_MISSING_LIB_BOTH_DIR/protect-harness.sh" >/dev/null 2>&1; echo $?)

if [[ "$_missing_both_crit_rc" == "0" && "$_missing_both_harn_rc" == "0" \
      && "$_missing_both_crit_stderr" == *"WARNING"* && "$_missing_both_harn_stderr" == *"WARNING"* ]]; then
  echo "PASS: bash-3: missing lib/bash-write-targets.py warns and passes on BOTH hooks"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: bash-3: missing lib/bash-write-targets.py warns and passes on BOTH hooks (critical: rc=$_missing_both_crit_rc; harness: rc=$_missing_both_harn_rc)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"
echo "(7 of these are DECLARED verdict changes, checked against their new expected value, not the oracle)"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
