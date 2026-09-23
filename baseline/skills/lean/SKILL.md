---
name: lean
description: Ship a feature as one plan.md plus checks.md instead of a spec/tasks pair - dispatch one specialist to build it its own way, grade every claim with a fresh verifier and verify-gate.py, review once, open a PR. Use when today's model is strong enough that /orchestrate's per-task scaffolding costs more than it buys. Not for weaker models, work needing an audited checkbox trail, or a change too big for one specialist's context - use /orchestrate for those.
argument-hint: <what to build, free-form, or an existing spec folder to lean-build from>
---

# Lean

You are the **lean driver** for: **$ARGUMENTS**. One plan, one build dispatch, one verification pass, one review - for the case where `/orchestrate`'s fine `tasks.md` and task-by-task babysitting cost time and tokens without buying quality. `/orchestrate` stays the right tool for cheaper models and for work that must be audited step by step; this skips the scaffolding, not the discipline.

You coordinate; a specialist implements (`.claude/rules/harness/delegation.md`). Never write feature code from this thread. Before step 1, if the human has not already said where this runs, ask ("Where the work happens" in `.claude/rules/harness/git-workflow.md`: local, the agent tool's own worktree, or `spec-worktree`).

## 1 - Plan, not spec plus tasks

Reuse `write-spec`'s folder: `specs/YYYY-MM-DD-<slug>/`. Lean writes exactly one artifact there, `plan.md` - it skips `spec.md` (its problem statement folds into `plan.md`'s own `Problem` section, so there is nothing left for it to hold) and skips `tasks.md` (the per-task checkbox choreography is exactly what lean removes; `checks.md`, step 2, replaces it as the thing graded at the end, not a checkbox list).

`plan.md` sections:

- **Problem** - what's broken or missing, one paragraph.
- **Flow** - the user- or system-level sequence, end to end.
- **What changes** - files, modules, layers touched, at reviewer granularity, not a task list.
- **Entities / relations touched** - schema, types, contracts.
- **Surface** - routes, commands, screens, public APIs added or changed.
- **One-way doors** - irreversible decisions (a migration, a new secret/env var, a breaking API change). State "none" explicitly if true; an empty section reads as an omission, not a claim.
- **Acceptance criteria** - the observable behaviors that must hold. Source for `checks.md`.

`plan.md` lives under `specs/**`, so `.claude/rules/harness/specs.md` already applies to it: every claim about the current code checked against the repo when written, never carried over from memory.

**If `One-way doors` is non-empty, STOP and get explicit human sign-off before step 3.** If the plan cannot be written without guessing something material, STOP and ask instead of guessing.

## 2 - Checks, not tasks

`checks.md`, same folder: one line per observable claim drawn from `plan.md`'s acceptance criteria, each paired with how to prove it:

```
- <claim> (proof: <test to run | command | file:line to inspect once built>)
```

This is a pre-registration, written before the build exists. Step 4 turns it into the actual evidence report `baseline/scripts/verify-gate.py` already validates (`## Commands` with exit codes, `## Claims` with `file:line` or a backtick-quoted command as evidence) - reuse that contract as-is, do not define a second one.

## 3 - Build

Dispatch **one** specialist with `plan.md` and `checks.md` in full: the stack specialist from `.claude/agents/` if this repo has one for the work, else the baseline's `implementer` (portable fallback), never `general-purpose`. Let it implement its own way - no per-task dispatch, no checkbox table. Ask for coherent commits (Conventional Commits, `.claude/rules/harness/git-workflow.md`), not one per line of `checks.md`.

## 4 - Verify

Dispatch a **fresh subagent that never built the change** - `tester` by default, since most proofs in `checks.md` are commands or tests it can run directly, and it can still `Read`/`Grep` a `file:line` proof. Hand it `checks.md` and have it grade every claim, writing `.claude/verification/<date>-<slug>.md` (and refreshing `latest.md`) in `verify-before-done`'s "Evidence or zero" format, then run `baseline/scripts/verify-gate.py` on it as the deterministic close. If `plan.md`'s surface touches a screen, an acceptance criterion about that screen is only proven by `verify-ui`'s driven-flow claim in the same report, not by a passing build.

**Red gate means back to step 3 with the specific failure, never a note in the report.** Up to 3x; still red, or the fix looks hacky, is a STOP.

## 5 - Review

Dispatch `code-reviewer` once for the whole change - no cluster scope, there is only one specialist's output to review - handing it `plan.md` and `checks.md` in place of `spec.md`/`tasks.md`. It classifies findings by severity (`.claude/agents/code-reviewer.md`): any open `blocker` goes back to step 3 with the finding; `should-fix`/`nit` are reported, not blocking.

## 6 - When to use which

| | `/lean` | `/wave` | `/orchestrate` |
|---|---|---|---|
| Ceremony | one plan, one gate, one review | one batch, one gate, no spec | full spec, approval table, per-cluster review |
| Fits | a strong model, a change one specialist can hold in its head | a handful of independent tasks | a change too big for one specialist's context, or that must be audited task by task |
| Auditability | `plan.md` + `checks.md` + one review | none (no spec) | a checkbox per task, gated per cluster |
| Model quality assumed | high, trusted to sequence its own work | high | any - the structure carries a weaker model |

**Use `/orchestrate` instead when:** the model is weaker than today's frontier, a human needs to audit progress task by task, the work spans more than one specialist's context, or the team's process requires a checkbox trail.

## Finish

Dispatch `reviewer` for the whole branch, run the gate once more, open a **PR to the repo's integration branch**. Never merge - `protect-main` blocks it.

## STOP and ask a human when

- `One-way doors` is non-empty in `plan.md` - always, before step 3.
- `plan.md` cannot be written without guessing something material.
- A hook blocks something (a protected-branch operation, a critical-file edit).
- The gate in step 4 stays red after 3 attempts, or the fix looks hacky.
