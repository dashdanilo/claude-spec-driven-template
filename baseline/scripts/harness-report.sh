#!/usr/bin/env bash
# harness-report.sh
# Reads the two observability logs and prints the numbers that say whether the
# harness is being used the way it is designed:
#
#   .claude/tool-log.txt    (log-edit.sh)   — who edits: main thread or specialist
#   .claude/agent-log.txt   (log-agent.sh)  — what each dispatch cost
#
# Prints a plain table on stdout. Exits 0 always — this measures, it does not gate.
# Compare the output against .claude/docs/harness/harness-baseline.md.
#
#   .claude/scripts/harness/harness-report.sh
#   .claude/scripts/harness/harness-report.sh --json

set -uo pipefail

TOOL_LOG=".claude/tool-log.txt"
AGENT_LOG=".claude/agent-log.txt"
BASELINE_DOC=".claude/docs/harness/harness-baseline.md"
JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

python3 - "$TOOL_LOG" "$AGENT_LOG" "$BASELINE_DOC" "$JSON" <<'PY'
import sys, os, json, re, collections

tool_log, agent_log, baseline_doc, as_json = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"

# ------------------------------------------------------------- instrument epoch
# harness-baseline.md marks, in prose, every date on which a fix to these two
# hooks made everything logged before it unusable for a headline number (see
# its 2026-09-09 section). The marker is a plain HTML comment,
# `<!-- instrument-epoch: YYYY-MM-DD -->`, so a future fix only has to add
# another one there — this script always takes the latest it finds, so it
# never needs its own edit when the next one lands. Missing the file (a repo
# that never linked the docs) or finding no marker means "no epoch known":
# nothing gets excluded, exactly like today with no fix pending.
def read_epoch(path):
    if not os.path.exists(path):
        return None
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except Exception:
        return None
    dates = re.findall(r"<!--\s*instrument-epoch:\s*(\d{4}-\d{2}-\d{2})\s*-->", text)
    return max(dates) if dates else None

epoch_date = read_epoch(baseline_doc)

# ---------------------------------------------------------------- delegation
# `tool` (column 3) is "Edit"/"Write"/"MultiEdit"/"NotebookEdit" for the
# original detector, or "Bash:<kind>" (redirect, sed-i, tee, cp, mv) for a
# write log-edit.sh recovered from a Bash command. Both count toward
# delegation the same way — a write is a write, and the thread is known
# either way — but the Bash-sourced ones are also tallied separately so a
# reader can see how much of the number rests on the newer, less-tested path.
edits = collections.Counter()
by_ext = collections.Counter()
by_specialist = collections.Counter()
bash_writes = 0
bash_writes_unresolved = 0
by_ext_ignored_unresolved = 0
if os.path.exists(tool_log):
    for line in open(tool_log, encoding="utf-8", errors="replace"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 4:
            continue
        _, thread, tool_col, path = parts[0], parts[1], parts[2], parts[3]
        agent_type = parts[4] if len(parts) > 4 else ""
        edits[thread] += 1
        is_bash_write = tool_col.startswith("Bash:")
        if is_bash_write:
            bash_writes += 1
            if path == "?":
                bash_writes_unresolved += 1
        if thread == "main" and path:
            if path == "?":
                by_ext_ignored_unresolved += 1
            else:
                by_ext[os.path.splitext(path)[1] or "(no ext)"] += 1
        if thread == "sub" and agent_type:
            by_specialist[agent_type] += 1

total_edits = sum(edits.values())
known = edits["main"] + edits["sub"]
delegated_pct = round(100 * edits["sub"] / known) if known else None

# ---------------------------------------------------------------- dispatches
# agent-log.txt lines look like:
#   "[<ts>] subagent_stop  agent=<type> desc=... tokens=N cached=N dur=Ns
#    tools=N [approx=1] [dup=1] session=..."
#
# Two lines never enter the headline "reliable" numbers:
#   - anything timestamped before the instrument epoch above — a different
#     era of the hook, mixed in it describes the detector, not this run.
#   - approx=1 lines' tokens/cached — a degree-3 guess (see log-agent.sh),
#     kept out of the total instead of dressed up as a measurement. A dup=1
#     line (a same-transcript collision the hook caught) has no tokens=
#     field at all, so it already contributes 0 without special-casing.
# Both are still counted and reported, on their own line, with the reason —
# never dropped in silence.
agents = collections.Counter()
tokens_total = 0
cached_total = 0
dispatches = 0
unknown_agent = 0
approx_attribution = 0
approx_tokens = 0
dup_dispatches = 0
pre_epoch_lines = 0
if os.path.exists(agent_log):
    for line in open(agent_log, encoding="utf-8", errors="replace"):
        if not line.strip():
            continue
        date_m = re.match(r"^\[(\d{4}-\d{2}-\d{2})", line)
        line_date = date_m.group(1) if date_m else None
        if epoch_date and line_date and line_date < epoch_date:
            pre_epoch_lines += 1
            continue
        dispatches += 1
        m = re.search(r"agent=(\S+)", line)
        a = m.group(1) if m else "?"
        if a in ("?", "unknown"):
            unknown_agent += 1
        agents[a] += 1
        t = re.search(r"tokens=(\d+)", line)
        c = re.search(r"cached=(\d+)", line)
        is_approx = re.search(r"approx=1\b", line) is not None
        if re.search(r"dup=1\b", line):
            dup_dispatches += 1
        if is_approx:
            approx_attribution += 1
            if t:
                approx_tokens += int(t.group(1))
        else:
            if t:
                tokens_total += int(t.group(1))
            if c:
                cached_total += int(c.group(1))

out = {
    "edits_total": total_edits,
    "edits_main": edits["main"],
    "edits_sub": edits["sub"],
    "edits_unknown_thread": edits["?"],
    "delegated_pct": delegated_pct,
    "dispatches": dispatches,
    "dispatch_types": dict(agents.most_common()),
    "unattributed_dispatches": unknown_agent,
    "approximate_attribution": approx_attribution,
    "approximate_attribution_tokens": approx_tokens,
    "dup_dispatches": dup_dispatches,
    "instrument_epoch": epoch_date,
    "pre_epoch_lines_excluded": pre_epoch_lines,
    "specialist_edits_by_agent": dict(by_specialist.most_common()),
    "subagent_tokens": tokens_total,
    "subagent_cache_reads": cached_total,
    "main_thread_edit_hotspots": dict(by_ext.most_common(5)),
    "main_thread_edit_hotspots_ignored_unresolved": by_ext_ignored_unresolved,
    "bash_writes": bash_writes,
    "bash_writes_unresolved_target": bash_writes_unresolved,
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
    if pre_epoch_lines:
        print(f"  no post-epoch dispatch data yet — {pre_epoch_lines} line(s) in")
        print(f"  {agent_log} predate the {epoch_date} instrument fix and are")
        print("  excluded (see harness-baseline.md). Run some work, then re-run this.")
    else:
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
    if by_ext_ignored_unresolved:
        line("  (ignored, unresolved target)", by_ext_ignored_unresolved)
if by_specialist:
    line("specialist edits by agent", ", ".join(f"{k} {v}" for k, v in by_specialist.most_common()))
if bash_writes:
    # Own line, on purpose: a write recovered from a Bash command is a
    # heuristic (see log-edit.sh's header), not a guaranteed target — a
    # number a reader cannot audit against the log has to announce itself.
    detail = f"{bash_writes} (of which {bash_writes_unresolved} have an unresolved target, logged as \"?\")" if bash_writes_unresolved else str(bash_writes)
    line("writes recovered from Bash", detail)

print()
print(" dispatch  (docs/dispatching.md)")
if pre_epoch_lines:
    line("pre-epoch lines excluded", f"{pre_epoch_lines}  (before {epoch_date} instrument fix — see harness-baseline.md)")
line("dispatches logged", dispatches)
if agents:
    line("by agent", ", ".join(f"{k} {v}" for k, v in agents.most_common(6)))
if unknown_agent:
    line("unattributed", f"{unknown_agent}  (log-agent.sh could not resolve the type)")
if tokens_total:
    line("subagent tokens (reliable)", f"{tokens_total:,}")
if cached_total:
    line("  of which cache reads", f"{cached_total:,}")
if approx_attribution:
    detail = f"{approx_attribution} dispatches, {approx_tokens:,} tokens — out of the total (fallback by mtime, unreliable in a parallel wave)"
    if dup_dispatches:
        detail += f"; {dup_dispatches} of those had no metric at all (dup=1, a same-transcript collision the hook caught)"
    line("approximate attribution", detail)

print()
print(" compare against .claude/docs/harness/harness-baseline.md")
print()
PY

exit 0
