#!/usr/bin/env bash
# check-index.sh
# Checks that CLAUDE.md and the .claude/ machinery still describe each other,
# and that the machinery itself is well-formed. Three classes of drift:
#
#   1. on disk, not in the index   — you added a skill/agent and forgot to list it
#   2. in the index, not on disk   — you renamed or deleted one and the index still advertises it
#   3. malformed on disk           — missing frontmatter, name/filename mismatch, non-executable hook
#
# (2) and (3) are the silent ones. A stale index entry sends an agent looking for
# something that is not there; a hook without +x never runs and never says so.
#
# Where it looks, in order of what exists:
#   baseline/     — the harness repo itself, where the machinery is authored
#   .claude/      — a consumer repo's own machinery
#   ~/.claude/    — personal scope (ADR 0002). Counted only as "exists", never
#                   reported as unlisted: a repo's CLAUDE.md is not supposed to
#                   index your personal harness. Without this, every consumer
#                   would report /orchestrate as missing.
#
# Informational by default — always exits 0, so it is safe on SessionStart.
# Pass --strict to exit 1 when anything is found (for CI).
#
#   .claude/scripts/check-index.sh
#   .claude/scripts/check-index.sh --strict

set -uo pipefail

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

CLAUDE="CLAUDE.md"
[[ -f "$CLAUDE" ]] || exit 0

# Roots that this repo owns, and are therefore expected to be indexed.
#
# A repo can hold the same machinery under two paths: the harness repo itself has
# baseline/skills AND .claude/skills symlinked to it, and any repo that linked the
# harness has .claude/skills pointing outside. Scanning both would report every
# finding twice. Resolve each candidate and keep it only if it is new.
OWNED=()
seen=""
add_root() {
  local root="$1" real
  [[ -d "$root/agents" || -d "$root/skills" || -d "$root/rules" ]] || return 0
  for sub in skills agents rules; do
    [[ -e "$root/$sub" ]] || continue
    real=$(cd -- "$root/$sub" 2>/dev/null && pwd -P) || continue
    case "$seen" in *"|$real|"*) return 0 ;; esac
    seen="${seen}|$real|"
  done
  OWNED+=("$root")
}
add_root "baseline"
add_root ".claude"
# Personal scope contributes names, never expectations.
EXTRA=()
[[ -d "$HOME/.claude/skills" || -d "$HOME/.claude/rules" || -d "$HOME/.claude/agents" ]] && EXTRA+=("$HOME/.claude")

unlisted=""   # 1. on disk, not in the index
stale=""      # 2. in the index, not on disk
broken=""     # 3. malformed
known=""      # every name the machinery actually provides

add()  { printf -v "$1" '%s\n  %s' "${!1}" "$2"; }
know() { known="${known}
$1"; }

# Frontmatter value of a key, from the top of a file.
fm() { sed -n '/^---$/,/^---$/p' "$1" 2>/dev/null | grep -m1 "^$2:" | sed "s/^$2:[[:space:]]*//"; }

# ---------------------------------------------------------------- agents
for root in ${OWNED[@]+"${OWNED[@]}"}; do
for f in "$root"/agents/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f" .md)
  name=$(fm "$f" name)
  desc=$(fm "$f" description)
  [[ -n "$name" ]] || { add broken "agent    $base — no 'name:' in frontmatter"; name="$base"; }
  [[ -n "$desc" ]] || add broken "agent    $base — no 'description:' (it is what makes the agent discoverable)"
  [[ "$name" == "$base" ]] || add broken "agent    $base — frontmatter name is '$name'; dispatch by name will not find the file"
  know "$name"
  grep -q "\`$name\`" "$CLAUDE" || add unlisted "agent    $name"
done; done

# ---------------------------------------------------------------- skills
for root in ${OWNED[@]+"${OWNED[@]}"}; do
for d in "$root"/skills/*/; do
  [[ -d "$d" ]] || continue
  dir=$(basename "$d")
  if [[ ! -f "${d}SKILL.md" ]]; then
    add broken "skill    $dir — no SKILL.md; the directory will be ignored"
    continue
  fi
  name=$(fm "${d}SKILL.md" name)
  desc=$(fm "${d}SKILL.md" description)
  [[ -n "$name" ]] || { add broken "skill    $dir — no 'name:' in frontmatter"; name="$dir"; }
  [[ -n "$desc" ]] || add broken "skill    $dir — no 'description:' (it is the auto-invocation trigger)"
  [[ "$name" == "$dir" ]] || add broken "skill    $dir — frontmatter name is '$name'"
  know "$name"
  grep -q "\`$name\`" "$CLAUDE" || add unlisted "skill    $name"
done; done

# ---------------------------------------------------------------- rules
# Rules are discovered RECURSIVELY by Claude Code, and the harness lands its own
# in a rules/harness/ subdirectory, so a flat glob reports every one of them as
# missing. Walk the tree instead.
for root in ${OWNED[@]+"${OWNED[@]}"}; do
while IFS= read -r f; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  [[ -n "$(fm "$f" paths)" ]] || add broken "rule     $base — no 'paths:' in frontmatter; it will never scope to anything"
  know "$base"; know "${base%.md}"
  grep -q "$base" "$CLAUDE" || add unlisted "rule     $base"
done < <(find -L "$root/rules" -name '*.md' -type f 2>/dev/null); done

# ---------------------------------------------------------------- commands
for root in ${OWNED[@]+"${OWNED[@]}"}; do
for f in "$root"/commands/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f" .md)
  [[ -n "$(fm "$f" description)" ]] || add broken "command  /$base — no 'description:'; it lists without help text"
  know "$base"
  grep -q "\`$base\`" "$CLAUDE" || add unlisted "command  /$base"
done; done

# ---------------------------------------------------------------- docs
for root in ${OWNED[@]+"${OWNED[@]}"}; do
for f in "$root"/docs/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  know "$base"; know "${base%.md}"
done; done

# ---------------------------------------------------------------- hooks
# A hook without the executable bit is registered, never runs, and reports nothing.
for root in ${OWNED[@]+"${OWNED[@]}"}; do
for f in "$root"/hooks/*.sh; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  [[ -x "$f" ]] || add broken "hook     $base — not executable (chmod +x); it will silently never run"
  know "$base"
done; done

# ------------------------------------------------- plugins (names only)
# Machinery a plugin provides lives in ~/.claude/plugins/marketplaces/, not in
# any .claude/ this scan can see. Without this, every repo that enables a stack
# plugin reports its agents and skills as "indexed but not on disk" — which is
# the check crying wolf about the exact setup it is meant to support.
PLUGIN_ROOT="$HOME/.claude/plugins/marketplaces"
if [[ -d "$PLUGIN_ROOT" ]]; then
  while IFS= read -r f; do
    [[ -e "$f" ]] || continue
    n=$(fm "$f" name); know "${n:-$(basename "$f" .md)}"
  done < <(find -L "$PLUGIN_ROOT" -path '*/agents/*.md' -type f 2>/dev/null)
  while IFS= read -r d; do
    [[ -f "$d/SKILL.md" ]] || continue
    n=$(fm "$d/SKILL.md" name); know "${n:-$(basename "$d")}"
  done < <(find -L "$PLUGIN_ROOT" -type d -path '*/skills/*' -depth 3 2>/dev/null; find -L "$PLUGIN_ROOT" -type d -path '*/skills/*' -maxdepth 5 2>/dev/null)
fi

# ------------------------------------------------- personal scope (names only)
for root in ${EXTRA[@]+"${EXTRA[@]}"}; do
  for f in "$root"/agents/*.md; do [[ -e "$f" ]] || continue; n=$(fm "$f" name); know "${n:-$(basename "$f" .md)}"; done
  for d in "$root"/skills/*/; do [[ -f "${d}SKILL.md" ]] || continue; n=$(fm "${d}SKILL.md" name); know "${n:-$(basename "$d")}"; done
  for f in "$root"/rules/*.md; do [[ -e "$f" ]] || continue; b=$(basename "$f"); know "$b"; know "${b%.md}"; done
  for f in "$root"/commands/*.md; do [[ -e "$f" ]] || continue; know "$(basename "$f" .md)"; done
done

# ---------------------------------------------------------------- reverse
# Index entries are written as a bullet whose first token is a backticked
# lowercase name: "- `write-spec` - persists a shaped idea as ...".
# Anything matching that shape should exist on disk.
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  grep -qxF "$name" <<< "$known" || add stale "$name"
done < <(grep -oE '^- `[a-z][a-z0-9-]*(\.md)?`' "$CLAUDE" | tr -d '`' | sed 's/^- //' | sort -u)

# ---------------------------------------------------------------- report
found=0
emit() {
  [[ -n "$2" ]] || return 0
  found=1
  { echo ""; echo "$1"; echo "$2"; } >&2
}

emit "⚠  On disk but not listed in CLAUDE.md:" "$unlisted"
emit "⚠  Listed in CLAUDE.md but not on disk (renamed or deleted?):" "$stale"
emit "⚠  Malformed — these do not work as intended:" "$broken"

if [[ $found -eq 1 ]]; then
  {
    echo ""
    echo "   Update CLAUDE.md (and .claude/README.md) so the index matches reality."
    echo ""
  } >&2
  [[ $STRICT -eq 1 ]] && exit 1
fi

exit 0
