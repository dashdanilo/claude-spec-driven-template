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
- `verify-before-done` - runs the repo's own verification (install, codegen, typecheck, build, tests) and confirms green before claiming done; the gate for automated loops (stack-agnostic)
- `skill-architect` - guided workflow to author a new skill or agent the way this repo does it (CC-BY-4.0, adapted from [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills))
- `the-fool` - stress-tests a spec/plan/decision before committing (devil's advocacy, pre-mortem, red-team) (CC-BY-4.0, adapted from [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills))
- `documenting-domains` - creates durable local domain documentation (nested CLAUDE.md files) after a feature ships (attribution: [douglasgomes98](https://github.com/douglasgomes98))
- `skill-best-practices` - authoring standards for skills (frontmatter, progressive disclosure, descriptions)

> Stack-specific skills (e.g. React SPA conventions) are **not** part of the baseline — they come from a stack plugin in the [njord marketplace](https://github.com/njord-app/marketplace), installed per project (`/plugin install frontend-react@njord`).

### Subagents available

The subagents in `.claude/agents/` run in isolated context windows:

- `codebase-explorer` - read-only archaeology; uses the Repomix snapshot, refreshes when stale-major
- `spec-reviewer` - mandatory audit of `spec.md` before it becomes a plan (`write-spec` runs it automatically)
- `code-reviewer` - reviews implementation against spec, plan, tasks and conventions; auto-gates each phase (has persistent memory)
- `reviewer` - portable staff-level review of a whole diff/branch; runs the repo's verification and can open the PR (adapts to any stack)
- `tester` - portable; writes and runs tests using the repo's own framework, discovered from AGENTS.md/tooling
- `researcher` - deep-dives on libs and APIs (persistent memory across projects)
- `security-auditor` - audits auth, secrets, input validation

### Commands available

Slash commands in `.claude/commands/` are drivers that orchestrate a multi-step flow in the main thread:

- `orchestrate` - drives a spec's `tasks.md` to completion: plans waves, gets approval, dispatches specialists, gates each task with `verify-before-done`, runs `tester`/`code-reviewer`, opens a PR; halts for a human on anything ambiguous. Portable (stack specialists come from a plugin). See `docs/workflows/feature-pipeline.md`.
- `handover` - compact, high-signal session handover (done / in-progress / open decisions / next steps) so a fresh session continues without re-deriving context
- `checkpoint` - safe-save: runs `verify-before-done`, then commits the work on the feature branch (never on a red gate)
- `status` - read-only project health card: active spec/phase, unchecked tasks, gate status, branch, snapshot staleness

### Hooks registered

Configured in `.claude/settings.json`:

- `PreToolUse` on Bash: `block-secrets.sh` blocks commands that would read `.env` or print secret-named env vars
- `PreToolUse` on Bash: `protect-main.sh` blocks commits, pushes, merges on protected branches (main, master, etc)
- `PreToolUse` on Edit/Write: `protect-critical.sh` blocks modifications to lockfiles, applied migrations, generated code, and other critical files
- `SessionStart`: `check-snapshot-on-session.sh` warns if the Repomix snapshot is stale-major
- `SessionStart`: `check-index.sh` warns when `CLAUDE.md` has drifted from the `.claude/` machinery (a skill/agent/rule exists but is not listed)
- `SubagentStop`: `log-agent.sh` appends one audit line per subagent run to the gitignored `.claude/agent-log.txt`

### Rules with path scope

The files in `.claude/rules/` auto-load based on their `paths:` glob. Three ship with the template:

- `git-workflow.md` (matches `**`, always loaded) - branch naming, Conventional Commits, PR conventions
- `adr.md` (matches `docs/decisions/**`) - Architecture Decision Records are append-only; supersede, don't rewrite
- `example-rule.md` - template rule showing the pattern for path-scoped conventions

See `.claude/rules/example-rule.md` for the anatomy.

### AI-only knowledge

Documentation consulted only by agents (not humans) lives in `.claude/docs/`:

- `superpowers.md` - how the spec-driven flow integrates with the Superpowers plugin
- `context-engineering.md` - context discipline every agent should follow (return conclusions not raw material, isolate bulky work in subagents, externalize state)
- `libs/` - how this project uses each external library (endpoints, gotchas, project-specific patterns)

For human-facing docs (architecture, ADRs, runbooks, guides, patterns), see `docs/`.

## Nested CLAUDE.md files

Some folders under `src/` have their own `CLAUDE.md` with conventions specific to that folder. They auto-load only when Claude works inside that folder. See `src/example-module/CLAUDE.md` for the pattern.

## Personal preferences

Personal overrides go in `CLAUDE.local.md` (gitignored). See `CLAUDE.local.md.example` for the format.
