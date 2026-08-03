---
description: Produce a session handover — a compact, high-signal summary of what changed, current state, open decisions, and next steps, so a new session or agent can continue without re-deriving context.
---

Write a handover for whoever picks this up next (human or a fresh agent). Follow context discipline (`.claude/docs/context-engineering.md`): conclusions and pointers, not a transcript.

## Step 0 — Reconcile the state before writing about it ⚠️

**Do this first, always.** A handover written on top of a stale `tasks.md` documents a fiction.

1. If a spec is active, compare `tasks.md` against **reality** — the code, the commits, the merged PRs. Tick every box that is actually done. Do not trust the existing count.
2. If work happened outside the pipeline (edits in the main thread, phases done straight from `plan.md`), those boxes were never ticked by anyone. Those are exactly the ones to fix.
3. If a task shipped but its checkbox cannot be honestly ticked (partially done, or done differently), say so **in the box's line**, not only in the prose below.
4. Update `Last updated`.

Prose and checkboxes are two states of the same file, and only one of them is machine-readable. When they disagree, the next `/orchestrate` or `/wave` plans from the checkboxes — so a beautiful narrative on top of 78 stale boxes still produces a garbage wave plan. Reconcile first; then narrate.

**Also check `lessons.md`:** if the same class of failure appears 3+ times (here or in sibling specs), propose promoting it to a `.claude/rules/` rule or a skill, and put that proposal in the handover's open decisions. A lesson that never gets promoted will be re-learned at full price.

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

## Last step — close the session ✂️

A handover is only half the move. Externalizing state has no effect on context weight: the session keeps carrying everything it carried before. **`/handover` externalizes; `/clear` discards. One without the other does nothing.**

So end every handover with an explicit cut, exactly like this:

```
✂️ Estado externalizado em specs/<slug>/tasks.md § Handover — pode limpar.
   Próximo passo: <a primeira ação concreta>
   Retomar com: /status (ou abra a worktree ../<repo>.<slug> numa sessão nova)
```

Then **stop and say nothing else.** Do not start the next task in the same session — that is precisely the habit that produces 400-hour context windows.

You cannot run `/clear` yourself: it is a client-side command, and a project command cannot clear the session it is running in. Your job is to make it a single keystroke and to make clearing obviously safe — which Step 0 already guaranteed, because the state on disk is now true.

**Why bother, if the cache makes long context cheap:** it makes it cheap, not good. A session that spans weeks still has hour-3 competing for attention with hour-400 on every dispatch. Measured on a real project: 19 sessions, several past 400 hours, **8 handovers written and zero `/clear`** — the notes were written and the session rolled on anyway.

Rule of thumb: one session per worktree. The worktree is already the feature boundary — make it the session boundary too.
