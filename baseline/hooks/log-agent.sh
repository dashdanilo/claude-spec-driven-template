#!/usr/bin/env bash
# log-agent.sh
# Observability hook. Appends one line to .claude/agent-log.txt every time a
# subagent finishes: which agent, what it was asked, and what it cost.
#
# Wire on SubagentStop in .claude/settings.json. Never blocks (always exit 0).
# The log is gitignored.
#
# The SubagentStop payload often omits the agent type (measured on a real
# project: unknown in ~77% of events), so we fall back to the subagent's own
# transcript, which always has it:
#   <dir of transcript_path>/<session_id>/subagents/agent-<id>.meta.json  -> agentType, description
#   <same>/agent-<id>.jsonl                                               -> usage, timestamps, tool calls

input=$(cat)

line=$(printf '%s' "$input" | python3 -c '
import sys, json, os, glob, datetime

def iso(s):
    try: return datetime.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except Exception: return None

try:
    d = json.load(sys.stdin)
except Exception:
    d = {}

session = d.get("session_id") or "?"
agent = d.get("subagent_type") or d.get("agent_type") or d.get("agent")
desc = ""
tokens = dur = tools = None

# Fall back to the subagent transcript for anything the payload did not carry.
tp = d.get("transcript_path") or ""
subdir = os.path.join(os.path.dirname(tp), session, "subagents") if tp and session != "?" else ""
if subdir and os.path.isdir(subdir):
    metas = sorted(glob.glob(os.path.join(subdir, "*.meta.json")), key=os.path.getmtime)
    if metas:
        newest = metas[-1]
        try:
            m = json.load(open(newest))
            agent = agent or m.get("agentType")
            desc = (m.get("description") or "")[:60]
        except Exception:
            pass
        jf = newest[: -len(".meta.json")] + ".jsonl"
        if os.path.exists(jf):
            tok = 0; ntool = 0; t0 = t1 = None
            try:
                for raw in open(jf, errors="replace"):
                    try: e = json.loads(raw)
                    except Exception: continue
                    t = iso(e.get("timestamp"))
                    if t:
                        t0 = t0 or t; t1 = t
                    msg = e.get("message") or {}
                    u = msg.get("usage") or {}
                    tok += u.get("input_tokens", 0) + u.get("output_tokens", 0)
                    c = msg.get("content")
                    if isinstance(c, list):
                        ntool += sum(1 for b in c if isinstance(b, dict) and b.get("type") == "tool_use")
                tokens = tok or None
                tools = ntool or None
                if t0 and t1:
                    dur = int((t1 - t0).total_seconds())
            except Exception:
                pass

parts = ["agent=%s" % (agent or "?")]
if tokens is not None: parts.append("tokens=%d" % tokens)
if dur is not None:    parts.append("dur=%ds" % dur)
if tools is not None:  parts.append("tools=%d" % tools)
if desc:               parts.append("desc=%s" % json.dumps(desc))
parts.append("session=%s" % session[:8])
print("  ".join(parts))
' 2>/dev/null) || line=""

[ -z "$line" ] && line="agent=?"
ts=$(date +"%Y-%m-%d %H:%M:%S")

log=".claude/agent-log.txt"
{ touch "$log" && echo "[$ts] subagent_stop  $line" >> "$log"; } 2>/dev/null

exit 0
