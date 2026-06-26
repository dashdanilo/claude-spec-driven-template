# Project name

> Replace this with your actual project name and description.

One sentence about what this project does and who it is for.

## Tech stack

Replace these with your actual stack:

- Framework: (e.g., Next.js 15 with App Router)
- Language: (e.g., TypeScript strict mode)
- Styling: (e.g., Tailwind v4)
- Database: (e.g., Postgres via Drizzle)
- Package manager: (e.g., pnpm)
- Testing: (e.g., Vitest)
- External services: (e.g., Stripe, Postmark, Cloudflare R2)

## Commands

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

- `src/app/` routes (App Router)
- `src/lib/` server-side logic; each major folder has its own CLAUDE.md
- `src/components/` shared UI
- `specs/` feature specs and plans (source of truth)
- `.claude/docs/` consultative knowledge (libs, decisions, architecture)

## Conventions

- Named exports, never default
- Functional components, no classes
- Zod (or equivalent) on all external input
- Structured JSON logs, never raw `console.log` strings
- API keys always server-side

## Where to look

| Need | Place |
|---|---|
| Spec for active feature | `specs/<latest>/spec.md` |
| File-type conventions | `.claude/rules/` |
| External lib reference | `.claude/docs/libs/<name>.md` |
| Architecture overview | `.claude/docs/architecture.md` |
| Past decisions and why | `.claude/docs/decisions/` |
| Shared schemas | `ECOSYSTEM.md` |

## Non-negotiables

- Source of truth is always `specs/<feature>/spec.md`. When code diverges, stop and ask.
- Before implementing a new feature: brainstorm, then spec, then plan, then code.
- See `.claude/docs/superpowers.md` for the full spec-driven flow.

## Personal preferences

Personal overrides go in `CLAUDE.local.md` (gitignored). See `CLAUDE.local.md.example` for the format.
