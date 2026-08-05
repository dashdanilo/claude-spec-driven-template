# Tasks: example-feature (rename this folder)

**Spec:** ./spec.md
**Plan:** ./plan.md
**Current status:** not started
**Last updated:** YYYY-MM-DD

> This file is the atomic execution checklist. Every task follows red-green-refactor (TDD).
> Each task has: a path, a failing test to write, minimal code to make it pass, and a commit message.
> Update the checkboxes as you go. This is where you find "where did I stop?"

## How to read this file

- `- [ ]` = not started
- `- [x]` = done
- Use inline `Notes:` under a task to capture blockers, decisions, or discoveries during that task
- If a task grows too big, split it in place (add sub-tasks)

## Phase gate (automatic)

At the end of each phase - not each task - the `code-reviewer` subagent runs **automatically, without asking permission**, reviews the phase against spec/plan/tasks/conventions, and reports a verdict. A phase does not advance until the review is `APPROVED` (or its `NEEDS_CHANGES` items are resolved and it re-runs). It is a standard gate, like CI - it reports, it does not ask.

## Tasks

### Phase 1: <name from plan.md>

- [ ] **Task 1: short description**
  - **Path:** `src/<area>/<file>.ts`
  - **Estimate:** 15min
  - Write failing test in `src/<area>/<file>.test.ts`:
    ```ts
    import { describe, it, expect } from 'vitest';
    import { yourFunction } from './your-file';

    describe('yourFunction', () => {
      it('handles the basic case', () => {
        expect(yourFunction(input)).toEqual(expected);
      });
    });
    ```
  - Verify it fails: `pnpm test your-file`
  - Implement minimum in `src/<area>/<file>.ts`:
    ```ts
    export function yourFunction(input: Input): Output {
      // minimal implementation
    }
    ```
  - Verify it passes
  - Refactor if needed
  - Commit: `feat(<area>): add yourFunction`

- [ ] **Task 2: short description**
  - **Path:** `src/<area>/<file>.ts`
  - **Estimate:** 20min
  - (same red-green-refactor structure)

### Phase 2: <name from plan.md>

- [ ] **Task 3: short description**
  - ...

- [ ] **Task 4: short description**
  - ...

### Phase 3: <name from plan.md>

- [ ] **Task 5: short description**
  - ...

## Recording progress

At the top of this file, keep `Current status` and `Last updated` accurate. When you hit a blocker mid-task, add an inline note:

```
- [ ] **Task 7: API route for lead submission**
  - **Path:** `src/app/api/lead/route.ts`
  - **Estimate:** 1h
  - Notes: paused here. Zod v4 changed union types API,
    need to confirm shape with team before continuing.
    See: https://zod.dev/v4/changelog
  - ...
```

That way, next time you (or another agent) opens this file, the first unchecked box tells you where to resume, and the inline notes tell you why you paused.

## Completion

When the last box is checked:

1. Update `Current status` to `done`
2. Verify all done criteria in `plan.md` pass
3. Update the spec status to `Done` (in `spec.md`)
4. Optional: extract any durable domain knowledge into nested `CLAUDE.md`, `docs/patterns/`, or `docs/lessons/`
