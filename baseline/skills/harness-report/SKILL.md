---
name: harness-report
description: Is the harness actually being used the way it is designed? Reports delegation, dispatch and attribution from the observability logs, and judges them against the recorded baseline. Read-only.
---

Report on the harness itself, not the code. Read state; change nothing.

## 1 — Collect

Run `.claude/scripts/harness/harness-report.sh`. It reads `.claude/tool-log.txt` (who edits: main thread or specialist) and `.claude/agent-log.txt` (what each dispatch cost). Both are gitignored and per-checkout.

If it says there is no data, say so and stop. An empty log means the hooks have not fired yet, not that behaviour is perfect.

## 2 — Judge against the baseline

Read `.claude/docs/harness/harness-baseline.md` and compare. Report the **direction**, not just the value:

- **Edit delegated** vs the 29% baseline — this is the headline. Below or near 29% means `rules/delegation.md` did not change behaviour. Since 2026-09-12 this count also includes writes recovered from `Bash` (a redirect, `sed -i`, `tee`, `cp`, `mv`), not only Edit/Write/MultiEdit/NotebookEdit — a number measured before that date is not comparable to one measured after it, because the denominator changed (see `harness-baseline.md`'s 2026-09-12 section).
- **Dispatch count and mix** — a healthy run shows several dispatches and more than one agent type. All `general-purpose` means the stack plugin is missing specialists, which costs multiples per task.
- **Unattributed dispatches** — should be near zero now that `log-agent.sh` falls back to the subagent transcript. If it is high again, the hook regressed. The report only counts this from lines **after** the instrument epoch it reads out of `harness-baseline.md` (an `<!-- instrument-epoch: YYYY-MM-DD -->` marker); older lines are excluded from every headline number and shown on their own line instead, so a pre-fix batch of `agent=?` never reads as a live problem again.
- **Subagent tokens** — the headline total now excludes every `approx=1` line (log-agent.sh's degree-3 fallback, which cannot always tell two subagents' transcripts apart in a parallel wave). Those are reported on their own line — count and tokens — instead of folded into the total; a `dup=1` line among them means the hook caught the same transcript being about to be charged twice and logged no metric for it rather than copying one.
- **Writes recovered from Bash** — shown on its own line when nonzero, with how many of those had an unresolved target (logged as `?` because a shell variable or command substitution can't be resolved to a literal path, not dropped). This is a heuristic on shell text, not a shell parser; a large share unresolved is worth a look, not necessarily a defect.

## 3 — Say what the numbers do not cover

State the limits every time, because a report that hides them reads as more authoritative than it is:

- The sample size, and whether it is large enough to mean anything.
- Whether this session did implementation at all — delegation is meaningless in a session that only read files.
- How many edits had an **unknown** thread. Thread detection is a heuristic on the hook payload; if unknowns dominate, the report describes the detector.

## 4 — One recommendation, or none

If a number is clearly off the baseline in the wrong direction, name **one** concrete change and stop. If everything is in range, say so plainly and recommend nothing — a report that always finds something to fix trains people to ignore it.

Do not edit any file. This command reports; acting on it is a separate decision.

**Invariant:** never present a number this command did not read from a log. If a metric in the baseline has no corresponding measurement (`/orchestrate` run count, main-thread token share), say it is **not instrumented** rather than estimating it.
