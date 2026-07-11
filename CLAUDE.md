# Project name (Claude Code)

> **Read [`AGENTS.md`](./AGENTS.md) first.** It is the source of truth for project context (tech stack, commands, structure, conventions, workflow, and non-negotiables). The content below is only what is specific to Claude Code and would not apply to other agents.

## Claude Code specific: what this project ships

### Skills available

The skills in `.claude/skills/` are workflows Claude Code auto-invokes based on their descriptions:

- `analyze-codebase` - one-time setup when adopting the template on an existing project
- `refresh-snapshot` - manually regenerates the Repomix snapshot
- `explore` - free-form investigation before writing a spec
- `find-existing-first` - reuse before create, invoked before any new file
- `write-spec` - persists a shaped idea as `specs/YYYY-MM-DD-<slug>/` with `spec.md` filled and `plan.md`/`tasks.md` scaffolded
- `spec-worktree` - one git worktree per feature (`../<repo>.<slug>`, branch from `main`); wraps `.claude/scripts/spec-worktree.sh`
- `documenting-domains` - creates durable local domain documentation (nested CLAUDE.md files) after a feature ships (attribution: [douglasgomes98](https://github.com/douglasgomes98))

### Subagents available

The subagents in `.claude/agents/` run in isolated context windows:

- `codebase-explorer` - read-only archaeology; uses the Repomix snapshot, refreshes when stale-major
- `spec-reviewer` - mandatory audit of `spec.md` before it becomes a plan (`write-spec` runs it automatically)
- `code-reviewer` - reviews implementation against spec, plan, tasks and conventions (has persistent memory)
- `researcher` - deep-dives on libs and APIs (persistent memory across projects)
- `security-auditor` - audits auth, secrets, input validation

### Hooks registered

Configured in `.claude/settings.json`:

- `PreToolUse` on Bash: `block-secrets.sh` blocks commands that would read `.env` or print secret-named env vars
- `PreToolUse` on Bash: `protect-main.sh` blocks commits, pushes, merges on protected branches (main, master, etc)
- `PreToolUse` on Edit/Write: `protect-critical.sh` blocks modifications to lockfiles, applied migrations, generated code, and other critical files
- `SessionStart`: `check-snapshot-on-session.sh` warns if the Repomix snapshot is stale-major

### Rules with path scope

The files in `.claude/rules/` auto-load based on their `paths:` glob. Two ship with the template:

- `git-workflow.md` (matches `**`, always loaded) - branch naming, Conventional Commits, PR conventions
- `example-rule.md` - template rule showing the pattern for path-scoped conventions

See `.claude/rules/example-rule.md` for the anatomy.

### AI-only knowledge

Documentation consulted only by agents (not humans) lives in `.claude/docs/`:

- `superpowers.md` - how the spec-driven flow integrates with the Superpowers plugin
- `libs/` - how this project uses each external library (endpoints, gotchas, project-specific patterns)

For human-facing docs (architecture, ADRs, runbooks, guides, patterns), see `docs/`.

## Nested CLAUDE.md files

Some folders under `src/` have their own `CLAUDE.md` with conventions specific to that folder. They auto-load only when Claude works inside that folder. See `src/example-module/CLAUDE.md` for the pattern.

## Personal preferences

Personal overrides go in `CLAUDE.local.md` (gitignored). See `CLAUDE.local.md.example` for the format.
