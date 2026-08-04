# .claude/scripts/

Utility scripts used by hooks, skills, and subagents. Not directly invoked by the user.

## Contents

- **`check-snapshot.sh`** - Compares the current git HEAD against the Repomix snapshot metadata and classifies staleness. Returns JSON. Called by the `SessionStart` hook and by the `codebase-explorer` subagent.
- **`spec-worktree.sh`** - Creates and manages one git worktree per feature (`../<repo>.<slug>`, branch from `main`), provisioning gitignored local files (symlinks config, copy-seeds the snapshot). Supports `--list`, `--remove <slug>`, `--prune`. Prints the worktree path on stdout; human messages on stderr. Used by the `spec-worktree` skill and runnable directly.
- **`check-index.sh`** - Warns on three classes of drift between `CLAUDE.md` and the `.claude/` machinery: **on disk but not indexed** (you added one and forgot to list it), **indexed but not on disk** (you renamed or deleted one and the index still advertises it), and **malformed** (missing `name:`/`description:`/`paths:`, a frontmatter name that does not match the filename, a skill directory with no `SKILL.md`, a hook without `+x`). Informational by default, always exits 0 — wired on `SessionStart`. Pass `--strict` to exit 1 when anything is found, for CI.

- **`harness-report.sh`** - Reads `.claude/tool-log.txt` and `.claude/agent-log.txt` and prints how much implementation is delegated, the dispatch mix, and how many dispatches are unattributed. `--json` for machine output. Always exits 0 — it measures, it does not gate. Used by the `harness-report` command.
- **`check-baseline.sh`** - Warns when the shared harness moved since this repo last verified it. Reads `.claude/baseline.lock` (`source` = path to the shared repo, `sha` = last verified commit); no lock file means the repo does not consume a shared baseline and it exits silently. Reports how far it moved and which consumed files changed; `--accept` records the current SHA. **It does not pin** — it detects. Informational, always exits 0. Wired on `SessionStart`.

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
