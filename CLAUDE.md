# Project name (Claude Code)

> **Read [`AGENTS.md`](./AGENTS.md) first.** It is the source of truth for project context (tech stack, commands, structure, conventions, workflow, and non-negotiables). The content below is only what is specific to Claude Code and would not apply to other agents.

## Claude Code specific: what this project ships

### Skills available

The skills in `baseline/skills/` are workflows Claude Code auto-invokes based on their descriptions. Linked into a project with `./install-harness.sh` (opt-in, per repo), they land in that project's `.claude/skills/`:

- `analyze-codebase` - one-time setup when adopting the template on an existing project
- `refresh-snapshot` - manually regenerates the Repomix snapshot
- `explore` - free-form investigation before writing a spec
- `grilling` - relentless one-question-at-a-time interview that walks a decision tree to lock open decisions; called by `explore` for decision rigor (MIT, adapted from [mattpocock/skills](https://github.com/mattpocock/skills))
- `find-existing-first` - reuse before create, invoked before any new file
- `write-spec` - persists a shaped idea as `specs/YYYY-MM-DD-<slug>/` with `spec.md` filled and `plan.md`/`tasks.md` scaffolded
- `spec-worktree` - one git worktree per feature (`../<repo>.<slug>`, branch from `main`); wraps `.claude/scripts/spec-worktree.sh`
- `verify-before-done` - runs the repo's own verification (install, codegen, typecheck, build, tests) and confirms green before claiming done; the gate for automated loops (stack-agnostic)
- `skill-architect` - guided workflow to author a new skill or agent the way this repo does it (CC-BY-4.0, adapted from [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills))
- `devils-advocate` - stress-tests a spec/plan/decision before committing (devil's advocacy, pre-mortem, red-team) (CC-BY-4.0, adapted from [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills))
- `diagnosing-bugs` - disciplined diagnosis loop for hard bugs and perf regressions; the gate is a tight, red-capable feedback loop before any hypothesis (MIT, adapted from [mattpocock/skills](https://github.com/mattpocock/skills))
- `documenting-domains` - creates durable local domain documentation (nested CLAUDE.md files) after a feature ships (attribution: [douglasgomes98](https://github.com/douglasgomes98))
- `skill-best-practices` - authoring standards for skills (frontmatter, progressive disclosure, descriptions)

> Stack-specific skills (e.g. React SPA conventions) are **not** part of the baseline — they come from a stack plugin in the [njord marketplace](https://github.com/njord-app/marketplace), installed per project (`/plugin install frontend-react@njord`).

### Subagents available

The subagents in `baseline/agents/` run in isolated context windows:

- `codebase-explorer` - read-only archaeology; uses the Repomix snapshot, refreshes when stale-major
- `spec-reviewer` - mandatory audit of `spec.md` before it becomes a plan (`write-spec` runs it automatically)
- `code-reviewer` - reviews implementation against spec, plan, tasks and conventions; auto-gates each phase (has persistent memory)
- `reviewer` - portable staff-level review of a whole diff/branch; runs the repo's verification and can open the PR (adapts to any stack)
- `tester` - portable; writes and runs tests using the repo's own framework, discovered from AGENTS.md/tooling
- `researcher` - deep-dives on libs and APIs (persistent memory across projects)
- `security-auditor` - audits auth, secrets, input validation

### Drivers (also skills)

These are skills too — `baseline/skills/<name>/SKILL.md` — but they *drive* a multi-step flow in the main thread rather than teaching one thing. A command file and a skill produce the same `/name`, so they are authored as skills and nothing depends on a personal `commands/` path:

- `orchestrate` - drives a spec's `tasks.md` to completion: reconciles the boxes against the code, classifies each task to select its gates, plans waves, gets approval, then executes **one wave at a time** (whole wave dispatched in a single message, collected, gated once with `verify-before-done` plus the reviewers that wave needs), and opens a PR; halts for a human on anything ambiguous. Portable (stack specialists come from a plugin). See `docs/workflows/feature-pipeline.md`.
- `wave` - the low-ceremony half of `orchestrate`: dispatches **one** batch of independent tasks to specialists in parallel (single message = concurrent), gates once, reports, stops. No spec, no approval table, no PR. Use when `orchestrate` is more process than the work deserves.
- `handover` - compact, high-signal session handover (done / current state / open decisions / not started) so a fresh session continues without re-deriving context. **State, not instructions** — it describes what is true, never what to do next, because a fact outlives an instruction. **Reconciles `tasks.md` against reality before writing the narrative, prints a copyable block, and ends with an explicit cut** — state is on disk, clear the session and resume in a fresh one
- `checkpoint` - safe-save: runs `verify-before-done`, then commits the work on the feature branch (never on a red gate)
- `status` - read-only project health card: active spec/phase, unchecked tasks, gate status, branch, snapshot staleness
- `harness-report` - read-only report on the **harness itself**: how much implementation is actually delegated, how dispatches are distributed, how many are unattributed — judged against `.claude/docs/harness-baseline.md`. Answers "is this being used the way it is designed", which a rule cannot answer about itself

### Hooks registered

For this repo, in `.claude/settings.json`. For a project that linked the harness, `./install-harness.sh` registers the portable ones in that project's gitignored `.claude/settings.local.json`, pointing at absolute paths in this checkout — the repo's committed `settings.json` is never touched. `protect-critical.sh` and `check-snapshot-on-session.sh` are **deliberately excluded** from the global set: the first knows about lockfiles and migrations, the second about a per-repo snapshot, so both belong to a repo and not to a machine.

- `PreToolUse` on Bash: `block-secrets.sh` blocks commands that would read `.env` or print secret-named env vars
- `PreToolUse` on Bash: `protect-main.sh` blocks commits, pushes, merges on protected branches (main, master, etc)
- `PreToolUse` on Edit/Write: `protect-critical.sh` blocks modifications to lockfiles, applied migrations, generated code, and other critical files
- `PreToolUse` on Edit/Write: `log-edit.sh` appends one line per file edit to the gitignored `.claude/tool-log.txt`, recording **which thread** did it (main or specialist) — the raw material for `/harness-report`. Never blocks
- `SessionStart`: `check-snapshot-on-session.sh` warns if the Repomix snapshot is stale-major
- `SessionStart`: `check-index.sh` warns when `CLAUDE.md` and the machinery (`baseline/`, `.claude/`, and `~/.claude/` for names only) have drifted apart — not listed, listed but gone, or malformed (bad frontmatter, name/filename mismatch, hook without `+x`). `--strict` exits 1 for CI
- `SessionStart`: `check-baseline.sh` warns when your harness checkout is behind its remote, or has **uncommitted** edits under `baseline/` — those are live in every project on the machine, unreviewed. Does not fetch and does not pin
- `SubagentStop`: `log-agent.sh` appends one audit line per subagent run to the gitignored `.claude/agent-log.txt` — agent type, task description, tokens, duration and tool count, recovered from the subagent's own transcript when the hook payload omits them

### Rules with path scope

The files in `baseline/rules/` auto-load based on their `paths:` glob, and land in `.claude/rules/harness/` when linked into a project — rules are discovered recursively, so the repo's own rules coexist. **Project rules win over personal ones**, so a repo can always override. Five ship with the template:

- `delegation.md` (matches `**`, always loaded) - the main thread coordinates, specialists implement; never write feature code from the main thread
- `specs.md` (matches `specs/**`) - claims are verified against code/git when written, never copied from existing prose; a hand-written spec still goes through `spec-reviewer`
- `git-workflow.md` (matches `**`, always loaded) - branch naming, Conventional Commits, PR conventions
- `adr.md` (matches `docs/decisions/**`) - Architecture Decision Records are append-only; supersede, don't rewrite
- `example-rule.md` - template rule showing the pattern for path-scoped conventions

See `baseline/rules/example-rule.md` for the anatomy.

### AI-only knowledge

Documentation consulted only by agents (not humans) lives in `baseline/docs/`:

- `superpowers.md` - how the spec-driven flow integrates with the Superpowers plugin
- `context-engineering.md` - context discipline every agent should follow (return conclusions not raw material, isolate bulky work in subagents, externalize state, continue agents instead of re-dispatching)
- `dispatching.md` - how to dispatch: the six topology shapes (pipeline, fan-out/fan-in, expert pool, producer-reviewer, supervisor, hierarchical) and how to run each with sub-agents; then the mechanics - parallel means one message with several agent calls; background only for long work collected this turn; never background a gate; concurrency ceiling; agent memory
- `harness-baseline.md` - the measured numbers the harness is judged against (delegation 29%, main-thread token share 71%, 1.0 dispatches per message, from 22 sessions and 54 dispatches on a real project), plus what each correction claims and which number would confirm it. Read by `harness-report`
- `libs/` - how this project uses each external library (endpoints, gotchas, project-specific patterns)

For human-facing docs (architecture, ADRs, runbooks, guides, patterns), see `docs/`.

## Nested CLAUDE.md files

Some folders under `src/` have their own `CLAUDE.md` with conventions specific to that folder. They auto-load only when Claude works inside that folder. See `src/example-module/CLAUDE.md` for the pattern.

## Personal preferences

Personal overrides go in `CLAUDE.local.md` (gitignored). See `CLAUDE.local.md.example` for the format.
