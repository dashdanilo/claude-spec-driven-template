# .claude/scripts/

Utility scripts used by hooks, skills, and subagents. Not directly invoked by the user.

## Contents

- **`check-snapshot.sh`** - Compares the current git HEAD against the Repomix snapshot metadata and classifies staleness. Returns JSON. Called by the `SessionStart` hook and by the `codebase-explorer` subagent.
- **`spec-worktree.sh`** - Creates and manages one git worktree per feature (`../<repo>.<slug>`, branch from `main`), provisioning gitignored local files (symlinks config, copy-seeds the snapshot). Supports `--list`, `--remove <slug>`, `--prune`. Prints the worktree path on stdout; human messages on stderr. Used by the `spec-worktree` skill and runnable directly.
- **`check-index.sh`** - Warns when `CLAUDE.md` has drifted from the actual `.claude/` machinery (an agent, skill, rule, or command exists on disk but is not listed). Informational, always exits 0. Wired on `SessionStart`; also runnable directly.

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
