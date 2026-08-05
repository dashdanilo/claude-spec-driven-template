#!/usr/bin/env bash
# install-global.sh
# Installs this harness into YOUR personal Claude Code scope, so it is available
# in every project on this machine — njord or not, new or old, with no per-repo
# setup. See docs/decisions/0002 in the njord marketplace for why.
#
# It symlinks, it does not copy:
#
#   ~/.claude/skills  ->  <this checkout>/baseline/skills
#   ~/.claude/agents  ->  <this checkout>/baseline/agents
#   ~/.claude/rules   ->  <this checkout>/baseline/rules
#
# so updating the harness is `git pull` in this checkout. There is no update
# command, because there is nothing to copy.
#
# Hooks cannot be symlinked into place — they are registered by path in
# settings.json — so those entries are merged into ~/.claude/settings.json,
# pointing at absolute paths in this checkout. Existing settings are preserved.
#
#   ./install-global.sh              # install or repair
#   ./install-global.sh --dry-run    # show what would change
#   ./install-global.sh --uninstall  # remove the links and the hook entries
#   ./install-global.sh --status     # what is linked right now
#
# Idempotent: safe to run repeatedly. It never overwrites a real directory —
# if ~/.claude/skills exists and is not a link into this checkout, it stops and
# tells you, rather than destroying files you wrote.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BASE="$HERE/baseline"
DEST="$HOME/.claude"
SETTINGS="$DEST/settings.json"
LINKS=(skills agents rules)

MODE=install
case "${1:-}" in
  --dry-run)   MODE=dryrun ;;
  --uninstall) MODE=uninstall ;;
  --status)    MODE=status ;;
  --help|-h)   sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")          ;;
  *)           echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

[[ -d "$BASE" ]] || { warn "no baseline/ next to this script — run it from the harness checkout"; exit 2; }
mkdir -p "$DEST"

# ------------------------------------------------------------------ status
if [[ $MODE == status ]]; then
  say "harness checkout: $HERE"
  for d in "${LINKS[@]}"; do
    t="$DEST/$d"
    if [[ -L "$t" ]]; then
      printf '  %-8s -> %s\n' "$d" "$(readlink "$t")"
    elif [[ -e "$t" ]]; then
      printf '  %-8s (real directory, not linked)\n' "$d"
    else
      printf '  %-8s (absent)\n' "$d"
    fi
  done
  if [[ -f "$SETTINGS" ]] && grep -q "$HERE/baseline/hooks" "$SETTINGS" 2>/dev/null; then
    say "  hooks    registered in ~/.claude/settings.json"
  else
    say "  hooks    not registered"
  fi
  exit 0
fi

# ------------------------------------------------------------------ links
for d in "${LINKS[@]}"; do
  src="$BASE/$d"
  dst="$DEST/$d"
  [[ -d "$src" ]] || { warn "skip $d — not in this checkout"; continue; }

  if [[ $MODE == uninstall ]]; then
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
      rm "$dst"; say "unlinked  ~/.claude/$d"
    else
      say "left alone ~/.claude/$d (not ours)"
    fi
    continue
  fi

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      say "ok        ~/.claude/$d"
      continue
    fi
    say "relink    ~/.claude/$d  (was $(readlink "$dst"))"
    [[ $MODE == dryrun ]] || ln -sfn "$src" "$dst"
    continue
  fi

  if [[ -e "$dst" ]]; then
    # A real directory with your own files. Never clobber it.
    warn "STOP      ~/.claude/$d exists and is not a link."
    warn "          Move or merge it yourself, then re-run. Nothing was changed."
    exit 2
  fi

  say "link      ~/.claude/$d -> $src"
  [[ $MODE == dryrun ]] || ln -s "$src" "$dst"
done

# ------------------------------------------------------------------ hooks
# Hooks are registered by path, so they cannot ride a directory symlink.
python3 - "$SETTINGS" "$HERE" "$MODE" <<'PY'
import json, sys, os, collections

settings, here, mode = sys.argv[1], sys.argv[2], sys.argv[3]
hooks_dir   = os.path.join(here, "baseline", "hooks")
scripts_dir = os.path.join(here, "baseline", "scripts")

WANT = {
    "SessionStart": [(None, [f"{scripts_dir}/check-index.sh", f"{scripts_dir}/check-baseline.sh"])],
    "SubagentStop": [(None, [f"{hooks_dir}/log-agent.sh"])],
    "PreToolUse": [
        ("Bash", [f"{hooks_dir}/block-secrets.sh", f"{hooks_dir}/protect-main.sh"]),
        ("Edit|Write|MultiEdit|NotebookEdit", [f"{hooks_dir}/log-edit.sh"]),
    ],
}

d = {}
if os.path.exists(settings):
    try:
        d = json.load(open(settings), object_pairs_hook=collections.OrderedDict)
    except Exception:
        print("  settings.json is not valid JSON — leaving hooks alone", file=sys.stderr)
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
            if mode == "uninstall":
                if c in have:
                    g["hooks"] = [h for h in g["hooks"] if h.get("command") != c]
                    changed.append(f"unregistered {os.path.basename(c)}")
            elif c not in have:
                g["hooks"].append(collections.OrderedDict([("type", "command"), ("command", c)]))
                changed.append(f"registered   {os.path.basename(c)}")

# Drop groups and events we emptied.
for event in list(hooks):
    hooks[event] = [g for g in hooks[event] if g.get("hooks")]
    if not hooks[event]:
        del hooks[event]
if not hooks:
    d.pop("hooks", None)

if not changed:
    print("ok        hooks already as expected")
elif mode == "dryrun":
    for c in changed:
        print("would     " + c)
else:
    os.makedirs(os.path.dirname(settings), exist_ok=True)
    with open(settings, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    for c in changed:
        print(c)
PY

# ------------------------------------------------------------------ closing
if [[ $MODE == dryrun ]]; then
  say ""
  say "dry run — nothing changed."
elif [[ $MODE == uninstall ]]; then
  say ""
  say "removed. Your projects keep whatever lives in their own .claude/."
else
  say ""
  say "installed. Open any project and the harness is there."
  say "update it with: git -C $HERE pull"
fi

exit 0
