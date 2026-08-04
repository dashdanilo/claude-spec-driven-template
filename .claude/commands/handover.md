---
description: Produce a session handover — a compact, high-signal statement of what is true now: what changed, where it stands, what is undecided, so a new session or agent can continue without re-deriving context. Ends by closing the session.
---

Write a handover for whoever picks this up next (human or a fresh agent). Follow context discipline (`.claude/docs/context-engineering.md`): conclusions and pointers, not a transcript.

## The rule that shapes everything below: state, not instructions

**Describe what *is true*, never what the next agent *should do*.** Write "the auth endpoint is implemented; logout is not started" — not "implement logout next."

This is not style. An instruction written now ages worse than a fact: *"implement logout next"* becomes wrong the moment priorities change or someone else does it, while *"logout is not started"* stays true until someone touches it. And the fresh agent has context you do not — it should decide the action from ground truth.

The same principle runs through `.claude/rules/specs.md` (claims verified, not copied), Step 0 below, and `deviations.md` (what happened, not what to do about it). The single exception is the one resume line in the cut at the end.

## Step 0 — Reconcile the state before writing about it ⚠️

**Do this first, always.** A handover written on top of a stale `tasks.md` documents a fiction.

1. If a spec is active, compare `tasks.md` against **reality** — the code, the commits, the merged PRs. Tick every box that is actually done. Do not trust the existing count. (Same audit as `/orchestrate` Step 0, from the other end: that one reconciles before planning, this one before narrating. If you change what "reconcile" means, change both.)
2. If work happened outside the pipeline (edits in the main thread, phases done straight from `plan.md`), those boxes were never ticked by anyone. Those are exactly the ones to fix.
3. If a task shipped but its checkbox cannot be honestly ticked (partially done, or done differently), say so **in the box's line**, not only in the prose below.
4. Update `Last updated`.

Prose and checkboxes are two states of the same file, and only one of them is machine-readable. When they disagree, the next `/orchestrate` or `/wave` plans from the checkboxes — so a beautiful narrative on top of 78 stale boxes still produces a garbage wave plan. Reconcile first; then narrate.

**Also check `lessons.md`:** if the same class of failure appears 3+ times (here or in sibling specs), propose promoting it to a `.claude/rules/` rule or a skill, and put that proposal in the handover's open decisions. A lesson that never gets promoted will be re-learned at full price.

**And read `deviations.md`:** every entry still marked `needs decision` goes into the handover's open decisions verbatim — that file is the raw material for that section, not a separate concern. An `accepted` deviation that the spec still contradicts is worth one line too: the next reader will otherwise trust the spec.

## Include

1. **Goal / scope** — what this stretch of work is trying to achieve (1-2 lines).
2. **Done** — what changed, as a short list (area + one-line why). Reference commits/PRs by number.
3. **Current state** — where each thread actually stands: the first unchecked box in `tasks.md`, what is half-done on the branch, what is merged, what is open. Facts, in the present tense.
4. **Open decisions / blockers** — anything waiting on a human, with the options considered and the trade-off, but **without picking for them**. This is where `deviations.md` entries marked `needs decision` land.
5. **Not started** — the named things nobody has begun. This is how a handover conveys scope without turning into a to-do list: *"governance is not started"* is a fact; *"do governance next"* is an instruction that expires.
6. **Pointers** — branch, PR links, spec folder, relevant file paths (paths, not contents).

There is deliberately no "next steps" section. The one forward-looking line lives in the cut at the end, where it belongs — at the resume point, singular, and cheap to discard when it is wrong.

## Reference, don't duplicate

If a fact already lives in a PR description, an ADR, a commit message, or the spec, **point at it — do not restate it**. A handover that re-embeds content becomes a second copy that drifts from the first, and the reader then has two versions and no way to tell which is current.

This is stronger than "don't paste diffs": it also rules out summarizing an ADR's reasoning, restating a spec's requirements, or re-explaining what a merged PR did. Name it, link it, move on.

## Frame claims as claims

Everything in a handover is prose about state, and prose ages — including this document, from the moment it is written. Say so in it, and mark anything that was **not** verified in this session as unverified rather than presenting it as confirmed. `.claude/rules/specs.md` applies to a handover as much as to a spec: the confident, well-written paragraph is the dangerous one, because it reads as settled.

## Where to put it

- If a spec is active, append/update a `## Handover` section at the bottom of `specs/<slug>/tasks.md` (durable and re-findable).
- Otherwise, output it in chat.
- **Either way, also print it in chat as a single fenced block**, so the person opening a fresh session can copy it in one gesture. The file is the durable copy; the block is the one that actually gets carried across the cut.

Do not dump file or tool output — link and point to it. This is a map, not the territory.

## Last step — close the session ✂️

A handover is only half the move. Externalizing state has no effect on context weight: the session keeps carrying everything it carried before. **`/handover` externalizes; `/clear` discards. One without the other does nothing.**

So end every handover with an explicit cut, exactly like this:

```
✂️ State is on disk in specs/<slug>/tasks.md § Handover — safe to clear.
   Resume with: /status  (or open the worktree ../<repo>.<slug> in a fresh session)
   Most likely first move: <one line — the only forward-looking sentence in the whole handover>
```

Then **stop and say nothing else.** Do not start the next task in the same session — that is precisely the habit that produces 400-hour context windows.

You cannot run `/clear` yourself: it is a client-side command, and a project command cannot clear the session it is running in. Your job is to make it a single keystroke and to make clearing obviously safe — which Step 0 already guaranteed, because the state on disk is now true.

**Why bother, if the cache makes long context cheap:** it makes it cheap, not good. A session that spans weeks still has hour-3 competing for attention with hour-400 on every dispatch. Measured on a real project: 19 sessions, several past 400 hours, **8 handovers written and zero `/clear`** — the notes were written and the session rolled on anyway.

Rule of thumb: one session per worktree. The worktree is already the feature boundary — make it the session boundary too.
