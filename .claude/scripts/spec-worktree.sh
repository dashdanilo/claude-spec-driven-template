#!/usr/bin/env bash
# spec-worktree.sh
# Manages one git worktree per feature. A feature branch lives in its own
# sibling directory so multiple features (and their many plans) can be worked
# on in parallel without switching branches in the main checkout.
#
# Convention:
#   - Worktree path: <parent>/<repo>.<slug>   (flat sibling, dot separator)
#   - Branch:        <type>/<slug>            (always created from main)
#   - One worktree per FEATURE. Several specs/plans can share it.
#   - Worktrees are NOT removed on merge. Clean up later with --remove / --prune.
#
# On create, gitignored local files are provisioned into the new worktree:
#   - Symlinked (single source of truth): CLAUDE.local.md,
#     .claude/settings.local.json, .claude/context/config.json
#   - Copy-seeded (regenerable per-branch cache): .claude/context/repomix-snapshot.md
#
# Usage:
#   spec-worktree.sh <slug> [--type <type>]   Create worktree + branch from main
#   spec-worktree.sh --list                   List worktrees (git worktree list)
#   spec-worktree.sh --remove <slug>          Remove one worktree
#   spec-worktree.sh --prune                  Remove worktrees whose branch is merged
#   spec-worktree.sh --help                   Show this help
#
# The created worktree path is printed to stdout (last line) so a caller can:
#   cd "$(.claude/scripts/spec-worktree.sh add-dark-mode)"
# Human-readable progress goes to stderr.
#
# Exit codes:
#   0 - success
#   1 - usage error
#   2 - git error / precondition failed

set -euo pipefail

DEFAULT_TYPE="feature"
# Types accepted for the branch prefix (mirrors .claude/rules/git-workflow.md)
VALID_TYPES="feature fix hotfix refactor docs chore test"

log()  { echo "$@" >&2; }
die()  { echo "error: $*" >&2; exit "${2:-2}"; }

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit "${1:-0}"
}

# --- Resolve the MAIN working tree, even when invoked from a linked worktree ---
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  die "not a git repository" 2
fi

common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
if [[ -z "$common_dir" ]]; then
  # Fallback for older git without --path-format
  common_dir="$(cd "$(git rev-parse --show-toplevel)" && pwd)/.git"
fi
MAIN_ROOT=$(dirname "$common_dir")
REPO_NAME=$(basename "$MAIN_ROOT")
PARENT_DIR=$(dirname "$MAIN_ROOT")

# --- Pick the base branch (latest main) ---
base_ref() {
  git fetch origin --quiet 2>/dev/null || true
  if git rev-parse --verify --quiet origin/main > /dev/null; then
    echo "origin/main"
  elif git rev-parse --verify --quiet main > /dev/null; then
    echo "main"
  else
    die "no 'main' branch found (looked for origin/main and main)" 2
  fi
}

validate_slug() {
  local slug="$1"
  [[ -n "$slug" ]] || die "slug is required" 1
  if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    die "slug must be kebab-case (e.g. add-dark-mode), got: '$slug'" 1
  fi
}

worktree_path() { echo "${PARENT_DIR}/${REPO_NAME}.$1"; }

provision_locals() {
  # $1 = worktree path
  local wt="$1" f
  # Symlink personal config (single source of truth in the main checkout)
  for f in "CLAUDE.local.md" ".claude/settings.local.json" ".claude/context/config.json"; do
    if [[ -e "$MAIN_ROOT/$f" && ! -e "$wt/$f" ]]; then
      mkdir -p "$(dirname "$wt/$f")"
      ln -s "$MAIN_ROOT/$f" "$wt/$f"
      log "  linked  $f"
    fi
  done
  # Copy-seed the regenerable snapshot cache (do NOT symlink: it is per-branch
  # and gets rewritten when it goes stale; sharing it would corrupt main's copy)
  local snap=".claude/context/repomix-snapshot.md"
  if [[ -f "$MAIN_ROOT/$snap" && ! -e "$wt/$snap" ]]; then
    mkdir -p "$(dirname "$wt/$snap")"
    cp "$MAIN_ROOT/$snap" "$wt/$snap"
    log "  seeded  $snap"
  fi
}

cmd_create() {
  local slug="$1" type="$2"
  validate_slug "$slug"
  if [[ " $VALID_TYPES " != *" $type "* ]]; then
    die "invalid type '$type' (valid: $VALID_TYPES)" 1
  fi

  local branch="${type}/${slug}"
  local wt; wt=$(worktree_path "$slug")

  [[ ! -e "$wt" ]] || die "path already exists: $wt" 2
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    die "branch already exists: $branch (remove it or pick another slug)" 2
  fi

  local base; base=$(base_ref)
  log "Creating worktree for feature '$slug'"
  log "  branch  $branch"
  log "  base    $base"
  log "  path    $wt"
  git worktree add -b "$branch" "$wt" "$base" >&2

  provision_locals "$wt"

  log ""
  log "Done. Next:"
  log "  cd \"$wt\" && claude"
  # Machine-readable result on stdout
  echo "$wt"
}

cmd_list() {
  git worktree list
}

cmd_remove() {
  local slug="$1"
  validate_slug "$slug"
  local wt; wt=$(worktree_path "$slug")
  [[ -d "$wt" ]] || die "no worktree at $wt" 2
  log "Removing worktree $wt"
  if ! git worktree remove "$wt" 2>/dev/null; then
    die "worktree has uncommitted changes; rerun with 'git worktree remove --force $wt' if intended" 2
  fi
  git worktree prune
  log "Removed. Branch is kept; delete it manually if fully merged."
}

cmd_prune() {
  local base; base=$(base_ref)
  log "Pruning worktrees whose branch is merged into $base"
  local removed=0
  # Parse porcelain output: blocks separated by blank lines, keys 'worktree' and 'branch'
  local path="" branch=""
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) path="${line#worktree }" ;;
      branch\ *)   branch="${line#branch refs/heads/}" ;;
      "")
        if [[ -n "$path" && -n "$branch" && "$path" != "$MAIN_ROOT" ]]; then
          if git merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
            if git worktree remove "$path" 2>/dev/null; then
              log "  removed $path ($branch, merged)"
              removed=$((removed + 1))
            else
              log "  kept    $path ($branch, has local changes)"
            fi
          fi
        fi
        path=""; branch=""
        ;;
    esac
  done < <(git worktree list --porcelain; echo "")
  git worktree prune
  log "Prune complete. $removed worktree(s) removed."
}

# --- Dispatch ---
[[ $# -ge 1 ]] || usage 1

case "$1" in
  --help|-h) usage 0 ;;
  --list)    cmd_list ;;
  --remove)  shift; [[ $# -ge 1 ]] || die "--remove needs a slug" 1; cmd_remove "$1" ;;
  --prune)   cmd_prune ;;
  -*)        die "unknown option: $1" 1 ;;
  *)
    slug="$1"; shift
    type="$DEFAULT_TYPE"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --type) shift; [[ $# -ge 1 ]] || die "--type needs a value" 1; type="$1" ;;
        *)      die "unexpected argument: $1" 1 ;;
      esac
      shift
    done
    cmd_create "$slug" "$type"
    ;;
esac
