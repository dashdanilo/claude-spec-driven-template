#!/usr/bin/env bash
# log-edit.sh
# Observability hook. Appends one line to .claude/tool-log.txt every time a file
# is edited or written, recording WHICH THREAD did it.
#
# Wire on PreToolUse for Edit|Write|MultiEdit|NotebookEdit. Never blocks (always
# exit 0, no decision output). The log is gitignored.
#
# Why this exists: `.claude/rules/delegation.md` says the main thread coordinates
# and specialists implement. On a real project that rule was already written and
# 71% of Edit calls still happened in the main thread. A rule you cannot see
# being broken is a rule that decays. This makes it countable, and
# `/harness-report` makes it visible.
#
# Thread detection: read the payload directly rather than inferring from
# `transcript_path`. A subagent's `PreToolUse` payload carries `agent_id` (and
# usually `agent_type`) — that alone means "sub", regardless of what
# `transcript_path` points at. Measured: a captured payload from inside an
# `implementer` subagent had `transcript_path` pointing at the *main* session's
# transcript (no `subagents` segment anywhere in it) while `agent_id` and
# `agent_type` were both present. The old heuristic — "sub" only when
# `transcript_path` contains a `subagents` segment, "main" otherwise — read
# that as `main`, so every specialist edit was silently counted as main-thread
# work, one direction only. The old header comment claimed it "records `?`
# rather than guessing" for the case it cannot tell; it did not — it guessed
# `main` with full confidence. The `subagents`-segment check is kept as a
# second-line fallback for older clients whose payload omits `agent_id`. `?` is
# reserved for the one case with neither signal: no `agent_id` and no
# `transcript_path` at all.

set -uo pipefail

input=$(cat)

printf '%s' "$input" | python3 -c '
import sys, json, datetime, os

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = d.get("tool_name") or "?"
ti = d.get("tool_input") or {}
path = ti.get("file_path") or ti.get("notebook_path") or ""

agent_type = d.get("agent_type") or ""
agent_id = d.get("agent_id") or ""
tp = d.get("transcript_path") or ""

if agent_id or agent_type:
    thread = "sub"
elif tp and "subagents" in tp.split(os.sep):
    thread = "sub"
elif tp:
    thread = "main"
else:
    thread = "?"

# Repo-relative when possible: absolute paths make the log unreadable and leak
# the checkout location into a file people paste into issues.
cwd = os.getcwd()
if path.startswith(cwd + os.sep):
    path = path[len(cwd) + 1:]

ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print("\t".join([ts, thread, tool, path, agent_type]))
' >> .claude/tool-log.txt 2>/dev/null

exit 0
