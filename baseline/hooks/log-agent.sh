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
# Degree 3's guess is fundamentally approximate, but there is one thing it
# must never do: charge the same transcript's tokens twice. When two or more
# SubagentStop events in the same session fall through to degree 3 and land
# on the same file (the exact parallel-wave case above), only the FIRST one
# may report that file's metrics; every later hit on the same file still
# gets agent= from the payload (that part is reliable — every approx=1 line
# observed so far had the correct type, since it comes straight off the
# payload, not off the guessed transcript) but tokens/cached/dur/tools are
# omitted rather than copied, and the line carries dup=1 instead. A line with
# no metric is honest; a line with someone else's metric is not, because the
# total sums it.
#
# The "already charged" registry is .claude/.agent-log-consumed (gitignored),
# one line per "<session><TAB><transcript path>" that degree 3 has already
# billed in this session. The whole check-then-record is done under one
# exclusive OS file lock (fcntl.flock): open, lock, read the (short) file,
# decide dup or not, append if not, unlock. The transcript's own per-line
# token scan happens AFTER the lock is released, so the lock is never held
# across the slow part — contention is bounded by "read a few dozen short
# lines and maybe append one." A held flock cannot deadlock this hook: it is
# scoped to the open file descriptor, and the OS releases it the instant that
# descriptor closes, including on a crash, so there is nothing to wait out.
# If fcntl is unavailable (some Windows shells) or the registry can't be
# read/written for any reason, the dedup check is skipped and degree 3
# behaves exactly as it did before this fix — approx=1, metrics included.
# That is the deliberate worst case: a lost dedup check, never a corrupted
# registry and never a hang.
#
# tokens= is new context actually paid for: input + output + cache_creation.
# cached= (when > 0) is cache_read separately — real but an order of magnitude
# cheaper, so it is never folded into tokens= (that would hide the distinction
# that matters).

input=$(cat)

# python3, falling back to `python` (some Windows shells only have `python` on
# PATH). Never blocks either way: if neither is present, this observability
# hook just has nothing to log this time.
PYTHON_BIN=python3
command -v python3 >/dev/null 2>&1 || PYTHON_BIN=python
command -v "$PYTHON_BIN" >/dev/null 2>&1 || exit 0

line=$(printf '%s' "$input" | "$PYTHON_BIN" -c '
import sys, json, os, glob, datetime

try:
    import fcntl
    HAVE_FLOCK = True
except Exception:
    HAVE_FLOCK = False

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
dup = False

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
#    SubagentStop resolves to the same newest file, so flag it as a guess —
#    and check the "already charged" registry before trusting its metrics.
if jf is None and subdir and os.path.isdir(subdir):
    metas = sorted(glob.glob(os.path.join(subdir, "*.meta.json")), key=os.path.getmtime)
    if metas:
        meta_path = metas[-1]
        jf = meta_path[: -len(".meta.json")] + ".jsonl"
        approx = True

        if session != "?":
            consumed_log = os.path.join(".claude", ".agent-log-consumed")
            key = session + "\t" + jf
            try:
                os.makedirs(os.path.dirname(consumed_log) or ".", exist_ok=True)
                fd = open(consumed_log, "a+")
                try:
                    if HAVE_FLOCK:
                        fcntl.flock(fd.fileno(), fcntl.LOCK_EX)
                    fd.seek(0)
                    existing = set(l.rstrip("\n") for l in fd)
                    if key in existing:
                        dup = True
                    else:
                        fd.write(key + "\n")
                        fd.flush()
                finally:
                    if HAVE_FLOCK:
                        try: fcntl.flock(fd.fileno(), fcntl.LOCK_UN)
                        except Exception: pass
                    fd.close()
            except Exception:
                # Bookkeeping failed (unreadable/unwritable registry, no
                # fcntl, etc). Never let this block the hook — fall back to
                # the pre-fix behaviour: approx=1, metrics included, no dup
                # check. A lost dedup check is the accepted worst case.
                pass

if meta_path and os.path.exists(meta_path):
    try:
        m = json.load(open(meta_path))
        agent = agent or m.get("agentType")
        desc = (m.get("description") or "")[:60]
    except Exception:
        pass

# A file already charged to another degree-3 line in this session must not
# be charged again: emit the (reliable) agent type above, but skip the
# transcript scan entirely so tokens/cached/dur/tools stay unset.
if jf and os.path.exists(jf) and not dup:
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
if dup:                parts.append("dup=1")
parts.append("session=%s" % session[:8])
print("  ".join(parts))
' 2>/dev/null) || line=""

[ -z "$line" ] && line="agent=?"
ts=$(date +"%Y-%m-%d %H:%M:%S")

log=".claude/agent-log.txt"
{ touch "$log" && echo "[$ts] subagent_stop  $line" >> "$log"; } 2>/dev/null

exit 0
