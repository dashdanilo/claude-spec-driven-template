#!/usr/bin/env bash
# check-index.sh
# Checks that CLAUDE.md and the .claude/ machinery still describe each other,
# and that the machinery itself is well-formed. Four classes of drift:
#
#   1. on disk, not in the index   — you added a skill/agent and forgot to list it
#   2. in the index, not on disk   — you renamed or deleted one and the index still advertises it
#   3. malformed on disk           — missing frontmatter, name/filename mismatch, non-executable hook
#   4. dangling pointer            — a `.claude/docs/...`, `.claude/scripts/...`,
#      `.claude/rules/...`, `.claude/skills/...` or `.claude/agents/...` mention
#      in a rule, skill, agent or script that does not resolve from the repo root
#      (a `.claude/agents/<name>` pointer without the `.md` extension, the way
#      an agent is usually referenced by name, also resolves when `<name>.md`
#      exists on disk)
#
# (2), (3) and (4) are the silent ones. A stale index entry sends an agent looking
# for something that is not there; a hook without +x never runs and never says so;
# a dangling pointer sends an agent to read a file that was never linked.
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
#   .claude/scripts/harness/check-index.sh
#   .claude/scripts/harness/check-index.sh --strict

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
  grep -q "\`$name\`\|\`/$name\`" "$CLAUDE" || add unlisted "skill    $name"
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
  # Both forms are normal in an index: `name` and `/name`. Only accepting the
  # first reported four correctly-listed commands as missing in a real repo.
  grep -q "\`$base\`\|\`/$base\`" "$CLAUDE" || add unlisted "command  /$base"
done; done

# ---------------------------------------------------------------- docs
# Docs can live in a subdirectory (`docs/harness/*.md`, the harness's own
# AI-only docs, still reachable in a consumer repo through its `.claude/docs/
# harness` symlink) so this walks recursively, the same as rules already do
# above — a flat glob only sees `docs/*.md` and reports every nested one as
# stale.
for root in ${OWNED[@]+"${OWNED[@]}"}; do
while IFS= read -r f; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  know "$base"; know "${base%.md}"
done < <(find -L "$root/docs" -name '*.md' -type f 2>/dev/null); done

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

# ----------------------------------------------- dangling pointers
# A fourth class, orthogonal to the other three: `.claude/docs/...`,
# `.claude/scripts/...`, `.claude/rules/...`, `.claude/skills/...` and
# `.claude/agents/...` are the paths a repo gets when it links the harness
# (install-harness.sh) — docs/scripts/rules namespaced under a `harness/`
# subdirectory, skills/agents linked one item at a time straight into
# `.claude/skills/<name>` and `.claude/agents/<name>.md`. A stale one survives
# every check above, because nothing dereferences prose — until an agent tries
# to read it and finds nothing. Resolved from the repo root, the same way
# every pointer in this codebase is written.
#
# Three things must stay out of the file list this scans, or it reports
# drift that isn't real:
#   - any path with a component ending in `.pre-harness` — install-harness.sh
#     --adopt renames the old skills/agents dirs to `skills.pre-harness/`,
#     `agents.pre-harness/` and the adopting guide says to keep them on disk
#     until the migration PR merges. Their broken cross-references are old
#     copies, not something an agent will ever be sent to read.
#   - files git considers ignored (e.g. a generated `.claude/context/
#     repomix-snapshot.md`) — their content is a machine-written snapshot,
#     not authored prose someone is expected to keep pointers current in.
#   - any path with a directory component literally named `tests` —
#     `baseline/hooks/tests/*.test.sh` and `baseline/scripts/tests/*.test.sh`
#     write `.claude/...`-shaped strings as INPUT DATA for the hook or
#     script under test, not as prose pointing an agent at something to
#     read, and a fair number of those strings are deliberately made up
#     because the test needs a path that resolves to nothing. The criterion
#     is the directory name, not an enumerated list of test files, for the
#     same reason `.pre-harness` above is a suffix shape rather than a list:
#     a new hook or script gains its own `tests/` fixture file regularly,
#     and none of those additions should ever need a matching edit here to
#     stay exempt.
# `find -L` still follows symlinks either way: that is how a consumer's own
# `.claude/skills` and `.claude/docs/harness` links resolve at all.
#
# The gitignore check needs `git`. When it is unavailable (no git on PATH, or
# this tree is not a git repository at all — a tarball export, for instance)
# the safe default is to skip nothing: an unverifiable "probably ignored"
# guess could hide a real dangling pointer, which is the exact failure class
# this script exists to catch. Erring toward reporting is the same trade-off
# `broken` already makes when frontmatter parsing is inconclusive.
GIT_AVAILABLE=0
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_AVAILABLE=1
fi

# Matched whole, with the separators pinned into the pattern, instead of
# split into components with `IFS=/` and looped unquoted: an unquoted
# `for part in $path` also runs pathname expansion on each token, and a
# component containing `*`, `?` or `[...]` would glob-expand against this
# script's CWD (the repo root) instead of reaching `case` as a literal.
# That turns an unrelated file whose path happens to hold a bare `*`
# component into a false exemption whenever the repo root holds anything
# ending in `.pre-harness`, silently hiding whatever that file points at.
# Quoting the subject and letting the pattern alone carry the globbing
# avoids that entirely.
is_pre_harness_path() {
  case "/$1/" in */*.pre-harness/*) return 0 ;; esac
  return 1
}

# A directory component literally named `tests` marks a hook or script test
# suite (baseline/hooks/tests/*.test.sh, baseline/scripts/tests/*.test.sh),
# whose `.claude/...`-shaped strings are fixture input for the thing under
# test, not pointers an agent is meant to follow. See the longer rationale
# above the exemption comment near GIT_AVAILABLE.
#
# Same whole-path match as `is_pre_harness_path` above, for the same reason:
# a split-and-loop over `$path` with `IFS=/` would glob-expand an unquoted
# component such as `*` against the CWD, so a path with a literal `*`
# segment could wrongly exempt itself whenever the repo root happens to
# contain a `tests` entry.
is_test_fixture_path() {
  case "/$1/" in */tests/*) return 0 ;; esac
  return 1
}

# A directory that holds its own `.git` (file or folder) is a nested git
# checkout — most often a worktree parked under `.claude/worktrees/` — and
# everything under it belongs to that other repository, not this scan.
# `node_modules` gets the same treatment: never authored pointers, only
# vendored ones. Both are pruned in the `find` below so the walk never
# descends into them at all, instead of visiting every file underneath and
# discarding it one at a time — the difference between a stray worktree's
# `node_modules` (tens of thousands of files) taking seconds instead of
# minutes.
#
# The gitignore check is batched the same way: every remaining candidate is
# collected first, then handed to ONE `git check-ignore --stdin` call,
# instead of one `git` process per file. `check-ignore` exits 1 when NONE of
# the paths it was given are ignored — that is a normal empty result, not an
# error; only an exit above 1 is a real failure, and the safe response to a
# real failure is the same as having no git at all (see above): report
# everything rather than guess.
#
# Two pointer shapes are exempt, not because the regex cannot see them but
# because they are correct without ever resolving in THIS checkout:
#   - `.claude/scripts/check-snapshot.sh` — install.sh (not install-harness.sh)
#     copies this one script directly into a consumer's .claude/scripts/, by
#     design, so it works for a teammate who never linked the harness at all.
#     This repo never runs install.sh on itself, so the copy never exists here.
#   - `.claude/docs/libs/...` — "how THIS project uses each library" is
#     project-owned content, never delivered by the harness link. What ships
#     in baseline/docs/libs/example-lib.md is a template to be copied into a
#     project's own docs, not something the harness link exposes at that path.
is_exempt_pointer() {
  case "$1" in
    .claude/scripts/check-snapshot.sh) return 0 ;;
    .claude/docs/libs|.claude/docs/libs/*) return 0 ;;
  esac
  return 1
}

# A `.claude/agents/<name>` pointer is often written without the `.md`
# extension, the same way the agent is dispatched by name (backtick-quoted
# in prose, e.g. `.claude/agents/code-reviewer`) rather than referenced as a
# literal file path. The file on disk is always `<name>.md`, so a pointer
# missing the extension still resolves as long as that file exists.
pointer_resolves() {
  local pointer="$1"
  [[ -e "$pointer" ]] && return 0
  case "$pointer" in
    .claude/agents/*) [[ -e "$pointer.md" ]] && return 0 ;;
  esac
  return 1
}

dangling=""
seen_ptr_files=""
ptr_files=()
for f in "$CLAUDE" AGENTS.md; do
  [[ -f "$f" ]] || continue
  ptr_files+=("$f")
done
candidates=()
for root in ${OWNED[@]+"${OWNED[@]}"}; do
  while IFS= read -r f; do
    [[ -e "$f" ]] || continue
    is_pre_harness_path "$f" && continue
    is_test_fixture_path "$f" && continue
    candidates+=("$f")
  done < <(find -L "$root" \
    \( -type d \( -name node_modules -o -name '*.pre-harness' \) -prune \) \
    -o \( -type d -mindepth 1 -exec test -e {}/.git \; -prune \) \
    -o -type f \( -name '*.md' -o -name '*.sh' \) -print 2>/dev/null)
done

# A candidate reached through a symlinked DIRECTORY — a whole-folder link
# (old-style `.claude/skills -> .../baseline/skills`) or a per-item one
# (`.claude/skills/write-spec -> .../baseline/skills/write-spec`) — makes
# `git check-ignore` fatal with "pathspec '...' is beyond a symbolic link"
# for THAT line, regardless of whether the symlink points inside or
# outside the repo. `check-ignore --stdin` reads its input sequentially and
# ABORTS THE WHOLE BATCH at the first such line: every candidate listed
# after it in the same invocation never gets evaluated at all, not just
# skipped. `find -L`'s traversal order isn't guaranteed, so whether the
# offending line lands before or after everything else is filesystem-
# dependent — this passed for years on one OS and failed the moment CI ran
# it on another. Pull anything under a symlinked directory out of the
# batch before it can poison the rest of it; git can never classify these
# anyway, so they are simply never counted as ignored (a leaf file that is
# itself a symlink, like a per-item agent link, does not trigger this and
# stays in the batch — only a symlinked directory COMPONENT does).
symlinked_dirs=()
for root in ${OWNED[@]+"${OWNED[@]}"}; do
  while IFS= read -r d; do
    symlinked_dirs+=("$d")
  done < <(find "$root" -type l -xtype d 2>/dev/null)
done

check_candidates=()
if [[ ${#symlinked_dirs[@]} -gt 0 ]]; then
  for f in ${candidates[@]+"${candidates[@]}"}; do
    skip=0
    for d in "${symlinked_dirs[@]}"; do
      case "$f" in "$d"/*) skip=1; break ;; esac
    done
    [[ $skip -eq 0 ]] && check_candidates+=("$f")
  done
else
  check_candidates=(${candidates[@]+"${candidates[@]}"})
fi

ignored=""
if [[ $GIT_AVAILABLE -eq 1 && ${#check_candidates[@]} -gt 0 ]]; then
  # Trust stdout, not the exit code: an unrelated `check-ignore` failure
  # (exit 1 alone means "nothing in the batch is ignored", not an error)
  # should not discard results that were already printed correctly.
  ignored="$(printf '%s\n' "${check_candidates[@]}" | git check-ignore --stdin 2>/dev/null)"
fi

if [[ -n "$ignored" ]]; then
  while IFS= read -r f; do
    ptr_files+=("$f")
  done < <(printf '%s\n' "${candidates[@]}" | grep -vxF -- "$ignored")
else
  ptr_files+=(${candidates[@]+"${candidates[@]}"})
fi

for f in ${ptr_files[@]+"${ptr_files[@]}"}; do
  real=$( (cd -- "$(dirname -- "$f")" 2>/dev/null && pwd -P) )/$(basename -- "$f")
  case "$seen_ptr_files" in *"|$real|"*) continue ;; esac
  seen_ptr_files="${seen_ptr_files}|$real|"
  while IFS=: read -r lineno pointer; do
    [[ -n "$pointer" ]] || continue
    # A pointer at the end of a sentence ("...harness-baseline.md.") picks up
    # the full stop; it is punctuation, not part of the path.
    pointer="${pointer%.}"
    pointer_resolves "$pointer" && continue
    is_exempt_pointer "$pointer" && continue
    add dangling "$f:$lineno — $pointer"
  done < <(grep -noE '\.claude/(docs|scripts|rules|skills|agents)/[A-Za-z0-9_./-]+' "$f" 2>/dev/null)
done

# ---------------------------------------------------------------- reverse
# Index entries are written as a bullet whose first token is a backticked
# lowercase name: "- `write-spec` - persists a shaped idea as ...".
# Anything matching that shape should exist on disk.
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  grep -qxF "$name" <<< "$known" || add stale "$name"
done < <(grep -oE '^- `/?[a-z][a-z0-9-]*(\.md)?`' "$CLAUDE" | tr -d '`' | sed 's/^- //; s/^\///' | sort -u)

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
emit "⚠  .claude/(docs|scripts|rules|skills|agents) pointer that does not resolve:" "$dangling"

if [[ $found -eq 1 ]]; then
  {
    echo ""
    echo "   Update CLAUDE.md so the index matches reality."
    echo ""
  } >&2
  [[ $STRICT -eq 1 ]] && exit 1
fi

exit 0
