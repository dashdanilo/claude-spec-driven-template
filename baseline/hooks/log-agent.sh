#!/usr/bin/env bash
# log-agent.sh
# Observability hook. Appends one line to .claude/agent-log.txt every time a
# subagent finishes: which agent, what it was asked, and what it cost.
#
# Wire on SubagentStop in .claude/settings.json. Never blocks (always exit 0).
# The log is gitignored.
#
# The current SubagentStop payload already carries agent_type, agent_id and
# agent_transcript_path, so resolution is a cascade from most to least
# reliable:
#   1. agent_transcript_path from the payload, used directly if it exists.
#   2. agent_id, matched to <subagents-dir>/agent-<id>.jsonl — never by mtime.
#   3. newest-by-mtime in the subagents dir, kept only for older clients that
#      send neither of the above; a parallel wave makes every SubagentStop in
#      it resolve to the same (wrong) file, so this path is marked approx=1
#      so the report does not treat a guess as a measurement.
# The matching *.meta.json (same path, .jsonl -> .meta.json) supplies
# agentType/description only when the payload itself did not.
#
# tokens= is new context actually paid for: input + output + cache_creation.
# cached= (when > 0) is cache_read separately — real but an order of magnitude
# cheaper, so it is never folded into tokens= (that would hide the distinction
# that matters).

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
agent_id = d.get("agent_id") or ""
agent_tp = d.get("agent_transcript_path") or ""
desc = ""
tokens = cached = dur = tools = None
approx = False

tp = d.get("transcript_path") or ""
subdir = os.path.join(os.path.dirname(tp), session, "subagents") if tp and session != "?" else ""

jf = meta_path = None

# 1. The payload already points at the exact transcript. Trust it.
if agent_tp and os.path.isfile(agent_tp):
    jf = agent_tp
    base = agent_tp[: -len(".jsonl")] if agent_tp.endswith(".jsonl") else agent_tp
    meta_path = base + ".meta.json"

# 2. No path, but an id: match the file by name, never by recency.
elif agent_id and subdir and os.path.isdir(subdir):
    cand = os.path.join(subdir, "agent-%s.jsonl" % agent_id)
    if os.path.isfile(cand):
        jf = cand
        meta_path = os.path.join(subdir, "agent-%s.meta.json" % agent_id)

# 3. Neither: last resort for older clients. In a parallel wave every
#    SubagentStop resolves to the same newest file, so flag it as a guess.
if jf is None and subdir and os.path.isdir(subdir):
    metas = sorted(glob.glob(os.path.join(subdir, "*.meta.json")), key=os.path.getmtime)
    if metas:
        meta_path = metas[-1]
        jf = meta_path[: -len(".meta.json")] + ".jsonl"
        approx = True

if meta_path and os.path.exists(meta_path):
    try:
        m = json.load(open(meta_path))
        agent = agent or m.get("agentType")
        desc = (m.get("description") or "")[:60]
    except Exception:
        pass

if jf and os.path.exists(jf):
    tok = 0; cache_read = 0; ntool = 0; t0 = t1 = None
    try:
        for raw in open(jf, errors="replace"):
            try: e = json.loads(raw)
            except Exception: continue
            t = iso(e.get("timestamp"))
            if t:
                t0 = t0 or t; t1 = t
            msg = e.get("message") or {}
            u = msg.get("usage") or {}
            tok += (
                u.get("input_tokens", 0)
                + u.get("output_tokens", 0)
                + u.get("cache_creation_input_tokens", 0)
            )
            cache_read += u.get("cache_read_input_tokens", 0)
            c = msg.get("content")
            if isinstance(c, list):
                ntool += sum(1 for b in c if isinstance(b, dict) and b.get("type") == "tool_use")
        tokens = tok or None
        cached = cache_read or None
        tools = ntool or None
        if t0 and t1:
            dur = int((t1 - t0).total_seconds())
    except Exception:
        pass

parts = ["agent=%s" % (agent or "?")]
if tokens is not None: parts.append("tokens=%d" % tokens)
if cached is not None: parts.append("cached=%d" % cached)
if dur is not None:    parts.append("dur=%ds" % dur)
if tools is not None:  parts.append("tools=%d" % tools)
if desc:               parts.append("desc=%s" % json.dumps(desc))
if approx:             parts.append("approx=1")
parts.append("session=%s" % session[:8])
print("  ".join(parts))
' 2>/dev/null) || line=""

[ -z "$line" ] && line="agent=?"
ts=$(date +"%Y-%m-%d %H:%M:%S")

log=".claude/agent-log.txt"
{ touch "$log" && echo "[$ts] subagent_stop  $line" >> "$log"; } 2>/dev/null

exit 0
