# .claude/scripts/

Utility scripts used by hooks, skills, and subagents. Not directly invoked by the user.

In a project that linked the harness (`install-harness.sh`), this whole directory
lands at `.claude/scripts/harness/` — except `check-snapshot.sh`, which
`install.sh` copies directly into `.claude/scripts/check-snapshot.sh` because it
is a per-repo guard, not harness method (see `install.sh`'s header).

## Contents

- **`repo-map.sh`** - Generates a small, deterministic map of the repo's shape (directory tree with per-directory file counts, entry points, test locations, the commands block from `AGENTS.md`) from `git ls-files`, so gitignored content is excluded for free. No caching, no staleness check - cheap enough (low thousands of tokens even on 1000+ file repos) to regenerate on every use instead. This is what `codebase-explorer` reads for panoramic context; see `docs/decisions/0003-repo-map-over-snapshot.md` for why it replaced the Repomix snapshot in that role.
- **`check-snapshot.sh`** - The Repomix snapshot (`.claude/context/repomix-snapshot.md`) is a separate, manual/opt-in export now (see the `refresh-snapshot` skill), never auto-generated or auto-read. This script classifies it when one exists on disk: a hard size-budget check first (`too-large` above 300,000 bytes, independent of staleness), then the original staleness classification. Returns JSON. Called by the `SessionStart` hook (warns only on `too-large`) and runnable manually.
- **`spec-worktree.sh`** - Creates and manages one git worktree per feature (`../<repo>.<slug>`, branch from the remote's default branch - `origin/HEAD`, falling back to `origin/main` then local `main`), provisioning gitignored local files (symlinks config, copy-seeds the snapshot). Supports `--list`, `--remove <slug>`, `--prune`. Prints the worktree path on stdout; human messages on stderr. Used by the `spec-worktree` skill and runnable directly.
- **`check-index.sh`** - Warns on three classes of drift between `CLAUDE.md` and the machinery. It scans `baseline/` and `.claude/` for things this repo owns, and `~/.claude/` for names only — a repo's index is not supposed to list your personal harness. Three classes: **on disk but not indexed** (you added one and forgot to list it), **indexed but not on disk** (you renamed or deleted one and the index still advertises it), and **malformed** (missing `name:`/`description:`/`paths:`, a frontmatter name that does not match the filename, a skill directory with no `SKILL.md`, a hook without `+x`). Informational by default, always exits 0 — wired on `SessionStart`. Pass `--strict` to exit 1 when anything is found, for CI.

- **`harness-report.sh`** - Reads `.claude/tool-log.txt` and `.claude/agent-log.txt` and prints how much implementation is delegated, the dispatch mix, and how many dispatches are unattributed. `--json` for machine output. Always exits 0 — it measures, it does not gate. Used by the `harness-report` command.
- **`verify-gate.py`** - Validates a `.claude/verification/*.md` evidence report (a `## Commands` section with exit codes, a `## Claims` section where every claim carries a `file:line` citation or a reference to a listed command) and exits 0 or 1. `--json` for machine output. Python 3 stdlib only, no dependencies. The contract is documented at the top of the file. Used by the `verify-before-done` skill's "Evidence or zero" step.
- **`check-baseline.sh`** - Warns on a **broken link** (the checkout was moved or deleted, so the linked skills/agents/rules resolve to nothing — Claude Code does not error on that, it just runs unarmed), and when your harness checkout is behind its remote or has uncommitted edits under `baseline/` — those are live in every project on the machine, unreviewed. Does not fetch (no network on session start) and does not pin. Silent outside a harness checkout. Always exits 0. Wired on `SessionStart`.
- **`env-set.sh`** - Upserts ONE key in a `.env`-style file without ever printing the file's contents: the value is read from STDIN, never an argument, so it never lands in argv, shell history, or an agent transcript. Pairs with a permission split an adopting repo makes in its own committed `.claude/settings.json` (not auto-registered like a hook): `Bash(.claude/scripts/harness/env-set.sh:*)` allowed, `Read(.env)` still denied. Backs up to `<file>.bak` before writing, but refuses the write if that backup path would not be gitignored in the caller's repo (a plaintext copy of a secrets file is not safe to leave where `git add -A` could pick it up) - override with `ENV_SET_ALLOW_UNIGNORED_BACKUP=1` once verified safe. Never truncates: refuses if the rewrite would end up with fewer logical lines than it started with. See the script's own header for the full guarantee list, and ADOPTING.md's "Scripts com permissão própria" for the adopting-repo walkthrough.

## Conventions

Most of these are already how the scripts above behave; this section names the convention so a new one follows it on purpose instead of by accident.

- All scripts must be executable (`chmod +x`)
- All scripts must exit 0 on success, non-zero on error
- All scripts that produce structured output must emit JSON on stdout
- Human-readable messages go to stderr
- Every error message says how to fix it, not just what went wrong (see `die()` in `spec-worktree.sh`, or the block messages in the hooks under `baseline/hooks/`). "invalid type" is not actionable; "invalid type 'x': must be one of feat fix hotfix refactor docs chore test" is.
- Exit codes are distinct and documented at the top of the script, because a caller (a hook, another script, CI) matches on the number, not the message. `spec-worktree.sh`'s header comment listing 0/1/2/3 and what each means is the model to follow; do not reuse the same code for two different failure classes.
- Terminal and pipe output can differ (colored, human-friendly text for a terminal; plain text or JSON when stdout is not a TTY): gate any ANSI codes on `[[ -t 1 ]]`, and additionally suppress them when `NO_COLOR` is set, per the [NO_COLOR](https://no-color.org/) convention (`[[ -n "${NO_COLOR:-}" ]]`). None of the current scripts color their output yet; the next one that does should check both.
- Anything destructive (deletes a worktree, rewrites a file in place, force-pushes) supports `--dry-run`, printing what it would do without doing it, and `--force` where skipping a safety check is a legitimate, deliberate choice. `spec-worktree.sh --remove` and `--prune` delete worktrees today without either flag; treat that as the gap to close, not the pattern to copy.

## Adding scripts here

Scripts belong here when they:

- Are shared logic used by multiple hooks, skills, or agents
- Contain non-trivial parsing or git operations
- Would be duplicated if inlined into every caller

Simple one-liners can stay inline in the hook or skill.
