---
name: spec-worktree
description: Creates and manages one git worktree per feature so a feature branch is worked on in isolation, in its own sibling directory, without switching branches in the main checkout. Use when starting to implement a feature (moving from spec/plan into execution), when the user wants to work on multiple features in parallel, or says "work on this in a worktree", "create a worktree", "spin up a worktree for X". Also handles listing and cleaning up worktrees. Delegates the mechanics to `.claude/scripts/harness/spec-worktree.sh`.
disable-model-invocation: true
---

# Spec worktree

One worktree per **feature**, not per plan. A feature branch (`<type>/<slug>`) lives in its own sibling directory `../<repo>.<slug>`. Several specs and plans that belong to the same feature share that one worktree.

This skill is the decision layer. The mechanics (git worktree, symlinks, snapshot seeding, cleanup) live in `.claude/scripts/harness/spec-worktree.sh` so a human or any agent can run them without Claude.

## When to invoke

- The user is about to **start implementing** a feature and wants it isolated
- The user wants to work on **several features in parallel**
- The user says "worktree", "trabalhar num worktree", "spin up a worktree for X"
- After a spec is approved and the plan is ready, before executing `tasks.md`

Do NOT create a worktree per `plan.md`. If a feature has multiple plans, they all execute in the same worktree.

## Create a worktree

```bash
.claude/scripts/harness/spec-worktree.sh <slug> [--type <type>]
```

- `<slug>` is the feature slug in kebab-case (same slug family as the spec folder, without the date prefix).
- `--type` defaults to `feat`. Valid: `feat fix hotfix refactor docs chore test` (the Conventional Commits / commitlint types; see `.claude/rules/git-workflow.md`).
- The branch is always created **from the latest remote default branch** — `origin/HEAD` (`origin/main` on most repos, but whatever the remote actually points at, e.g. `origin/develop`), falling back to `origin/main` then local `main` (the script fetches first).
- The script provisions gitignored local files into the new worktree: it **symlinks** `CLAUDE.local.md`, `.claude/settings.local.json`, `.claude/context/config.json` (single source of truth), and **copy-seeds** `.claude/context/repomix-snapshot.md` (regenerable per-branch cache).
- If the repo has an executable `script/setup` at its root (the Scripts to Rule Them All convention — see `docs/guides/script-setup-and-test.md`), it runs it inside the new worktree right after provisioning, taking the worktree from "created" to "ready to work in" (deps installed, env file provisioned, codegen run). Pass `--no-setup` to skip it. A repo without `script/setup` is unaffected — this step is a no-op, not a warning.
- If `script/setup` fails, the worktree is **kept, never deleted** — the script exits non-zero (3) and tells you where the worktree is and that the environment did not come up. Fix the issue and rerun `script/setup` by hand inside the worktree.

The script prints the new worktree path on stdout. **You cannot `cd` the user's shell from a subprocess**, so after creating, tell the user to move into it and launch Claude there:

```bash
cd "../<repo>.<slug>" && claude
```

Each worktree is best opened as its own editor window so the file view is scoped to that feature.

## List, remove, prune

```bash
.claude/scripts/harness/spec-worktree.sh --list            # what exists (git worktree list)
.claude/scripts/harness/spec-worktree.sh --remove <slug>   # remove one worktree (keeps the branch)
.claude/scripts/harness/spec-worktree.sh --prune           # remove worktrees whose branch is merged into the default branch
```

Worktrees are **not** removed automatically on merge — you may still need one. Clean up deliberately, later, with `--remove` or `--prune`. `--prune` skips any worktree that has uncommitted changes.

## What NOT to do

- Do not create a worktree per plan. One per feature.
- Do not write `script/setup` yourself — it is project-owned, not something this skill or the harness generates. If it does not exist, note the gap and let the human write it (see `docs/guides/script-setup-and-test.md`).
- Do not base the branch on anything but the remote's default branch. Always fresh from it (not local `main`, not a stale checkout).
- Do not nest the worktree inside the repo. It is a flat sibling (`../<repo>.<slug>`), so git never sees it and it can't be committed by accident.
- Do not symlink the Repomix snapshot. It is per-branch and gets rewritten when stale; sharing it corrupts main's copy. The script copies it once and the existing staleness mechanism refreshes it in-place.
- Do not remove a worktree just because its PR merged, unless the user asks. Keep it until cleanup.

## Claude Code note

Claude Code also has a native worktree feature that creates worktrees under `.claude/worktrees/`. That is Claude-only and uses a different (in-repo) layout. This skill deliberately uses the portable sibling convention so the same flow works in the terminal and in other agents.
