# Plan: example-feature (rename this folder)

**Spec:** ./spec.md
**Total estimate:** N hours across small tasks

> This is the plan template. A plan breaks the spec into 2-5 minute tasks following TDD.
> Each task: failing test first (red), minimal code to pass (green), refactor if needed.
> Commit after each task with a clear message.

## Plan conventions

- Every task starts with a failing test
- Minimum implementation to make the test pass
- Refactor only if needed
- Commit at the end of each task

## Tasks

### Task 1: <short description>

**Path:** `src/<area>/<file>.ts`
**Estimate:** 15min

1. Write the failing test in `src/<area>/<file>.test.ts`:
   ```ts
   import { describe, it, expect } from 'vitest';
   import { yourFunction } from './your-file';

   describe('yourFunction', () => {
     it('handles the basic case', () => {
       expect(yourFunction(input)).toEqual(expected);
     });
   });
   ```
2. Verify it fails: `pnpm test your-file`
3. Implement the minimum in `src/<area>/<file>.ts`:
   ```ts
   export function yourFunction(input: Input): Output {
     // minimal implementation
   }
   ```
4. Verify it passes
5. Refactor if needed
6. Commit: `feat(<area>): add yourFunction`

### Task 2: <short description>

**Path:** `src/<area>/<file>.ts`
**Estimate:** 20min

(Same red-green-refactor structure)

### Task 3: ...

## Done criteria

- All tasks committed and tests green
- `pnpm typecheck` clean
- `pnpm lint` clean
- Coverage at acceptable level for the touched area
- `code-reviewer` subagent approved all tasks
- `security-auditor` approved if applicable (no CRITICAL or HIGH issues)
- Spec status updated to "Done"

## Notes

Document significant decisions made during execution here. If a decision changes the spec, update the spec and note it here.
