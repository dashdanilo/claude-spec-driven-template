---
description: Produce a session handover — a compact, high-signal summary of what changed, current state, open decisions, and next steps, so a new session or agent can continue without re-deriving context.
---

Write a handover for whoever picks this up next (human or a fresh agent). Follow context discipline (`.claude/docs/context-engineering.md`): conclusions and pointers, not a transcript.

## Include

1. **Goal / scope** — what this stretch of work is trying to achieve (1-2 lines).
2. **Done** — what changed, as a short list (area + one-line why). Reference commits/PRs by number; do **not** paste diffs.
3. **In progress** — the current task and exactly where it stands (the first unchecked box in `tasks.md`, or the branch + what's half-done).
4. **Open decisions / blockers** — anything waiting on a human, with the options considered.
5. **Next steps** — the concrete next 1-3 actions.
6. **Pointers** — branch, PR links, spec folder, relevant file paths (paths, not contents).

## Where to put it

- If a spec is active, append/update a `## Handover` section at the bottom of `specs/<slug>/tasks.md` (durable and re-findable).
- Otherwise, output it in chat.

Do not dump file or tool output — link and point to it. This is a map, not the territory.
