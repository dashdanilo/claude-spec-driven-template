---
paths: "**"
---

# Git workflow

Conventions for branches, commits, and pull requests. Applies whenever an agent performs git operations in this repo.

## Branches

Never commit directly to `main` or `master`. Create a feature branch first.

Format: `<type>/<short-slug>` in kebab-case.

The `<type>` mirrors the Conventional Commits / commitlint types (see the Commits section), so a branch and its commits share the same vocabulary.

Valid types:

- `feat/` - new functionality
- `fix/` - bug fix
- `hotfix/` - urgent production fix
- `refactor/` - change that doesn't alter behavior
- `docs/` - documentation only
- `chore/` - build, deps, config
- `test/` - tests only

Good examples:

- `feat/dark-mode`
- `fix/lead-form-validation`
- `refactor/extract-auth-lib`
- `chore/upgrade-nextjs-15`

Bad examples (avoid):

- `dev`, `working`, `temp` - not descriptive
- `<username>/dark-mode` - personal prefix doesn't scale in a team
- `feat-dark-mode` - uses hyphen instead of slash
- `feat/2026-06-21-dark-mode` - date belongs in the spec folder, not the branch name

## Worktrees

Optional but recommended for parallel work: each feature branch lives in its own git worktree so you can work several features at once without switching branches in the main checkout.

**One worktree per feature, not per plan.** A feature may span multiple specs/plans; they all share the one worktree and commit to the one branch.

Convention:

- Path: `../<repo>.<slug>` - a flat sibling directory (dot separator, no nesting), so git never sees it and it can't be committed by accident
- Branch: `<type>/<slug>`, always created fresh from the remote's default branch (`origin/HEAD` - `origin/main` on most repos, but whatever the remote actually points at, e.g. `origin/develop`)
- Not removed on merge - clean up deliberately later

Use the helper (it also provisions gitignored local files - symlinks `CLAUDE.local.md` / `.claude/settings.local.json` / `.claude/context/config.json`, and copy-seeds the Repomix export if main happens to have one):

```bash
.claude/scripts/harness/spec-worktree.sh <slug>            # create + branch from the remote's default branch
.claude/scripts/harness/spec-worktree.sh --list            # list worktrees
.claude/scripts/harness/spec-worktree.sh --remove <slug>   # remove one (keeps the branch)
.claude/scripts/harness/spec-worktree.sh --prune           # remove worktrees whose branch is merged
```

After creating, open the worktree as its own editor window and launch your agent from inside it:

```bash
cd "../<repo>.<slug>" && claude
```

Agents: the `spec-worktree` skill wraps this with the when/how. See also `.claude/scripts/harness/README.md`.

### Where the work happens

Before writing the first line of code for a task, ask the human **where**, offering three options:

1. **local**, on the checkout's current branch.
2. **the agent tool's own worktree**, if the tool provides one (in Claude Code, `EnterWorktree`: the session moves into `.claude/worktrees/<name>`, the app shows an indicator, and on exit it asks whether to keep or remove it).
3. **`spec-worktree`** (above): a flat sibling `../<repo>.<slug>`, harness linked, `script/setup` run if present, worked from its own session.

If the human does not answer within 5 minutes, proceed with `spec-worktree` and say so.

**Mechanics.** A blocking question dialog has no timeout, so ask as plain text in the conversation and start a background timer alongside it: a backgrounded shell command that sleeps roughly 300 seconds and exits, which notifies the agent when it fires. If it fires with no answer, proceed with the default and state the choice; do not poll for a reply in the meantime.

**Why the two worktree mechanisms are not interchangeable.** The agent tool's own worktree lives *inside* the repo, under `.claude/worktrees/`, so a stale one keeps a full copy of whatever the repo held at that moment, and nothing prunes it automatically. On 2026-09-23 that is exactly what made `harness-score` report `njord-back` as L4 (99/108): a leftover `.claude/worktrees/<name>/` directory still held an old, fully vendored copy of 48 skills and 20 agents, and the scanner counted it in full. `spec-worktree` puts the tree outside the repo, at `../<repo>.<slug>`, where no scan ever sees it. See `docs/guides/harness-score.md` for the full mechanism.

### When a worktree's life ends

Two kinds of worktree end differently.

**Created only to produce a PR: dies when the PR opens.** The branch lives on the remote and the PR lives on GitHub; keeping the directory afterward buys nothing, and if review asks for changes the worktree is recreated in seconds from the branch (`spec-worktree.sh <slug>`).

**Has work in progress: stays.** Uncommitted changes, commits not yet pushed anywhere, or an experiment someone will come back to: none of that lives anywhere but the worktree, so it stays until whoever owns it is done with it. Running `checkpoint` closes that gap for anything already worth keeping: it commits and pushes, so `git log @{u}..` goes empty and the worktree stops being the only place that work exists.

Before removing one, check it is safe to lose nothing:

```bash
git status -s      # empty: no uncommitted changes
git log @{u}..      # empty: nothing unpushed
```

Delete the **local** branch only once its PR has merged; keep it while the PR is open (the remote already has the branch, and a local copy costs nothing while it saves a fetch if the PR needs another commit).

Removing a worktree is not the same as deleting work: the branch and its commits survive on the remote either way. Hoarding worktrees comes from fearing otherwise, and that fear does not apply here.

A stale worktree left inside the repo also distorts `harness-score`; see the note above and `docs/guides/harness-score.md`.

## Commits

**Format: Conventional Commits.**

```
<type>(<scope>): <short description>

[optional body with additional context]

[optional footer: BREAKING CHANGE, Closes #123, etc]
```

Common types:

- `feat` - new functionality
- `fix` - bug fix
- `refactor` - change that doesn't alter behavior
- `docs` - documentation only
- `chore` - build, deps, config, cleanup
- `test` - tests only
- `style` - formatting (not CSS)
- `perf` - optimization
- `revert` - undoes a previous commit

Scope is optional but helps. Use the module or area name:

- `feat(auth): add magic link login`
- `fix(lead): normalize phone to E.164 before submit`
- `refactor(api): extract error handler middleware`
- `docs(readme): update install instructions`
- `chore(deps): bump next to 15.2`

**Strict rules:**

- Description in imperative present ("add", "fix", "remove"), not past ("added", "fixed")
- Description in lowercase, no trailing period
- Max 72 characters on the first line
- Body separated by a blank line, each line max 100 characters
- One commit = one logical, coherent change

**BREAKING CHANGE** goes in the footer:

```
feat(api)!: rename user.email to user.emailAddress

BREAKING CHANGE: consumers must update the field name in payloads.
Migration: replace `user.email` with `user.emailAddress` in all clients.
```

## Commit frequency

One commit per task completed in `tasks.md`. Do not accumulate 5 tasks in one commit.

If you ever need to undo, you want the granularity to be fine.

## Squash vs merge vs rebase

- **PR merge (GitHub default):** every commit from the branch stays in history. Preserves detailed context.
- **PR squash merge:** all commits collapse into one on main. Cleaner history, loses granularity.
- **PR rebase merge:** commits are replayed linearly. Linear history without merge commits.

Recommendation for teams to define and document. This template does not enforce a choice.

## Branching, merging and the four rules that came from breaking them

These are not style. Each one is here because skipping it put someone else's
unreviewed work on a shared branch.

### Branch from the remote ref, never from the local branch

```bash
git checkout -b feat/x origin/main      # correct
git checkout main && git pull && git checkout -b feat/x   # not this
```

`origin/main` here stands for the remote's default branch, not a fixed literal —
on most repos that is `origin/main`, but the actual ref is whatever `origin/HEAD`
points at (`origin/develop` on a repo whose integration branch is `develop`, for
example). Resolve it once (`git symbolic-ref refs/remotes/origin/HEAD`) rather
than hardcoding `main`.

The second looks equivalent and is not. If the local branch carries commits that
were never pushed — your own work in progress, an old propagation, anything —
your new branch inherits them, and they ride into the PR under your change's
title. Branching from the remote ref cannot pick up what the remote does not have.

This matters most in exactly the situation where you are least likely to check:
a script looping over several repositories.

### Read the file list before merging your own PR

```bash
gh pr view <n> --json files --jq '.files[].path'
```

A PR you opened by hand you already know. A PR opened by a script you do not, and
the title tells you nothing — it says what you *meant* to change. If the list
contains a file you cannot explain, stop.

Note that `gh pr view` shows the diff against the base *as GitHub sees it*, which
is the honest one; a local `git diff` against a stale branch can look clean while
the PR is not.

### Never `--admin` on a repository other people share

`gh pr merge --admin` bypasses branch protection. Used on your own repo to
unblock yourself it is fine. Used on a shared repo it removes the review that
exists precisely to catch the previous two mistakes, and it removes it silently —
the merge looks identical to a reviewed one afterwards.

If protection is genuinely in the way, say so and let a human decide, rather than
routing around it.

**Why this is a rule after one occurrence** rather than the usual three: the
failure mode is someone else's unreviewed code landing on a protected branch. The
cost of the mistake is not paid by the person who makes it, and it is invisible
once merged.

### Merge a stacked PR by deleting its branch

```bash
gh pr merge <n> --squash --delete-branch
```

A stacked PR is one whose base is another feature branch instead of the
integration branch. Merging the bottom PR **and deleting its branch** is what
makes GitHub retarget the PRs above it onto the integration branch. Leave the
branch alive and the PR on top merges into a branch that is already dead: the
merge succeeds, the PR shows *Merged*, and the content never reaches the
integration branch.

On 2026-09-11 in `dashdanilo/claude-spec-driven-template`, #45 was stacked on
#44's branch. #44 was merged without deleting `fix/install-link-docs-and-scripts`,
#45 was merged right after and landed in that dead branch, and nothing of it
reached `main`. It had to be reapplied in #47.

Two checks catch this before the merge, and the second one catches its
neighbour too:

```bash
gh pr view <n> --json baseRefName,headRefOid   # base is the one you expect, head is the commit you pushed
gh pr merge <n> --match-head-commit <sha>      # refuses to merge if the head moved
```

The neighbour: #42 was merged while GitHub was still showing an older head, and
its last commit (`f81a2f4`) never reached `main` either. That one was reapplied
inside #44.

**Why this is a rule:** both failures report success. Nothing turns red, the PR
says *Merged*, and the only symptom is content missing from the integration
branch, noticed days later, if at all, and then paid for a second time as a
reapply. A rule is cheaper than the archaeology.

## Pull requests

**Before opening a PR:**

- Run `pnpm typecheck` and `pnpm lint` locally, both green
- Run `pnpm test` locally, everything green
- Verify all tasks in `tasks.md` are checked
- Rebase the branch on top of the latest main

**PR description:**

Reference the spec:

```markdown
Implements [`specs/2026-06-21-dark-mode/`](specs/2026-06-21-dark-mode/spec.md)

## Summary
One paragraph summarizing what changes.

## Tasks completed
See `tasks.md` in the spec folder. All boxes checked.

## Testing
- Unit: pnpm test src/features/dark-mode
- Manual: verified in Chrome, Firefox, Safari

## Screenshots (if UI)
...
```

**After merge:**

- Delete the remote branch
- Update the `spec.md` of the feature: status to `Done`
- If applicable, extract durable learnings (nested CLAUDE.md, docs/patterns/, ADR)

## Do not

- Do not commit `WIP` as message
- Do not commit generated files (`dist/`, `.next/`, etc - should be in `.gitignore`)
- Do not commit `console.log`, `debugger`, forgotten `// TODO: remove` comments
- Do not commit credentials, tokens, or secrets (see `block-secrets.sh` hook)
- Do not `git push --force` on a shared branch (local rebase ok if working alone)
- Do not mix refactor with feature in the same commit
