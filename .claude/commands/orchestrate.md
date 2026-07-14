---
description: Drive a spec's tasks.md to completion — plan waves, get approval, dispatch specialists, gate every task with verify-before-done, open a PR. Halts on anything that needs a human. Stack-agnostic.
argument-hint: <spec folder, e.g. specs/2026-07-13-my-feature>
---

You are the **orchestrator** for the feature spec at: **$ARGUMENTS**

You coordinate; specialist subagents implement. **Never write feature code yourself — dispatch it.** Follow `docs/workflows/feature-pipeline.md`. This runs in the main thread on purpose, so the human can approve the plan and interrupt at any time.

## Step 1 — Load & plan

1. Read `$ARGUMENTS/spec.md`, `plan.md`, and `tasks.md`. If `tasks.md` is missing or has no unchecked tasks, stop and say so.
2. Confirm the current branch is a **feature branch/worktree**, not a protected branch (`main` / `master` / `develop`). If on a protected branch, stop and ask the user to create one (`spec-worktree`).
3. Build a **wave plan**: group the unchecked tasks into waves. Within a wave the tasks are independent (safe to run in parallel); across waves they depend in order. For each task, pick the **specialist agent for this repo's stack** — the stack-specific agents in `.claude/agents/` (provided by a stack plugin). If the repo has no stack specialists, dispatch to a general-purpose implementer.

   **Default dependency order** — foundational layers first: data model / schema / migration → core logic / services → interface / API / UI contract → tests. A task that consumes another task's output goes in a **later** wave; only genuinely independent tasks share a wave.

## Step 2 — Approval gate ⏸

Present the wave plan as a table (`wave | task | specialist | parallel?`) and **STOP**. Wait for the user's explicit "go" (or edits). Do not execute without approval.

## Step 3 — Execute, wave by wave

For each task, in the approved order:

1. **Dispatch** to the specialist subagent (Agent tool) with a **context handoff**: the task text, a one-line summary of what earlier waves already changed (files touched) so it doesn't re-discover them, the relevant `spec.md`/`plan.md` context, this task's explicit "done" criteria, "follow this repo's `.claude/rules/` and skills", and "**return only a concise summary — files changed + one paragraph — not a transcript**" (context discipline, see `.claude/docs/context-engineering.md`). Independent tasks in the same wave may be dispatched in parallel (background). Keep the main thread lean: bulky work stays in the subagents.
2. **Build gate** — run the `verify-before-done` skill (it discovers the repo's install → codegen → typecheck → build → tests from `AGENTS.md`).
   - Red → **hand the specialist the specific failure/diagnosis so the next attempt takes a different path** (fix the root cause; re-plan or re-scope the task if needed) — never blind-retry the same approach. A correction must change the path, not just be logged. Up to **3×**. Still red, or the fix looks hacky → **STOP** and report (and record a lesson, Step 5).
3. **Test + review** — dispatch `tester` (tests for the touched area) and `code-reviewer` (against `spec`/`plan`/`tasks`). Blocking findings → back to the specialist.
4. **Docs gate** — if the task changed public behavior/contracts, ensure the relevant doc or nested `src/<folder>/CLAUDE.md` is updated (`documenting-domains`) before marking done.
5. **Check the box** for that task in `tasks.md` (Edit). Add a short inline `Note:` if useful.
6. Next task.

## Step 4 — Finish

When every box is checked: dispatch `reviewer` to review the whole branch, run the gate once more, and open a **PR to the repo's integration branch** (`main` / `develop`). **Never merge** (`protect-main` blocks it). Report the PR link.

## Step 5 — Learn (the improve loop)

Maintain `$ARGUMENTS/lessons.md`: after any failure+fix, append a one-line lesson (what broke → the fix). If the **same class of mistake** happens 3+ times, propose promoting it to a `.claude/rules/` rule or a skill rule, and tell the user.

## STOP and ask a human when

- A task needs a **decision**: an irreversible target (a DB/migration, a new secret/env var) or a product question.
- A **hook blocks** something (a protected-branch operation, a critical-file edit).
- The gate stays **red after retries**, or a fix would be hacky.
- `tasks.md` is **ambiguous**.
- **Stagnation / budget:** no task got checked off in the last **3** iterations, or you have run ~**10** task-iterations without finishing — halt and report status instead of spinning.

**Invariants:** never claim a task done without a **fresh** green gate (re-run it each task; never trust a previous green); never push/merge to a protected branch; one worktree per feature.
