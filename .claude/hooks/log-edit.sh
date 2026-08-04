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
# Thread detection: a subagent's transcript lives under a `subagents/` directory,
# the main thread's does not. That is a heuristic on the payload shape, not a
# documented field — when it cannot tell, it records `?` rather than guessing,
# and the report counts unknowns separately instead of folding them into either
# side.

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

tp = d.get("transcript_path") or ""
if not tp:
    thread = "?"
elif "subagents" in tp.split(os.sep):
    thread = "sub"
else:
    thread = "main"

# Repo-relative when possible: absolute paths make the log unreadable and leak
# the checkout location into a file people paste into issues.
cwd = os.getcwd()
if path.startswith(cwd + os.sep):
    path = path[len(cwd) + 1:]

ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print("\t".join([ts, thread, tool, path]))
' >> .claude/tool-log.txt 2>/dev/null

exit 0
