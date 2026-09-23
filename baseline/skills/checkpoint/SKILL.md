---
name: checkpoint
description: Safe-save with verification, run the project's verification gate, commit the current work on the feature branch, then push it to the remote. A durable, known-good checkpoint you can return to even if the local directory is lost.
argument-hint: [optional commit subject]
disable-model-invocation: true
---

Create a **verified** checkpoint of the current work.

1. Confirm you are on a **feature branch**, not a protected branch (`main` / `master` / `develop`). If not, stop and ask the user to create one (`spec-worktree`).
2. Run the `verify-before-done` skill (the repo's install → codegen → typecheck → build → tests, discovered from `AGENTS.md`).
   - **Red → STOP.** Report the failure; do not commit broken code. Fix the root cause or hand back to the user.
3. Green → stage and commit the coherent change with a Conventional Commit message (use `$ARGUMENTS` as the subject if given, else infer one). One logical change per checkpoint.
4. **Push the branch to the remote. This is the default, not an extra step to ask about.** `git push` (`-u origin <branch>` on the first push). A commit that only exists in a directory that can be deleted, lost, or never returned to is not durable; pushing the feature branch is what makes it survive that. Handle the cases honestly instead of silently skipping:
   - **No remote configured:** skip the push, say so in the report, and note the checkpoint is local-only until one exists.
   - **Push rejected, diverged from the remote:** never force-push. Stop, report the divergence, and hand back to the user rather than guessing which side wins.
   - **Offline, or the push fails for network reasons:** skip, report the failure, and say the checkpoint is committed but not yet pushed. Retry the push once connectivity is back.
   - **The user has explicitly said this branch stays local** (a throwaway experiment, nothing to share yet): skip the push and say why in the report, rather than pushing over an explicit instruction.
5. If a spec is active, tick any newly-completed boxes in `tasks.md` and update `Last updated`.
6. Report: the commit, whether it was pushed (or which of the cases above applied), what was verified, and the next unchecked task.

Never checkpoint on a red gate: a checkpoint means "this is known-good". Never push or merge to a protected branch.

**A checkpoint is not a PR and not a merge.** Pushing a feature branch makes the commit durable; it does not publish, review, or ship anything. Nobody should read "pushed" as "shipped".
