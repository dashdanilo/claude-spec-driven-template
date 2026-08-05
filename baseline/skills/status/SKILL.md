---
name: status
description: Project health card — the active spec/phase, unchecked tasks, gate status, branch, and snapshot staleness at a glance. Read-only.
---

Report a compact status card. Read state; change nothing.

- **Branch / worktree** — the current branch; flag if it is a protected branch.
- **Active spec** — the most recent `specs/<slug>/` and its status (Draft / Approved / In progress / Done).
- **Progress** — from `tasks.md`: total tasks, how many checked, and the first unchecked one (where work resumes).
  - **Sanity-check it.** If the branch has commits the checkboxes do not reflect, the count is stale — say `progress: N/M (suspeito — reconciliar)` instead of reporting a number you do not believe. A stale count is worse than no count: `/orchestrate` and `/wave` plan from it.
- **Gates** — last known: spec-reviewer verdict, `verify-before-done` result (run it only if cheap, else report the last known), and any open PR for this branch.
  - Flag any **known-red** test that everyone has learned to ignore. A gate with permanent red is not a gate.
- **Lessons** — `lessons.md` entries for the active spec, and any class of failure that appears 3+ times across specs (candidate for promotion to `.claude/rules/`).
- **Deviations** — open entries in `deviations.md`: count them, and list every `needs decision` in full. Those are things the run did that nobody approved, and they age badly — an unresolved deviation is a spec that no longer describes the code.
- **Background agents** — any dispatched in the background and never collected. They cost tokens and block nothing.
- **Snapshot** — Repomix snapshot staleness (`.claude/scripts/check-snapshot.sh`).
- **Uncommitted** — a one-line `git status --short` summary (count of changed files).

Keep it to a short card. Point at files and PRs; do not paste them.
