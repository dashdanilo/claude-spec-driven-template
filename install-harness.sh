#!/usr/bin/env bash
# install-harness.sh
# Links this harness into a project you choose. Opt-in, per repo.
#
#   cd ~/Sites/some-project
#   ~/Sites/harness/install-harness.sh              # link it here
#   ~/Sites/harness/install-harness.sh --unlink     # take it back out
#   ~/Sites/harness/install-harness.sh --status     # what is linked here
#   ~/Sites/harness/install-harness.sh --dry-run    # show, change nothing
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

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BASE="$HERE/baseline"

MODE=link
SCOPE=repo
TARGET="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unlink)  MODE=unlink ;;
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
  [[ "$TARGET" != "$HERE" ]] || { warn "that is the harness itself — it already has baseline/"; exit 2; }
  DEST="$TARGET/.claude"
  SETTINGS="$DEST/settings.local.json"
  EXCLUDE="$TARGET/.git/info/exclude"
  [[ -d "$TARGET/.git" ]] || warn "note: $TARGET is not a git repo — the links cannot be excluded from anything"
fi

NAMES=(skills agents "rules/harness")
SRCS=("$BASE/skills" "$BASE/agents" "$BASE/rules")

# ------------------------------------------------------------------ status
if [[ $MODE == status ]]; then
  say "harness:  $HERE"
  say "target:   $DEST"
  for i in 0 1 2; do
    n="${NAMES[$i]}"; s="${SRCS[$i]}"; d="$DEST/$n"
    if [[ -L "$d" ]]; then
      if [[ "$(readlink "$d")" == "$s" ]]; then printf '  %-14s linked\n' "$n"
      else printf '  %-14s linked elsewhere -> %s\n' "$n" "$(readlink "$d")"; fi
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
    else
      say "left alone .claude/$n (not ours)"
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
    warn "STOP       .claude/$n exists and is not a link."
    warn "           Move or merge it yourself, then re-run. Nothing was changed."
    exit 2
  fi

  say "link       .claude/$n -> $src"
  [[ $MODE == dryrun ]] || ln -s "$src" "$dst"
done

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
if [[ -n "$EXCLUDE" && -d "$(dirname "$EXCLUDE")" ]]; then
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
      { echo ""; echo "$MARK"; echo ".claude/skills"; echo ".claude/agents"; echo ".claude/rules/harness"; echo ".claude/settings.local.json"; } >> "$EXCLUDE"
      say "excluded   from git via .git/info/exclude"
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
  *)      say "linked. Update everything that opted in with: git -C $HERE pull" ;;
esac

exit 0
