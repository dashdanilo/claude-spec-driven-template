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
# It also reports a BROKEN LINK, which is the failure this model fails at worst:
# move the harness checkout and every link in every project that opted in points
# at nothing. Claude Code does not error on that — the skills, agents and rules
# simply are not there, and a session looks normal while being unarmed. Detecting
# it costs one stat call; not detecting it costs a day of wondering.
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

# --------------------------------------------------------- broken links first
# Checked before anything else: if the links are dead, everything below is moot.
broken=""
for n in skills agents rules/harness; do
  l=".claude/$n"
  [[ -L "$l" ]] || continue
  [[ -e "$l" ]] && continue          # resolves — fine
  broken="${broken}
     .claude/$n -> $(readlink "$l")"
done

if [[ -n "$broken" ]]; then
  {
    echo ""
    echo "⚠  the linked harness is not there. These point at nothing:"
    echo "$broken"
    echo ""
    echo "   Claude Code does not error on this — the skills, agents and rules are"
    echo "   simply absent, so a session looks normal while being unarmed."
    echo "   The checkout was probably moved or deleted. Re-link with:"
    echo "     <harness>/install-harness.sh"
    echo ""
  } >&2
fi

# ------------------------------------------------------- stale fallback copies
# On a platform that would not symlink, install-harness.sh copies instead and
# marks the copy. A copy does NOT follow the checkout, so `git pull` updates
# nothing for that person — and nothing else would tell them, which is the whole
# problem with a fallback nobody checks on.
stale_copies=""
for n in skills agents rules/harness; do
  d=".claude/$n"
  [[ -f "$d/.harness-copy" ]] || continue
  src=$(cat "$d/.harness-copy" 2>/dev/null)
  [[ -n "$src" && -d "$src" ]] || continue
  if ! diff -rq --exclude=.harness-copy "$src" "$d" >/dev/null 2>&1; then
    stale_copies="${stale_copies}
     .claude/$n"
  fi
done

if [[ -n "$stale_copies" ]]; then
  {
    echo ""
    echo "⚠  these are COPIES of the harness, and they no longer match it:"
    echo "$stale_copies"
    echo ""
    echo "   A copy does not follow the checkout — git pull did not update them."
    echo "   Re-run the installer to refresh:"
    echo "     <harness>/install-harness.sh"
    echo ""
  } >&2
fi

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
    echo "   $dirty uncommitted file(s) under baseline/ — live in every project that"
    echo "   LINKED the harness, right now, unreviewed. Projects that fell back to"
    echo "   copying are unaffected until the installer is re-run there."
    git -C "$CO" status --porcelain -- baseline 2>/dev/null | head -6 | sed 's/^/     /'
  fi
  echo ""
} >&2

exit 0
