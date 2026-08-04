#!/usr/bin/env bash
# harness-report.sh
# Reads the two observability logs and prints the numbers that say whether the
# harness is being used the way it is designed:
#
#   .claude/tool-log.txt    (log-edit.sh)   — who edits: main thread or specialist
#   .claude/agent-log.txt   (log-agent.sh)  — what each dispatch cost
#
# Prints a plain table on stdout. Exits 0 always — this measures, it does not gate.
# Compare the output against .claude/docs/harness-baseline.md.
#
#   .claude/scripts/harness-report.sh
#   .claude/scripts/harness-report.sh --json

set -uo pipefail

TOOL_LOG=".claude/tool-log.txt"
AGENT_LOG=".claude/agent-log.txt"
JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

python3 - "$TOOL_LOG" "$AGENT_LOG" "$JSON" <<'PY'
import sys, os, json, re, collections

tool_log, agent_log, as_json = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

# ---------------------------------------------------------------- delegation
edits = collections.Counter()
by_ext = collections.Counter()
if os.path.exists(tool_log):
    for line in open(tool_log, encoding="utf-8", errors="replace"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 4:
            continue
        _, thread, _tool, path = parts[0], parts[1], parts[2], parts[3]
        edits[thread] += 1
        if thread == "main" and path:
            by_ext[os.path.splitext(path)[1] or "(no ext)"] += 1

total_edits = sum(edits.values())
known = edits["main"] + edits["sub"]
delegated_pct = round(100 * edits["sub"] / known) if known else None

# ---------------------------------------------------------------- dispatches
# agent-log.txt lines look like: "<iso> agent=<type> desc=... tokens=N dur=Ns tools=N"
agents = collections.Counter()
tokens_total = 0
dispatches = 0
unknown_agent = 0
if os.path.exists(agent_log):
    for line in open(agent_log, encoding="utf-8", errors="replace"):
        if not line.strip():
            continue
        dispatches += 1
        m = re.search(r"agent=(\S+)", line)
        a = m.group(1) if m else "?"
        if a in ("?", "unknown"):
            unknown_agent += 1
        agents[a] += 1
        t = re.search(r"tokens=(\d+)", line)
        if t:
            tokens_total += int(t.group(1))

out = {
    "edits_total": total_edits,
    "edits_main": edits["main"],
    "edits_sub": edits["sub"],
    "edits_unknown_thread": edits["?"],
    "delegated_pct": delegated_pct,
    "dispatches": dispatches,
    "dispatch_types": dict(agents.most_common()),
    "unattributed_dispatches": unknown_agent,
    "subagent_tokens": tokens_total,
    "main_thread_edit_hotspots": dict(by_ext.most_common(5)),
}

if as_json:
    print(json.dumps(out, indent=2))
    sys.exit(0)

def line(k, v):
    print(f"  {k:<34} {v}")

print()
print("harness report")
print("─" * 52)

if total_edits == 0 and dispatches == 0:
    print("  no data yet — the logs are gitignored and start empty.")
    print("  run some work first, then re-run this.")
    print()
    sys.exit(0)

print(" delegation  (rules/delegation.md)")
if known:
    line("file edits, total", total_edits)
    line("  in the main thread", edits["main"])
    line("  in a specialist", edits["sub"])
    line("DELEGATED", f"{delegated_pct}%")
else:
    line("file edits", "no thread-attributable edits yet")
if edits["?"]:
    line("thread unknown", edits["?"])
if by_ext:
    line("main-thread edits by type", ", ".join(f"{k} {v}" for k, v in by_ext.most_common(5)))

print()
print(" dispatch  (docs/dispatching.md)")
line("dispatches logged", dispatches)
if agents:
    line("by agent", ", ".join(f"{k} {v}" for k, v in agents.most_common(6)))
if unknown_agent:
    line("unattributed", f"{unknown_agent}  (log-agent.sh could not resolve the type)")
if tokens_total:
    line("subagent tokens", f"{tokens_total:,}")

print()
print(" compare against .claude/docs/harness-baseline.md")
print()
PY

exit 0
