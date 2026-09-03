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
#   .claude/skills        -> <checkout>/baseline/skills
#   .claude/agents        -> <checkout>/baseline/agents
#   .claude/rules/harness -> <checkout>/baseline/rules
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
#   Rules land in a SUBDIRECTORY (.claude/rules/harness/) instead of replacing
#   the rules folder. Rules are discovered recursively, so the repo's own rules
#   keep working alongside — and a project rule still wins over a harness one.
#
# Hooks cannot ride a symlink because they are registered by path, so they are
# merged into .claude/settings.local.json — already gitignored, so the repo's
# committed settings.json is never touched.
#
# Idempotent. It never replaces a real directory: if .claude/skills exists and
# is not our link, it stops and says so rather than deleting what you wrote.
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
# tracked and the symlink does not expose them. That is expected and harmless as
# long as you do not COMMIT, MERGE or PULL in that state. --unlink restores them
# and leaves the working tree exactly as it was; deleting the .pre-harness copies
# for good is a separate, deliberate commit.
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

NAMES=(skills agents "rules/harness")
SRCS=("$BASE/skills" "$BASE/agents" "$BASE/rules")

# Marker dropped inside a fallback copy, so --status and --unlink can tell a copy
# WE made from a directory the repo owns. Without it an interrupted install looks
# identical to a hand-written folder, and the safe move would be to leave it.
MARKER=".harness-copy"

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
COPIED=0

# ------------------------------------------------------------------ status
if [[ $MODE == status ]]; then
  say "harness:  $HERE"
  say "target:   $DEST"
  for i in 0 1 2; do
    n="${NAMES[$i]}"; s="${SRCS[$i]}"; d="$DEST/$n"
    if [[ -L "$d" ]]; then
      if [[ "$(readlink "$d")" == "$s" ]]; then printf '  %-14s linked\n' "$n"
      else printf '  %-14s linked elsewhere -> %s\n' "$n" "$(readlink "$d")"; fi
    elif [[ -f "$d/.harness-copy" ]]; then
      printf '  %-14s COPIED (this platform would not symlink — re-run after git pull)\n' "$n"
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

[[ $MODE == dryrun ]] || mkdir -p "$DEST" "$DEST/rules"

# ------------------------------------------------------------------ links
for i in 0 1 2; do
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
WANT = {
    "SessionStart": [(None, [scripts_dir + "/check-index.sh", scripts_dir + "/check-baseline.sh"])],
    "SubagentStop": [(None, [hooks_dir + "/log-agent.sh"])],
    "PreToolUse": [
        ("Bash", [hooks_dir + "/block-secrets.sh", hooks_dir + "/protect-main.sh"]),
        ("Edit|Write|MultiEdit|NotebookEdit", [hooks_dir + "/log-edit.sh"]),
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
else:
    os.makedirs(os.path.dirname(settings), exist_ok=True)
    with open(settings, "w") as f:
        json.dump(d, f, indent=2); f.write("\n")
    for c in changed:
        print(c)
PY

# ------------------------------------------------------- keep it out of git
MARK="# claude harness (install-harness.sh) — local only, never commit"
if [[ -n "$EXCLUDE" ]]; then
  mkdir -p "$(dirname "$EXCLUDE")"
  if [[ $MODE == unlink ]]; then
    if grep -qF "$MARK" "$EXCLUDE" 2>/dev/null; then
      python3 - "$EXCLUDE" "$MARK" <<'PY'
import sys
p, mark = sys.argv[1], sys.argv[2]
keep, dropping = [], False
for line in open(p):
    if line.strip() == mark:
        dropping = True
        continue
    if dropping and line.startswith(".claude/"):
        continue
    dropping = False
    keep.append(line)
open(p, "w").writelines(keep)
PY
      say "cleaned    .git/info/exclude"
    fi
  elif ! grep -qF "$MARK" "$EXCLUDE" 2>/dev/null; then
    if [[ $MODE == dryrun ]]; then
      say "would      add the links to .git/info/exclude"
    else
      { echo ""; echo "$MARK"; echo ".claude/skills"; echo ".claude/agents"; echo ".claude/rules/harness"; echo ".claude/settings.local.json"; echo ".claude/**/*.pre-harness"; echo ".claude/*.pre-harness"; } >> "$EXCLUDE"
      say "excluded   from git via $(basename "$(dirname "$(dirname "$EXCLUDE")")")/info/exclude"
      [[ $IS_WORKTREE -eq 1 ]] && say "           (shared with every worktree of this repo — harmless, the paths are tracked there)"
    fi
  else
    say "ok         already in .git/info/exclude"
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
          if [[ $ADOPT -eq 1 ]]; then
            say ""
            say "NOTE: the files you set aside are tracked, so git now reports them as"
            say "      deleted. Do not commit while adopted — run --unlink to put them"
            say "      back, or delete the .pre-harness copies deliberately once you are"
            say "      satisfied and commit that as its own change."
          fi ;;
esac

exit 0
