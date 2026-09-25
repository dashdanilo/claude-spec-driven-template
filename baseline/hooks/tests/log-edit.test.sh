#!/usr/bin/env bash
# log-edit.test.sh
# Standalone fixture suite for baseline/hooks/log-edit.sh. Builds a throwaway
# directory in a mktemp dir with its own .claude/tool-log.txt (NEVER the real
# .claude/tool-log.txt of this checkout), feeds the hook the same JSON-on-
# stdin shape Claude Code sends, and inspects the LINE(S) actually written to
# that log — not just the exit code, since this hook never blocks and a
# passing exit code proves nothing about what it logged.
#
# No git fixture is needed here (unlike protect-main.test.sh): this hook
# never shells out to git, so there is nothing for the session's own live
# guard hooks to intercept while building the fixture. See
# .claude/agent-memory/implementer/feedback_hook-testing-in-harness-worktrees.md
# for why that note exists at all.
#
# Run: bash baseline/hooks/tests/log-edit.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../log-edit.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "log-edit.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
# Canonicalize: on macOS, mktemp returns a path under /var/folders, which is
# itself a symlink to /private/var/folders. bash's `cd` does not resolve that
# symlink, but Python's os.getcwd() (what the hook actually compares against)
# returns the resolved, physical path — so a file_path built from the
# unresolved $TMPDIR_ROOT would never match the hook's cwd-prefix check
# through no fault of the hook. `pwd -P` resolves it once, up front, so every
# path built from $TMPDIR_ROOT below agrees with what the hook sees.
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO/.claude" "$REPO/sub"
LOG="$REPO/.claude/tool-log.txt"
: > "$LOG"

PASS_COUNT=0
FAIL_COUNT=0

_count_lines() {
  # wc -l on a file with no trailing newline undercounts by one; every line
  # this hook writes ends in \n (print()), so this is exact for our fixture.
  [[ -f "$1" ]] || { echo 0; return; }
  wc -l < "$1" | tr -d '[:space:]'
}

_bash_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({
    "tool_name": "Bash",
    "tool_input": {"command": sys.argv[1]},
    "transcript_path": "/fake/session/main.jsonl",
  }))' "$1"
}

_edit_payload() {
  # $1 = tool name, $2 = file_path, $3 = "main" or "sub"
  if [[ "$3" == "sub" ]]; then
    "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({
      "tool_name": sys.argv[1],
      "tool_input": {"file_path": sys.argv[2]},
      "agent_id": "abc123",
      "agent_type": "implementer",
      "transcript_path": "/fake/session/main.jsonl",
    }))' "$1" "$2"
  else
    "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({
      "tool_name": sys.argv[1],
      "tool_input": {"file_path": sys.argv[2]},
      "transcript_path": "/fake/session/main.jsonl",
    }))' "$1" "$2"
  fi
}

# $1 = test name, $2 = payload (already JSON), $3 = expected new lines: each
# a tab-separated "thread\ttool\tpath\tagent_type" (timestamp column
# stripped before comparing), joined by real newlines; "" means "no new
# line at all". $4 (optional) = expected exit code, default 0.
_run_case() {
  local name="$1" payload="$2" expected="$3" expected_rc="${4:-0}"
  local before after new_count actual_rc actual

  before=$(_count_lines "$LOG")
  actual_rc=$(
    cd "$REPO" || exit 99
    printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
    echo $?
  )
  after=$(_count_lines "$LOG")
  new_count=$((after - before))

  if [[ "$new_count" -gt 0 ]]; then
    actual=$(tail -n "$new_count" "$LOG" | cut -f2-)
  else
    actual=""
  fi

  if [[ "$actual" == "$expected" && "$actual_rc" == "$expected_rc" ]]; then
    echo "PASS: $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name"
    echo "  expected rc=$expected_rc, lines:"
    echo "$expected" | sed 's/^/    /'
    echo "  actual   rc=$actual_rc, lines:"
    echo "$actual" | sed 's/^/    /'
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

TAB=$'\t'

# ------------------------------------------------------------- Bash: redirects
_run_case "1: simple redirect, target inside repo" \
  "$(_bash_payload 'echo hi > out.txt')" \
  "main${TAB}Bash:redirect${TAB}out.txt${TAB}"

_run_case "2: append redirect, target inside repo" \
  "$(_bash_payload 'echo hi >> out.txt')" \
  "main${TAB}Bash:redirect${TAB}out.txt${TAB}"

# ------------------------------------------------------------- Bash: write cmds
_run_case "3: sed -i, target inside repo" \
  "$(_bash_payload "sed -i 's/a/b/' sub/file.txt")" \
  "main${TAB}Bash:sed-i${TAB}sub/file.txt${TAB}"

_run_case "4: tee, target inside repo" \
  "$(_bash_payload 'echo hi | tee sub/teed.txt')" \
  "main${TAB}Bash:tee${TAB}sub/teed.txt${TAB}"

_run_case "5: cp, target inside repo" \
  "$(_bash_payload 'cp out.txt sub/copy.txt')" \
  "main${TAB}Bash:cp${TAB}sub/copy.txt${TAB}"

_run_case "6: mv, target inside repo" \
  "$(_bash_payload 'mv out.txt sub/moved.txt')" \
  "main${TAB}Bash:mv${TAB}sub/moved.txt${TAB}"

# ------------------------------------------------------------- outside the repo
_run_case "7: redirect to /tmp — outside the repo, not logged" \
  "$(_bash_payload 'echo hi > /tmp/should-not-appear.txt')" \
  ""

_run_case "8: redirect to /dev/null — outside the repo, not logged" \
  "$(_bash_payload 'echo hi > /dev/null')" \
  ""

# -------------------------------------------------------------- false positives
_run_case "9: 2>&1 — stderr-to-fd, no file target, not logged" \
  "$(_bash_payload 'echo hi 2>&1')" \
  ""

_run_case "10: 2>/dev/null — stderr redirect, not logged" \
  "$(_bash_payload 'some-cmd 2>/dev/null')" \
  ""

# `&>`, `>|`, `>&` (with a filename) and `2>` (with a real target, not
# /dev/null) all write a file exactly like plain `>` — an earlier version
# excluded all of them outright on the wrong theory that they are always
# fd-duplication. `>&2`/`2>&1` (a BARE fd reference, no filename at all)
# stay excluded, right below.
_run_case "10b: &> writes a file, target inside repo — logged" \
  "$(_bash_payload 'echo hi &> out.txt')" \
  "main${TAB}Bash:redirect${TAB}out.txt${TAB}"

_run_case "10c: >| (force-write) writes a file, target inside repo — logged" \
  "$(_bash_payload 'echo hi >| out.txt')" \
  "main${TAB}Bash:redirect${TAB}out.txt${TAB}"

_run_case "10d: >& with a filename writes a file, target inside repo — logged" \
  "$(_bash_payload 'echo hi >& out.txt')" \
  "main${TAB}Bash:redirect${TAB}out.txt${TAB}"

_run_case "10e: 2> with a real target creates/truncates it, target inside repo — logged" \
  "$(_bash_payload 'echo hi 2> out.txt')" \
  "main${TAB}Bash:redirect${TAB}out.txt${TAB}"

_run_case "10f: >&2 — a BARE fd reference, no filename at all — not logged" \
  "$(_bash_payload 'echo hi >&2')" \
  ""

_run_case "11: >/dev/null with no space — not logged" \
  "$(_bash_payload 'echo hi >/dev/null')" \
  ""

_run_case "12: '>' inside a quoted string — not a redirect, not logged" \
  "$(_bash_payload 'git commit -m "a > b"')" \
  ""

_run_case "13: [[ ]] string comparison — not a redirect, not logged" \
  "$(_bash_payload '[[ 5 > 3 ]]')" \
  ""

_run_case "14: (( )) arithmetic comparison — not a redirect, not logged" \
  "$(_bash_payload '(( 5 > 3 ))')" \
  ""

# ----------------------------------------- keyword-prefixed [[ ]] (regression)
# Found by an independent probe after the first pass of this suite: the
# guard checked only whether the SEGMENT'S FIRST TOKEN was "[[", but a
# keyword (`if`, `while`, `until`, `elif`, `!`) sits in front of `[[` in the
# very same segment (the segment runs up to the next `;`/`&&`/etc, and none
# of those keywords introduce one), so the anchored check never fired and
# `if [[ 5 > 3 ]]` logged a phantom write to a file named "3". The guard now
# looks for "[[" / "]]" / "[" / "]" ANYWHERE in the segment, the same way the
# "((" / "))" arithmetic check already did — these five cases would all have
# produced a phantom "Bash:redirect" line under the old anchored check.
_run_case "15: if [[ a > b ]] — keyword prefix, not logged" \
  "$(_bash_payload 'if [[ 5 > 3 ]]; then echo ok; fi')" \
  ""

_run_case "16: while [[ a > b ]] — keyword prefix, not logged" \
  "$(_bash_payload 'while [[ $a > $b ]]; do sleep 1; done')" \
  ""

_run_case "17: until [[ a > b ]] — keyword prefix, not logged" \
  "$(_bash_payload 'until [[ $a > $b ]]; do sleep 1; done')" \
  ""

_run_case "18: if ! [[ a > b ]] — negation prefix, not logged" \
  "$(_bash_payload 'if ! [[ $a > $b ]]; then echo ok; fi')" \
  ""

_run_case "19: then inline with [[ ]] in the same segment — not logged" \
  "$(_bash_payload 'if cond; then [[ $a > $b ]] && echo x; fi')" \
  ""

# The risk of the fix above: a guard that starts ignoring the whole segment
# could turn into "ignore anything touching an if/while/until", which would
# LOSE a real write that happens to sit inside one — worse than the phantom
# write it replaces. This proves a real redirect in its own segment (split
# off by the `;` after the test) is still caught.
_run_case "20: real write inside an if — still logged" \
  "$(_bash_payload 'if [[ -f x ]]; then echo y > real.txt; fi')" \
  "main${TAB}Bash:redirect${TAB}real.txt${TAB}"

# -------------------------------------------------------------- unresolvable
_run_case "21: redirect target is a variable — logged with path=?" \
  "$(_bash_payload 'echo hi > "$OUT"')" \
  "main${TAB}Bash:redirect${TAB}?${TAB}"

_run_case "22: mv target is a command substitution — logged with path=?" \
  "$(_bash_payload 'mv out.txt "$(echo sub)/report.txt"')" \
  "main${TAB}Bash:mv${TAB}?${TAB}"

# A `cd` earlier in the SAME command changes the base a later relative
# target resolves against. `cd`'s own argument is resolved and used as the
# new base when it can be (round 2): a LITERAL relative destination like
# `sub` is fully knowable, so the later target now resolves against it
# instead of the payload's original cwd — "sub/out.txt", not "?". Round 1
# only ever marked this unresolvable; round 2 actually follows the cd.
_run_case "22b: relative target after a cd with a LITERAL destination — resolved against the NEW base" \
  "$(_bash_payload 'cd sub && echo pwned > out.txt')" \
  "main${TAB}Bash:redirect${TAB}sub/out.txt${TAB}"

# `cd`'s own argument can still be genuinely unresolvable (a shell
# variable, a command substitution): THAT keeps every later relative
# target at path=?, since there is no way to know where the command
# actually ended up.
_run_case "22c: relative target after a cd whose OWN destination is unresolvable — logged with path=?" \
  "$(_bash_payload 'cd "$SOME_DIR" && echo pwned > out.txt')" \
  "main${TAB}Bash:redirect${TAB}?${TAB}"

# -------------------------------------------------------------- multiple targets
_run_case "23: two write commands chained — one line per target" \
  "$(_bash_payload 'cp out.txt sub/d1.txt && mv out.txt sub/d2.txt')" \
  "main${TAB}Bash:cp${TAB}sub/d1.txt${TAB}
main${TAB}Bash:mv${TAB}sub/d2.txt${TAB}"

_run_case "24: tee with two targets — one line per target" \
  "$(_bash_payload 'echo hi | tee sub/t1.txt sub/t2.txt')" \
  "main${TAB}Bash:tee${TAB}sub/t1.txt${TAB}
main${TAB}Bash:tee${TAB}sub/t2.txt${TAB}"

# -------------------------------------------------------------- Edit/Write — no regression
_run_case "25: Write, main thread — unchanged behaviour" \
  "$(_edit_payload "Write" "$REPO/written.txt" "main")" \
  "main${TAB}Write${TAB}written.txt${TAB}"

_run_case "26: Edit, sub thread (agent_id present) — unchanged behaviour" \
  "$(_edit_payload "Edit" "$REPO/edited.txt" "sub")" \
  "sub${TAB}Edit${TAB}edited.txt${TAB}implementer"

# -------------------------------------------------------------- malformed payload
_run_case "27: malformed JSON payload — exit 0, nothing written" \
  "not json at all" \
  "" \
  "0"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
