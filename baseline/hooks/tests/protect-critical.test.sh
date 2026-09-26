#!/usr/bin/env bash
# protect-critical.test.sh
# Standalone fixture suite for baseline/hooks/protect-critical.sh. Feeds the
# hook synthetic JSON-on-stdin payloads shaped like Claude Code's Edit/Write
# PreToolUse calls (`{"tool_input":{"file_path":"..."}}`) and asserts the exit
# code (2 = blocked, 0 = passes).
#
# This suite covers only what protect-critical.sh still owns after the
# governance split: files that are sensitive (env, secrets) or would cause
# silent damage if edited without explicit approval (lockfiles, applied
# migrations, generated code), plus the `.example` template exemption and the
# payload-without-file_path no-op. None of these cases need a real git repo.
#
# The governance cases (the harness's own hooks, hook config, and rules —
# .claude/settings.json, baseline/hooks/*.sh, baseline/rules/**, etc.) moved
# to protect-harness.test.sh alongside the hook that now owns them.
#
# Run: bash baseline/hooks/tests/protect-critical.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../protect-critical.sh"

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
  echo "protect-critical.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_make_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1]}}))' "$1"
}

_make_payload_no_file_path() {
  "$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Edit", "tool_input": {}}))'
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

# --- Bash coverage: the same critical_patterns, reached through a Bash
# write instead of Edit/Write.

_make_bash_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$2"
}

# $1 = name, $2 = cwd (also the payload cwd), $3 = command, $4 = expected
# exit code.
_run_bash_case() {
  local name="$1" cwd="$2" command_str="$3" expected="$4"

  local payload
  payload="$(_make_bash_payload "$command_str" "$cwd")"

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

# --- pre-existing behavior: must not regress ---

_run_case "1: .env is blocked" \
  "$TMPDIR_ROOT" ".env" 2

_run_case "2: .env.local is blocked" \
  "$TMPDIR_ROOT" ".env.local" 2

_run_case "3: pnpm-lock.yaml is blocked" \
  "$TMPDIR_ROOT" "pnpm-lock.yaml" 2

_run_case "4: package-lock.json is blocked" \
  "$TMPDIR_ROOT" "package-lock.json" 2

_run_case "5: applied migration is blocked" \
  "$TMPDIR_ROOT" "db/migrations/2026_applied.sql" 2

_run_case "6: generated code is blocked" \
  "$TMPDIR_ROOT" "src/schema.generated.ts" 2

# --- change 1: .example templates are the fix for the original false positive ---

_run_case "7: .env.example passes (regression check)" \
  "$TMPDIR_ROOT" ".env.example" 0

_run_case "8: .env.test.example passes (regression check)" \
  "$TMPDIR_ROOT" ".env.test.example" 0

_run_case "9: nested .env.example passes" \
  "$TMPDIR_ROOT" "apps/api/.env.example" 0

# --- payload without file_path must not block ---

actual_missing=$(cd "$TMPDIR_ROOT" && printf '%s' "$(_make_payload_no_file_path)" | bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ "$actual_missing" == "0" ]]; then
  echo "PASS: 10: payload missing file_path exits 0 (exit $actual_missing)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 10: payload missing file_path exits 0 (expected 0, got $actual_missing)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# ===================================================================
# Bash coverage: the exact same critical_patterns, reached through a write
# performed via Bash (redirect, sed -i, tee, cp, mv, python3 -c, a python
# heredoc) instead of Edit/Write. Before this hook learned about Bash, every
# one of these sailed straight through it.
# ===================================================================

_run_bash_case "11: Bash redirect into .env is blocked" \
  "$TMPDIR_ROOT" "echo hi > .env" 2

_run_bash_case "12: Bash sed -i into pnpm-lock.yaml is blocked" \
  "$TMPDIR_ROOT" "sed -i s/a/b/ pnpm-lock.yaml" 2

_run_bash_case "13: Bash tee into a secrets/ file is blocked" \
  "$TMPDIR_ROOT" "echo hi | tee secrets/token.txt" 2

_run_bash_case "14: Bash cp into package-lock.json is blocked" \
  "$TMPDIR_ROOT" "cp foo.json package-lock.json" 2

_run_bash_case "15: Bash mv into an applied migration is blocked" \
  "$TMPDIR_ROOT" "mv foo.sql db/migrations/2026_applied.sql" 2

# --- the mandatory case: this is the one that motivated pulling the Bash
# write parser out into its own shared file. A `python3 -c "...open(path,
# 'w')..."` (or the equivalent heredoc) writing into a critical file used to
# sail straight through this hook. ---

_run_bash_case "16: [MANDATORY] python3 -c writing to .env is blocked" \
  "$TMPDIR_ROOT" "python3 -c \"open('.env','w').write('x')\"" 2

_run_bash_case "17: [MANDATORY] python3 heredoc writing to .env is blocked" \
  "$TMPDIR_ROOT" "python3 - <<'PY'
open('.env', 'w').write('x')
PY" 2

# --- the other mandatory case: the SAME shapes, targeting an ordinary
# repo-owned file instead of a critical one, must still pass ---

_run_bash_case "18: [MANDATORY] python3 -c writing to a common file passes" \
  "$TMPDIR_ROOT" "python3 -c \"open('README.md','w').write('x')\"" 0

_run_bash_case "19: python3 heredoc writing to a common file passes" \
  "$TMPDIR_ROOT" "python3 - <<'PY'
open('README.md', 'w').write('x')
PY" 0

# --- the .example exemption applies through Bash too ---

_run_bash_case "20: Bash redirect into .env.example passes (exemption)" \
  "$TMPDIR_ROOT" "echo hi > .env.example" 0

# --- a target this parser cannot resolve to a literal path must be SKIPPED,
# never blocked — a guard that blocks on "could not tell" gets disabled
# outright instead of fixed ---

_run_bash_case "21: Bash redirect target built from a shell variable is not blocked (unresolvable, skipped)" \
  "$TMPDIR_ROOT" 'echo hi > "$SOME_UNSET_VAR"' 0

# --- a command that writes to MULTIPLE targets: one critical, one ordinary
# -> blocked, because one match is enough ---

_run_bash_case "22: Bash command with two targets, one critical one ordinary, is blocked" \
  "$TMPDIR_ROOT" "cp foo.txt ordinary.txt && cp foo.txt pnpm-lock.yaml" 2

# ===================================================================
# F2: every redirect shape that actually writes a file, not just `>`/`>>`.
# ===================================================================

_run_bash_case "23: &> into .env is blocked" \
  "$TMPDIR_ROOT" "echo pwned &> .env" 2

_run_bash_case "24: >| (force-write) into .env is blocked" \
  "$TMPDIR_ROOT" "echo pwned >| .env" 2

_run_bash_case "25: >& (with a filename, not a bare fd) into .env is blocked" \
  "$TMPDIR_ROOT" "echo pwned >& .env" 2

_run_bash_case "26: 2> (stderr redirect, still creates/truncates the target) into .env is blocked" \
  "$TMPDIR_ROOT" "echo pwned 2> .env" 2

_run_bash_case "27: >&2 (bare fd reference, no file at all) is not treated as a write" \
  "$TMPDIR_ROOT" "echo pwned >&2" 0

# FD_REF_RE's exclusion cannot be proven through this hook's own BLOCK/PASS
# decision: none of critical_patterns is digit-shaped, so a bare fd
# reference ("2", "-") never coincidentally matches one whether it was
# correctly excluded or wrongly treated as a write. What IS provable here
# is that the shared parser's raw output is empty for it — checked
# directly, same technique log-edit.test.sh's case 10f already uses (the
# actual mutation-proof for this mechanic).
_LIB="$SCRIPT_DIR/../lib/bash-write-targets.py"
_fdref_payload="$("$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "echo pwned >&2"}, "cwd": "/tmp"}))')"
_fdref_out="$(printf '%s' "$_fdref_payload" | "$PYTHON_BIN" "$_LIB")"
if [[ -z "$_fdref_out" ]]; then
  echo "PASS: 27b: shared parser reports NO target at all for >&2 (bare fd reference)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 27b: shared parser reports NO target at all for >&2 (bare fd reference) (got: $_fdref_out)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# ===================================================================
# F3: a heredoc's OPENING line can carry more than the delimiter (e.g. a
# redirect); the body must still be scanned, and a body that only MENTIONS
# a dangerous command as prose must not cause a false block.
# ===================================================================

_run_bash_case "28: python3 heredoc WITH a trailing redirect on its opener line still finds the critical write in the body" \
  "$TMPDIR_ROOT" "python3 - <<'PY' > out.txt
open('.env', 'w')
PY" 2

_run_bash_case "29: a heredoc body whose text merely CONTAINS a real write-command shape (cp ... .env) is not blocked; only the heredoc's own real redirect target (an ordinary file) matters" \
  "$TMPDIR_ROOT" "cat <<'EOF' > notas.md
cp x .env
EOF" 0

# ===================================================================
# F7: if the shared parser file goes missing, the Bash branch must warn
# loudly on stderr and pass (fail open), never silently do nothing.
# ===================================================================

_MISSING_LIB_DIR="$TMPDIR_ROOT/missing-lib-hooks"
mkdir -p "$_MISSING_LIB_DIR"
cp "$HOOK" "$_MISSING_LIB_DIR/protect-critical.sh"
_missing_lib_payload="$("$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "echo hi > .env"}}))')"
_missing_lib_stderr=$(cd "$TMPDIR_ROOT" && printf '%s' "$_missing_lib_payload" | bash "$_MISSING_LIB_DIR/protect-critical.sh" 2>&1 >/dev/null)
_missing_lib_rc=$(cd "$TMPDIR_ROOT" && printf '%s' "$_missing_lib_payload" | bash "$_MISSING_LIB_DIR/protect-critical.sh" >/dev/null 2>&1; echo $?)

if [[ "$_missing_lib_rc" == "0" && "$_missing_lib_stderr" == *"WARNING"* && "$_missing_lib_stderr" == *"bash-write-targets.py"* ]]; then
  echo "PASS: 30: missing lib/bash-write-targets.py warns loudly on stderr and passes (exit $_missing_lib_rc)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 30: missing lib/bash-write-targets.py warns loudly on stderr and passes (exit $_missing_lib_rc, stderr: $_missing_lib_stderr)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# ===================================================================
# F5: `sed -i` with a critical file that is NOT the last argument, and
# `cp -t DIR`/`mv -t DIR`, whose destination is the -t FLAG's value, not
# the last positional word (a source).
# ===================================================================

_run_bash_case "31: sed -i with the critical file NOT last -> still blocked" \
  "$TMPDIR_ROOT" "sed -i s/a/b/ .env ordinary.txt" 2

_run_bash_case "32: cp -t DIR, DIR is a critical directory -> blocked" \
  "$TMPDIR_ROOT" "cp -t secrets ordinary.txt" 2

# ===================================================================
# F5 [round 2]: the COMMON form of "copy into a directory" -- no -t, just
# `cp SRC DIR` or `cp SRC DIR/` -- used to report the bare DIR as the
# target, and os.path.normpath then stripped any trailing slash before
# that string ever reached the critical-pattern check, so a no-trailing-`$`
# directory pattern (like `/secrets/`) stopped matching. The rare `-t DIR`
# form (above) was already protected; the common form was not.
# ===================================================================

mkdir -p "$TMPDIR_ROOT/secrets"

_run_bash_case "33: [MANDATORY] cp SRC DIR/ (trailing slash, no -t), DIR is critical -> blocked" \
  "$TMPDIR_ROOT" "cp ordinary.txt secrets/" 2

_run_bash_case "34: [MANDATORY] mv SRC DIR (no trailing slash, DIR exists on disk), DIR is critical -> blocked" \
  "$TMPDIR_ROOT" "mv ordinary.txt secrets" 2

_run_bash_case "35: cp SRC1 SRC2 DIR (more than one source, DIR must be a directory by cp's own syntax) -> blocked" \
  "$TMPDIR_ROOT" "cp a.txt b.txt secrets" 2

_run_bash_case "36: cp SRC DEST, DEST does not exist as a directory on disk -> still a plain file destination, not blocked" \
  "$TMPDIR_ROOT" "cp ordinary.txt not-a-real-directory" 0

# The trailing-slash half of dest_is_dir (`dest.endswith("/")`) has no case
# of its own where it is the ONLY thing making the destination count as a
# directory: case 33, above, ALSO exists on disk (secrets/ was mkdir'd),
# so `os.path.isdir` alone already covers it -- removing the endswith check
# would leave case 33 green. Here the destination directory does NOT exist
# on disk at all: only the trailing "/" marks it as a directory, so the
# source's basename gets appended and the joined result ends in ".env"
# (matching `\.env$`, a `$`-anchored pattern) while the bare, un-joined
# destination string does not.
_run_bash_case "36b: cp x.env DIR/ (trailing slash, DIR does NOT exist on disk at all), joined result ends in .env -> blocked" \
  "$TMPDIR_ROOT" "cp x.env newdir-does-not-exist/" 2

# ===================================================================
# F12 [round 2 blocker]: `sed -i -e SCRIPT` / `-f FILE` (the SEPARATED
# form) reported SCRIPT/FILE itself as a write target whenever -e/-f
# appeared anywhere in the word list, because the flag's own operand was
# never consumed. `-f script.sed` was worse: that file is READ by sed,
# never written.
# ===================================================================

_run_bash_case "37: [MANDATORY] sed -i -e EXPR FILE, EXPR text shaped like a critical path -> not blocked (EXPR is a flag operand, not a file)" \
  "$TMPDIR_ROOT" "sed -i -e /secrets/d ordinary.txt" 0

_run_bash_case "38: sed -i -f SCRIPT FILE, SCRIPT itself critical-shaped -> not blocked (SCRIPT is read, not written)" \
  "$TMPDIR_ROOT" "sed -i -f .env ordinary.txt" 0

_run_bash_case "39: sed -i -e EXPR FILE, FILE is critical-shaped -> still blocked (the real file, not the expression)" \
  "$TMPDIR_ROOT" "sed -i -e s/a/b/ .env" 2

# ===================================================================
# F4 [round 2]: `cd`'s own literal argument is resolved and used as the new
# base for later relative targets, not just marked unresolvable.
# ===================================================================

_run_bash_case "40: [MANDATORY] cd sub && a relative critical write -> resolved against the NEW base, blocked" \
  "$TMPDIR_ROOT" "cd sub && echo pwned > .env" 2

_run_bash_case "41: cd \"\$VAR\" (genuinely unresolvable) && a relative write -> not blocked (unresolvable, skipped)" \
  "$TMPDIR_ROOT" 'cd "$VAR" && echo pwned > .env' 0

# ===================================================================
# F13: the half of F3 that keeps the heredoc's OPENER line (its own
# trailing redirect) in the token stream instead of dropping it with the
# body. Here the REDIRECT itself is the critical target, with an ordinary
# body -- the inverse of case 28, which has it the other way around.
# ===================================================================

_run_bash_case "42: heredoc opener's OWN redirect target is critical-shaped, body is ordinary -> blocked" \
  "$TMPDIR_ROOT" "cat <<'EOF' > .env
ordinary body text
EOF" 2

# ===================================================================
# F14 [round 3]: round 2's cd/pushd base tracking had no SCOPE. A `cd`
# inside `(...)`, on either side of a `|`, or backgrounded with `&`, runs
# in a CHILD process and never changes the PARENT shell's directory once
# that construct ends. `secrets/` (created above, for the cp -t case)
# stands in for a critical DIRECTORY here: without scoping, `(cd secrets
# && ok) && echo x > ordinary.txt` reads the later relative target as
# resolved INSIDE secrets/, matching `/secrets/` and blocking a write that,
# run for real, lands as plain TMPDIR_ROOT/ordinary.txt.
# ===================================================================

_run_bash_case "43: [MANDATORY] (cd secrets && ok) && an ordinary write -> NOT blocked, subshell cd does not leak" \
  "$TMPDIR_ROOT" "(cd secrets && echo ok) && echo x > ordinary.txt" 0

_run_bash_case "44: (cd secrets); an ordinary write, after the subshell closes -> NOT blocked" \
  "$TMPDIR_ROOT" "(cd secrets); echo x > ordinary.txt" 0

_run_bash_case "45: [MANDATORY] cd secrets | cat; an ordinary write -> NOT blocked, pipeline stage cd does not leak" \
  "$TMPDIR_ROOT" "cd secrets | cat; echo x > ordinary.txt" 0

_run_bash_case "46: [MANDATORY] pushd secrets; popd; an ordinary write -> NOT blocked, popd un-does the pushd" \
  "$TMPDIR_ROOT" "pushd secrets >/dev/null; popd >/dev/null; echo x > ordinary.txt" 0

# --- control: a TOP-LEVEL cd, not inside any of the scopes above, still
# carries forward exactly like round 2. ---

_run_bash_case "47: [control] cd secrets; an ordinary-NAMED write (';', not '&&') -> blocked, top-level cd is unaffected by the scoping fix" \
  "$TMPDIR_ROOT" "cd secrets; echo x > ordinary.txt" 2

# ===================================================================
# F16: a WORD that is a redirect's own OPERAND (an INPUT file, never
# written) used to be reported as a second WRITE target for the command it
# follows (see bash-write-targets.py's own REDIRECT_OPERAND_OPS comment).
# For this hook specifically that is not just an observability miscount —
# it is a FALSE BLOCK: a command that only READS a critical-shaped file
# (never writes it) used to be refused anyway, because the input file's
# name landed in the same "files this command writes" list as the real,
# ordinary target sitting right next to it.
# ===================================================================

_run_bash_case "48: [MANDATORY] sed -i with a critical-shaped INPUT redirect -> NOT blocked (.env is only read, ordinary.txt is the real write)" \
  "$TMPDIR_ROOT" "sed -i s/a/b/ ordinary.txt < .env" 0

_run_bash_case "49: [MANDATORY] tee with a critical-shaped INPUT redirect -> NOT blocked (.env is only read, ordinary.txt is the real write)" \
  "$TMPDIR_ROOT" "tee ordinary.txt < .env" 0

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
