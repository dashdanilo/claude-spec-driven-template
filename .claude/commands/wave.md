---
description: Fan out one batch of independent tasks to specialists, in parallel, in a single message — the useful half of /orchestrate without the spec, the approval table, or the PR. Stack-agnostic.
argument-hint: <what to do — free-form, or a spec folder to take the next unchecked tasks from>
---

Dispatch **one wave** and stop. No spec required, no PR at the end. Use this when `/orchestrate` is more ceremony than the work deserves — which is most of the time.

Follow `.claude/rules/delegation.md` (you coordinate, specialists implement) and `.claude/docs/dispatching.md` (how to fan out).

## 1 — Build the batch

From `$ARGUMENTS`: either a spec folder (take the next unchecked tasks from its `tasks.md`) or a free-form description (split it yourself).

Keep the batch to a handful. **Every task in a wave must touch disjoint files** — two tasks editing the same file belong in different waves, not the same one. If you cannot split them cleanly, run the batch as one task.

Pick the specialist per task from `.claude/agents/` (stack specialists arrive via a stack plugin). No specialist for this stack → use a general-purpose implementer **and say the specialist is missing**.

## 2 — Confirm branch

Feature branch or worktree, never a protected branch (`main` / `master` / `develop`). If protected, stop and ask (`spec-worktree`).

## 3 — Dispatch — all of them, in ONE message

This is the whole point of the command. Independent tasks go out as **several agent calls in a single message** so they run concurrently. One-per-message is sequential and defeats the wave.

Each dispatch carries a **curated handoff**: the task, one line on what earlier work already changed (files touched), the relevant spec/plan context if any, this task's explicit done criteria, "follow this repo's `.claude/rules/` and skills", and "**return only files changed + one paragraph — not a transcript**".

Announce the batch in one line before dispatching (task → specialist). Do not stop for approval — the human can interrupt.

## 4 — Collect, then gate

Wait for all of them. Then run `verify-before-done` **once, in the foreground** — never in the background, a gate you do not wait for blocks nothing.

- Green → tick the boxes in `tasks.md` if a spec is active (`tasks.md` is yours, not the specialists'), and report.
- Red → hand the specific failure back to the responsible specialist so the next attempt takes a **different path**. Up to 3×; still red or the fix looks hacky → STOP and report.

## 5 — Report and stop

One short card: what each specialist changed, gate result, what is left. Then **stop** — do not roll into the next wave on your own. The human decides whether to run `/wave` again.

## STOP and ask when

- A task needs a decision: an irreversible target (migration, new secret/env var) or a product question.
- A hook blocks something.
- The gate stays red after retries.
- The tasks cannot be made disjoint and the batch would clobber itself.

**Invariants:** never claim done without a fresh green gate; never push or merge to a protected branch; a specialist edits only its own task's files.
