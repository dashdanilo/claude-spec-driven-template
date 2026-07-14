---
description: Safe-save with verification — run the project's verification gate, then commit the current work on the feature branch. A durable, known-good checkpoint you can return to.
argument-hint: [optional commit subject]
---

Create a **verified** checkpoint of the current work.

1. Confirm you are on a **feature branch**, not a protected branch (`main` / `master` / `develop`). If not, stop and ask the user to create one (`spec-worktree`).
2. Run the `verify-before-done` skill (the repo's install → codegen → typecheck → build → tests, discovered from `AGENTS.md`).
   - **Red → STOP.** Report the failure; do not commit broken code. Fix the root cause or hand back to the user.
3. Green → stage and commit the coherent change with a Conventional Commit message (use `$ARGUMENTS` as the subject if given, else infer one). One logical change per checkpoint.
4. If a spec is active, tick any newly-completed boxes in `tasks.md` and update `Last updated`.
5. Report: the commit, what was verified, and the next unchecked task.

Never checkpoint on a red gate — a checkpoint means "this is known-good". Do not push or merge to a protected branch.
