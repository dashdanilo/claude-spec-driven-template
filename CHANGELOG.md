# Changelog

All notable changes to this template are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

**Delegation and dispatch discipline** — from telemetry on a real project running this template (22 sessions, 54 subagent dispatches):
- `.claude/rules/delegation.md` (always loaded) — the main thread coordinates, specialists implement. The rule previously existed only inside `/orchestrate`, a command that ran twice in 729 prompts; meanwhile 71% of `Edit` calls happened in the main thread while `Grep`/`Glob` were 100% delegated. Also added to `AGENTS.md` non-negotiables.
- `.claude/docs/dispatching.md` — opens with the **six topology shapes** (pipeline, fan-out/fan-in, expert pool, producer-reviewer, supervisor, hierarchical delegation): what each fits, what to watch for, and how to run each with sub-agents, since picking the wrong shape costs more than any mechanic recovers. Catalogue adapted from [revfactory/harness](https://github.com/revfactory/harness) (Apache-2.0). Then the mechanics: parallel means several agent calls **in one message** (measured: 54 of 54 dispatches went out one per message, so the wave plan never actually fanned out); background only for long work collected in the same turn (measured: two dispatches collected 16 days after launch, across a suspended session); never background a gate; concurrency ceiling; diversity over redundancy; agent memory.
- `/wave` command — the low-ceremony half of `/orchestrate`: one batch of independent tasks, dispatched in parallel, gated once, then stop. No spec, no approval table, no PR.

### Changed

- `/handover` — new **Step 0**: reconcile `tasks.md` against reality before writing the narrative, and check `lessons.md` for a class of failure worth promoting to a rule. Prose and checkboxes are two states of the same file and only one is machine-readable; a handover written over stale boxes documents a fiction that the next wave plan then executes. New **last step**: end with an explicit cut (state is on disk → `/clear` → resume with `/status`) and stop, instead of rolling into the next task. Measured: 19 sessions, several past 400 hours, 8 handovers written and **zero** `/clear` — the note was being written and the session rolled on anyway. Cache makes a long window cheap, not good.
- `/status` — now flags a task count it does not believe, permanently-red gates, promotable lessons, and uncollected background agents.
- `.claude/docs/context-engineering.md` — two additions: continue a live agent instead of re-dispatching it for a second pass on the same artifact (measured: three fresh dispatches of the same spec review in 12 minutes, ~57k tokens each); and a declared `memory:` is not a used memory.
- `.claude/hooks/log-agent.sh` — now logs agent type, description, tokens, duration and tool count by falling back to the subagent's own transcript. The `SubagentStop` payload omitted the agent type in 183 of 238 real events (77%), which made the log countable but not attributable.

## [0.1.0] - 2026-07-04

Initial release.

### Added

**Cross-tool foundation**
- `AGENTS.md` as the shared source of truth for any AI coding agent
- `CLAUDE.md` as a stub pointing to `AGENTS.md` plus Claude Code-specific extras
- `.github/copilot-instructions.md` as a stub for GitHub Copilot
- `CLAUDE.local.md.example` template for personal overrides
- `ECOSYSTEM.md` template for shared schemas

**Claude Code configuration**
- `.claude/settings.json` with permissions and hooks
- Six skills: `analyze-codebase`, `refresh-snapshot`, `explore`, `find-existing-first`, `write-spec`, `documenting-domains` (attribution: [douglasgomes98](https://github.com/douglasgomes98))
- Five subagents: `codebase-explorer`, `spec-reviewer`, `code-reviewer`, `researcher`, `security-auditor`
- Four hooks: `block-secrets.sh` (PreToolUse Bash), `protect-main.sh` (PreToolUse Bash), `protect-critical.sh` (PreToolUse Edit/Write), `check-snapshot-on-session.sh` (SessionStart)
- Path-scoped rules in `.claude/rules/`: `git-workflow.md` (branches, Conventional Commits, PRs) and `example-rule.md`
- AI-only knowledge in `.claude/docs/` (superpowers guide, external lib docs)

**Repomix integration for brownfield support**
- `.claude/scripts/check-snapshot.sh` staleness classifier (fresh, stale-mild, stale-major)
- `.claude/context/` folder for generated context with proper gitignore
- Auto-refresh in `codebase-explorer` when snapshot is stale-major
- SessionStart hook warns when snapshot is stale-major
- Configurable threshold (100 files) for generating snapshot

**Documentation**
- `README.md` centralized explanation with tree, layers, brownfield section, recommended ecosystem
- `LEARN.md` guided course with 12 chapters
- `CONTRIBUTING.md` with skill/agent/hook conventions and testing guidance
- `docs/` folder for human-facing docs:
  - `docs/README.md` layout guide
  - `docs/CONSTITUTION.md.example` template
  - `docs/architecture/overview.md` template
  - `docs/decisions/` with ADR template
  - `docs/runbooks/README.md`
  - `docs/guides/README.md`
  - `docs/guides/initial-setup.md` walkthrough for adopting the template
  - `docs/patterns/README.md`

**Spec-driven layer**
- `specs/YYYY-MM-DD-<slug>/` as the single canonical location for feature artifacts
- Three-file pattern aligned with Kiro, Spec Kit, and Junie conventions:
  - `spec.md` (WHAT + WHY, source of truth)
  - `plan.md` (HOW at high level: architecture, tech, phases)
  - `tasks.md` (HOW at execution level: atomic TDD checkboxes with inline Notes)
- `specs/README.md` explaining the pattern
- `specs/0000-example-feature/` with example `spec.md`, `plan.md`, and `tasks.md` templates

**Nested guidance**
- `src/example-module/CLAUDE.md` showing the nested CLAUDE.md pattern

**GitHub integration**
- Issue templates: bug report, feature request, question
- Pull request template
- `.gitignore` covering AI-generated context and personal overrides
- `.claudeignore` for context reduction

### Notes for future versions

This is a v0 release. The structure is stable but the following may change based on community feedback:

- Additional stubs for Gemini CLI (`GEMINI.md`) and Cursor (`.cursor/rules/`) are not yet included
- The Repomix threshold (100 files) is calibrated for typical web projects and may need adjusting for other domains
- Ponytail, OpenSpec, and Superpowers are recommended but not required; their integration patterns may evolve as those tools mature

[Unreleased]: https://github.com/dashdanilo/claude-spec-driven-template/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dashdanilo/claude-spec-driven-template/releases/tag/v0.1.0
