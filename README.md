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
- shared schemas and contracts in [`ECOSYSTEM.md`](./ECOSYSTEM.md)
- contributor workflow in [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- internal Claude config in [`.claude/`](./.claude)
- spec-driven features in [`specs/`](./specs)
- nested CLAUDE.md examples in [`src/`](./src)
- a guided course in [`LEARN.md`](./LEARN.md)

---

## Quick navigation

- [Who this is for](#who-this-is-for)
- [Learn this repo](#learn-this-repo)
- [Why this repo exists](#why-this-repo-exists)
- [How to read this repo](#how-to-read-this-repo)
- [How the AI layers connect](#how-the-ai-layers-connect)
- [Project structure](#project-structure)
- [Shared root layer](#shared-root-layer)
- [Internal Claude layer](#internal-claude-layer)
- [Spec-driven layer](#spec-driven-layer)
- [Nested instructions in src](#nested-instructions-in-src)
- [Decision table: where does this instruction go?](#decision-table-where-does-this-instruction-go)
- [What hooks are doing here](#what-hooks-are-doing-here)
- [What this repo is demonstrating](#what-this-repo-is-demonstrating)
- [Using this template](#using-this-template)

---

## Who this is for

- Developers building an AI-enabled repo from scratch
- Teams that want a cleaner Claude Code setup
- People learning what each AI-related file is for
- Maintainers who want internal AI helpers for review, structure, and documentation
- Anyone who wants a repo that is both a template and a teaching example

---

## Learn this repo

Want the guided version instead of just the structure?

Read [`LEARN.md`](./LEARN.md) for a short course that explains:

- what each AI layer is for
- a decision table for choosing where instructions go
- how the files relate to each other
- best practices for writing them
- templates you can copy
- the spec-driven workflow with Superpowers

---

## Why this repo exists

This repository answers questions like:

- What is `AGENTS.md` for? What about `CLAUDE.md`?
- What is the difference between rules, skills, agents, and hooks?
- Where do I put knowledge about external libs?
- How do I keep CLAUDE.md from becoming a 2000-line wiki?
- How do specs, plans, and code stay in sync?
- How do I build a repo that an AI agent can actually navigate?

This repo has three jobs at once:

- **template** to copy
- **reference implementation** to study
- **learning repo** to read

---

## How to read this repo

A simple reading order:

1. [`README.md`](./README.md) (this file)
2. [`LEARN.md`](./LEARN.md)
3. [`AGENTS.md`](./AGENTS.md)
4. [`CLAUDE.md`](./CLAUDE.md)
5. [`CONTRIBUTING.md`](./CONTRIBUTING.md)
6. [`.claude/`](./.claude/)
7. [`specs/`](./specs/)
8. [`src/example-module/CLAUDE.md`](./src/example-module/CLAUDE.md)

---

## How the AI layers connect

- `README.md` introduces the repo and points to the right places
- `LEARN.md` is the guided course
- `AGENTS.md` gives shared guidance for any coding agent (Codex, Cursor, Gemini CLI, Claude Code)
- `CLAUDE.md` gives Claude project-specific context that other tools ignore
- `ECOSYSTEM.md` defines shared schemas across surfaces
- `CONTRIBUTING.md` explains how to change things without breaking the teaching value
- `.claude/` contains Claude-specific configuration: skills, agents, rules, docs, hooks
- `specs/` contains the spec-driven artifacts: one folder per feature with spec + plan
- `src/<module>/CLAUDE.md` adds nested instructions scoped to a single folder

```
┌──────────────────────────────────────────────────────────────┐
│ Root layer (always loaded)                                   │
│   CLAUDE.md  AGENTS.md  ECOSYSTEM.md                         │
└────────────────────────┬─────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
   .claude/         specs/             src/<module>/
   ├─ skills/     YYYY-MM-DD-slug/    └─ CLAUDE.md
   ├─ agents/     ├─ spec.md             (nested, scoped)
   ├─ rules/      └─ plan.md
   ├─ docs/
   └─ hooks/
   (loaded on demand or by trigger)
```

---

## Project structure

```
claude-spec-driven-template/
├─ .claude/                                # Internal Claude config
│  ├─ agents/                              # Subagents: isolated specialists
│  │  ├─ spec-reviewer.md                  # Audits spec.md before it becomes plan.md
│  │  ├─ code-reviewer.md                  # Reviews code against plan and conventions
│  │  ├─ researcher.md                     # Deep-dives on libs, accumulates MEMORY.md
│  │  └─ security-auditor.md               # Audits auth, secrets, validation
│  │
│  ├─ skills/                              # Reusable workflows loaded on demand
│  │  └─ example-skill/                    # Anatomy of a skill (rename and adapt)
│  │     └─ SKILL.md                       # Frontmatter trigger + workflow
│  │
│  ├─ rules/                               # Path-scoped conventions (auto-load by glob)
│  │  └─ example-rule.md                   # Rule template with paths: frontmatter
│  │
│  ├─ docs/                                # Static knowledge, loaded only when referenced
│  │  ├─ architecture.md                   # System overview, trust model
│  │  ├─ superpowers.md                    # How spec-driven flow works here
│  │  ├─ libs/                             # One doc per external lib
│  │  │  └─ example-lib.md                 # Lib template (endpoints, gotchas, troubleshooting)
│  │  └─ decisions/                        # ADRs (architecture decision records)
│  │     └─ 0001-example.md                # ADR template
│  │
│  ├─ hooks/                               # Scripts triggered on tool lifecycle events
│  │  └─ block-secrets.sh                  # PreToolUse hook that blocks reading .env
│  │
│  └─ settings.json                        # Permissions, hooks registration, model
│
├─ specs/                                  # Spec-driven development
│  └─ 0000-example-feature/                # One folder per feature
│     ├─ spec.md                           # WHAT to build (source of truth)
│     └─ plan.md                           # HOW to build (2-5min TDD tasks)
│
├─ src/                                    # Application code
│  └─ example-module/
│     └─ CLAUDE.md                         # Nested instructions for this folder
│
├─ .claudeignore                           # Patterns excluded from auto context
├─ .gitignore                              # Standard + AI-specific entries
├─ AGENTS.md                               # Cross-tool agent guidance (Codex, Cursor, etc)
├─ CLAUDE.md                               # Claude-specific project context
├─ CLAUDE.local.md.example                 # Personal overrides template (rename to use)
├─ CONTRIBUTING.md                         # How to contribute without breaking teaching value
├─ ECOSYSTEM.md                            # Shared schemas and contracts
├─ LEARN.md                                # Guided course
├─ LICENSE                                 # MIT
└─ README.md                               # This file
```

---

## Shared root layer

The highest-level explanation layer. These files are read by humans and agents alike.

### [`README.md`](./README.md)

The human entry point. Explains what the repo is, how layers fit together, and how to reuse the structure.

### [`AGENTS.md`](./AGENTS.md)

Cross-tool instructions. Read by Codex, Cursor, Gemini CLI, Claude Code, and any other coding agent that supports the AGENTS.md convention. Think of it as a README written for agents: setup, commands, conventions, boundaries.

### [`CLAUDE.md`](./CLAUDE.md)

Claude Code specific. Loaded automatically at the start of every Claude session. Keeps the stack, conventions, and where-to-look pointers tight. Other tools ignore this file.

### [`ECOSYSTEM.md`](./ECOSYSTEM.md)

Shared schemas and contracts across surfaces of the system. Critical for multi-platform projects where multiple services must agree on field names, types, and enums.

### [`CONTRIBUTING.md`](./CONTRIBUTING.md)

How to make changes without breaking the repo's teaching value. Workflow rules, validation steps, conventions.

---

## Internal Claude layer

This is what makes Claude effective at this project specifically.

### [`.claude/skills/`](./.claude/skills/)

Reusable workflows. Each skill is a directory with a `SKILL.md`. The `description` in the frontmatter is the trigger: Claude reads it and auto-invokes the skill when it matches a task.

Use skills when you find yourself repeating the same multi-step process across sessions.

### [`.claude/agents/`](./.claude/agents/)

Subagents are specialists with isolated context windows. When invoked, they explore, read, and reason in their own session, then return a final summary. The main conversation stays clean.

Four templates included:

- **`spec-reviewer.md`** audits a spec before it becomes a plan
- **`code-reviewer.md`** reviews implementation against the plan
- **`researcher.md`** investigates libraries and accumulates a persistent `MEMORY.md`
- **`security-auditor.md`** audits auth, secrets, and input validation

The `description` field is the auto-delegation trigger. Convention: include "Use PROACTIVELY" or "Use when..." to push automatic delegation.

### [`.claude/rules/`](./.claude/rules/)

Path-scoped conventions. The `paths:` frontmatter glob determines when the rule auto-loads. Without `paths:`, the rule loads always (becoming a hidden CLAUDE.md).

### [`.claude/docs/`](./.claude/docs/)

Static knowledge that loads on demand only. Nothing here auto-loads. Skills and agents reference these docs explicitly when they need them.

Sub-folders:

- **`libs/`** one doc per external library or integration, focused on how this project uses it (not the official docs)
- **`decisions/`** architecture decision records, immutable once accepted

### [`.claude/hooks/`](./.claude/hooks/)

Scripts that run on Claude Code lifecycle events: `PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `Notification`. Registered in `settings.json`.

The example `block-secrets.sh` is a `PreToolUse` hook that prevents the agent from reading `.env` files via Bash.

### [`.claude/settings.json`](./.claude/settings.json)

Permissions (`allow` and `deny`), hook registrations, and default model. Commit this. Personal overrides go in `.claude/settings.local.json` (gitignored).

---

## Spec-driven layer

### [`specs/`](./specs/)

The spec-driven development pattern, popularized by the Superpowers plugin. Each feature lives in its own folder:

```
specs/YYYY-MM-DD-feature-slug/
├─ spec.md       # WHAT to build, source of truth
└─ plan.md       # HOW to build, broken into 2-5min TDD tasks
```

The flow:

```
1. Brainstorm (chat)
       ↓
2. spec.md committed
       ↓
3. spec-reviewer subagent audits the spec
       ↓
4. plan.md committed (TDD tasks with red-green-refactor)
       ↓
5. subagent-driven execution (fresh subagent per task)
       ↓
6. code-reviewer subagent gates between tasks
       ↓
7. Merge
```

When code and spec diverge, the spec wins. Code gets fixed.

The example folder [`0000-example-feature/`](./specs/0000-example-feature/) shows the format.

---

## Nested instructions in src

A `CLAUDE.md` placed inside a folder loads automatically when Claude navigates that folder. Use it for conventions that are specific to that layer of the code.

Example use cases:

- a server-side lib folder that should never import from the client
- a UI components folder with naming conventions
- an API folder with auth requirements

See [`src/example-module/CLAUDE.md`](./src/example-module/CLAUDE.md) for the pattern.

---

## Decision table: where does this instruction go?

| Question | Place |
|---|---|
| Should every session know this? | `CLAUDE.md` root (keep short) |
| Cross-tool guidance for any agent? | `AGENTS.md` |
| Shared schemas across services? | `ECOSYSTEM.md` |
| Only applies inside a specific folder? | `src/<folder>/CLAUDE.md` (nested) |
| Applies when editing a file type? | `.claude/rules/*.md` with `paths:` |
| Long reference doc, read on demand? | `.claude/docs/` |
| Repeatable multi-step process? | `.claude/skills/<name>/SKILL.md` |
| Specialist with its own perspective? | `.claude/agents/<name>.md` |
| Knowledge that grows over time? | Subagent with `memory:` field |
| What to build for this feature? | `specs/<slug>/spec.md` |
| How to build it, step by step? | `specs/<slug>/plan.md` |
| External lib docs that change often? | Context7 MCP, do not duplicate here |
| Personal preferences? | `CLAUDE.local.md` (gitignored) |
| Permanent architectural choice? | `.claude/docs/decisions/NNNN-*.md` |

---

## What hooks are doing here

Hooks are deterministic side effects on tool lifecycle events. They do not load into context.

This template ships one hook:

- **`block-secrets.sh`** intercepts `Bash` tool calls and blocks commands that try to read `.env` files or print secret-named environment variables

That is a good fit for hooks because it is:

- deterministic
- fast (under 100ms)
- safety-critical
- impossible to forget when added as a hook

Bad fits for hooks:

- anything that needs to load into context
- anything that makes network calls
- anything slow or unreliable

---

## What this repo is demonstrating

1. **AI instruction files should have clear roles.** Not everything belongs in CLAUDE.md.
2. **Context cost matters.** What loads always must be small. What is detailed must load on demand.
3. **Specs are versioned alongside code.** They are the source of truth, not the code.
4. **Agents, skills, rules, hooks, and docs each do different jobs.**
   - Rules: scoped guidance that auto-loads
   - Skills: reusable workflows loaded by description match
   - Agents: specialists with isolated context
   - Hooks: deterministic side effects
   - Docs: static knowledge consulted on demand
5. **A template repo should still feel real.** Folder names alone do not teach. This template ships realistic content in each layer.

---

## Using this template

### Option 1: Use as a GitHub template

1. Click "Use this template" at the top of the GitHub page
2. Create your new repository
3. Edit `README.md`, `CLAUDE.md`, and `AGENTS.md` to match your project
4. Delete `specs/0000-example-feature/` once you create your first real feature
5. Customize `.claude/docs/libs/` for the libraries you actually use

### Option 2: Adopt incrementally

You do not need everything at once. Three adoption levels:

**Minimal:** copy `CLAUDE.md`, `AGENTS.md`, `.gitignore`, `.claudeignore`. Start there.

**Practical:** add `.claude/settings.json`, `.claude/agents/code-reviewer.md`, and one or two skills. Add `specs/` when you have your first non-trivial feature.

**Full:** adopt the complete structure. Use this when you have a team and want consistent AI workflows across people.

### Option 3: Install Superpowers alongside

The spec-driven workflow in this template is compatible with the [Superpowers plugin](https://github.com/obra/superpowers):

```bash
# Inside Claude Code
/plugin install superpowers@claude-plugins-official
```

Superpowers ships brainstorming, writing-plans, subagent-driven-development, TDD, and code-review skills that enforce the spec-driven flow.

---

## License

[MIT](./LICENSE)
