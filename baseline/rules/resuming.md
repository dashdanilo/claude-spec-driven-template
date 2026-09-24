---
paths: "**"
---

# Resuming: where to look before re-deriving context

When the human says "continue", "what's pending", "where are we", or anything
else that asks you to pick work back up, look for state that already exists
before you reconstruct it from the code. This rule loads always, because
resuming is not tied to any one file type.

## Order of consultation

1. **Whichever handover is newest: `.claude/handovers/` or the active
   spec's `tasks.md`.** Both sources are checked, and the one with the
   later date wins, a same-day tie going to the spec. `check-handover.sh`
   already points at the winner at session start; read the file it names
   before answering anything about project state.
2. **`tasks.md`** of the active spec: the checkbox count, the first
   unchecked task.
3. **Open PRs** for the current branch (`gh pr list`, `gh pr view`).
4. **`git log` / `git status`**: what actually landed, what is uncommitted.

Older files in `.claude/handovers/` are history, not current state. Only the
newest one describes where things stand now (see the `handover` skill's
"Retention" section).

## A handover is dated state, not an instruction

Confirm it against reality before repeating it. A PR it names as open may
have merged or closed since; an item it calls "not started" may have shipped
in a session that never wrote its own handover. Treat every claim in it the
way `.claude/rules/harness/specs.md` treats a spec's claims: verified, not
copied.

## Why this is a rule and not advice

The pointer to `.claude/handovers/` already lives inside the `handover` and
`status` skills, but a skill only loads when invoked. A session that starts
with `/clear` and a plain "continue" invokes neither, and silently re-derives
everything a prior session already wrote down, paying for it a second time
at full price. `check-handover.sh` surfaces the pointer at `SessionStart` so
it reaches every resume, not just the ones that happen to call a skill; this
rule is what tells you to act on it.
