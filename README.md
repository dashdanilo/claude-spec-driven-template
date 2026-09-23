# claude-spec-driven-template

**A practical template repository for structuring AI-enabled projects**
**with shared instructions, Claude-specific configuration, subagents, skills, hooks, and spec-driven development.**

![Status](https://img.shields.io/badge/status-active-2563eb?style=for-the-badge)
![Type](https://img.shields.io/badge/type-template-111827?style=for-the-badge)
![Stack](https://img.shields.io/badge/stack-agnostic-0f766e?style=for-the-badge)
![Learn](https://img.shields.io/badge/learn-course-1d4ed8?style=for-the-badge)
![AGENTS.md](https://img.shields.io/badge/AGENTS.md-supported-5b21b6?style=for-the-badge)
![Claude](https://img.shields.io/badge/claude-configured-d97706?style=for-the-badge)
![Superpowers](https://img.shields.io/badge/superpowers-ready-0891b2?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-16a34a?style=for-the-badge)

---

## Overview

`claude-spec-driven-template` is a stack-agnostic template for structuring repositories around AI coding agents. It shows where each AI instruction file belongs, how the layers interact, and how to combine them with spec-driven development.

This is not just a folder tree. It is a working reference whose own AI setup is part of the lesson.

It combines:

- shared agent instructions in [`AGENTS.md`](./AGENTS.md)
- Claude-specific guidance in [`CLAUDE.md`](./CLAUDE.md)
- Copilot-specific guidance in [`.github/copilot-instructions.md`](./.github/copilot-instructions.md)
- shared schemas and contracts in [`ECOSYSTEM.md`](./ECOSYSTEM.md)
- contributor workflow in [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- change history in [`CHANGELOG.md`](./CHANGELOG.md)
- internal Claude config in [`.claude/`](./.claude/)
- human-facing project docs in [`docs/`](./docs)
- spec-driven features in [`specs/`](./specs)
- nested CLAUDE.md examples in [`src/`](./src)
- a guided course in [`LEARN.md`](./LEARN.md)
- setup walkthrough in [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md)

---

> **Adopting this on your own machine?** Start with [`ADOPTING.md`](./ADOPTING.md) (in Portuguese) — install, and which skill to reach for when. This file explains the structure; that one gets you running.

## Start here

| you want to | read |
|---|---|
| **install it and use it** | [`ADOPTING.md`](./ADOPTING.md) — the two commands, and which skill for which moment (pt-BR) |
| **understand the ideas** | [`LEARN.md`](./LEARN.md) — the guided course |
| **know where an instruction goes** | [`docs/reference/where-does-it-go.md`](./docs/reference/where-does-it-go.md) |
| **see how the layers fit** | [`docs/reference/layers.md`](./docs/reference/layers.md) |
| **adopt it on an existing codebase** | [`docs/guides/brownfield.md`](./docs/guides/brownfield.md) |
| **run the feature pipeline** | [`docs/workflows/feature-pipeline.md`](./docs/workflows/feature-pipeline.md) |

## What it is betting on

1. **Instruction files have distinct jobs.** Not everything belongs in `CLAUDE.md`.
2. **Context cost is the constraint.** What loads always must be small; what is detailed loads on demand.
3. **Specs are versioned beside the code** and are the source of truth when they disagree.
4. **Agents, skills, rules and hooks are different tools.** A hook runs whatever the model decides; a rule only persuades.
5. **A guard nobody can see failing decays.** So the harness measures itself — see [`baseline/docs/harness-baseline.md`](./baseline/docs/harness-baseline.md).

## Project structure

```
├─ baseline/          THE HARNESS — symlinked into projects, never committed
│  ├─ agents/           8 subagents (7 reviewers/explorers + implementer)
│  ├─ skills/          20 skills, a /name each, loaded on demand
│  ├─ rules/            path-scoped conventions, auto-loaded
│  ├─ hooks/            guardrails that run whatever the model decides
│  ├─ scripts/          check-index · check-baseline · spec-worktree · repo-map · check-snapshot
│  └─ docs/             AI-only: dispatching · context-engineering · harness-baseline
│
├─ .claude/           THIS repo's own config — links back into baseline/
├─ install-harness.sh Link the harness into a project you choose
├─ install.sh         Set up a project's own context (copied, committed)
│
├─ specs/             spec.md · plan.md · tasks.md · lessons.md · deviations.md
├─ docs/              human-facing: reference · guides · workflows · decisions
└─ src/example-module/CLAUDE.md   nested instructions, loaded per folder
```

**Two directories, two jobs.** `baseline/` is the harness — symlinked into the
projects you pick, never committed there. `.claude/` is this repository's own
configuration, which links back into `baseline/` so the harness can use itself.
A project that adopts it ends up with the same shape.

Every agent, skill, rule and hook is listed with its purpose in
[`CLAUDE.md`](./CLAUDE.md), which is also what `check-index.sh` validates on
every session start.

## Using this template

> **The fastest path is [`ADOPTING.md`](./ADOPTING.md)** — install it and know which
> skill to reach for. It is in Portuguese; this file explains the structure, that
> one gets you running.

### The two commands, and why there are two

```bash
git clone https://github.com/dashdanilo/claude-spec-driven-template ~/Sites/harness

cd ~/Sites/some-project
~/Sites/harness/install.sh           # the project's own CONTEXT — committed
~/Sites/harness/install-harness.sh   # the METHOD — symlinked, never committed
```

**Context** is what the repository owns and shares with its team: `AGENTS.md`,
`CLAUDE.md`, `docs/`, `specs/`, and the guards a teammate must have whether or
not they installed anything. It is copied, and it is different in every repo.

**Method** is how *you* work: the skills, agents and rules. It is symlinked from
your clone, so `git pull` there updates every project you linked, at once.
Skills and agents are linked one item at a time, so a skill or agent a repo
versions itself keeps loading next to the harness's; the cost is that one the
harness adds or renames needs the installer re-run, and the session-start check
names it. The
links go into `.git/info/exclude`, so a teammate cloning the repo sees nothing
and CI sees nothing — **opting in is invisible to everyone else, and opting out
costs nothing.**

On a platform that will not create symlinks (Git Bash on Windows without
Developer Mode), the installer copies instead, marks the copy and says so, and
the session-start check tells you when that copy has fallen behind.

`--adopt` sets aside a harness a repo already copied, `--unlink` puts it back,
`--status` says what is linked here.

Two more scripts, `script/setup` and `script/test`, are optional and yours to
write — the harness calls them when they exist (`spec-worktree` runs
`script/setup`, `verify-before-done` runs `script/test` as the gate) and is a
no-op without them. See [`docs/guides/script-setup-and-test.md`](./docs/guides/script-setup-and-test.md).

### Quick start

For a step-by-step walkthrough (both new projects and existing codebases), read [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md).

### Option 1: Use as a GitHub template

1. Click "Use this template" at the top of the GitHub page
2. Create your new repository
3. Follow [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md) Path 1 (New project)

### Option 2: Adopt on an existing project (brownfield)

Follow [`docs/guides/initial-setup.md`](./docs/guides/initial-setup.md) Path 2. Uses the `analyze-codebase` skill to generate a documentation baseline from your existing code.

### Option 3: Adopt incrementally

You do not need everything at once. Three adoption levels:

**Minimal:** copy `AGENTS.md`, `CLAUDE.md` (stub), `.gitignore`, `.claudeignore`. Start there.

**Practical:** add `.claude/settings.json`, `baseline/agents/code-reviewer.md`, and one or two skills. Add `specs/` when you have your first non-trivial feature.

**Full:** adopt the complete structure. Use this when you have a team and want consistent AI workflows across people.

### Option 4: Install Superpowers alongside

The spec-driven workflow in this template is compatible with the [Superpowers plugin](https://github.com/obra/superpowers):

```bash
# Inside Claude Code
/plugin install superpowers@claude-plugins-official
```

Superpowers ships brainstorming, writing-plans, subagent-driven-development, TDD, and code-review skills that enforce the spec-driven flow.

---

## Attributions

The template includes contributions from the broader Claude Code community:

- **[documenting-domains](baseline/skills/documenting-domains/SKILL.md)** skill by [douglasgomes98](https://github.com/douglasgomes98) - creates durable local domain documentation

Original attribution is preserved inline in each file. When you fork this template, keep the attribution intact if you keep the file.

## License

[MIT](./LICENSE)
