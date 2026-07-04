# Project name

> Cross-tool source of truth. Read by any AI coding agent: Codex, Cursor, Gemini CLI, GitHub Copilot, Windsurf, Aider, Claude Code, and others that support the AGENTS.md convention.
>
> Tool-specific additions live in their own files:
> - Claude Code: [`CLAUDE.md`](./CLAUDE.md) (stub pointing here + Claude-specific extras)
> - GitHub Copilot: [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) (stub pointing here + Copilot-specific extras)
> - Gemini CLI: `GEMINI.md` (when present)
> - Cursor: `.cursor/rules/` (when present)

One sentence about what this project does and who it is for.

## Tech stack

Replace with your actual stack:

- Framework: (e.g., your web framework and version)
- Language: (e.g., TypeScript strict mode)
- Styling: (e.g., your CSS approach)
- Database: (e.g., your DB and ORM)
- Package manager: (e.g., pnpm, npm, yarn)
- Testing: (e.g., your test runner)
- External services: (list the third-party APIs your project depends on)

## Build, test, lint

```bash
# Development
pnpm dev

# Tests
pnpm test
pnpm test:watch

# Quality
pnpm lint
pnpm typecheck

# Build
pnpm build
```

## Structure

- `src/app/` routes
- `src/lib/` server-side logic (each major folder may have its own nested CLAUDE.md)
- `src/components/` UI
- `specs/` feature specs and plans (source of truth for features)
- `docs/` human-facing project documentation (constitution, architecture, ADRs, patterns)
- `.claude/` Claude-specific config (other tools can ignore)

## Conventions

- Named exports, never default
- Functional components, no classes
- Validate all external input with Zod (or equivalent)
- Structured JSON logs, never raw `console.log` strings
- API keys always server-side
- Never call external APIs directly from the framework layer; use the orchestration layer

## Feature workflow

For non-trivial features:

1. Brainstorm requirements before writing code
2. Write `specs/YYYY-MM-DD-<slug>/spec.md` (WHAT + WHY, source of truth)
3. Write `specs/YYYY-MM-DD-<slug>/plan.md` (HOW at high level: architecture, tech, phases)
4. Write `specs/YYYY-MM-DD-<slug>/tasks.md` (HOW at execution level: atomic TDD checkboxes)
5. Implement task by task, test first, update checkboxes as you go
6. Review against spec before merging

When code and spec diverge, the spec wins. Stop and ask.

To resume mid-feature: open `tasks.md`, find the first unchecked `- [ ]`. That's where you stopped.

## Before writing new code

Check what exists first:

- Search for existing implementations by name and synonyms
- Look for related patterns in `docs/patterns/`
- Check past specs in `specs/` for prior work in the area
- Check `.claude/docs/libs/` for existing integrations (Claude Code) or equivalent

Only create new when nothing suitable exists, and match the style of neighboring code.

## Where to look

| Need | Place |
|---|---|
| Spec for the active feature | `specs/<latest>/spec.md` |
| Project DNA (principles, boundaries) | `docs/CONSTITUTION.md` |
| Style, naming, structure conventions | `docs/CONVENTIONS.md` |
| System architecture overview | `docs/architecture/overview.md` |
| Past decisions and their reasoning | `docs/decisions/` |
| "How we solved X" living examples | `docs/patterns/` |
| Shared schemas across services | `ECOSYSTEM.md` |
| Operational procedures (deploy, incident) | `docs/runbooks/` |
| Onboarding and tutorials | `docs/guides/` |

## Non-negotiables

- Source of truth is always `specs/<feature>/spec.md`. When code diverges, stop and ask.
- Before implementing a new feature: brainstorm, then spec, then plan, then code.
- Before creating any new file, check whether it already exists (see "Before writing new code" above).

## Files agents should not touch

- `.env*` and any file matching `**/secrets/**`
- `node_modules/`, `.next/`, `dist/`, `build/`
- `CLAUDE.local.md` and `.claude/settings.local.json` (personal)
- `.claude/agent-memory/` (managed by Claude Code)
- `.claude/context/` (generated, gitignored)

## More context

- [`README.md`](./README.md) human entry point
- [`LEARN.md`](./LEARN.md) guided course for the AI structure
- [`ECOSYSTEM.md`](./ECOSYSTEM.md) shared schemas
- [`docs/`](./docs/) all human-facing project documentation
