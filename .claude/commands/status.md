---
description: Project health card — the active spec/phase, unchecked tasks, gate status, branch, and snapshot staleness at a glance. Read-only.
---

Report a compact status card. Read state; change nothing.

- **Branch / worktree** — the current branch; flag if it is a protected branch.
- **Active spec** — the most recent `specs/<slug>/` and its status (Draft / Approved / In progress / Done).
- **Progress** — from `tasks.md`: total tasks, how many checked, and the first unchecked one (where work resumes).
- **Gates** — last known: spec-reviewer verdict, `verify-before-done` result (run it only if cheap, else report the last known), and any open PR for this branch.
- **Snapshot** — Repomix snapshot staleness (`.claude/scripts/check-snapshot.sh`).
- **Uncommitted** — a one-line `git status --short` summary (count of changed files).

Keep it to a short card. Point at files and PRs; do not paste them.
