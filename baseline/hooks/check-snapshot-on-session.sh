#!/usr/bin/env bash
# check-snapshot-on-session.sh
# SessionStart hook. Runs check-snapshot.sh and, if a Repomix snapshot exists
# and is over its size budget, warns that it is not context.
#
# The snapshot is a manual, opt-in export now (see the refresh-snapshot
# skill) - nothing generates it automatically and nothing reads it
# automatically, so its staleness is nobody's problem until a human decides
# to open it, at which point refreshing it is one command away. Its *size*
# is the thing worth a proactive warning: a multi-megabyte file sitting in
# .claude/context/ looks like it might be useful panoramic context and is
# not, and nothing else in the session would tell you that. Silent
# otherwise, including when no snapshot exists at all - most repos won't
# have one, by design.
#
# Registered in .claude/settings.json under hooks.SessionStart.

# If the check script does not exist, silently skip
if [[ ! -x ".claude/scripts/check-snapshot.sh" ]]; then
  exit 0
fi

# Run the check, capture output and exit code without exiting on error
verdict=$(.claude/scripts/check-snapshot.sh 2>/dev/null) || exit_code=$?
exit_code=${exit_code:-0}

# Exit code 2 = no snapshot on disk. The common case - stay silent.
if [[ $exit_code -eq 2 ]]; then
  exit 0
fi

# Parse status from JSON without jq (portable)
status=$(echo "$verdict" | grep -oE '"status": "[^"]+"' | head -1 | cut -d'"' -f4)

# Only warn on too-large (silent on fresh, stale-mild, stale-major, error -
# staleness of an artifact nothing auto-reads is not worth a session-start nag)
if [[ "$status" == "too-large" ]]; then
  size_bytes=$(echo "$verdict" | grep -oE '"size_bytes": [0-9]+' | grep -oE '[0-9]+' || echo "?")
  budget_bytes=$(echo "$verdict" | grep -oE '"budget_bytes": [0-9]+' | grep -oE '[0-9]+' || echo "?")

  echo "" >&2
  echo "⚠  Repomix snapshot (.claude/context/repomix-snapshot.md) is ${size_bytes} bytes, over the ${budget_bytes}-byte budget." >&2
  echo "   This is not context - do not read it whole. It is a manual grep/paste target for tools with no filesystem access." >&2
  echo "   For panoramic questions, use the repo map instead: .claude/scripts/harness/repo-map.sh" >&2
  echo "   Delete it if you don't need it: rm .claude/context/repomix-snapshot.md" >&2
  echo "" >&2
fi

exit 0
