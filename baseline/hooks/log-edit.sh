#!/usr/bin/env bash
# log-edit.sh
# Observability hook. Appends one line to .claude/tool-log.txt every time a
# file is written, recording WHICH THREAD did it — whether the write came
# through Edit/Write/MultiEdit/NotebookEdit, or through Bash.
#
# Wire on PreToolUse for Edit|Write|MultiEdit|NotebookEdit AND for Bash. Never
# blocks (always exit 0, no decision output). The log is gitignored.
#
# Why this exists: `.claude/rules/harness/delegation.md` says the main thread
# coordinates and specialists implement. On a real project that rule was
# already written and 71% of Edit calls still happened in the main thread. A
# rule you cannot see being broken is a rule that decays. This makes it
# countable, and `/harness-report` makes it visible.
#
# Why Bash too, added after the fact: this hook originally only watched
# Edit/Write/MultiEdit/NotebookEdit, so a write done through Bash — a
# redirect, `sed -i`, `tee`, `cp`, `mv` — was invisible to it. Measured
# consequence, recorded in baseline/docs/harness-baseline.md's 2026-09-10 A/B:
# a run whose orchestrator edited its own tracked documents through Bash
# reported 100% delegation, an artifact of the blind spot, not a real number.
# The metric erred OPTIMISTIC — the worse direction for something whose whole
# job is to say whether the harness is being used as designed.
#
# Thread detection (unchanged from before this file grew a Bash branch): read
# the payload directly rather than inferring from `transcript_path`. A
# subagent's `PreToolUse` payload carries `agent_id` (and usually
# `agent_type`) — that alone means "sub", regardless of what `transcript_path`
# points at. Measured: a captured payload from inside an `implementer`
# subagent had `transcript_path` pointing at the *main* session's transcript
# (no `subagents` segment anywhere in it) while `agent_id` and `agent_type`
# were both present. The old heuristic — "sub" only when `transcript_path`
# contains a `subagents` segment, "main" otherwise — read that as `main`, so
# every specialist edit was silently counted as main-thread work, one
# direction only. `?` is reserved for the one case with neither signal: no
# `agent_id` and no `transcript_path` at all.
#
# --- Bash write detection -----------------------------------------------
#
# The actual lexer — tokenizing the command, splitting it into segments,
# recognizing `>`/`>>` redirects and `sed -i`/`tee`/`cp`/`mv`/`python -c`/a
# python heredoc as write commands, and resolving each target to a literal
# path or the sentinel `?` when it cannot — lives in ONE place now:
# lib/bash-write-targets.py, next to this hook. protect-harness.sh and
# protect-critical.sh import the exact same module for the same reason this
# hook needed it first: a write performed through Bash (a redirect,
# `sed -i`, `tee`, `cp`, `mv`, or a `python3 -c`/heredoc `open(..., "w")`
# call) used to be invisible to every hook that only looked at Edit/Write
# payloads. See that file's header for the lexer's exact rules and its
# declared gaps.
#
# This hook's OWN rule on top of the shared parser: only a target that
# RESOLVES INSIDE THE REPO (this call's own cwd) is logged. This is the one
# filter that keeps the noise out: it silently drops `/dev/null`, `2>&1` (no
# file target at all), anything under `/tmp`, the session scratchpad, or any
# other path outside the project — and it does so with a single check
# instead of an ever-growing exclude list, because it matches what the
# metric actually measures: editing the project. protect-harness.sh and
# protect-critical.sh do NOT apply this filter — a write reaching outside the
# session's own cwd into another checkout entirely is exactly the shape of
# attack those two exist to catch.
#
# A target the shared parser cannot resolve to a literal path is NOT
# dropped: it is logged with `path` equal to the literal string `?`. This
# matters more than it looks: the delegation metric needs THREAD + COUNT,
# not the path. The thread comes from the payload (known regardless of the
# target), so a write to an unresolvable target still corrects the count; it
# only drops out of `harness-report.sh`'s by-extension breakdown, which is
# explicitly called out as ignoring `?` rows rather than silently
# under-counting them.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Bash" (in addition to the existing "Edit|Write|MultiEdit|NotebookEdit").

set -uo pipefail

input=$(cat)

# python3, falling back to `python` (some Windows shells only have `python` on
# PATH). Never blocks either way: if neither is present, this observability
# hook just has nothing to log this time.
PYTHON_BIN=python3
command -v python3 >/dev/null 2>&1 || PYTHON_BIN=python
command -v "$PYTHON_BIN" >/dev/null 2>&1 || exit 0

# The shared Bash-write-target parser, next to this hook — see the "Bash
# write detection" note above.
LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib/bash-write-targets.py"

printf '%s' "$input" | "$PYTHON_BIN" -c '
import sys, json, datetime, os

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = d.get("tool_name") or "?"
ti = d.get("tool_input") or {}

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

cwd = os.getcwd()
ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

out_lines = []

def emit(kind, path):
    out_lines.append("\t".join([ts, thread, kind, path, agent_type]))

# ---------------------------------------------------------- Edit/Write family
if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
    path = ti.get("file_path") or ti.get("notebook_path") or ""
    # Repo-relative when possible: absolute paths make the log unreadable and
    # leak the checkout location into a file people paste into issues.
    # Unchanged from before this hook learned about Bash: an Edit/Write path
    # outside the repo is still logged as-is, never dropped — the
    # inside-the-repo filter below applies ONLY to Bash-detected writes.
    if path.startswith(cwd + os.sep):
        path = path[len(cwd) + 1:]
    emit(tool, path)

# ------------------------------------------------------------------- Bash
elif tool == "Bash":
    command = ti.get("command") or ""

    # The payload own "cwd" when present, this process own cwd only as a
    # fallback — see the top-of-file note on why the shared parser resolves
    # relative targets this way. Kept separate from the Edit/Write branch
    # `cwd` (still this process own, unchanged): everything below filters
    # against the SAME base the shared parser resolved against.
    base_cwd = d.get("cwd") or cwd

    def to_repo_relative(raw):
        # None => outside the repo, caller must not log this target at all.
        if not raw:
            return None
        if raw == base_cwd:
            return "."
        if raw.startswith(base_cwd + os.sep):
            return raw[len(base_cwd) + 1:]
        return None

    try:
        if command:
            import importlib.util
            _spec = importlib.util.spec_from_file_location("bash_write_targets", sys.argv[1])
            _bwt = importlib.util.module_from_spec(_spec)
            _spec.loader.exec_module(_bwt)

            for kind_label, unresolvable, target in _bwt.extract_targets(command, base_cwd):
                if unresolvable:
                    emit(kind_label, "?")
                    continue
                rel = to_repo_relative(target)
                if rel is not None:
                    emit(kind_label, rel)
                # else: resolves outside the repo — not logged, by design.
    except Exception:
        # Never let a parsing bug turn an observability hook into a blocker,
        # and never emit a half-built line. Nothing gets logged this call.
        out_lines = []

for line in out_lines:
    print(line)
' "$LIB" >> .claude/tool-log.txt 2>/dev/null

exit 0
