#!/usr/bin/env bash
# log-agent.sh
# Observability hook. Appends one line to .claude/agent-log.txt every time a
# subagent finishes, giving an audit trail of orchestration runs.
#
# Wire on SubagentStop in .claude/settings.json. Never blocks (always exit 0).
# The log is gitignored.

input=$(cat)
ts=$(date +"%Y-%m-%d %H:%M:%S")

# Extract session id and (best-effort) the agent type with python3 (portable).
session=$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("session_id") or "?")
except Exception: print("?")' 2>/dev/null || echo "?")

agent=$(printf '%s' "$input" | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin)
    print(d.get("subagent_type") or d.get("agent_type") or d.get("agent") or "?")
except Exception:
    print("?")' 2>/dev/null || echo "?")

log=".claude/agent-log.txt"
{ touch "$log" && echo "[$ts] subagent_stop  agent=$agent  session=$session" >> "$log"; } 2>/dev/null

exit 0
