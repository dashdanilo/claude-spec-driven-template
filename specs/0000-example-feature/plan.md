# Plan: example-feature (rename this folder)

**Spec:** ./spec.md
**Tasks:** ./tasks.md
**Total estimate:** N hours

> The plan describes HOW to build the feature at a high level: architecture, tech choices, decomposition into phases, migration if applicable.
> The atomic executable checklist lives in `tasks.md`, not here.
> If you find yourself writing "task 1, task 2..." in this file, it belongs in `tasks.md`.

## Approach

Prose description of the technical approach. Which parts of the system will be touched, in what order, and why.

## Architecture

If the feature introduces or changes architecture, describe:

- New components or modules
- New data flows
- New dependencies or integrations
- Impact on existing modules

Reference `docs/architecture/overview.md` if the overall system diagram changes.

## Tech choices

Concrete choices with reasoning:

- Library or framework selections
- Data model changes
- API contract additions or changes
- Storage or caching decisions

If a choice contradicts a past ADR, either link the new ADR that supersedes it or justify the exception.

## Phases

Break the feature into 2-5 phases. Each phase is a coherent unit of work that could ship independently (feature-flagged or not).

### Phase 1: <name>

**Goal:** what this phase achieves
**Deliverable:** what is shippable at the end
**Blockers:** what depends on this being done

### Phase 2: <name>

...

### Phase N: <name>

...

## Migration and rollout

If this feature changes existing behavior or data:

- Migration strategy (backfill, dual-write, feature flag)
- Rollout plan (percentage, canary, all-at-once)
- Rollback plan

## Testing strategy

High-level approach, not individual test cases (those go in `tasks.md`):

- Unit tests focus
- Integration tests scope
- E2E tests scope (if applicable)
- Manual QA steps (if applicable)

## Done criteria

- All tasks in `tasks.md` completed
- `pnpm typecheck` clean
- `pnpm lint` clean
- Coverage at acceptable level for the touched area
- `code-reviewer` subagent approved all tasks
- `security-auditor` approved if applicable (no CRITICAL or HIGH issues)
- Spec status updated to "Done"

## Open questions

Anything that came up during planning that needs resolution. Move to spec if it changes what we're building; keep here if it changes only how.
