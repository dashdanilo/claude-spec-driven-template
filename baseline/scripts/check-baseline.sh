#!/usr/bin/env bash
# check-baseline.sh
# Warns when YOUR harness checkout is stale, or has uncommitted edits.
#
# Under ADR 0002 the baseline lives in one git checkout and is symlinked into
# ~/.claude/, so every project on this machine runs whatever that checkout has
# right now. Two things follow, and this reports both:
#
#   1. The checkout can fall behind its remote. `git pull` is the whole update
#      mechanism, which is only an advantage if you remember to run it.
#   2. Uncommitted edits in the checkout are LIVE in every project immediately —
#      before review, before CI, before anyone else sees them. That is the cost
#      ADR 0002 accepts; this makes it visible instead of silent.
#
# It does NOT pin, and it does not fetch. Pinning would freeze a version, which
# is the property the symlink model gives up on purpose. Fetching on every
# session start would put the network on your critical path, so this compares
# against the remote ref you already have — meaning "up to date" means "up to
# date as of your last fetch", and it says so rather than implying more.
#
# Silent when it cannot find a harness checkout, so a repo that does not use one
# is unaffected. Informational — always exits 0. Wire on SessionStart.
#
#   baseline/scripts/check-baseline.sh
#   baseline/scripts/check-baseline.sh --verbose   # also report when healthy

set -uo pipefail

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

# Where is the harness? Either we are inside it, or ~/.claude/skills points at it.
resolve_checkout() {
  local here
  here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)
  if [[ -n "$here" && -d "$here/baseline" && -e "$here/.git" ]]; then
    printf '%s' "$here"; return 0
  fi
  local link="$HOME/.claude/skills"
  if [[ -L "$link" ]]; then
    local target
    target=$(cd -- "$(readlink "$link")/../.." 2>/dev/null && pwd)
    [[ -n "$target" && -e "$target/.git" ]] && { printf '%s' "$target"; return 0; }
  fi
  return 1
}

CO=$(resolve_checkout) || exit 0
git -C "$CO" rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRANCH=$(git -C "$CO" rev-parse --abbrev-ref HEAD 2>/dev/null)
UPSTREAM=$(git -C "$CO" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)

behind=0
if [[ -n "$UPSTREAM" ]]; then
  behind=$(git -C "$CO" rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
fi

dirty=$(git -C "$CO" status --porcelain -- baseline 2>/dev/null | wc -l | tr -d ' ')

if [[ "$behind" -eq 0 && "$dirty" -eq 0 ]]; then
  [[ $VERBOSE -eq 1 ]] && echo "harness: up to date as of your last fetch (${BRANCH}, $CO)" >&2
  exit 0
fi

{
  echo ""
  echo "⚠  harness checkout: $CO"

  if [[ "$behind" -gt 0 ]]; then
    echo "   $behind commit(s) behind $UPSTREAM — as of your last fetch."
    files=$(git -C "$CO" diff --name-only "HEAD..$UPSTREAM" -- baseline 2>/dev/null | head -6)
    if [[ -n "$files" ]]; then
      echo "   incoming under baseline/:"
      printf '     %s\n' $files
    fi
    echo "   git -C $CO pull"
  fi

  if [[ "$dirty" -gt 0 ]]; then
    echo "   $dirty uncommitted file(s) under baseline/ — LIVE in every project on"
    echo "   this machine right now, unreviewed."
    git -C "$CO" status --porcelain -- baseline 2>/dev/null | head -6 | sed 's/^/     /'
  fi
  echo ""
} >&2

exit 0
