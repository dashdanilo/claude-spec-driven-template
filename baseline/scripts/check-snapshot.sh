#!/usr/bin/env bash
# check-snapshot.sh
# Repomix's `.claude/context/repomix-snapshot.md` is a manual, opt-in export
# (see the refresh-snapshot skill) — never auto-generated, never auto-read as
# context. It packs whole file contents, so unlike the repo map its size
# scales with the codebase, not with directory count, and on a real repo of a
# few hundred+ files it routinely lands in the megabytes, tens of times over
# any usable context budget. This script's first job is now that size
# budget: classify the snapshot "too-large" before anything else, so nothing
# downstream reads a multi-megabyte file on the assumption that "a snapshot
# exists" means "a snapshot fits." Staleness (the original job) is still
# reported, but only matters once the size check passes.
#
# Called by:
#   - .claude/hooks/check-snapshot-on-session.sh (SessionStart) — warns only
#     on too-large, since nothing auto-reads this file anymore and a
#     staleness nag about an artifact nobody reads is just noise
#   - manually, by anyone deciding whether to open the snapshot at all
#
# Returns JSON on stdout. Exit codes:
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

# Size budget: a single artifact should not eat a large slice of a 200k-token
# context window before an agent has done anything. 300000 bytes is
# ~75k tokens at the ~4-bytes/token estimate used throughout this repo's
# docs — generous headroom over the 20-50k tokens the harness originally
# assumed a snapshot would be, and still refused outright once past it.
SIZE_BUDGET_BYTES=300000

# Files whose changes signal convention drift and force stale-major
CONFIG_FILES_REGEX='(tsconfig|jsconfig|package\.json|pnpm-lock|yarn\.lock|\.eslintrc|biome|prettier|tailwind\.config|next\.config|vite\.config|astro\.config|remix\.config|nuxt\.config)'

# Check prerequisites
if [[ ! -f "$SNAPSHOT_PATH" ]]; then
  cat <<EOF
{
  "status": "missing",
  "recommendation": "generate",
  "message": "No snapshot exists. Run /skill refresh-snapshot if you specifically need one (e.g. to hand to a tool with no filesystem access) - the harness itself uses the repo map, not this, for panoramic context."
}
EOF
  exit 2
fi

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo '{"status": "error", "message": "Not a git repository"}'
  exit 3
fi

# Size budget check first - independent of staleness. A huge but fresh
# snapshot is exactly as unreadable as a huge stale one.
size_bytes=$(wc -c < "$SNAPSHOT_PATH" | tr -d ' ')
if (( size_bytes > SIZE_BUDGET_BYTES )); then
  approx_tokens=$(( size_bytes / 4 ))
  cat <<EOF
{
  "status": "too-large",
  "recommendation": "do-not-read-whole",
  "message": "Snapshot is ${size_bytes} bytes (~${approx_tokens} tokens), over the ${SIZE_BUDGET_BYTES}-byte budget. Do not read it as context. Grep it for a specific term if you must, or delete it and use the repo map + Grep/Glob instead.",
  "size_bytes": $size_bytes,
  "budget_bytes": $SIZE_BUDGET_BYTES
}
EOF
  exit 0
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
  "config_changed": $config_changed,
  "size_bytes": $size_bytes
}
EOF
exit 0
