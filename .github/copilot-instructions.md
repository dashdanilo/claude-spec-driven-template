# GitHub Copilot instructions

> **Read [`AGENTS.md`](../AGENTS.md) first.** It is the source of truth for project context: tech stack, commands, structure, conventions, workflow, and non-negotiables. The content below is only what is specific to GitHub Copilot.

This file is loaded automatically by:

- GitHub Copilot in VS Code, JetBrains, Visual Studio, and Neovim
- Copilot Chat
- Copilot Coding Agent (autonomous mode)
- Copilot in GitHub.com (PR reviews, issue triage)

## Copilot-specific guidance

### Follow the project workflow

For non-trivial features, follow the spec-driven flow documented in `AGENTS.md`:

1. Explore the codebase first (check `docs/patterns/`, existing implementations, past specs)
2. Write the spec in `specs/YYYY-MM-DD-<slug>/spec.md` before code (WHAT + WHY)
3. Write the plan in `specs/YYYY-MM-DD-<slug>/plan.md` (HOW: architecture, tech, phases)
4. Break the plan into atomic tasks in `specs/YYYY-MM-DD-<slug>/tasks.md` (checkboxes, TDD)
5. Implement task by task, test first, update checkboxes as you go

When code and spec diverge, the spec wins. Stop and ask.

To resume mid-feature: open `tasks.md`, find the first unchecked `- [ ]`.

### Before suggesting new code

Check what already exists:

- Search for similar implementations in the codebase
- Look for patterns in `docs/patterns/`
- Check past specs in `specs/`
- Prefer reusing and extending over creating new

### Respect the documentation layers

- `docs/CONSTITUTION.md` (if present) sets non-negotiable principles
- `docs/CONVENTIONS.md` (if present) defines code style and structure
- `docs/architecture/overview.md` explains system design and trust model
- `docs/decisions/` contains architecture decisions - do not silently violate accepted ADRs
- Nested `CLAUDE.md` files in `src/` folders add folder-specific conventions that Copilot should respect too

### Files Copilot should not touch

- `.env*` and any file matching `**/secrets/**`
- `node_modules/`, `.next/`, `dist/`, `build/`
- `CLAUDE.local.md` and any `*.local.*` files (personal)
- `.claude/agent-memory/` and `.claude/context/` (generated, gitignored)

## Personal Copilot preferences

If you need personal overrides, use your global Copilot settings or per-user config. This file is committed and shared with the team.
