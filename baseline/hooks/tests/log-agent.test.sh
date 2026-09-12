#!/usr/bin/env bash
# log-agent.test.sh
# Standalone fixture suite for baseline/hooks/log-agent.sh. Builds a throwaway
# project directory in a mktemp dir with its own .claude/agent-log.txt (NEVER
# the real .claude/agent-log.txt of this checkout), feeds the hook the same
# SubagentStop JSON-on-stdin shape Claude Code sends, and inspects the LINE(S)
# actually appended to that log — not just the exit code, since this hook
# never blocks and a passing exit code proves nothing about what it logged.
#
# No git fixture is needed here (unlike protect-main.test.sh): this hook
# never shells out to git, so there is nothing for the session's own live
# guard hooks to intercept while building the fixture. See
# .claude/agent-memory/implementer/feedback_hook-testing-in-harness-worktrees.md
# for why that note exists at all.
#
# The subagent transcript layout mirrors what Claude Code actually writes:
#   <projects-dir>/<session-id>/subagents/agent-<id>.jsonl
#   <projects-dir>/<session-id>/subagents/agent-<id>.meta.json
# with `transcript_path` in the payload pointing at
#   <projects-dir>/main.jsonl
# (i.e. dirname(transcript_path) is the projects dir, and the subagents dir
# for a session sits at <projects-dir>/<session-id>/subagents — one directory
# level the hook derives, not something the payload spells out directly).
#
# Run: bash baseline/hooks/tests/log-agent.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../log-agent.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "log-agent.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
# Canonicalize: on macOS, mktemp returns a path under /var/folders, which is
# itself a symlink to /private/var/folders. bash's `cd` does not resolve that
# symlink, and this hook's own Python subprocess opens files by the literal
# path it is handed (never a getcwd() comparison the way log-edit.sh's hook
# does) so this suite does not strictly need it for correctness — canonicalized
# anyway, on principle, so every path built below is stable if that ever
# changes. See
# .claude/agent-memory/implementer/feedback_macos-mktemp-symlink-in-hook-tests.md
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO/.claude"
LOG="$REPO/.claude/agent-log.txt"
: > "$LOG"

PASS_COUNT=0
FAIL_COUNT=0

_count_lines() {
  [[ -f "$1" ]] || { echo 0; return; }
  wc -l < "$1" | tr -d '[:space:]'
}

# Strips the "[YYYY-MM-DD HH:MM:SS] " timestamp prefix the hook writes fresh
# on every call, so the rest of the line (deterministic, built from the
# fixture) can be compared exactly.
_strip_ts() {
  sed -E 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] //'
}

# $1 = session_id, $2 = transcript_path, $3 = agent_id (optional),
# $4 = agent_transcript_path (optional)
_payload() {
  "$PYTHON_BIN" -c 'import json, sys
session, tp, agent_id, agent_tp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
d = {"session_id": session, "transcript_path": tp}
if agent_id:
    d["agent_id"] = agent_id
if agent_tp:
    d["agent_transcript_path"] = agent_tp
print(json.dumps(d))' "$1" "$2" "${3:-}" "${4:-}"
}

# Seeds one subagent transcript pair (deterministic metrics: tokens=170,
# cached=30, dur=5s, tools=1) so every tier of resolution can be checked
# against the exact same numbers.
# $1 = subagents dir, $2 = agent id, $3 = agentType, $4 = description
_seed_agent() {
  local dir="$1" id="$2" agent_type="$3" desc="$4"
  mkdir -p "$dir"
  "$PYTHON_BIN" -c 'import json, sys
json.dump({"agentType": sys.argv[2], "description": sys.argv[3]}, open(sys.argv[1], "w"))' \
    "$dir/agent-$id.meta.json" "$agent_type" "$desc"
  cat > "$dir/agent-$id.jsonl" <<'EOF'
{"timestamp": "2026-01-01T00:00:00Z", "message": {"usage": {"input_tokens": 100, "output_tokens": 50, "cache_creation_input_tokens": 20, "cache_read_input_tokens": 30}, "content": [{"type": "tool_use"}]}}
{"timestamp": "2026-01-01T00:00:05Z", "message": {"usage": {"input_tokens": 0, "output_tokens": 0}, "content": []}}
EOF
}

# $1 = test name, $2 = payload (already JSON), $3 = expected new lines
# (timestamp prefix stripped), joined by real newlines; "" means "no new
# line at all". $4 (optional) = expected exit code, default 0.
# $5 (optional) = a directory to run the hook FROM (defaults to $REPO).
_run_case() {
  local name="$1" payload="$2" expected="$3" expected_rc="${4:-0}" run_dir="${5:-$REPO}"
  local before after new_count actual_rc actual

  before=$(_count_lines "$LOG")
  actual_rc=$(
    cd "$run_dir" || exit 99
    printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
    echo $?
  )
  after=$(_count_lines "$LOG")
  new_count=$((after - before))

  if [[ "$new_count" -gt 0 ]]; then
    actual=$(tail -n "$new_count" "$LOG" | _strip_ts)
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

# --------------------------------------------------------- tier 1: exact path
SESS1="tier1"
DIR1="$REPO/proj/$SESS1/subagents"
_seed_agent "$DIR1" "aaa" "implementer" "case one task"

_run_case "1: agent_transcript_path in payload — full metrics, no approx" \
  "$(_payload "$SESS1" "$REPO/proj/main.jsonl" "" "$DIR1/agent-aaa.jsonl")" \
  "subagent_stop  agent=implementer  tokens=170  cached=30  dur=5s  tools=1  desc=\"case one task\"  session=$SESS1"

# ------------------------------------------------------ tier 2: agent_id only
SESS2="tier2"
DIR2="$REPO/proj/$SESS2/subagents"
_seed_agent "$DIR2" "bbb" "tester" "case two task"

_run_case "2: agent_id only — resolved by name, full metrics, no approx" \
  "$(_payload "$SESS2" "$REPO/proj/main.jsonl" "bbb" "")" \
  "subagent_stop  agent=tester  tokens=170  cached=30  dur=5s  tools=1  desc=\"case two task\"  session=$SESS2"

# --------------------------------------- tier 3: neither — first hit is approx
SESS3="tier3a"
DIR3="$REPO/proj/$SESS3/subagents"
_seed_agent "$DIR3" "ccc" "implementer" "case three task"
PAYLOAD3="$(_payload "$SESS3" "$REPO/proj/main.jsonl" "" "")"

_run_case "3: neither id nor path, not yet consumed — approx=1 with metrics" \
  "$PAYLOAD3" \
  "subagent_stop  agent=implementer  tokens=170  cached=30  dur=5s  tools=1  desc=\"case three task\"  approx=1  session=$SESS3"

# ------------------------------- tier 3 repeated: second hit on same transcript
_run_case "4: same case repeated — dup=1, no tokens/cached/dur/tools" \
  "$PAYLOAD3" \
  "subagent_stop  agent=implementer  desc=\"case three task\"  approx=1  dup=1  session=$SESS3"

# --------------------- tier 3, three SubagentStop in a row (parallel wave sim)
SESS5="wave1"
DIR5="$REPO/proj/$SESS5/subagents"
_seed_agent "$DIR5" "ddd" "implementer" "wave task"
PAYLOAD5="$(_payload "$SESS5" "$REPO/proj/main.jsonl" "" "")"

_run_case "5a: wave, 1st SubagentStop with no agent_id — approx=1 with metrics" \
  "$PAYLOAD5" \
  "subagent_stop  agent=implementer  tokens=170  cached=30  dur=5s  tools=1  desc=\"wave task\"  approx=1  session=$SESS5"

_run_case "5b: wave, 2nd SubagentStop, same guessed file — dup=1, no metric" \
  "$PAYLOAD5" \
  "subagent_stop  agent=implementer  desc=\"wave task\"  approx=1  dup=1  session=$SESS5"

_run_case "5c: wave, 3rd SubagentStop, same guessed file — dup=1, no metric" \
  "$PAYLOAD5" \
  "subagent_stop  agent=implementer  desc=\"wave task\"  approx=1  dup=1  session=$SESS5"

# ------------------------------------------- unwritable/unreadable registry
# A separate throwaway repo: this case deliberately makes
# .claude/.agent-log-consumed unusable as a file (a directory sits at that
# path instead), which must never corrupt the registry or block the hook —
# only skip the dedup check for this call, falling back to pre-fix behaviour
# (approx=1, metrics included).
REPO6="$TMPDIR_ROOT/repo6"
mkdir -p "$REPO6/.claude"
LOG6="$REPO6/.claude/agent-log.txt"
: > "$LOG6"
mkdir -p "$REPO6/.claude/.agent-log-consumed"

SESS6="nowrite"
DIR6="$REPO6/proj/$SESS6/subagents"
_seed_agent "$DIR6" "eee" "implementer" "no write task"

LOG="$LOG6"
_run_case "6: registry path is a directory (unwritable as a file) — exit 0, line still written" \
  "$(_payload "$SESS6" "$REPO6/proj/main.jsonl" "" "")" \
  "subagent_stop  agent=implementer  tokens=170  cached=30  dur=5s  tools=1  desc=\"no write task\"  approx=1  session=$SESS6" \
  "0" \
  "$REPO6"

if [[ -d "$REPO6/.claude/.agent-log-consumed" && ! -f "$REPO6/.claude/.agent-log-consumed" ]]; then
  echo "PASS: 6b: registry path still a directory afterward — not corrupted into a file"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: 6b: registry path still a directory afterward — not corrupted into a file"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
LOG="$REPO/.claude/agent-log.txt"

# -------------------------------------------------------------- malformed payload
_run_case "7: garbage payload — exit 0, agent=? session=?" \
  "not json at all" \
  "subagent_stop  agent=?  session=?" \
  "0"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
