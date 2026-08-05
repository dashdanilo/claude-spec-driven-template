#!/usr/bin/env bash
# install.sh
# Sets up a repo's own CONTEXT — the files that describe that project and must
# be committed with it. It does NOT install the harness.
#
# Two things, two commands, and the split matters:
#
#   ./install.sh --to <repo>     the project's context: AGENTS.md, CLAUDE.md,
#                                docs/, specs/, .claude/settings.json. Committed,
#                                shared with the team, different in every repo.
#
#   ./install-harness.sh         the machinery: skills, agents, rules, hooks.
#                                Symlinked from this checkout, never committed,
#                                identical everywhere, opt-in per repo.
#
# Before ADR 0003 this script copied `.claude/` wholesale, because the machinery
# lived there. It does not any more — it lives in baseline/ and is linked, not
# copied — so copying `.claude/` would now deliver almost nothing and imply it
# had delivered a harness.
#
# It NEVER overwrites files that already exist in the target (skips and warns,
# unless --force), and merges the required entries into the target .gitignore.
# Only git-tracked template files are copied, so local/generated cruft
# (settings.local.json, the Repomix snapshot, the logs) never leaks in.
#
# After running: personalize AGENTS.md, run `/skill analyze-codebase`, and link
# the harness with install-harness.sh if you want it in this repo.
#
# Usage:
#   # from a template clone, targeting another repo:
#   ./install.sh --to /path/to/your-repo
#
#   # from inside the target repo, pulling the template fresh:
#   curl -fsSL https://raw.githubusercontent.com/dashdanilo/claude-spec-driven-template/main/install.sh | bash
#
# Options:
#   --to <path>     Target repo (default: current directory)
#   --from <path>   Template source (default: this script's repo, else git clone)
#   --dry-run       Show what would happen; change nothing
#   --force         Overwrite files that already exist in the target
#   --help
#
# Exit codes:
#   0 - success   1 - usage error   2 - precondition failed

set -euo pipefail

TEMPLATE_REPO="https://github.com/dashdanilo/claude-spec-driven-template"

# Scaffolding to install (pathspecs relative to the template root).
# Deliberately excludes README.md, LICENSE, CONTRIBUTING.md, LEARN.md,
# CHANGELOG.md, src/ and .gitignore (the target keeps its own).
ITEMS=(
  ".claude/settings.json"
  "docs"
  "specs"
  "AGENTS.md"
  "CLAUDE.md"
  "CLAUDE.local.md.example"
  "ECOSYSTEM.md"
  ".claudeignore"
  ".github"
)

GITIGNORE_BLOCK='# Personal Claude Code files (do not share)
CLAUDE.local.md
.claude/settings.local.json
.claude/agent-memory/

# Generated context (Repomix snapshot, etc)
.claude/context/repomix-snapshot.md
.claude/context/last-analyze.log
.claude/context/config.json

# Claude Code session state
.claude/projects/
.claude/shell-snapshots/
.claude/backups/'

log()  { echo "$@" >&2; }
die()  { echo "error: $*" >&2; exit "${2:-2}"; }
usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//' >&2; exit "${1:-0}"; }

TARGET="$PWD"
FROM=""
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --to)      shift; [[ $# -ge 1 ]] || die "--to needs a path" 1; TARGET="$1" ;;
    --from)    shift; [[ $# -ge 1 ]] || die "--from needs a path" 1; FROM="$1" ;;
    --dry-run) DRY_RUN=true ;;
    --force)   FORCE=true ;;
    --help|-h) usage 0 ;;
    *)         die "unknown argument: $1" 1 ;;
  esac
  shift
done

# --- Resolve the template source ---
CLEANUP_TMP=""
resolve_source() {
  if [[ -n "$FROM" ]]; then
    [[ -d "$FROM/.claude" ]] || die "--from '$FROM' does not look like the template (no .claude/)" 2
    SRC="$FROM"; return
  fi
  # Running from a template clone?
  local self_dir
  self_dir="$(cd "$(dirname "$0")" && pwd)"
  if [[ -d "$self_dir/.claude" ]]; then
    SRC="$self_dir"; return
  fi
  # Piped (curl | bash): clone fresh
  command -v git >/dev/null || die "git is required to fetch the template" 2
  CLEANUP_TMP="$(mktemp -d)"
  log "Cloning template into $CLEANUP_TMP ..."
  git clone --depth 1 --quiet "$TEMPLATE_REPO" "$CLEANUP_TMP" || die "failed to clone $TEMPLATE_REPO" 2
  SRC="$CLEANUP_TMP"
}
cleanup() { [[ -n "$CLEANUP_TMP" && -d "$CLEANUP_TMP" ]] && rm -rf "$CLEANUP_TMP"; return 0; }
trap cleanup EXIT

resolve_source

# --- Validate target ---
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || die "target directory not found: $TARGET" 2
[[ "$TARGET" != "$SRC" ]] || die "target is the template itself; pick another --to" 1
if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "warning: $TARGET is not a git repository. Continuing anyway."
fi

# --- Enumerate tracked template files under the scaffolding items ---
list_files() {
  if git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$SRC" ls-files -- "${ITEMS[@]}"
  else
    local it
    for it in "${ITEMS[@]}"; do
      if [[ -d "$SRC/$it" ]]; then
        ( cd "$SRC" && find "$it" -type f )
      elif [[ -f "$SRC/$it" ]]; then
        echo "$it"
      fi
    done
  fi
}

log "Installing template scaffolding"
log "  from: $SRC"
log "  to:   $TARGET"
$DRY_RUN && log "  mode: DRY RUN (no changes)"
log ""

copied=0 skipped=0
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  src_file="$SRC/$rel"
  dst_file="$TARGET/$rel"
  if [[ -e "$dst_file" && "$FORCE" != true ]]; then
    log "  skip   $rel (exists)"
    skipped=$((skipped + 1))
    continue
  fi
  if $DRY_RUN; then
    log "  copy   $rel"
  else
    mkdir -p "$(dirname "$dst_file")"
    cp "$src_file" "$dst_file"
    log "  copy   $rel"
  fi
  copied=$((copied + 1))
done < <(list_files)

# --- Merge required .gitignore entries ---
merge_gitignore() {
  local gi="$TARGET/.gitignore" missing=""
  local line
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ ! -f "$gi" ]] || ! grep -qxF "$line" "$gi" 2>/dev/null; then
      missing+="$line"$'\n'
    fi
  done <<< "$GITIGNORE_BLOCK"

  if [[ -z "$missing" ]]; then
    log ""
    log ".gitignore already has the required entries."
    return
  fi
  if $DRY_RUN; then
    log ""
    log "would add to .gitignore:"; log "$missing"
    return
  fi
  {
    [[ -f "$gi" ]] && echo ""
    echo "$GITIGNORE_BLOCK"
  } >> "$gi"
  log ""
  log "Appended required entries to .gitignore"
}
merge_gitignore

# --- Repo-owned guards -------------------------------------------------------
# These are guards, not method: they must hold for everyone who touches the
# repo, including a teammate who never installed the harness and CI. So they are
# COPIED and committed, unlike the machinery, which is linked. install-harness.sh
# deliberately does not register them for exactly this reason.
#
# The settings.json we just copied lists hooks at baseline/..., which is where
# they live in the harness checkout and nowhere else. Rewrite it to the repo's
# own paths and drop the portable hooks, which arrive via settings.local.json
# when someone links the harness.
REPO_HOOKS=(protect-critical.sh check-snapshot-on-session.sh)
REPO_SCRIPTS=(check-snapshot.sh)

if ! $DRY_RUN; then
  mkdir -p "$TARGET/.claude/hooks" "$TARGET/.claude/scripts"
  for h in "${REPO_HOOKS[@]}"; do
    if [[ -e "$TARGET/.claude/hooks/$h" ]] && [[ "$FORCE" != true ]]; then
      log "  skip   .claude/hooks/$h (already present)"
    else
      cp "$SRC/baseline/hooks/$h" "$TARGET/.claude/hooks/$h" && log "  copy   .claude/hooks/$h"
    fi
  done
  for f in "${REPO_SCRIPTS[@]}"; do
    if [[ -e "$TARGET/.claude/scripts/$f" ]] && [[ "$FORCE" != true ]]; then
      log "  skip   .claude/scripts/$f (already present)"
    else
      cp "$SRC/baseline/scripts/$f" "$TARGET/.claude/scripts/$f" && log "  copy   .claude/scripts/$f"
    fi
  done
  find "$TARGET/.claude/hooks" "$TARGET/.claude/scripts" -name '*.sh' -type f -exec chmod +x {} + 2>/dev/null || true

  python3 - "$TARGET/.claude/settings.json" <<'PYEOF'
import json, sys, os, collections
p = sys.argv[1]
if not os.path.exists(p):
    sys.exit(0)
try:
    d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
except Exception:
    sys.exit(0)

KEEP = {"protect-critical.sh", "check-snapshot-on-session.sh"}
hooks = d.get("hooks", {})
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        kept = []
        for h in g.get("hooks", []):
            base = os.path.basename(h.get("command", ""))
            if base in KEEP:
                h["command"] = ".claude/hooks/" + base
                kept.append(h)
        if kept:
            g["hooks"] = kept
            groups.append(g)
    if groups:
        hooks[event] = groups
    else:
        del hooks[event]
if not hooks:
    d.pop("hooks", None)
with open(p, "w") as f:
    json.dump(d, f, indent=2); f.write("\n")
PYEOF
  log "  wrote  .claude/settings.json (repo-owned hooks only)"
fi

# --- Summary ---
log ""
log "Done. Copied $copied, skipped $skipped (already present)."
log ""
log "Next steps:"
log "  1. Personalize AGENTS.md (project name, tech stack, commands, structure)"
log "  2. Update the project name at the top of CLAUDE.md"
log "  3. Link the harness here, if you want it in this repo:"
log "       $(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/install-harness.sh --to $TARGET"
log "  4. In Claude Code, run:  /skill analyze-codebase"
log "  5. Review generated docs for TODO markers, then commit the context"
if $DRY_RUN; then log ""; log "(dry run: nothing was written)"; fi
