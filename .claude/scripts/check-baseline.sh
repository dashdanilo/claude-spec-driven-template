#!/usr/bin/env bash
# check-baseline.sh
# Warns when the shared harness has moved since this repo last verified it.
#
# Context: when the baseline is delivered by symlink to a sibling repo, every
# consumer tracks that repo's working tree. That is the point — a fix is live
# everywhere with no update step — and it is also the risk: a bad edit is live
# everywhere with no staged rollout and nothing to hold it back.
#
# This does NOT pin. Pinning would mean freezing a version, which is exactly the
# property the symlink model trades away on purpose. It gives the missing half:
# you always run the current baseline, and you are TOLD when it moved past what
# this repo last looked at. Detection, not a freeze.
#
# Reads .claude/baseline.lock:
#   source = ../marketplace          # path to the shared repo, relative to this one
#   sha    = <40-char commit>        # what this repo last verified
#   date   = YYYY-MM-DD
#
# No lock file means this repo does not consume a shared baseline: exit silently.
# Informational only — always exits 0. Wire on SessionStart.
#
#   .claude/scripts/check-baseline.sh
#   .claude/scripts/check-baseline.sh --accept    # record the current SHA as verified

set -uo pipefail

LOCK=".claude/baseline.lock"
[[ -f "$LOCK" ]] || exit 0

val() { grep -m1 "^$1[[:space:]]*=" "$LOCK" 2>/dev/null | sed 's/^[^=]*=[[:space:]]*//' | tr -d '[:space:]'; }

SRC=$(val source)
PINNED=$(val sha)

[[ -n "$SRC" ]] || exit 0

if [[ ! -d "$SRC/.git" ]]; then
  {
    echo ""
    echo "⚠  baseline: '$SRC' is not a git repo (or is not cloned next to this one)."
    echo "   The symlinked harness will not resolve. Clone it as a sibling."
    echo ""
  } >&2
  exit 0
fi

CURRENT=$(git -C "$SRC" rev-parse HEAD 2>/dev/null)
[[ -n "$CURRENT" ]] || exit 0

if [[ "$CURRENT" == "$PINNED" ]]; then
  exit 0
fi

if [[ -z "$PINNED" ]]; then
  {
    echo ""
    echo "⚠  baseline: no sha recorded in $LOCK — nothing to compare against."
    echo "   Run: .claude/scripts/check-baseline.sh --accept"
    echo ""
  } >&2
  exit 0
fi

if [[ "${1:-}" == "--accept" ]]; then
  tmp=$(mktemp)
  sed "s|^sha[[:space:]]*=.*|sha    = $CURRENT|; s|^date[[:space:]]*=.*|date   = $(date -u +%Y-%m-%d)|" "$LOCK" > "$tmp" && mv "$tmp" "$LOCK"
  echo "baseline: recorded ${CURRENT:0:8} as verified." >&2
  exit 0
fi

# How far, and did it touch the parts this repo actually consumes?
AHEAD=$(git -C "$SRC" rev-list --count "$PINNED..$CURRENT" 2>/dev/null || echo "?")
TOUCHED=$(git -C "$SRC" diff --name-only "$PINNED..$CURRENT" -- baseline knowledge 2>/dev/null | head -8)

{
  echo ""
  echo "⚠  baseline moved since this repo last verified it."
  echo "   ${PINNED:0:8} → ${CURRENT:0:8}  ($AHEAD commit(s) in $SRC)"
  if [[ -n "$TOUCHED" ]]; then
    echo "   changed here:"
    printf '     %s\n' $TOUCHED
    extra=$(git -C "$SRC" diff --name-only "$PINNED..$CURRENT" -- baseline knowledge 2>/dev/null | wc -l | tr -d ' ')
    [[ "$extra" -gt 8 ]] && echo "     ... and $((extra - 8)) more"
  else
    echo "   nothing under baseline/ or knowledge/ changed — safe to accept."
  fi
  echo "   Review, then: .claude/scripts/check-baseline.sh --accept"
  echo ""
} >&2

exit 0
