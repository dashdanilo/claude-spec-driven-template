---
paths: "specs/**"
---

# Specs — claims must be verified, not copied

## The rule

- **Every claim about the current state of the system is verified against the code, the schema, or git — at the moment of writing.** Not copied from an existing doc, however well written.
- **A spec written or edited by hand still goes through `spec-reviewer`.** `write-spec` invokes it automatically; a spec you typed yourself does not get that for free, and it is exactly the one nobody audited.
- **A referenced "pending fix" is checked before it becomes a task.** Branches and closed PRs go stale in both directions.

## Prose is a record, not a source

An existing spec's narrative says what was true **when someone wrote it**. A dated header (`Onde paramos (2026-07-16)`) is a warning label, not an authority. The older and more confident the prose, the more it deserves a check — a well-written stale paragraph is more dangerous than a scrappy one, because it reads as settled.

This cuts both ways, and the second direction is the one people miss:

| direction | what you find | cost of not checking |
|---|---|---|
| work claimed done, actually pending | the checkboxes lied optimistically | you ship a gap |
| **work claimed pending, actually done** | the debt was paid and nobody updated the doc | **you plan and execute work that already exists** |

## The cheapest check for a "pending fix"

When a doc says a fix is waiting on a branch or a closed PR:

```bash
git cherry-pick <sha>     # empty result = the content is already in your base
```

**A cherry-pick that comes back empty is the tell.** It means the change was re-applied under a different commit or PR number, so searching for the original PR finds it closed and you conclude, wrongly, that the work is pending. Check the file, not the PR status.

Same idea without applying anything: `git log --oneline <base> -- <the file>` and read what actually landed.

## Deviations go in `deviations.md`, not in the artifact they contaminated

Long or autonomous runs depart from the plan. That is not a failure — silently absorbing it is. When execution leaves what was agreed, append to `specs/<slug>/deviations.md`:

```markdown
## <date> — <one-line what changed>
- **Agreed:** <what the plan/tasks said>
- **Did:** <what actually happened>
- **Why:** <the reason, including the blocker or assumption that forced it>
- **Consequence:** <what is now true that the plan does not describe>
- **Status:** accepted | to revert | needs decision
```

Four things belong here: an **assumption** taken without confirmation, a **blocker** worked around, a **scope change** decided mid-flight, and work executed **outside the pipeline** (phases run straight from `plan.md`, edits made in the main thread — neither ever gets a checkbox ticked by anyone).

Do not write them into `tasks.md`. Checkboxes are machine-readable and prose is not; a narrative wedged between boxes is read by humans and ignored by the next wave plan, which is the worst of both.

`needs decision` is the only status that blocks. It is the one a `/handover` must surface and a reviewer must resolve.

## Why this is a rule

Measured, on this template's own work: a follow-ups spec was written from a three-week-old header that said two tests were failing. They had been fixed and merged under a different PR number. The spec, its task list, and a published PR description all carried the wrong premise — and the block was ranked priority 1, so it would have been the next thing built.

The defense already existed (`write-spec` hands the spec to `spec-reviewer` to verify claims against the codebase). It was skipped because the spec was written by hand. A guard that only fires on the happy path is not a guard.
