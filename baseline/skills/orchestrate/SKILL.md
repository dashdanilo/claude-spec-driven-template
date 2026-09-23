---
name: orchestrate
description: Drive a spec's tasks.md to completion — reconcile the boxes against the code, classify each task to pick its gates, plan waves, get approval, dispatch specialists, gate with verify-before-done, open a PR. Halts on anything that needs a human. Stack-agnostic.
argument-hint: <spec folder, e.g. specs/2026-07-13-my-feature>
---

You are the **orchestrator** for the feature spec at: **$ARGUMENTS**

You coordinate; specialist subagents implement. **Never write feature code yourself — dispatch it.** Follow `docs/workflows/feature-pipeline.md`. This runs in the main thread on purpose, so the human can approve the plan and interrupt at any time.

## Step 0 — Reconcile before you plan ⏸

`tasks.md` is prose, and prose drifts. A box is a **claim**, not evidence — plan from the code, never from the checkboxes (`.claude/rules/harness/specs.md`).

1. Read `$ARGUMENTS/spec.md`, `plan.md`, and `tasks.md`. If `tasks.md` is missing or has no unchecked tasks, stop and say so.
2. Confirm the current branch is a **feature branch/worktree**, not a protected branch (`main` / `master` / `develop`). If on a protected branch, or if the human has not already said where this runs, ask ("Where the work happens" in `.claude/rules/harness/git-workflow.md`: local, the agent tool's own worktree, or `spec-worktree`) before proceeding.
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

2. **Group the tasks into a few cohesive clusters — not one per task, and not one per phase.**

   A cluster is **5-7 related tasks that one specialist runs in order, in its own context**. Aim for roughly **three clusters** on a spec of ~18 tasks. This is the single most consequential number in the plan, and the reason is not speed:

   | how you slice | tokens | time | quality | main thread left |
   |---|---|---|---|---|
   | everything inline, no dispatch | 9M | 19m | 0.93 | **74% used** |
   | **~3 cohesive clusters** | 10.5M | 18m | **0.95** | **26% used** |
   | one per phase (7) | 15M | 35m | 0.90 | 24% used |
   | **one per task (18)** | **25M** | **43m** | **0.81** | 32% used |

   Three things that table is saying, and only one of them is obvious:

   - **Granularity destroys quality.** Every extra dispatch starts from zero, re-reads the files, and loses sight of the whole. One agent per task is the *worst* row, not the most parallel one.
   - **More workers does not mean a leaner main thread.** Eighteen workers left it *fatter* than seven, because each worker's summary comes back into it. Fan-out has a cost on the side you were trying to protect.
   - **Sub-agents here buy context budget, not speed.** Eighteen minutes against nineteen is no speed-up at all. What you actually bought is finishing with **26% of the window used instead of 74%**, so the correction rounds — where the real work happens — are cheap instead of degrading.

   Numbers from a benchmark by [Tech Leads Club](https://agent-skills.techleads.club/tlc-spec-driven/) on an 18-task epic: one codebase, one run per architecture. Treat the **shape** as established and the **number** as a hypothesis — see `.claude/docs/harness/harness-baseline.md`.

   **How to cluster:**
   - **Cohesive, not independent.** Tasks in a cluster should touch the same area and may touch the same files — one specialist runs them in order, so they cannot clobber each other. Cohesion is what gives the specialist the context that made the quality go up.
   - **Disjoint files *between* clusters**, since clusters are dispatched together. Two clusters editing the same file belong in consecutive waves.
   - **Size by tasks per specialist, not by cluster count.** Three is right for ~18 tasks. For 60, three clusters of 20 would blow each specialist's window — hold the cluster at 5-7 and accept more waves.
   - **A cluster takes the strictest gate** of the classes it contains.
   - One specialist per cluster, picked for this repo's stack from `.claude/agents/` (provided by a stack plugin). **If the project's context declares a specialist routing map** — a `specialists:` key in an imported knowledge catalog, or an equivalent table in `AGENTS.md`/`CLAUDE.md` — route each cluster to the specialist the map assigns to its task class (e.g. schema/migration vs. contract vs. everything else) instead of guessing from the stack alone; without a map, pick by stack as above. Either way, **an agent shipped by a plugin is namespaced** (`<plugin>:<agent>`, e.g. `some-stack:database`) — the name in the map must match exactly what the Agent tool accepts, or the dispatch fails to resolve. No stack specialist is a gap in the plugin — say so, and dispatch the baseline's `implementer`, which is the portable fallback. Not the built-in `general-purpose` agent, which starts with no knowledge of the repo.

   **Default dependency order** — foundational layers first: data model / schema / migration → core logic / services → interface / API / UI contract → tests. A cluster that consumes another cluster's output goes in a **later** wave; only clusters that are genuinely independent share a wave.

## Step 2 — Approval gate ⏸

Present the wave plan as a table (`wave | cluster | tasks | class | specialist | gates`) and **STOP**. Wait for the user's explicit "go" (or edits). Do not execute without approval.

The `gates` column is what Step 1 selected — showing it here is what makes the selection reviewable. A human who disagrees with a class corrects it now, not after a specialist has already run.

## Step 3 — Execute, one **wave** at a time

The wave is the **barrier**; the cluster is the **unit of dispatch**. One specialist per cluster, running its 5-7 tasks in order inside its own context — never one dispatch per task, which is the row that measured worst on every axis (Step 1).

Measured on this template's own project: **54 of 54 dispatches went out one per message**, so no wave plan ever actually fanned out.

For each wave, in the approved order:

1. **Dispatch the wave's clusters in ONE message** — one Agent call per cluster, all in a single message, which is what makes them concurrent. Not one per message (that is sequential), and not background (background is for long work you collect later in the same turn; here you are collecting immediately, and a backgrounded wave is how dispatches end up uncollected for days).

   Each dispatch carries its own **context handoff**: **all of the cluster's tasks, in order**, a one-line summary of what earlier waves already changed (files touched) so it doesn't re-discover them, the relevant `spec.md`/`plan.md` context, each task's explicit "done" criteria, "follow this repo's `.claude/rules/` and skills", and "**return only a concise summary — files changed + one paragraph for the whole cluster — not a transcript, and not one report per task**" (context discipline, see `.claude/docs/harness/context-engineering.md`).

   That last instruction is doing more work than it looks: a specialist's summary lands in the main thread, so a cluster reporting per task undoes the context saving that clustering bought.

   **For clusters whose class produces logic or tests, the handoff carries two more things:**
   - **Falsifiability, not a green run.** Before reporting done, the specialist proves its central assertions actually kill a mutation — applied to a **copy in scratchpad/tmp with the import redirected**, never to the tracked file (verification agents follow the same rule in Step 3 item 4). Denominators and arithmetic boundaries are named as an explicit case, not folded into "cover the boundaries". A claim of "equivalent mutant" is accepted only when proven **by construction against the real call site**, never by the parameter's declared type — a value arriving from a query string or an untransformed DTO routinely sits outside it (`?read[]=false` arrives as an array, not the `boolean` the type says).
   - **The run's known-bug marker** — one, chosen by the orchestrator once (the repo's own convention if it has one) and handed to every cluster, so a test that pins already-buggy behavior is recognizable in CI output instead of each cluster inventing its own.

   A wave of one cluster is fine — dispatch it and carry on. Do not pad a wave to make it look parallel.

2. **Collect all of them** before doing anything else. A wave is a barrier: you gate what the whole wave produced, not a moving target.

3. **Build gate — once, for the wave, in the foreground.** Run the `verify-before-done` skill (it discovers the repo's install → codegen → typecheck → build → tests from `AGENTS.md`). Never background a gate; a gate you do not wait for blocks nothing.
   - Red → **attribute the failure before retrying.** The cost of gating a batch is that a red does not name its author: read the failure against the files each specialist reported touching. If it is still ambiguous, gate the suspect cluster alone rather than guessing.
   - Then **hand the responsible specialist the specific failure/diagnosis so the next attempt takes a different path** (fix the root cause; re-plan or re-scope the task if needed) — never blind-retry the same approach. A correction must change the path, not just be logged. Up to **3×**. Still red, or the fix looks hacky → **STOP** and report (and record a lesson, Step 5).

4. **Test + review.** `tester` runs once for the wave, covering the union of the gates the wave's clusters selected in Step 1 (each cluster carries the strictest class it contains). `code-reviewer` runs **once per cluster**, scoped to the files that cluster's specialist reported touching — dispatch every cluster's `code-reviewer` **in one message**, same as the implementation wave. Per-cluster is the granularity that matches who wrote the code: one review across the whole wave is too coarse to catch what a review sized to one specialist's output catches, and one review per task is too fine to hold the cluster's context (`.claude/docs/harness/harness-baseline.md`, 2026-09-10). Neither `tester` nor `code-reviewer` modifies a tracked file outside its own deliverable — see the verification-agent rule in `.claude/docs/harness/dispatching.md`. Blocking findings → back to the responsible specialist.

5. **Docs gate** — for the tasks whose class selected it: ensure the relevant doc or nested `src/<folder>/CLAUDE.md` is updated (`documenting-domains`) before marking done.

6. **Check the boxes** for the wave in `tasks.md` (Edit) — only the tasks that are actually green. A task the specialist did not finish does not get a box because the rest of its cluster passed, and a cluster does not get its boxes because its wave-mates passed. Add a short inline `Note:` if useful.

7. **Next wave.**

If a task's work turned out to be bigger than its class assumed — a "config / chore" that ended up touching a service — **re-classify it and run the stricter gates** before checking its box. The class is a plan, and the diff outranks the plan.

**Document ownership** (so parallel specialists don't clobber): **clusters** in the same wave must touch **disjoint files** — that is what makes one-message dispatch safe. Inside a cluster the tasks may share files freely, because one specialist runs them in order. A specialist edits only its own task's files; `tasks.md` is **yours** to check off, not theirs; ADRs are append-only (`.claude/rules/harness/adr.md`). See the three principles in `.claude/docs/harness/principles.md`.

## Step 4 — Finish

When every box is checked: dispatch `reviewer` to review the whole branch — it runs its environment-variation checklist (timezones, locales, serial mode, random order; see `.claude/agents/reviewer.md`) rather than trusting the author's green — run the gate once more, and open a **PR to the repo's integration branch** (`main` / `develop`). **Never merge** (`protect-main` blocks it).

If `deviations.md` has any open `finding` (a production defect a test revealed, out of scope for this spec — `.claude/rules/harness/specs.md`), add a **"Findings outside scope"** section to the PR body listing each one in one line, so it does not stay invisible in a file nobody but this run reads. `finding` never blocks the PR; only `needs decision` does.

Report the PR link.

## Step 5 — Learn (the improve loop)

Maintain `$ARGUMENTS/lessons.md`: after any failure+fix, append a one-line lesson (what broke → the fix). If the **same class of mistake** happens 3+ times, propose promoting it to a `.claude/rules/` rule or a skill rule, and tell the user.

Maintain `$ARGUMENTS/deviations.md` **as you go, not at the end**: every time the run leaves the agreed plan — an assumption taken, a blocker worked around, scope changed mid-flight, a phase executed straight from `plan.md` instead of as tasks — append an entry in the format in `.claude/rules/harness/specs.md`. This is the log the human reads to find what they never approved.

Both files are yours, not the specialists'. A specialist reports what it did; you decide whether that was a deviation.

Anything you log as `needs decision` is a **STOP**, not a note. Report it and wait.

## STOP and ask a human when

- **Step 0 found drift** between `tasks.md` and the code — always, before any planning.
- A task needs a **decision**: an irreversible target (a DB/migration, a new secret/env var) or a product question.
- A **hook blocks** something (a protected-branch operation, a critical-file edit).
- The gate stays **red after retries**, or a fix would be hacky.
- `tasks.md` is **ambiguous**.
- **Stagnation / budget:** no task got checked off in the last **3** iterations, or you have run ~**10** task-iterations without finishing — halt and report status instead of spinning.

**Invariants:** never tick a box without a **fresh** green gate covering that wave (re-run it every wave; never trust a previous green); never plan waves from unreconciled checkboxes; dispatch a wave in one message, one call per cluster, never one per task; `code-reviewer` runs once per cluster, scoped to that cluster's files, never once for the whole wave; a verification agent never writes to a tracked file outside its own deliverable; never push/merge to a protected branch; one worktree per feature.
