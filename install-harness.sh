#!/usr/bin/env bash
# install-harness.sh
# Links this harness into a project you choose. Opt-in, per repo.
#
#   cd ~/Sites/some-project
#   ~/Sites/harness/install-harness.sh              # link it here
#   ~/Sites/harness/install-harness.sh --unlink     # take it back out
#   ~/Sites/harness/install-harness.sh --status     # what is linked here
#   ~/Sites/harness/install-harness.sh --dry-run    # show, change nothing
#   ~/Sites/harness/install-harness.sh --adopt      # set aside what is already there
#   ~/Sites/harness/install-harness.sh --global     # every project on this machine
#
# It symlinks, it does not copy — so `git pull` in this checkout updates every
# project that opted in, at once, with no propagation step.
#
#   .claude/skills/<name>     -> <checkout>/baseline/skills/<name>     one per skill
#   .claude/agents/<name>.md  -> <checkout>/baseline/agents/<name>.md  one per agent
#   .claude/rules/harness  -> <checkout>/baseline/rules
#   .claude/docs/harness   -> <checkout>/baseline/docs
#   .claude/scripts/harness -> <checkout>/baseline/scripts
#
# Three things make this safe to run inside a repository other people share:
#
#   Absolute paths.  No assumption that the harness sits as a sibling on disk,
#   so a work repo, a new site and a personal experiment all work the same.
#
#   A copy when a link is impossible.  Git Bash on Windows will not create a
#   symlink without Developer Mode, and a "symlink" that is quietly a copy is
#   worse than an honest one — every promise about `git pull` updating it would
#   be false. So the installer verifies the link it just made, falls back to
#   copying, marks the copy, and says so. --status reports which is which.
#
#   Nothing is committed.  The links go into .git/info/exclude, which is
#   per-clone and never leaves your machine. A teammate cloning the repo sees
#   no dangling symlink, and CI sees nothing at all.
#
#   Skills and agents are linked ONE ITEM AT A TIME, never the whole folder,
#   so a skill or agent the repo versions itself keeps loading next to the
#   harness's. Claude Code only looks directly under .claude/skills/ and
#   .claude/agents/, so a namespaced subfolder is not an option for these two.
#
#   Rules, docs and scripts land in a SUBDIRECTORY (.claude/rules/harness/,
#   .claude/docs/harness/, .claude/scripts/harness/) instead of replacing the
#   whole folder. Rules are discovered recursively, so the repo's own rules
#   keep working alongside — and a project rule still wins over a harness one.
#   The same namespace keeps a project's own .claude/docs/libs/ or its own
#   .claude/scripts/*.sh from colliding with what the harness provides.
#
# Hooks cannot ride a symlink because they are registered by path, so they are
# merged into .claude/settings.local.json — already gitignored, so the repo's
# committed settings.json is never touched.
#
# Idempotent. It never replaces what you wrote: a skill or agent the repo keeps
# in .claude/skills/ or .claude/agents/ is left alone, and only one with the SAME
# NAME as an item the harness ships stops the install (--adopt sets that one
# aside, to .claude/skills.pre-harness/<name>). A repo still on the old layout,
# the whole folder as one link, is converted in place, and whatever the repo
# tracks that the old link was hiding is put back.
#
# --adopt also handles the collisions a directory link cannot: a repo that
# copied the harness has its own .claude/rules/delegation.md next to the linked
# .claude/rules/harness/delegation.md (loaded twice), and its own
# .claude/commands/orchestrate.md shadowed by the linked skill. Those individual
# files are set aside too, and restored the same way.
#
# --adopt is for a repo that already has a copied harness. Instead of stopping,
# it renames what is in the way to .claude/<name>.pre-harness and links over it.
# --unlink then puts it back, so the whole thing is reversible with one command
# and you can try the new model on a real repository without losing the old one.
#
# While adopted, git reports the set-aside files as DELETED, because they are
# tracked and the link now in their place does not expose them. That is expected
# and harmless — including committing it: the intended flow (ADOPTING.md section
# 3, step 7) commits exactly that deletion with `git rm`/`git rm --cached`, never
# `git add -A`, and keeps the .pre-harness copies on disk until that PR merges
# (step 10). --unlink instead restores everything and leaves the working tree
# exactly as it was, if you decide not to go through with it.
#
# The merge/pull half is the one that bites. Git sees those files as deleted, so
# any operation that restores the working tree writes them back — over the links.
# You end up with a real .claude/skills next to an orphaned .claude/skills
# .pre-harness, and --unlink cannot fix it because the destination is occupied.
# The way out is `git checkout -- .claude`, which is authoritative, then removing
# the leftovers by hand. Unlink before you merge, and re-adopt after.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BASE="$HERE/baseline"

MODE=link
SCOPE=repo
ADOPT=0
IS_WORKTREE=0
TARGET="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unlink)  MODE=unlink ;;
    --adopt)   ADOPT=1 ;;
    --status)  MODE=status ;;
    --dry-run) MODE=dryrun ;;
    --global)  SCOPE=global ;;
    --to)      TARGET="${2:?--to needs a path}"; shift ;;
    --help|-h) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

# Set by has_tracked() whenever an --adopt run buries something git already
# tracks. Drives which closing NOTE prints: a repo where the only thing in the
# way was untracked or ignored content (a stray .DS_Store, say) never has git
# reporting a deletion, so the "do not commit while adopted" warning would be
# false there and just scares someone who did nothing wrong.
SET_ASIDE_TRACKED=0

# True if git, run from the parent of $1, sees any tracked file at or under
# $1. Works for a single file or a whole directory, and for both repo and
# --global scope, because it asks git to discover the repository itself
# instead of trusting TARGET/DEST — which would be wrong for --global, where
# the thing being adopted lives under $HOME, not inside the target repo.
has_tracked() {
  local p="$1" parent base
  [[ -e "$p" ]] || return 1
  parent=$(dirname -- "$p")
  base=$(basename -- "$p")
  [[ -n "$(git -C "$parent" ls-files -- "$base" 2>/dev/null | head -n1)" ]]
}

[[ -d "$BASE" ]] || { warn "no baseline/ next to this script — run it from the harness checkout"; exit 2; }

if [[ $SCOPE == global ]]; then
  DEST="$HOME/.claude"
  SETTINGS="$DEST/settings.json"
  EXCLUDE=""
else
  TARGET=$(cd -- "$TARGET" 2>/dev/null && pwd) || { warn "no such directory"; exit 2; }
  if [[ "$TARGET" == "$HERE" ]]; then
    # Having baseline/ is not the same as being able to use it: Claude Code
    # discovers machinery under .claude/, never under baseline/. The harness repo
    # therefore links itself too — but with RELATIVE links that are committed, so
    # every clone works with no install step and nothing breaks if the checkout
    # moves. Those links are already in git; there is nothing to do here.
    warn "this is the harness itself. It links to its own baseline/ with committed"
    warn "relative symlinks (.claude/skills -> ../baseline/skills), so it already"
    warn "works in any clone. Nothing to install."
    exit 0
  fi
  DEST="$TARGET/.claude"
  SETTINGS="$DEST/settings.local.json"
  # Resolve via git, not by guessing: in a worktree .git is a FILE, so a -d test
  # reports "not a repo" and silently skips the exclude. rev-parse handles a
  # plain checkout, a worktree and a submodule alike.
  EXCLUDE=$(git -C "$TARGET" rev-parse --git-path info/exclude 2>/dev/null)
  if [[ -n "$EXCLUDE" ]]; then
    [[ "$EXCLUDE" = /* ]] || EXCLUDE="$TARGET/$EXCLUDE"
    # info/exclude lives in the COMMON git dir, so it is shared by every worktree
    # of this repo. Harmless — the paths it lists are tracked in the other
    # worktrees, and gitignore does not affect tracked files — but say it, since
    # a surprise is worse than a caveat.
    if [[ -f "$TARGET/.git" ]]; then
      IS_WORKTREE=1
    fi
  else
    warn "note: $TARGET is not a git repo — the links cannot be excluded from anything"
  fi
fi

# Skills and agents are linked ONE ITEM AT A TIME: .claude/skills/<name> points
# at baseline/skills/<name>, .claude/agents/<name>.md at baseline/agents/<name>.md.
# Claude Code discovers skills and agents only directly under .claude/skills/
# and .claude/agents/, so a namespaced subdirectory (what rules, docs and
# scripts get below) is not an option for them. Linking the whole folder was the
# old layout, and it made every skill or agent the repo versions itself vanish
# for anyone who linked the harness: the link replaced the folder they live in.
# Per item, the repo's own skills keep loading alongside the harness's.
#
# The price: `git pull` still updates every linked skill's CONTENT, but a skill
# or agent the harness ADDS or RENAMES needs this installer re-run.
# check-baseline.sh reports a missing or dangling item at session start.
PER_ITEM=(skills agents)
NAMES=("rules/harness" "docs/harness" "scripts/harness")
SRCS=("$BASE/rules" "$BASE/docs" "$BASE/scripts")

# Marker dropped inside a fallback copy of a WHOLE folder, so --status and
# --unlink can tell a copy WE made from a directory the repo owns. Per-item
# copies are listed in a manifest instead, one name per line, since an agent is
# a single file with no inside to drop a marker into.
MARKER=".harness-copy"
MANIFEST=".harness-copies"

# What the harness ships in a per-item category: skill folders, agent files.
items_of() {
  local p
  case $1 in
    skills) for p in "$BASE/skills"/*/; do [[ -f "${p}SKILL.md" ]] && basename "$p"; done ;;
    agents) for p in "$BASE/agents"/*.md; do [[ -f "$p" ]] && basename "$p"; done ;;
  esac
  return 0
}
in_lines() { printf '%s\n' "$2" | grep -qxF -- "$1"; }
# Ours = a link into THIS checkout's baseline/<category>/, dangling or not.
ours() { [[ -L "$1" ]] && [[ "$(readlink "$1")" == "$BASE/$2/"* ]]; }
copies_of() { [[ -f "$DEST/$1/$MANIFEST" ]] && cat "$DEST/$1/$MANIFEST"; return 0; }
copy_mark() {
  local f="$DEST/$1/$MANIFEST" rest
  rest=$(copies_of "$1" | grep -vxF -- "$2")
  [[ $3 == add ]] && rest=$(printf '%s\n%s' "$rest" "$2")
  rest=$(printf '%s\n' "$rest" | sed '/^$/d' | sort -u)
  if [[ -n "$rest" ]]; then printf '%s\n' "$rest" > "$f"; else rm -f "$f"; fi
}
# Does the repo track this path (a file, or anything under a folder)? Read from
# the index with no pathspec: a pathspec under a folder that is still a symlink
# makes git refuse outright ("beyond a symbolic link").
repo_tracks() {
  [[ $SCOPE == repo ]] || return 1
  git -C "$TARGET" ls-files 2>/dev/null | awk -v p="$1" '$0==p || index($0, p"/")==1 {f=1} END {exit !f}'
}

# Try a symlink; fall back to copying if the platform will not make one.
# On Windows this is not hypothetical: Git Bash silently copies unless
# MSYS=winsymlinks:nativestrict is set AND the user has Developer Mode or admin,
# and a "symlink" that is quietly a copy is worse than an honest copy, because
# every promise this installer makes about `git pull` updating it would be false.
link_or_copy() {
  local src="$1" dst="$2" label="$3"
  if ln -s "$src" "$dst" 2>/dev/null && [[ -L "$dst" ]]; then
    say "link       .claude/$label -> $src"
    return 0
  fi
  rm -f "$dst" 2>/dev/null
  if cp -R "$src" "$dst" 2>/dev/null; then
    printf '%s\n' "$src" > "$dst/$MARKER" 2>/dev/null
    say "COPIED     .claude/$label (this platform would not make a symlink)"
    COPIED=1
    return 0
  fi
  warn "FAILED     could not link or copy .claude/$label"
  return 1
}
link_item() {
  local cat="$1" name="$2" src="$BASE/$1/$2" dst="$DEST/$1/$2"
  if ln -s "$src" "$dst" 2>/dev/null && [[ -L "$dst" ]]; then
    say "link       .claude/$cat/$name"
    return 0
  fi
  rm -rf "$dst" 2>/dev/null
  if cp -R "$src" "$dst" 2>/dev/null; then
    copy_mark "$cat" "$name" add
    say "COPIED     .claude/$cat/$name (this platform would not make a symlink)"
    COPIED=1
    return 0
  fi
  warn "FAILED     could not link or copy .claude/$cat/$name"
  return 1
}
COPIED=0

# ------------------------------------------------------------------ status
per_item_status() {
  local cat="$1" d="$DEST/$1" items copies total name e ok=0 cop=0 missing=0 broken=0 own=0 line
  items=$(items_of "$cat"); total=$(printf '%s\n' "$items" | grep -c .)
  if [[ -L "$d" ]]; then
    printf '  %-14s whole-folder link (old layout, hides the repo'"'"'s own; re-run the installer)\n' "$cat"; return
  fi
  if [[ -f "$d/$MARKER" ]]; then
    printf '  %-14s whole-folder COPY (old layout; re-run the installer)\n' "$cat"; return
  fi
  [[ -d "$d" ]] || { printf '  %-14s absent\n' "$cat"; return; }
  copies=$(copies_of "$cat")
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    e="$d/$name"
    if ours "$e" "$cat"; then
      if [[ -e "$e" ]]; then ok=$((ok + 1)); else broken=$((broken + 1)); fi
    elif in_lines "$name" "$copies"; then cop=$((cop + 1))
    else missing=$((missing + 1)); fi
  done <<< "$items"
  for e in "$d"/*; do
    [[ -e "$e" || -L "$e" ]] || continue
    ours "$e" "$cat" && continue
    in_lines "$(basename "$e")" "$items" || own=$((own + 1))
  done
  if [[ $ok -eq 0 && $cop -eq 0 ]]; then
    line="real directory (not linked)"
  elif [[ $missing -eq 0 && $broken -eq 0 ]]; then
    line="linked ($((ok + cop))/$total"
  else
    line="PARTIAL ($((ok + cop))/$total linked"
    [[ $missing -gt 0 ]] && line="$line, $missing missing"
    line="$line; re-run the installer"
  fi
  [[ $cop -gt 0 && "$line" != real* ]] && line="$line, $cop COPIED"
  [[ "$line" != real* ]] && line="$line)"
  [[ $own -gt 0 ]] && line="$line, $own of the repo's own alongside"
  printf '  %-14s %s\n' "$cat" "$line"
  if [[ $broken -gt 0 ]]; then
    for e in "$d"/*; do ours "$e" "$cat" && [[ ! -e "$e" ]] && printf '  %-14s   dangling: %s\n' "" "$(basename "$e")"; done
  fi
}

if [[ $MODE == status ]]; then
  say "harness:  $HERE"
  say "target:   $DEST"
  for cat in "${PER_ITEM[@]}"; do per_item_status "$cat"; done
  for i in "${!NAMES[@]}"; do
    n="${NAMES[$i]}"; s="${SRCS[$i]}"; d="$DEST/$n"
    if [[ -L "$d" ]]; then
      if [[ "$(readlink "$d")" == "$s" ]]; then printf '  %-14s linked\n' "$n"
      else printf '  %-14s linked elsewhere -> %s\n' "$n" "$(readlink "$d")"; fi
    elif [[ -f "$d/.harness-copy" ]]; then
      printf '  %-14s COPIED (this platform would not symlink; re-run after git pull)\n' "$n"
    elif [[ -e "$d" ]]; then
      printf '  %-14s real directory (not linked)\n' "$n"
    else
      printf '  %-14s absent\n' "$n"
    fi
  done
  if [[ -f "$SETTINGS" ]] && grep -q "$HERE/baseline/hooks" "$SETTINGS" 2>/dev/null; then
    say "  hooks          registered in $(basename "$SETTINGS")"
  else
    say "  hooks          not registered"
  fi
  exit 0
fi

# ------------------------------------------- collisions, before changing anything
# A per-item link only collides with an item of the SAME NAME. Everything else
# the repo keeps in .claude/skills/ or .claude/agents/ is left alone, with or
# without --adopt. Checked up front so a refusal changes nothing.
if [[ $MODE != unlink ]]; then
  clash=""
  for cat in "${PER_ITEM[@]}"; do
    d="$DEST/$cat"
    [[ -d "$d" && ! -L "$d" && ! -f "$d/$MARKER" ]] || continue
    copies=$(copies_of "$cat")
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      t="$d/$name"
      [[ -e "$t" && ! -L "$t" ]] || continue
      in_lines "$name" "$copies" && continue
      if [[ $ADOPT -eq 1 && -e "$DEST/$cat.pre-harness/$name" ]]; then
        warn "STOP       .claude/$cat.pre-harness/$name already exists; refusing to bury a second copy."
        exit 2
      fi
      clash="$clash
           .claude/$cat/$name"
    done <<< "$(items_of "$cat")"
  done
  if [[ -n "$clash" && $ADOPT -eq 0 ]]; then
    warn "STOP       the repo has its own item with the name of one the harness ships:$clash"
    warn "           Re-run with --adopt to set those aside (to .claude/<skills|agents>.pre-harness/)"
    warn "           and link over them. The repo's other skills and agents are left alone."
    warn "           Nothing was changed."
    exit 2
  fi
fi

if [[ $MODE != dryrun ]]; then
  mkdir -p "$DEST"
  # Parent dir of each namespaced entry (rules/harness needs .claude/rules/,
  # docs/harness needs .claude/docs/, scripts/harness needs .claude/scripts/),
  # derived from NAMES instead of hardcoded.
  for n in "${NAMES[@]}"; do
    [[ "$n" == */* ]] && mkdir -p "$DEST/$(dirname "$n")"
  done
fi

# ------------------------------------------------------------ per-item links
per_item_unlink() {
  local cat="$1" d="$DEST/$1" aside="$DEST/$1.pre-harness" e name n=0
  if [[ -L "$d" ]]; then
    if [[ "$(readlink "$d")" == "$BASE/$cat" ]]; then rm "$d"; say "unlinked   .claude/$cat"
    else say "left alone .claude/$cat (not ours)"; fi
  elif [[ -f "$d/$MARKER" ]]; then
    rm -rf "$d"; say "removed    .claude/$cat (was a fallback copy)"
  elif [[ -d "$d" ]]; then
    for e in "$d"/*; do
      ours "$e" "$cat" && { rm "$e"; n=$((n + 1)); }
    done
    while IFS= read -r name; do
      [[ -n "$name" ]] && { rm -rf "${d:?}/$name"; n=$((n + 1)); }
    done <<< "$(copies_of "$cat")"
    rm -f "$d/$MANIFEST"
    [[ $n -gt 0 ]] && say "unlinked   .claude/$cat ($n items; the repo's own are left alone)"
  fi
  if [[ -d "$aside" ]]; then
    if [[ ! -e "$d" ]]; then
      mv "$aside" "$d"; say "restored   .claude/$cat (from .pre-harness)"
    else
      for e in "$aside"/* "$aside"/.[!.]*; do
        [[ -e "$e" || -L "$e" ]] || continue
        name=$(basename "$e")
        if [[ -e "$d/$name" || -L "$d/$name" ]]; then
          warn "note       $e kept; .claude/$cat/$name is occupied"
        else
          mv "$e" "$d/$name"; say "restored   .claude/$cat/$name"
        fi
      done
      rmdir "$aside" 2>/dev/null
    fi
  fi
  # Only if nothing is left: a folder this installer created, now empty.
  if [[ -d "$d" && ! -L "$d" ]]; then rmdir "$d" 2>/dev/null; fi
  return 0
}

per_item_install() {
  local cat="$1" d="$DEST/$1" aside="$DEST/$1.pre-harness" items copies name t src e tgt n_ok=0 fresh=0
  items=$(items_of "$cat")

  # Old layout: the whole folder was one link (or one fallback copy). Replace
  # it with a real folder, then give back what the old --adopt had to bury
  # just because it lived in that folder: repo-owned items the harness does
  # not ship. In a repo, "repo-owned" means git tracks it, so an old vendored
  # copy already deleted from git stays buried; under --global there is no git
  # to ask, and everything that does not collide comes back.
  if [[ -L "$d" || -f "$d/$MARKER" ]]; then
    if [[ -L "$d" ]]; then
      say "convert    .claude/$cat (whole-folder link -> one link per item)"
      [[ $MODE == dryrun ]] || rm "$d"
    else
      say "convert    .claude/$cat (whole-folder copy -> one entry per item)"
      [[ $MODE == dryrun ]] || rm -rf "$d"
    fi
    [[ $MODE == dryrun ]] || mkdir -p "$d"
    # A dry run leaves the old link in place, so every harness item would still
    # resolve through it and read as something to set aside. The real run starts
    # from an empty folder: report exactly that.
    [[ $MODE == dryrun ]] && fresh=1
    if [[ -d "$aside" ]]; then
      for e in "$aside"/*; do
        [[ -e "$e" || -L "$e" ]] || continue
        name=$(basename "$e")
        in_lines "$name" "$items" && continue
        if [[ $SCOPE == repo ]] && ! repo_tracks ".claude/$cat/$name"; then continue; fi
        say "restored   .claude/$cat/$name (the old whole-folder link hid it)"
        [[ $MODE == dryrun ]] || mv "$e" "$d/$name"
      done
      if [[ $MODE != dryrun ]] && rmdir "$aside" 2>/dev/null; then
        say "removed    .claude/$cat.pre-harness (nothing left in it)"
      fi
    fi
  fi
  [[ $MODE == dryrun ]] || mkdir -p "$d"
  copies=$(copies_of "$cat")

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    src="$BASE/$cat/$name"; t="$d/$name"
    if [[ $fresh -eq 1 ]]; then say "link       .claude/$cat/$name"; continue; fi
    if [[ -L "$t" && "$(readlink "$t")" == "$src" ]]; then
      n_ok=$((n_ok + 1)); continue
    fi
    if [[ -L "$t" ]]; then
      say "relink     .claude/$cat/$name  (was $(readlink "$t"))"
      [[ $MODE == dryrun ]] || ln -sfn "$src" "$t"
      continue
    fi
    if in_lines "$name" "$copies"; then
      say "refresh    .claude/$cat/$name (copy)"
      [[ $MODE == dryrun ]] || { rm -rf "$t"; cp -R "$src" "$t"; }
      continue
    fi
    if [[ -e "$t" ]]; then
      # Only reachable with --adopt: the collision check above stopped otherwise.
      has_tracked "$t" && SET_ASIDE_TRACKED=1
      say "set aside  .claude/$cat/$name -> .claude/$cat.pre-harness/$name"
      [[ $MODE == dryrun ]] || { mkdir -p "$aside"; mv "$t" "$aside/$name"; }
    fi
    if [[ $MODE == dryrun ]]; then say "link       .claude/$cat/$name"
    else link_item "$cat" "$name"; fi
  done <<< "$items"

  # Whatever the harness stopped shipping (a rename, a removal): drop our link,
  # or a dangling one left by a checkout that moved. Never touch anything else.
  [[ $fresh -eq 1 ]] && return 0
  for e in "$d"/*; do
    [[ -L "$e" ]] || continue
    name=$(basename "$e")
    in_lines "$name" "$items" && continue
    tgt=$(readlink "$e")
    if [[ "$tgt" == "$BASE/$cat/"* ]] || { [[ ! -e "$e" ]] && [[ "$tgt" == */baseline/$cat/* ]]; }; then
      say "remove     .claude/$cat/$name (the harness no longer ships it)"
      [[ $MODE == dryrun ]] || rm "$e"
    fi
  done
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    in_lines "$name" "$items" && continue
    say "remove     .claude/$cat/$name (copy; the harness no longer ships it)"
    [[ $MODE == dryrun ]] || { rm -rf "${d:?}/$name"; copy_mark "$cat" "$name" del; }
  done <<< "$copies"

  [[ $n_ok -gt 0 ]] && say "ok         .claude/$cat ($n_ok already linked)"
  return 0
}

for cat in "${PER_ITEM[@]}"; do
  [[ -d "$BASE/$cat" ]] || { warn "skip $cat (not in this checkout)"; continue; }
  if [[ $MODE == unlink ]]; then per_item_unlink "$cat"; else per_item_install "$cat"; fi
done

# ----------------------------------------------- namespaced whole-folder links
for i in "${!NAMES[@]}"; do
  n="${NAMES[$i]}"; src="${SRCS[$i]}"; dst="$DEST/$n"
  [[ -d "$src" ]] || { warn "skip $n — not in this checkout"; continue; }

  if [[ $MODE == unlink ]]; then
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
      rm "$dst"; say "unlinked   .claude/$n"
    elif [[ -f "$dst/$MARKER" ]]; then
      rm -rf "$dst"; say "removed    .claude/$n (was a fallback copy)"
    else
      say "left alone .claude/$n (not ours)"
    fi
    kept="$dst.pre-harness"
    if [[ -e "$kept" && ! -e "$dst" ]]; then
      mv "$kept" "$dst"; say "restored   .claude/$n (from .pre-harness)"
    elif [[ -e "$kept" ]]; then
      warn "note       $kept kept — something else now occupies .claude/$n"
    fi
    continue
  fi

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then say "ok         .claude/$n"; continue; fi
    say "relink     .claude/$n  (was $(readlink "$dst"))"
    [[ $MODE == dryrun ]] || ln -sfn "$src" "$dst"
    continue
  fi

  if [[ -e "$dst" ]]; then
    if [[ $ADOPT -eq 1 ]]; then
      kept="$dst.pre-harness"
      if [[ -e "$kept" ]]; then
        warn "STOP       $kept already exists — refusing to bury a second copy."
        exit 2
      fi
      has_tracked "$dst" && SET_ASIDE_TRACKED=1
      say "set aside  .claude/$n -> .claude/$n.pre-harness"
      [[ $MODE == dryrun ]] || mv "$dst" "$kept"
    else
      warn "STOP       .claude/$n exists and is not a link."
      warn "           Re-run with --adopt to set it aside and link over it,"
      warn "           or move it yourself. Nothing was changed."
      exit 2
    fi
  fi

  if [[ $MODE == dryrun ]]; then
    say "link       .claude/$n -> $src"
  else
    link_or_copy "$src" "$dst" "$n"
  fi
done

# --------------------------------------------------- per-file collisions
# A directory link replaces a folder wholesale, but rules and commands MERGE:
# a repo that copied the harness ends up with its own delegation.md beside the
# linked one (loaded twice), and its own orchestrate.md shadowed by the linked
# skill. Set those specific files aside; leave anything the repo actually owns.
collide() {
  local t="$1" action="$2"
  if [[ $action == aside ]]; then
    [[ -f "$t" && ! -L "$t" && ! -e "$t.pre-harness" ]] || return 0
    has_tracked "$t" && SET_ASIDE_TRACKED=1
    say "set aside  ${t#$DEST/} -> $(basename "$t").pre-harness"
    [[ $MODE == dryrun ]] || mv "$t" "$t.pre-harness"
  else
    [[ -f "$t.pre-harness" && ! -e "$t" ]] || return 0
    mv "$t.pre-harness" "$t"; say "restored   ${t#$DEST/}"
  fi
}

if [[ $MODE == unlink ]]; then
  for f in "$DEST"/rules/*.pre-harness "$DEST"/commands/*.pre-harness; do
    [[ -e "$f" ]] || continue
    collide "${f%.pre-harness}" back
  done
elif [[ $ADOPT -eq 1 ]]; then
  for f in "$BASE"/rules/*.md; do
    [[ -e "$f" ]] || continue
    collide "$DEST/rules/$(basename "$f")" aside
  done
  for d in "$BASE"/skills/*/; do
    [[ -d "$d" ]] || continue
    collide "$DEST/commands/$(basename "$d").md" aside
  done
fi

# ------------------------------------------------------------------ hooks
python3 - "$SETTINGS" "$HERE" "$MODE" <<'PY'
import json, sys, os, collections

settings, here, mode = sys.argv[1], sys.argv[2], sys.argv[3]
hooks_dir   = os.path.join(here, "baseline", "hooks")
scripts_dir = os.path.join(here, "baseline", "scripts")

# Only the portable ones. protect-critical.sh knows about lockfiles and applied
# migrations, check-snapshot-on-session.sh about a per-repo snapshot: both
# belong to a repository's own settings, not to something linked over it.
# protect-harness.sh is the opposite case — it exists specifically to stop a
# session in THIS adopting project from reaching, by absolute path, into the
# shared harness checkout and disarming the guard every project depends on —
# so unlike protect-critical.sh it has to be registered everywhere.
#
# log-edit.sh is registered on BOTH matchers: Edit/Write/MultiEdit/
# NotebookEdit (always has been) and now also Bash, so a write done through a
# redirect, `sed -i`, `tee`, `cp` or `mv` is no longer invisible to it.
WANT = {
    "SessionStart": [(None, [scripts_dir + "/check-index.sh", scripts_dir + "/check-baseline.sh"])],
    "SubagentStop": [(None, [hooks_dir + "/log-agent.sh"])],
    "PreToolUse": [
        ("Bash", [hooks_dir + "/block-secrets.sh", hooks_dir + "/protect-main.sh", hooks_dir + "/log-edit.sh"]),
        ("Edit|Write|MultiEdit|NotebookEdit", [hooks_dir + "/protect-harness.sh", hooks_dir + "/log-edit.sh"]),
    ],
}

d = {}
if os.path.exists(settings):
    try:
        d = json.load(open(settings), object_pairs_hook=collections.OrderedDict)
    except Exception:
        print("  " + os.path.basename(settings) + " is not valid JSON — leaving hooks alone", file=sys.stderr)
        sys.exit(0)

hooks = d.setdefault("hooks", collections.OrderedDict())
changed = []

def group_for(event, matcher):
    for g in hooks.setdefault(event, []):
        if (g.get("matcher") or None) == matcher:
            return g
    g = collections.OrderedDict()
    if matcher:
        g["matcher"] = matcher
    g["hooks"] = []
    hooks[event].append(g)
    return g

for event, groups in WANT.items():
    for matcher, cmds in groups:
        g = group_for(event, matcher)
        have = [h.get("command") for h in g["hooks"]]
        for c in cmds:
            if mode == "unlink":
                if c in have:
                    g["hooks"] = [h for h in g["hooks"] if h.get("command") != c]
                    changed.append("unregistered " + os.path.basename(c))
            elif c not in have:
                g["hooks"].append(collections.OrderedDict([("type", "command"), ("command", c)]))
                changed.append("registered   " + os.path.basename(c))

for event in list(hooks):
    hooks[event] = [g for g in hooks[event] if g.get("hooks")]
    if not hooks[event]:
        del hooks[event]
if not hooks:
    d.pop("hooks", None)

if not changed:
    print("ok         hooks already as expected")
elif mode == "dryrun":
    for c in changed:
        print("would      " + c)
elif mode == "unlink" and not d and os.path.exists(settings):
    # Unlinking removed the last thing WE ever put in this file. Writing an
    # empty `{}` back would leave a file with no exclude entry to cover it
    # (strip_block just dropped the whole harness block, settings.local.json
    # included) -- an orphan `git status` would report as untracked forever.
    # Delete it instead: --unlink promises "the repo keeps whatever lives in
    # its own .claude/", and a file that held nothing but our own hooks was
    # never the repo's to keep.
    os.remove(settings)
    for c in changed:
        print(c)
    print("removed    " + os.path.basename(settings) + " (nothing else left in it)")
else:
    os.makedirs(os.path.dirname(settings), exist_ok=True)
    with open(settings, "w") as f:
        json.dump(d, f, indent=2); f.write("\n")
    for c in changed:
        print(c)
PY

# ------------------------------------------------------- keep it out of git
# One entry per linked ITEM, not the whole .claude/skills or .claude/agents: an
# entry for the folder would also ignore every skill or agent the repo adds
# there itself, and `git add` would silently skip it. The block is rewritten on
# every run, so an item the harness adds or drops is reflected here too.
#
# It also covers the RUNTIME FILES the portable hooks and skills themselves
# write once registered: log-agent.sh appends to agent-log.txt and keeps the
# .agent-log-consumed registry, log-edit.sh appends to tool-log.txt,
# verify-before-done writes one evidence report per run under
# .claude/verification/ (see that skill and baseline/scripts/verify-gate.py),
# and the handover skill writes .claude/handovers/<date>-<slug>.md when no
# spec is active — that skill's own SKILL.md calls a handover local session
# state and says explicitly not to commit it. Only install.sh (the
# copy-context installer) puts these in the target's own .gitignore; a repo
# that only ever linked the harness has no reason to carry those names in its
# committed .gitignore, so they belong in this per-clone block instead —
# otherwise the first tool call after linking leaves an untracked file
# `git status`/`git add -A` would pick up.
MARK="# claude harness (install-harness.sh) — local only, never commit"
exclude_block() {
  local cat name n
  printf '%s\n' "$MARK"
  for cat in "${PER_ITEM[@]}"; do
    while IFS= read -r name; do
      [[ -n "$name" ]] && printf '.claude/%s/%s\n' "$cat" "$name"
    done <<< "$(items_of "$cat")"
    printf '.claude/%s/%s\n' "$cat" "$MANIFEST"
  done
  for n in "${NAMES[@]}"; do printf '.claude/%s\n' "$n"; done
  printf '%s\n' ".claude/settings.local.json" ".claude/**/*.pre-harness" ".claude/*.pre-harness"
  printf '%s\n' ".claude/agent-log.txt" ".claude/tool-log.txt" ".claude/.agent-log-consumed"
  printf '%s\n' ".claude/verification/"
  printf '%s\n' ".claude/handovers/"
}
current_block() {
  awk -v m="$MARK" '$0 == m {f = 1; print; next} f && /^\.claude\// {print; next} {f = 0}' "$EXCLUDE" 2>/dev/null
}
strip_block() {
  python3 - "$EXCLUDE" "$MARK" <<'PY2'
import sys
p, mark = sys.argv[1], sys.argv[2]
keep, dropping = [], False
for line in open(p):
    if line.strip() == mark:
        dropping = True
        if keep and not keep[-1].strip():
            keep.pop()
        continue
    if dropping and line.startswith(".claude/"):
        continue
    dropping = False
    keep.append(line)
open(p, "w").writelines(keep)
PY2
}

if [[ -n "$EXCLUDE" ]]; then
  mkdir -p "$(dirname "$EXCLUDE")"
  if [[ $MODE == unlink ]]; then
    if grep -qF "$MARK" "$EXCLUDE" 2>/dev/null; then
      strip_block
      say "cleaned    .git/info/exclude"
    fi
  else
    want=$(exclude_block)
    if [[ "$(current_block)" == "$want" ]]; then
      say "ok         already in .git/info/exclude"
    elif [[ $MODE == dryrun ]]; then
      say "would      write the links to .git/info/exclude"
    else
      grep -qF "$MARK" "$EXCLUDE" 2>/dev/null && strip_block
      { echo ""; printf '%s\n' "$want"; } >> "$EXCLUDE"
      say "excluded   from git via $(basename "$(dirname "$(dirname "$EXCLUDE")")")/info/exclude"
      [[ $IS_WORKTREE -eq 1 ]] && say "           (shared with every worktree of this repo; harmless, the paths are tracked there)"
    fi
  fi
fi

# ------------------------------------------------------------------ closing
say ""
case $MODE in
  dryrun) say "dry run — nothing changed." ;;
  unlink) say "removed. The repo keeps whatever lives in its own .claude/." ;;
  *)      if [[ ${COPIED:-0} -eq 1 ]]; then
            say "Some entries were COPIED, not linked, because this platform would not"
            say "make a symlink — Git Bash on Windows does this unless Developer Mode"
            say "is on. A copy does NOT follow the checkout, so \`git pull\` alone will"
            say "not update it: re-run this installer after pulling. --status says which"
            say "entries are copies."
            say ""
          fi
          say "linked. Update everything that opted in with: git -C $HERE pull"
          say "When the harness adds or renames a skill or agent, re-run this installer"
          say "(check-baseline.sh says so at session start)."
          if [[ $ADOPT -eq 1 ]]; then
            say ""
            if [[ $SET_ASIDE_TRACKED -eq 1 ]]; then
              say "NOTE: the files you set aside are tracked, so git now reports them as"
              say "      deleted. Commit ONLY the removals (ADOPTING.md section 3, step 7:"
              say "      git rm / git rm --cached, never git add -A) and keep the"
              say "      .pre-harness copies on disk until that PR merges (step 10)."
              say "      Do not merge or pull while adopted — run --unlink first, or a"
              say "      restored working tree writes the old files back over the links."
            else
              say "note: what you set aside was untracked or ignored (e.g. a stray"
              say "      .DS_Store), so git reports nothing as deleted and there is"
              say "      nothing to commit. Delete the .pre-harness copies whenever"
              say "      you like."
            fi
          fi ;;
esac

exit 0
