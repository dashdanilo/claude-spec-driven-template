#!/usr/bin/env bash
# check-index.sh
# Warns when CLAUDE.md has drifted from the actual .claude/ machinery — i.e. an
# agent, skill, rule, or command exists on disk but is not mentioned in CLAUDE.md.
# This is the common failure: you add a skill/agent and forget to list it.
#
# Informational only — always exits 0. Wire on SessionStart (warn), and/or run
# it manually: `.claude/scripts/check-index.sh`.

set -uo pipefail
CLAUDE="CLAUDE.md"
[[ -f "$CLAUDE" ]] || exit 0

missing=""
note() { missing="${missing}
  $1"; }

# Agents — frontmatter `name:` (fallback: filename)
for f in .claude/agents/*.md; do
  [[ -e "$f" ]] || continue
  name=$(grep -m1 '^name:' "$f" 2>/dev/null | sed 's/^name:[[:space:]]*//')
  [[ -n "$name" ]] || name=$(basename "$f" .md)
  grep -q "\`$name\`" "$CLAUDE" || note "agent    $name"
done

# Skills — frontmatter `name:` in SKILL.md (fallback: dir name)
for d in .claude/skills/*/; do
  [[ -f "${d}SKILL.md" ]] || continue
  name=$(grep -m1 '^name:' "${d}SKILL.md" 2>/dev/null | sed 's/^name:[[:space:]]*//')
  [[ -n "$name" ]] || name=$(basename "$d")
  grep -q "\`$name\`" "$CLAUDE" || note "skill    $name"
done

# Rules — filename
for f in .claude/rules/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  grep -q "$base" "$CLAUDE" || note "rule     $base"
done

# Commands — filename (as /name)
for f in .claude/commands/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f" .md)
  grep -q "$base" "$CLAUDE" || note "command  /$base"
done

if [[ -n "$missing" ]]; then
  {
    echo ""
    echo "⚠  CLAUDE.md index looks stale — on disk but not listed in CLAUDE.md:"
    echo "$missing"
    echo "   Update CLAUDE.md (and .claude/README.md) so the index matches reality."
    echo ""
  } >&2
fi

exit 0
