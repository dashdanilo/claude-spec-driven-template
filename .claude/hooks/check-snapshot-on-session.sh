#!/usr/bin/env bash
# check-snapshot-on-session.sh
# SessionStart hook. Runs check-snapshot.sh and, if the snapshot is stale-major,
# prints a friendly warning. Never blocks the session.
#
# Registered in .claude/settings.json under hooks.SessionStart.

# If the check script does not exist, silently skip
if [[ ! -x ".claude/scripts/check-snapshot.sh" ]]; then
  exit 0
fi

# Run the check, capture output and exit code without exiting on error
verdict=$(.claude/scripts/check-snapshot.sh 2>/dev/null) || exit_code=$?
exit_code=${exit_code:-0}

# Exit code 2 = snapshot does not exist yet (first-time setup)
# Skip silently to avoid nagging users who haven't run analyze-codebase
if [[ $exit_code -eq 2 ]]; then
  exit 0
fi

# Parse status from JSON without jq (portable)
status=$(echo "$verdict" | grep -oE '"status": "[^"]+"' | head -1 | cut -d'"' -f4)

# Only warn on stale-major (silent on fresh, stale-mild, error)
if [[ "$status" == "stale-major" ]]; then
  commits_ahead=$(echo "$verdict" | grep -oE '"commits_ahead": [0-9]+' | grep -oE '[0-9]+' || echo "?")
  days_old=$(echo "$verdict" | grep -oE '"days_old": [0-9]+' | grep -oE '[0-9]+' || echo "?")
  config_changed=$(echo "$verdict" | grep -oE '"config_changed": (true|false)' | awk '{print $2}')

  echo "" >&2
  echo "⚠  Repomix snapshot is stale (${commits_ahead} commits behind, ${days_old} days old)" >&2
  if [[ "$config_changed" == "true" ]]; then
    echo "   Config files changed since the snapshot was taken." >&2
  fi
  echo "   The codebase-explorer subagent will refresh it automatically on next use." >&2
  echo "   To refresh now: /skill refresh-snapshot" >&2
  echo "" >&2
fi

exit 0
