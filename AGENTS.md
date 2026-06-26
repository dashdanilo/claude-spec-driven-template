# Project name

> Cross-tool instructions for any AI coding agent: Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode, etc.
> Claude Code specific guidance is in [`CLAUDE.md`](./CLAUDE.md).

One sentence about the project.

## Tech stack

Replace with your actual stack:

- Framework, language, styling, database, package manager, testing
- Key external services and integrations

## Build, test, lint

```bash
pnpm dev          # development server
pnpm test         # run tests
pnpm lint         # linter
pnpm typecheck    # type checker
pnpm build        # production build
```

## Structure

- `src/app/` routes
- `src/lib/` server-side logic
- `src/components/` UI
- `specs/` feature specs and plans
- `.claude/` Claude-specific config (other tools can ignore)

## Conventions

- Named exports only
- Functional components, no classes
- Validate all external input with Zod
- Structured JSON logs
- API keys always server-side
- Never call external APIs directly from the framework layer; use the orchestration layer

## Feature workflow

For non-trivial features:

1. Brainstorm requirements
2. Write `specs/<date>-<slug>/spec.md` (source of truth)
3. Write `specs/<date>-<slug>/plan.md` (TDD tasks, 2-5 min each)
4. Implement task by task, test first
5. Review against spec before merging

When code and spec diverge, the spec wins. Stop and ask.

## Files agents should not touch

- `.env*` and any file matching `**/secrets/**`
- `node_modules/`, `.next/`, `dist/`, `build/`
- `CLAUDE.local.md` and `.claude/settings.local.json` (personal)
- `.claude/agent-memory/` (managed by Claude Code)

## More context

- [`README.md`](./README.md) human entry point
- [`LEARN.md`](./LEARN.md) guided course for the AI structure
- [`ECOSYSTEM.md`](./ECOSYSTEM.md) shared schemas
- [`.claude/docs/architecture.md`](./.claude/docs/architecture.md) system overview
