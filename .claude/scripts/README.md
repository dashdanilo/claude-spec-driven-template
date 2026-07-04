# .claude/scripts/

Utility scripts used by hooks, skills, and subagents. Not directly invoked by the user.

## Contents

- **`check-snapshot.sh`** - Compares the current git HEAD against the Repomix snapshot metadata and classifies staleness. Returns JSON. Called by the `SessionStart` hook and by the `codebase-explorer` subagent.

## Conventions

- All scripts must be executable (`chmod +x`)
- All scripts must exit 0 on success, non-zero on error
- All scripts that produce structured output must emit JSON on stdout
- Human-readable messages go to stderr

## Adding scripts here

Scripts belong here when they:

- Are shared logic used by multiple hooks, skills, or agents
- Contain non-trivial parsing or git operations
- Would be duplicated if inlined into every caller

Simple one-liners can stay inline in the hook or skill.
