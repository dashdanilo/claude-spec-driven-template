# Changelog

All notable changes to this template are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

**Delegation and dispatch discipline** — from telemetry on a real project running this template (22 sessions, 54 subagent dispatches):
- `.claude/rules/delegation.md` (always loaded) — the main thread coordinates, specialists implement. The rule previously existed only inside `/orchestrate`, a command that ran twice in 729 prompts; meanwhile 71% of `Edit` calls happened in the main thread while `Grep`/`Glob` were 100% delegated. Also added to `AGENTS.md` non-negotiables.
- `.claude/docs/dispatching.md` — opens with the **six topology shapes** (pipeline, fan-out/fan-in, expert pool, producer-reviewer, supervisor, hierarchical delegation): what each fits, what to watch for, and how to run each with sub-agents, since picking the wrong shape costs more than any mechanic recovers. Catalogue adapted from [revfactory/harness](https://github.com/revfactory/harness) (Apache-2.0). Then the mechanics: parallel means several agent calls **in one message** (measured: 54 of 54 dispatches went out one per message, so the wave plan never actually fanned out); background only for long work collected in the same turn (measured: two dispatches collected 16 days after launch, across a suspended session); never background a gate; concurrency ceiling; diversity over redundancy; agent memory.
- `.claude/rules/specs.md` (`paths: specs/**`) — claims about the current state of the system are verified against code/git when written, never copied from existing prose; a hand-written spec still goes through `spec-reviewer`. Includes the cheapest check for a referenced "pending fix": a `git cherry-pick` that comes back **empty** means the content is already in your base, re-applied under a different PR number. Measured: a follow-ups spec was written from a three-week-old header claiming two tests were failing; they had been fixed and merged under another PR, and the block was ranked priority 1. The defense already existed (`write-spec` hands the spec to `spec-reviewer` to verify claims against the codebase) and was skipped because the spec was written by hand — a guard that only fires on the happy path is not a guard.
- `/wave` command — the low-ceremony half of `/orchestrate`: one batch of independent tasks, dispatched in parallel, gated once, then stop. No spec, no approval table, no PR.
- **`deviations.md`** — a fifth spec-folder artifact, created on demand, for where execution left the agreed plan: assumptions taken, blockers worked around, scope changed mid-flight, phases run straight from `plan.md` instead of as tasks. Distinct from `lessons.md`, which is about the system (*this broke, here is the fix*, promotable to a rule) where a deviation is about this feature's plan (*we agreed X and did Y*, resolved and closed, never promoted). Format and the four things that belong in it are in `.claude/rules/specs.md`; `/orchestrate` and `/wave` append as they go, `/status` lists open entries, `/handover` lifts every `needs decision` into open decisions. Measured: deviations with nowhere to go get narrated inside `tasks.md`, where prose competes with the checkboxes and the next wave plan ignores it — which is how a task file becomes a state dump. Concept adapted from [migoVanDingo/base-template](https://github.com/migoVanDingo/base-template).

**Baseline drift detection** — `.claude/scripts/check-baseline.sh` + `.claude/baseline.lock`:
- When the harness is delivered by symlink from a sibling repo, every consumer tracks that repo's working tree. That is the point (a fix is live everywhere with no update step) and it is the risk (a mistake is live everywhere with no staged rollout). This hook gives the missing half: on `SessionStart` it compares the shared repo's `HEAD` against the SHA this repo last verified, reports how far it moved and which consumed files changed, and offers `--accept`. Silent when there is no lock file, so a repo that does not consume a shared baseline is unaffected.
- **It does not pin, and says so.** Pinning would freeze a version, which is the property the symlink model trades away deliberately. This is detection: you always run the current baseline, and you are told when it moved past what you looked at.

### Changed

- `/orchestrate` — **Step 3 now executes one wave at a time instead of one task at a time.** The loop was written `for each task: dispatch → gate → review → tick → next`, which is a queue wearing a wave's name: it plans a fan-out in Step 1 and then serializes it in Step 3, paying full latency per task and delivering nothing the plan promised. Measured: 54 of 54 dispatches went out one per message, so no wave plan ever actually fanned out — and the old wording (*"may be dispatched in parallel (background)"*) both permitted the serial path and pointed at background, the mechanism that left two dispatches uncollected for 16 days. Now the whole wave goes out in **one message**, is collected as a barrier, and is gated **once in the foreground**, with the reviewers the wave's classes selected also dispatched together. Gating a batch costs attribution, so a red gate now requires attributing the failure against the files each specialist reported touching — and gating the suspect task alone rather than guessing when that is ambiguous. Waves must contain tasks that touch **disjoint files** (Step 1), which is what makes single-message dispatch safe. Invariant updated: boxes are ticked only on a fresh green gate covering that wave, and a task whose specialist came back short does not inherit a box from its wave-mates.
- `/orchestrate` — new **Step 0 (reconcile)** and a **class-to-gates matrix** in Step 1. Step 0 audits the unchecked tasks against the code and `git log` before any planning, reports the drift in both directions (unchecked-but-done, checked-but-absent) and halts to fix the file: measured, a shipped feature's `tasks.md` sat at 78 open / 12 done and had been copied into three worktrees, so a wave plan would have dispatched a specialist per finished task. Step 1 now classifies each task (schema, logic, API, UI, tests, chore, docs) and selects only the gates that class needs, instead of running `tester` + `code-reviewer` + docs on everything — that uniform ceremony is why the command ran twice in 729 prompts. The build gate never gets skipped, the stricter row wins on ambiguity, and a task whose diff outgrew its class is re-classified before the box is checked. Phase-0 audit and the phase-selection matrix adapted from [revfactory/harness](https://github.com/revfactory/harness) (Apache-2.0).
- `/handover` — now built on **state, not instructions**: it describes what *is true*, never what the next agent *should do*. The `Next steps — the concrete next 1-3 actions` section is gone, replaced by `Current state` and `Not started`; the single forward-looking sentence lives in the closing cut, where it is cheap to discard when wrong. An instruction written now ages worse than a fact — *"implement logout next"* is wrong the moment priorities change, while *"logout is not started"* stays true until someone touches it. Three independent sources converged on this (`davidondrej/skills`, the `_features/` rule in `migoVanDingo/base-template`, and this command's own Step 0), and the command was violating it while teaching it. Also added: **reference, don't duplicate** (stronger than the old "don't paste diffs" — it also rules out restating an ADR's reasoning or a spec's requirements, which creates a second copy that drifts), **frame claims as claims** (mark anything not verified this session as unverified; `.claude/rules/specs.md` applies to a handover too), and the handover is now **printed as a single fenced block** in chat as well as written to the file, since the block is what actually gets carried across the cut. The closing cut template was in Portuguese in an otherwise English template; it is now English. Principles adapted from [davidondrej/skills](https://github.com/davidondrej/skills).
- `/handover` — new **Step 0**: reconcile `tasks.md` against reality before writing the narrative, and check `lessons.md` for a class of failure worth promoting to a rule. Prose and checkboxes are two states of the same file and only one is machine-readable; a handover written over stale boxes documents a fiction that the next wave plan then executes. New **last step**: end with an explicit cut (state is on disk → `/clear` → resume with `/status`) and stop, instead of rolling into the next task. Measured: 19 sessions, several past 400 hours, 8 handovers written and **zero** `/clear` — the note was being written and the session rolled on anyway. Cache makes a long window cheap, not good.
- `/status` — now flags a task count it does not believe, permanently-red gates, promotable lessons, and uncollected background agents.
- `.claude/docs/context-engineering.md` — two additions: continue a live agent instead of re-dispatching it for a second pass on the same artifact (measured: three fresh dispatches of the same spec review in 12 minutes, ~57k tokens each); and a declared `memory:` is not a used memory.
- `.claude/scripts/check-index.sh` — extended from one class of drift to three. It already caught *on disk but not indexed*; it now also catches **indexed but not on disk** (a bullet in `CLAUDE.md` whose skill/agent/command/rule no longer exists — the rename case: `the-fool` became `devils-advocate` and an index would happily keep advertising the old name) and **malformed machinery** (missing `name:`/`description:`/`paths:`, a frontmatter name that does not match the filename so dispatch-by-name silently misses, a skill directory with no `SKILL.md`, and a hook without `+x` — registered, never runs, reports nothing). New `--strict` flag exits 1 for CI; the default stays exit 0 so `SessionStart` is unaffected. Verified against fixtures for all three classes, including that uppercase (`PreToolUse`) and path-shaped (`libs/`) bullets do not produce false positives.
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
