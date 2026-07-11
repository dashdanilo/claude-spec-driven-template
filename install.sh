#!/usr/bin/env bash
# install.sh
# Install the claude-spec-driven-template agent scaffolding into an existing repo.
#
# Copies the AI-relevant files (.claude/, docs/, specs/, AGENTS.md, CLAUDE.md,
# ECOSYSTEM.md, .claudeignore, .github/, CLAUDE.local.md.example) into a target
# repo. It NEVER overwrites files that already exist there (skips and warns,
# unless --force), and merges the required entries into the target .gitignore.
# Only git-tracked template files are copied, so local/generated cruft
# (settings.local.json, the Repomix snapshot, etc.) never leaks in.
#
# After running, personalize AGENTS.md and run `/skill analyze-codebase`.
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
  ".claude"
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

# --- Ensure hook/script shell files are executable ---
# settings.json invokes hooks directly (.claude/hooks/foo.sh), so they must be
# executable. git does not always carry the bit and cp does not always preserve
# it, so set it explicitly on the target (even for files that were skipped).
if ! $DRY_RUN; then
  find "$TARGET/.claude/hooks" "$TARGET/.claude/scripts" -name '*.sh' -type f \
    -exec chmod +x {} + 2>/dev/null || true
fi

# --- Summary ---
log ""
log "Done. Copied $copied, skipped $skipped (already present)."
log ""
log "Next steps:"
log "  1. Personalize AGENTS.md (project name, tech stack, commands, structure)"
log "  2. Update the project name at the top of CLAUDE.md"
log "  3. In Claude Code, run:  /skill analyze-codebase"
log "  4. Review generated docs for TODO markers, then commit the baseline"
if $DRY_RUN; then log ""; log "(dry run: nothing was written)"; fi
