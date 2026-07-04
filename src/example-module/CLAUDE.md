# src/example-module - Nested CLAUDE.md template

> Global context in `/CLAUDE.md`. Active spec in `/specs/<latest>/spec.md`.

> This is a template for a nested `CLAUDE.md`. Rename the folder and adapt the content to your actual module.
> Nested files load automatically when Claude navigates inside this folder, and stay invisible elsewhere.
> They are the right place for conventions specific to a single layer of the code.

## What this folder is

One sentence describing the role of this module. Examples:

- "Authentication and session management, server-side only"
- "Reusable UI primitives, no business logic"
- "API route handlers and request validation"

## Files expected here

List what should exist in this folder. This helps Claude not invent filenames:

- `schema.ts` validation schemas
- `<entity>.ts` core logic
- `<entity>.test.ts` tests for the core logic
- Each file has a `.test.ts` next to it

## Mandatory conventions

Patterns this folder enforces. Each one should be checkable:

- Validate all external input with Zod
- Never call external APIs directly (use the orchestration layer)
- Logs are structured JSON, not string concatenation
- No imports from `../app/` (this folder is lower-level)

## Testing

- Coverage minimum: 80%
- Run before commit: `pnpm test src/example-module`
- Required test cases for edge logic: enumerate the explicit ones

## Source of truth

Logic in this folder must reflect Section X.Y of the active spec at `/specs/<latest>/spec.md`.

When code and spec diverge, stop and ask. Do not let them drift silently.

## Do not

Explicit anti-patterns. More useful than listing what to do:

- Do not call external APIs directly from here
- Do not import from layers above
- Do not store secrets in code
- Do not log PII in clear
