---
paths: "**"
---

# Git workflow

Conventions for branches, commits, and pull requests. Applies whenever an agent performs git operations in this repo.

## Branches

Never commit directly to `main` or `master`. Create a feature branch first.

Format: `<type>/<short-slug>` in kebab-case.

Valid types:

- `feature/` - new functionality
- `fix/` - bug fix
- `hotfix/` - urgent production fix
- `refactor/` - change that doesn't alter behavior
- `docs/` - documentation only
- `chore/` - build, deps, config
- `test/` - tests only

Good examples:

- `feature/dark-mode`
- `fix/lead-form-validation`
- `refactor/extract-auth-lib`
- `chore/upgrade-nextjs-15`

Bad examples (avoid):

- `dev`, `working`, `temp` - not descriptive
- `<username>/dark-mode` - personal prefix doesn't scale in a team
- `feature-dark-mode` - uses hyphen instead of slash
- `feature/2026-06-21-dark-mode` - date belongs in the spec folder, not the branch name

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
