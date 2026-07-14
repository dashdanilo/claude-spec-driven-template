# Feature pipeline

The end-to-end path from an idea to an open PR: the spec-driven flow, specialist agents, the `verify-before-done` gate, and one worktree per feature. **Supervised-autonomous** — drive it step by step, or hand the loop to the `/orchestrate` command to work through `tasks.md` on its own, stopping on any red gate.

> **Portable spine.** The pipeline (spec → worktree → implement → gate → review → PR) is stack-agnostic. A **stack plugin** fills in the specialist agents and the exact build/test commands; `verify-before-done` discovers those commands from `AGENTS.md`.

## Agents and responsibilities

| Agent | Does |
|---|---|
| `codebase-explorer` | read-only recon before writing a spec |
| `spec-reviewer` | audits `spec.md` before it becomes plan/tasks |
| stack specialists (from a plugin) | implement the change in their layer (e.g. data / API / UI) |
| `tester` | writes and runs tests, discovers the framework |
| `code-reviewer` | per-phase review vs the active spec/plan/tasks |
| `reviewer` | whole-branch review, runs the gate, opens the PR |

## Pipeline

```
0. explore ─▶ 1. write-spec ─▶ 2. spec-reviewer ═╗ (spec gate)
                                                 ▼
3. spec-worktree (branch from main/develop)
                                                 ▼
   ┌───────────────── loop over tasks.md ───────────────────┐
   │ 4. implement next unchecked task (stack specialist)    │
   │ 5. GATE verify-before-done  ── red ──▶ fix, back to 4  │
   │ 6. tester: tests for the area ── red ─▶ fix, back to 4 │
   │ 7. code-reviewer            ── blocking ─▶ back to 4   │
   │ 8. check the box ─▶ more tasks? back to 4              │
   └────────────────────────────────────────────────────────┘
                                                 ▼
9. reviewer: whole-branch review + gate ─▶ opens PR
10. human merges (protect-main blocks direct merge) ─▶ cleanup worktree
```

## Gates (must be green to advance)

1. **Spec gate** — `spec-reviewer` approves `spec.md` (scope, clarity, out-of-scope). `write-spec` runs it automatically.
2. **Build gate** — `verify-before-done` green: install → codegen → typecheck → build → tests, discovered from `AGENTS.md`.
3. **Test gate** — the repo's tests green for the touched area (`tester`).
4. **Review gate** — `code-reviewer` (auto per phase) and `reviewer` (branch) have no blocking findings.

A red gate never advances. The loop fixes the root cause and re-runs. **The pipeline ends at an open PR — never auto-merge** (`protect-main` blocks direct merges to protected branches).

## Variants

- **Full feature** — all steps (explore → spec → worktree → loop → PR).
- **Quick fix** — skip the spec: branch → reproduce the bug as a failing test (`tester`) → fix → build + test gates → `reviewer` → PR.
- **Docs-only** — skip the build/test gates; `reviewer` for correctness of the docs, then PR.

## The loop (supervised, and autonomous)

- **Supervised (`/loop`):** `/loop implement the next unchecked task in specs/<slug>/tasks.md; run verify-before-done; if green check the box, else fix and retry` — one task per pass.
- **Orchestrated (`/orchestrate <spec folder>`):** the command reads `tasks.md`, plans waves, dispatches each task to the stack specialist, runs the gate + `tester` + `code-reviewer`, checks the box, and repeats — halting on a red gate or anything ambiguous.

## Non-negotiables

- Never commit to a protected branch — branch (`<type>/<slug>`) and open a PR.
- Don't advance a red gate, and never claim "done" without `verify-before-done`.
- One worktree per feature (`spec-worktree`), shared across the feature's tasks.
