#!/usr/bin/env bash
# check-handover.sh
# SessionStart hook. Points a fresh session at state a PRIOR session already
# wrote to disk, so "continue" or "what's pending" does not re-derive
# everything from scratch.
#
# The knowledge "read the newest file in .claude/handovers/ before resuming"
# already exists - but only inside the `handover` and `status` skills, which
# means it only reaches a session that thinks to invoke one of them. A
# session that starts with `/clear` and the user typing "continue" never
# loads either skill, and silently ignores whatever the previous session
# wrote down. This hook closes that gap by surfacing the same pointer as
# part of SessionStart itself, before the first prompt.
#
# It emits ONLY a pointer - path, date, size, title - never the handover's
# content. Pasting a handover whole would cost roughly 2k tokens on every
# single session, most of which are not resuming anything that file
# describes; a ten-line pointer plus an instruction to read the file costs
# a few dozen tokens and lets the model decide whether reading it is worth
# it. See the `handover` skill's "Where to put it" and "Retention" sections
# for the convention this hook reads - it does not redefine that contract,
# it repeats only the part that changes what the next session does.
#
# Output channel: this hook prints the Claude Code `hookSpecificOutput` JSON
# form (`{"hookSpecificOutput":{"hookEventName":"SessionStart",
# "additionalContext":"..."}}`) rather than plain stdout text. Both are
# delivered to the model's context on SessionStart, per Claude Code's own
# hooks reference - plain stdout is treated as text and injected the same
# way `additionalContext` is. The JSON form is chosen because it is
# self-documenting about which hook produced it and survives silently if a
# future Claude Code version changes how plain stdout is handled on this
# event; either channel is a one-line change if that assumption ever needs
# revisiting.
#
# Deliberately silent (empty stdout, exit 0):
#   - no .claude/handovers/ directory, and no spec's tasks.md has a
#     "## Handover" section - most repos, most of the time
#   - source is "compact" - a compaction's own summary already carries the
#     session's state; a pointer on top of it is noise, not signal
#   - anything unreadable or malformed (missing stdin, non-JSON payload, a
#     handover file with unexpected permissions) - reporting nothing is
#     always safer than a hook that errors on SessionStart
#
# Deliberately NOT silent on source="resume": a session resumed days later
# benefits from the same reminder a fresh startup gets, and the pointer
# costs only a few dozen tokens against the real risk of losing track of
# state. If this looks like an oversight later, it is not - only "compact"
# is silenced, on purpose.
#
# Comparing recency across sources: a loose .claude/handovers/<date>-
# <slug>.md file's date comes straight from its filename, which is accurate
# because a new handover is always a NEW file (see the `handover` skill's
# "Retention" section). A spec's <slug>/tasks.md is different: it can be
# edited many times after its directory was created, so the folder's own
# YYYY-MM-DD is only when the spec STARTED, never when its "## Handover"
# section was last written - comparing against it would reintroduce, on the
# spec side, the exact staleness bug this hook exists to avoid on the
# handovers-directory side. The section is expected to carry its own
# `Updated: YYYY-MM-DD` line (see the `handover` skill); when a `tasks.md`
# predates that convention and has no such line, this hook falls back to
# the file's mtime instead - an APPROXIMATION, because ticking an unrelated
# checkbox in the same file also bumps its mtime and would make a stale
# handover section look freshly written. The folder's own date is still
# shown as part of the path; it is just never used to decide which source
# wins.
#
# Never blocks. Always exits 0.
#
# Registered in .claude/settings.json under hooks.SessionStart.

set -uo pipefail

HANDOVER_DIR=".claude/handovers"

# --------------------------------------------------------------- read stdin
# The SessionStart payload is JSON on stdin with a "source" field:
# "startup" | "resume" | "clear" | "compact" | "fork". No jq dependency -
# this repo's other hooks parse JSON with grep/sed, and this hook needs
# exactly one scalar field.
PAYLOAD="$(cat 2>/dev/null || true)"
SOURCE=""
if [[ -n "$PAYLOAD" ]]; then
  SOURCE=$(printf '%s' "$PAYLOAD" | grep -oE '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
fi

# compact: the summary already carries state; stay silent.
[[ "$SOURCE" == "compact" ]] && exit 0

# ------------------------------------------------------- portable file stat
# GNU form (`stat -c %Y`) tried FIRST, BSD/macOS form (`stat -f %m`) as the
# fallback - the reverse of the obvious "try BSD, then GNU" ordering, and
# for a specific reason: on GNU coreutils, `-f` does not mean "use this
# format", it means "report on the FILESYSTEM the file lives on instead of
# the file itself", so `stat -f %m` on Linux silently succeeds and prints
# the MOUNT POINT (e.g. "/"), not a timestamp - it never falls through to
# the correct GNU form at all, because the first command in the `||` chain
# already "worked". BSD stat has no such trap: `-c` is not a flag it
# recognizes, so it fails loudly (exit 1, no stdout) and the fallback runs
# as intended. Trying the form that fails CLEANLY on the other platform
# first is what makes a `||` chain like this safe without an `uname`
# branch. The result is validated as digits-only before use - defense
# against a third stat dialect answering something unexpected - so a
# downstream `(( ))` arithmetic comparison can never choke on it and take
# the whole hook down with a nonzero exit (the CI failure this fixes:
# ubuntu-latest's `stat -f %m` silently returning "/" fed straight into an
# arithmetic comparison).
mtime_of() {
  local v
  v="$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null)"
  [[ "$v" =~ ^[0-9]+$ ]] && printf '%s' "$v" || printf '0'
}
size_of()  { wc -c < "$1" 2>/dev/null | tr -d ' '; }
# Epoch seconds -> YYYY-MM-DD. Same reasoning and ordering as mtime_of
# above: GNU date's `-d @EPOCH` is tried first because BSD/macOS date fails
# it cleanly (no `-d` flag at all), while the reverse order risks a BSD
# form that some GNU date build tolerates in an unintended way. `-r EPOCH`
# is the BSD/macOS fallback.
date_from_epoch() {
  date -d "@$1" +%Y-%m-%d 2>/dev/null || date -r "$1" +%Y-%m-%d 2>/dev/null || echo "1970-01-01"
}

# The first non-empty line after a "## Handover" heading, if any. "Empty"
# means empty even in a CRLF file: a blank line there is not the empty
# string, it is a lone \r (awk/grep split records on \n only), and awk's
# default NF-based emptiness check does NOT treat \r as whitespace, so a
# CRLF blank line reads as one non-empty field and gets returned as if it
# were content - which, sitting right after the heading, would either bury
# a real Updated: line one record later or hand an empty "\r" back as the
# title. Matching explicitly against "only spaces, tabs or a lone \r"
# avoids both.
handover_first_line() {
  awk '/^## Handover/{f=1;next} f && $0 !~ /^[ \t\r]*$/ {print; exit}' "$1" 2>/dev/null
}
# That line's date, only when it is the `Updated: YYYY-MM-DD` line the
# `handover` skill now asks for - empty otherwise, which the caller treats
# as "fall back to mtime" (see the header note on why mtime is only an
# approximation). Trailing whitespace and a trailing CR (a tasks.md saved
# with CRLF line endings) are tolerated on both sides of the date: awk and
# grep split records on \n only, so a CRLF file leaves \r attached to the
# captured line, and an anchor that only allowed the date to sit immediately
# before end-of-line would silently miss it - falling back to mtime with no
# sign anything was wrong, the same failure mode F2 fixed for the title.
handover_updated_date() {
  local line
  line="$(handover_first_line "$1")"
  if [[ "$line" =~ ^Updated:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]*$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}
# The title line: the first non-empty line after "## Handover" that is NOT
# the Updated: line, so the date line is never shown as if it were prose.
# Same CRLF-blank-line and trailing-whitespace/CR tolerance as
# handover_first_line and handover_updated_date above.
handover_title() {
  awk '/^## Handover/{f=1;next} f && $0 !~ /^[ \t\r]*$/ && $0 !~ /^Updated:[ \t]*[0-9]{4}-[0-9]{2}-[0-9]{2}[ \t\r]*$/ {print; exit}' "$1" 2>/dev/null
}

# ---------------------------------------------------- JSON string escaping
# Backslash, double-quote, embedded newlines, tabs and carriage returns all
# need handling here. Most of what we emit is ours (paths, dates, byte
# counts), but the title line is not: it comes straight from a handover's
# own content, which this hook does not control. A tab or a CRLF line
# ending in that title, left raw, breaks the JSON Claude Code tries to
# parse ("Invalid control character"), and the whole hook's context is then
# silently discarded exactly when it mattered most. The newline join is
# done with awk, not sed's classic N;ba loop: BSD sed (macOS) reads
# everything after a `:label` up to end of line as the label name, so a
# semicolon-joined `:a;N;$!ba;...` script fails there with "unused label"
# while working fine on GNU sed - awk's NR-based join has no such split.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s" | awk '{printf "%s%s", (NR > 1 ? "\\n" : ""), $0}'
}

emit_context() {
  local ctx escaped
  ctx="$1"
  escaped="$(json_escape "$ctx")"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$escaped"
}

# ------------------------------------------------- 1. newest .claude/handovers/*.md
# Filenames follow YYYY-MM-DD-<slug>.md by convention (the `handover` skill's
# "Where to put it" section). Newest by that date, ties broken by mtime -
# same rule the skill documents in its "Retention" section; do not diverge.
newest_file=""
newest_date=""
newest_mtime=0
handover_count=0

if [[ -d "$HANDOVER_DIR" ]]; then
  for f in "$HANDOVER_DIR"/*.md; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-.+\.md$ ]] || continue
    handover_count=$((handover_count + 1))
    d_date="${BASH_REMATCH[1]}"
    mtime="$(mtime_of "$f")"
    if [[ -z "$newest_file" ]] || [[ "$d_date" > "$newest_date" ]] || { [[ "$d_date" == "$newest_date" ]] && (( mtime > newest_mtime )); }; then
      newest_file="$f"
      newest_date="$d_date"
      newest_mtime="$mtime"
    fi
  done
fi

# --------------------------------------- 2. newest specs/<slug>/tasks.md with a handover
# The other place a handover can live: a "## Handover" section appended to
# an active spec's tasks.md (see the `handover` skill's "Where to put it" -
# a spec active means the handover goes there, not to .claude/handovers/).
# Spec directories are named YYYY-MM-DD-<slug>/ by the write-spec skill's
# own convention, but that folder date is when the spec was CREATED, not
# when this section was last written - see the header note on why it is
# never the comparison key. spec_date below is comparable recency (the
# section's own `Updated:` line, or mtime as a fallback); the folder's date
# is not tracked separately because the path itself already shows it.
spec_file=""
spec_date=""
spec_mtime=0

if [[ -d "specs" ]]; then
  for d in specs/*/; do
    [[ -d "$d" ]] || continue
    tf="${d}tasks.md"
    [[ -f "$tf" ]] || continue
    grep -q '^## Handover' "$tf" 2>/dev/null || continue
    d_base="$(basename "$d")"
    [[ "$d_base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}- ]] || continue
    mtime="$(mtime_of "$tf")"
    d_date="$(handover_updated_date "$tf")"
    [[ -n "$d_date" ]] || d_date="$(date_from_epoch "$mtime")"
    if [[ -z "$spec_file" ]] || [[ "$d_date" > "$spec_date" ]] || { [[ "$d_date" == "$spec_date" ]] && (( mtime > spec_mtime )); }; then
      spec_file="$tf"
      spec_date="$d_date"
      spec_mtime="$mtime"
    fi
  done
fi

# Nothing anywhere - silent.
if [[ -z "$newest_file" && -z "$spec_file" ]]; then
  exit 0
fi

# ----------------------------------------- 3. pick the newer of the two sources
# Both sources are evaluated every run, never cascaded: a loose file in
# .claude/handovers/ can be months older than an active spec's own
# "## Handover" section, and a fixed "directory always wins" rule would send
# a fresh session to read stale residue from a PAST stretch of work while
# staying silent about the spec that actually describes today's state -
# exactly backwards from this hook's purpose. Compare by date; a same-day
# tie goes to the spec, because that is where the `handover` skill's
# "Where to put it" section says a handover belongs whenever a spec is
# active - a loose file dated the same day is then the residue, not the
# current state.
use_spec=0
if [[ -n "$spec_file" && -z "$newest_file" ]]; then
  use_spec=1
elif [[ -n "$spec_file" && -n "$newest_file" ]] && { [[ "$spec_date" > "$newest_date" ]] || [[ "$spec_date" == "$newest_date" ]]; }; then
  use_spec=1
fi

if (( use_spec )); then
  size_bytes="$(size_of "$spec_file")"
  title="$(handover_title "$spec_file")"
  [[ -n "$title" ]] || title="(spec: $(basename "$(dirname "$spec_file")"))"

  ctx="A previous session left a handover in the active spec. Read the
'## Handover' section before answering any question about project state,
or before resuming work - do not re-derive state from the codebase first.

File:  $spec_file (section: ## Handover)
Date:  $spec_date
Size:  ${size_bytes:-?} bytes
Title: $title"

  # The losing source gets one line naming its path only - no Date/Size/
  # Title repeated for it, so the model knows it exists without being
  # handed two full pointer blocks to weigh against each other.
  if [[ -n "$newest_file" ]]; then
    ctx="$ctx

Also present, not chosen: $newest_file"
  fi

  emit_context "$ctx"
  exit 0
fi

size_bytes="$(size_of "$newest_file")"
title="$(grep -m1 '^# ' "$newest_file" 2>/dev/null | sed 's/^# //')"
[[ -n "$title" ]] || title="$(grep -m1 -v '^[[:space:]]*$' "$newest_file" 2>/dev/null)"

ctx="A previous session left a handover on disk. Read it before answering
any question about project state, or before resuming work - do not
re-derive state from the codebase first.

File:  $newest_file
Date:  $newest_date
Size:  ${size_bytes:-?} bytes
Title: ${title:-(no title line)}"

if (( handover_count > 1 )); then
  ctx="$ctx

$((handover_count - 1)) older handover(s) also live in $HANDOVER_DIR/ - history, not current state."
fi

if [[ -n "$spec_file" ]]; then
  ctx="$ctx

Also present, not chosen: $spec_file (section: ## Handover)"
fi

emit_context "$ctx"
exit 0
