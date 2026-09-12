#!/usr/bin/env bash
# block-new-em-dashes.sh
# PreToolUse hook for Edit, Write and MultiEdit. Blocks a call that would
# INCREASE the number of em-dashes (U+2014, "-") in a Markdown file, relative
# to that same file's current content on disk.
#
# This repo has 516 em-dashes across 49 Markdown files (excluding
# CHANGELOG.md), most of them in baseline/skills/, written before this rule
# had any enforcement behind it. That is debt, and this hook does not touch
# it: rewriting an em-dash sentence needs a human's judgment about phrasing,
# not a script's guess, and most of those files are injected into every
# adopting project. What this hook governs is the diff, not the tree: editing
# a line that already had an em-dash, moving text around, or deleting an
# em-dash all pass; a call that leaves the file with MORE em-dashes than it
# had before that same call runs is blocked. Same lesson as this template's
# own specs/*/lessons.md elsewhere: do not reformat what you did not write.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Edit|Write|MultiEdit|NotebookEdit" (the existing group). NotebookEdit
# payloads are ignored below (tool_name check), since this rule is about
# prose, not notebook cells.
#
# Scope: Markdown files only (path ends in ".md", case-insensitive). A .sh
# file, or any other extension, is out of scope and always passes here: this
# hook does not comment on code, only on the copy convention in AGENTS.md.
#
# Character: only U+2014 (em-dash, "-"). U+2013 (en-dash, "-") is
# deliberately NOT covered. AGENTS.md's rule has only ever named "em-dashes",
# and an en-dash's common legitimate uses in this repo's prose (a numeric
# range like "2020-2021", or a minus sign) are a different typographic
# question than the one this rule answers. Widening scope to en-dash was not
# asked for and is not done here; if AGENTS.md's convention line is ever
# widened to say "dashes" instead of "em-dashes", this hook's EM_DASH check
# should grow to match it, not the other way around.
#
# Not blocked, and deliberately so: replacing an em-dash with a literal
# double hyphen ("--"). That is the obvious way to defeat this rule while
# looking like it was followed, and it is called out in the block message
# instead of being caught by pattern-matching for "--", because "--" also
# appears legitimately in CLI flags quoted inside Markdown (e.g. `--strict`).
# Blocking "--" outright would break every doc that shows a command-line flag.
#
# Registration note: this hook is a style preference OF THIS REPO, not a
# portable convention. It is registered only in THIS repo's own
# .claude/settings.json, and deliberately left out of install-harness.sh's
# WANT list and install.sh's REPO_HOOKS list: an adopting project does not
# inherit this template's typographic taste just by linking the harness.
#
# old_string not found in the file (an Edit that is about to fail on its own
# terms): this hook does not try to guess what the failed call would have
# produced. It exits 0 and lets Edit itself raise the "not found" error.
#
# Same fallback and fail-open posture as the other guard hooks: try python3,
# then python; if neither is on PATH, warn on stderr and let the call
# through rather than blocking every Edit/Write/MultiEdit call on a machine
# that cannot run this guard at all.

set -uo pipefail

input=$(cat)

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: block-new-em-dashes.sh: no python3 or python on PATH -- cannot read the tool payload, so this guard is DISABLED for this call." >&2
  exit 0
fi

printf '%s' "$input" | "$PYTHON_BIN" -c '
import sys, json

EM_DASH = "—"


def count(s):
    return s.count(EM_DASH)


def read_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None


try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = d.get("tool_name") or ""
ti = d.get("tool_input") or {}

if tool not in ("Edit", "Write", "MultiEdit"):
    sys.exit(0)

path = ti.get("file_path") or ""
if not path or not path.lower().endswith(".md"):
    sys.exit(0)

before = None
after = None

if tool == "Write":
    existing = read_file(path)
    before = existing if existing is not None else ""
    after = ti.get("content")
    if after is None:
        sys.exit(0)

elif tool == "Edit":
    existing = read_file(path)
    if existing is None:
        # File does not exist (or is unreadable): Edit against it is going
        # to fail on its own terms. Nothing for this guard to compare.
        sys.exit(0)
    old = ti.get("old_string")
    new = ti.get("new_string")
    if old is None or new is None:
        sys.exit(0)
    if old not in existing:
        # old_string not found: the Edit call fails on its own. Do not
        # guess at what would have happened; let it fail.
        sys.exit(0)
    replace_all = bool(ti.get("replace_all", False))
    before = existing
    after = existing.replace(old, new) if replace_all else existing.replace(old, new, 1)

elif tool == "MultiEdit":
    existing = read_file(path)
    if existing is None:
        sys.exit(0)
    edits = ti.get("edits") or []
    if not edits:
        sys.exit(0)
    before = existing
    running = existing
    for e in edits:
        old = e.get("old_string")
        new = e.get("new_string")
        if old is None or new is None:
            sys.exit(0)
        if old not in running:
            # Same rule as a plain Edit: a MultiEdit whose Nth edit does
            # not find its old_string fails the whole call on its own.
            sys.exit(0)
        replace_all = bool(e.get("replace_all", False))
        running = running.replace(old, new) if replace_all else running.replace(old, new, 1)
    after = running

before_count = count(before)
after_count = count(after)

if after_count > before_count:
    added = after_count - before_count
    plural = "es" if added != 1 else ""
    sys.stderr.write(
        "BLOCKED by block-new-em-dashes.sh: {} new em-dash{} in {!r} ({} -> {}).\n".format(
            added, plural, path, before_count, after_count
        )
    )
    sys.stderr.write("\n")
    sys.stderr.write("AGENTS.md bans new em-dashes in copy. Fix it by REWRITING the\n")
    sys.stderr.write("sentence (a comma, a colon, parentheses, or a period), not by\n")
    sys.stderr.write("swapping the character for a double hyphen (--) -- that only\n")
    sys.stderr.write("defeats the rule while looking like it was followed.\n")
    sys.stderr.write("\n")
    sys.stderr.write("Em-dashes already in this file, outside this edit, are pre-existing\n")
    sys.stderr.write("debt and are not blocked. Only a net increase from this call is.\n")
    sys.exit(2)

sys.exit(0)
'
exit $?
