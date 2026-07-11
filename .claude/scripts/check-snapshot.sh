#!/usr/bin/env bash
# check-snapshot.sh
# Compares the current git HEAD against the metadata in the Repomix snapshot
# and classifies staleness. Returns JSON on stdout.
#
# Called by:
#   - .claude/hooks/check-snapshot-on-session.sh (SessionStart)
#   - .claude/agents/codebase-explorer.md (as first step of exploration)
#
# Exit codes:
#   0 - success (check stdout for JSON verdict)
#   2 - snapshot does not exist
#   3 - not a git repository or git error

set -euo pipefail

SNAPSHOT_PATH=".claude/context/repomix-snapshot.md"
CONFIG_PATH=".claude/context/config.json"

# Thresholds (defaults, can be overridden by config.json)
FRESH_MAX_FILES=4
FRESH_MAX_DAYS=2
STALE_MILD_MAX_FILES=29
STALE_MILD_MAX_DAYS=13
# Above these = stale-major

# Files whose changes signal convention drift and force stale-major
CONFIG_FILES_REGEX='(tsconfig|jsconfig|package\.json|pnpm-lock|yarn\.lock|\.eslintrc|biome|prettier|tailwind\.config|next\.config|vite\.config|astro\.config|remix\.config|nuxt\.config)'

# Check prerequisites
if [[ ! -f "$SNAPSHOT_PATH" ]]; then
  cat <<EOF
{
  "status": "missing",
  "recommendation": "generate",
  "message": "No snapshot exists. Run /skill analyze-codebase or /skill refresh-snapshot."
}
EOF
  exit 2
fi

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo '{"status": "error", "message": "Not a git repository"}'
  exit 3
fi

# Extract metadata from snapshot header
snapshot_commit=$(grep -m1 '^commit_sha:' "$SNAPSHOT_PATH" | awk '{print $2}' || echo "")
snapshot_date=$(grep -m1 '^generated_at:' "$SNAPSHOT_PATH" | awk '{print $2}' || echo "")

if [[ -z "$snapshot_commit" ]] || [[ -z "$snapshot_date" ]]; then
  echo '{"status": "error", "message": "Snapshot missing metadata header. Regenerate via /skill refresh-snapshot."}'
  exit 3
fi

# Verify snapshot commit exists in current repo
if ! git cat-file -e "$snapshot_commit" 2>/dev/null; then
  cat <<EOF
{
  "status": "stale-major",
  "recommendation": "refresh",
  "reason": "snapshot references a commit not found in this repo (rebase or force-push?)",
  "snapshot_commit": "$snapshot_commit"
}
EOF
  exit 0
fi

# Compute drift
commits_ahead=$(git rev-list --count "${snapshot_commit}..HEAD" 2>/dev/null || echo "0")
files_changed=$(git diff --name-only "$snapshot_commit" HEAD | wc -l | tr -d ' ')
config_changed="false"
if git diff --name-only "$snapshot_commit" HEAD | grep -qE "$CONFIG_FILES_REGEX"; then
  config_changed="true"
fi

# Compute age in days
if [[ "$(uname)" == "Darwin" ]]; then
  # BSD date (macOS)
  snapshot_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$snapshot_date" "+%s" 2>/dev/null || echo "0")
else
  # GNU date (Linux)
  snapshot_epoch=$(date -d "$snapshot_date" "+%s" 2>/dev/null || echo "0")
fi
now_epoch=$(date "+%s")
days_old=$(( (now_epoch - snapshot_epoch) / 86400 ))

# Classify
if [[ "$config_changed" == "true" ]] \
   || (( files_changed >= (STALE_MILD_MAX_FILES + 1) )) \
   || (( days_old >= (STALE_MILD_MAX_DAYS + 1) )); then
  status="stale-major"
  recommendation="refresh"
elif (( files_changed >= (FRESH_MAX_FILES + 1) )) \
     || (( days_old >= (FRESH_MAX_DAYS + 1) )); then
  status="stale-mild"
  recommendation="use-with-note"
else
  status="fresh"
  recommendation="use"
fi

cat <<EOF
{
  "status": "$status",
  "recommendation": "$recommendation",
  "snapshot_commit": "$snapshot_commit",
  "snapshot_date": "$snapshot_date",
  "commits_ahead": $commits_ahead,
  "files_changed": $files_changed,
  "days_old": $days_old,
  "config_changed": $config_changed
}
EOF
exit 0
