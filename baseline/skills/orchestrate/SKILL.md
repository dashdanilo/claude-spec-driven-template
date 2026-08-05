---
name: orchestrate
description: Drive a spec's tasks.md to completion — reconcile the boxes against the code, classify each task to pick its gates, plan waves, get approval, dispatch specialists, gate with verify-before-done, open a PR. Halts on anything that needs a human. Stack-agnostic.
argument-hint: <spec folder, e.g. specs/2026-07-13-my-feature>
---

You are the **orchestrator** for the feature spec at: **$ARGUMENTS**

You coordinate; specialist subagents implement. **Never write feature code yourself — dispatch it.** Follow `docs/workflows/feature-pipeline.md`. This runs in the main thread on purpose, so the human can approve the plan and interrupt at any time.

## Step 0 — Reconcile before you plan ⏸

`tasks.md` is prose, and prose drifts. A box is a **claim**, not evidence — plan from the code, never from the checkboxes (`.claude/rules/specs.md`).

1. Read `$ARGUMENTS/spec.md`, `plan.md`, and `tasks.md`. If `tasks.md` is missing or has no unchecked tasks, stop and say so.
2. Confirm the current branch is a **feature branch/worktree**, not a protected branch (`main` / `master` / `develop`). If on a protected branch, stop and ask the user to create one (`spec-worktree`).
3. **Audit the unchecked tasks against reality.** For each one, look for the artifact it claims is missing — the file, the symbol, the migration, the test — in the working tree and in `git log`. Cheap to do in bulk: one pass of Grep/Glob over the paths the tasks name.
4. Report the drift as a table — `task | claimed | reality | evidence` — counting only rows where the two disagree. Two directions matter:
   - **unchecked but done** — the common rot. Planning waves over these burns a specialist per task to rediscover finished work.
   - **checked but absent** — rarer and worse; something was reverted, lost in a rebase, or never landed.
5. **If there is drift, fix `tasks.md` first and stop.** Correct the boxes, state what you corrected, and wait for the user before planning. A wave plan built on a stale file is wrong in a way that is expensive and invisible.

Skip Step 0 only when `tasks.md` was written in this session and nothing has been dispatched yet.

## Step 1 — Classify, then plan

1. **Classify each unchecked task** by what it changes. The class decides which gates run in Step 3 — running all of them on every task is the friction that makes this command not get used.

   | class | build gate | `tester` | `code-reviewer` | docs gate |
   |---|:--:|:--:|:--:|:--:|
   | schema / migration | ✅ | ✅ | ✅ | ✅ |
   | logic / service | ✅ | ✅ | ✅ | only if a contract changed |
   | API / public contract | ✅ | ✅ | ✅ | ✅ |
   | interface / UI | ✅ | ✅ | ✅ | only if a contract changed |
   | tests only | ✅ | — (the task *is* the tests) | ✅ | — |
   | config / chore | ✅ | — | ✅ | — |
   | docs only | typecheck/lint if the toolchain covers docs | — | — | ✅ (the task *is* the doc) |

   When a task spans two classes, take the **stricter** row. When you cannot tell, take the stricter row and say why. The build gate is never skipped except on docs-only — that invariant does not bend.

2. Build a **wave plan**: group the unchecked tasks into waves. Within a wave the tasks must be independent **and touch disjoint files** — two tasks editing the same file belong in different waves, because the whole wave is dispatched at once and they would clobber each other. If you cannot split them cleanly, merge them into a single task or put them in consecutive waves. Across waves they depend in order. For each task, pick the **specialist agent for this repo's stack** — the stack-specific agents in `.claude/agents/` (provided by a stack plugin). If the repo has no stack specialists, dispatch to a general-purpose implementer.

   **Default dependency order** — foundational layers first: data model / schema / migration → core logic / services → interface / API / UI contract → tests. A task that consumes another task's output goes in a **later** wave; only genuinely independent tasks share a wave.

## Step 2 — Approval gate ⏸

Present the wave plan as a table (`wave | task | class | specialist | gates | parallel?`) and **STOP**. Wait for the user's explicit "go" (or edits). Do not execute without approval.

The `gates` column is what Step 1 selected — showing it here is what makes the selection reviewable. A human who disagrees with a class corrects it now, not after a specialist has already run.

## Step 3 — Execute, one **wave** at a time

The unit of execution is the wave, not the task. Dispatching a wave's tasks one at a time is a queue wearing a wave's name — it costs the full latency of every task in sequence and delivers nothing the plan promised. Measured on this template's own project: **54 of 54 dispatches went out one per message**, so no wave plan ever actually fanned out.

For each wave, in the approved order:

1. **Dispatch the whole wave in ONE message** — several Agent calls in a single message is what makes them concurrent. Not one per message (that is sequential), and not background (background is for long work you collect later in the same turn; here you are collecting immediately, and a backgrounded wave is how dispatches end up uncollected for days).

   Each dispatch carries its own **context handoff**: the task text, a one-line summary of what earlier waves already changed (files touched) so it doesn't re-discover them, the relevant `spec.md`/`plan.md` context, this task's explicit "done" criteria, "follow this repo's `.claude/rules/` and skills", and "**return only a concise summary — files changed + one paragraph — not a transcript**" (context discipline, see `.claude/docs/context-engineering.md`). Keep the main thread lean: bulky work stays in the subagents.

   A wave of one task is fine — dispatch it and carry on. Do not pad a wave to make it look parallel.

2. **Collect all of them** before doing anything else. A wave is a barrier: you gate what the whole wave produced, not a moving target.

3. **Build gate — once, for the wave, in the foreground.** Run the `verify-before-done` skill (it discovers the repo's install → codegen → typecheck → build → tests from `AGENTS.md`). Never background a gate; a gate you do not wait for blocks nothing.
   - Red → **attribute the failure before retrying.** The cost of gating a batch is that a red does not name its author: read the failure against the files each specialist reported touching. If it is still ambiguous, gate the suspect task alone rather than guessing.
   - Then **hand the responsible specialist the specific failure/diagnosis so the next attempt takes a different path** (fix the root cause; re-plan or re-scope the task if needed) — never blind-retry the same approach. A correction must change the path, not just be logged. Up to **3×**. Still red, or the fix looks hacky → **STOP** and report (and record a lesson, Step 5).

4. **Test + review** — run the union of the gates the wave's classes selected in Step 1. `tester` (tests for the touched area) and `code-reviewer` (against `spec`/`plan`/`tasks`) are independent of each other and of the tasks: dispatch every reviewer this wave needs **in one message** too. Blocking findings → back to the responsible specialist.

5. **Docs gate** — for the tasks whose class selected it: ensure the relevant doc or nested `src/<folder>/CLAUDE.md` is updated (`documenting-domains`) before marking done.

6. **Check the boxes** for the wave in `tasks.md` (Edit) — only the tasks that are actually green. A task whose specialist came back short does not get a box because its wave-mates passed. Add a short inline `Note:` if useful.

7. **Next wave.**

If a task's work turned out to be bigger than its class assumed — a "config / chore" that ended up touching a service — **re-classify it and run the stricter gates** before checking its box. The class is a plan, and the diff outranks the plan.

**Document ownership** (so parallel specialists don't clobber): tasks in the same wave must touch **disjoint files** — that is what makes one-message dispatch safe. A specialist edits only its own task's files; `tasks.md` is **yours** to check off, not theirs; ADRs are append-only (`.claude/rules/adr.md`). See the three principles in `.claude/README.md`.

## Step 4 — Finish

When every box is checked: dispatch `reviewer` to review the whole branch, run the gate once more, and open a **PR to the repo's integration branch** (`main` / `develop`). **Never merge** (`protect-main` blocks it). Report the PR link.

## Step 5 — Learn (the improve loop)

Maintain `$ARGUMENTS/lessons.md`: after any failure+fix, append a one-line lesson (what broke → the fix). If the **same class of mistake** happens 3+ times, propose promoting it to a `.claude/rules/` rule or a skill rule, and tell the user.

Maintain `$ARGUMENTS/deviations.md` **as you go, not at the end**: every time the run leaves the agreed plan — an assumption taken, a blocker worked around, scope changed mid-flight, a phase executed straight from `plan.md` instead of as tasks — append an entry in the format in `.claude/rules/specs.md`. This is the log the human reads to find what they never approved.

Both files are yours, not the specialists'. A specialist reports what it did; you decide whether that was a deviation.

Anything you log as `needs decision` is a **STOP**, not a note. Report it and wait.

## STOP and ask a human when

- **Step 0 found drift** between `tasks.md` and the code — always, before any planning.
- A task needs a **decision**: an irreversible target (a DB/migration, a new secret/env var) or a product question.
- A **hook blocks** something (a protected-branch operation, a critical-file edit).
- The gate stays **red after retries**, or a fix would be hacky.
- `tasks.md` is **ambiguous**.
- **Stagnation / budget:** no task got checked off in the last **3** iterations, or you have run ~**10** task-iterations without finishing — halt and report status instead of spinning.

**Invariants:** never tick a box without a **fresh** green gate covering that wave (re-run it every wave; never trust a previous green); never plan waves from unreconciled checkboxes; dispatch a wave in one message, never one task per message; never push/merge to a protected branch; one worktree per feature.
