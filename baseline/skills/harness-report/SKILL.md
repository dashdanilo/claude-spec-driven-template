---
name: harness-report
description: Is the harness actually being used the way it is designed? Reports delegation, dispatch and attribution from the observability logs, and judges them against the recorded baseline. Read-only.
---

Report on the harness itself, not the code. Read state; change nothing.

## 1 — Collect

Run `.claude/scripts/harness-report.sh`. It reads `.claude/tool-log.txt` (who edits: main thread or specialist) and `.claude/agent-log.txt` (what each dispatch cost). Both are gitignored and per-checkout.

If it says there is no data, say so and stop. An empty log means the hooks have not fired yet, not that behaviour is perfect.

## 2 — Judge against the baseline

Read `.claude/docs/harness-baseline.md` and compare. Report the **direction**, not just the value:

- **Edit delegated** vs the 29% baseline — this is the headline. Below or near 29% means `rules/delegation.md` did not change behaviour.
- **Dispatch count and mix** — a healthy run shows several dispatches and more than one agent type. All `general-purpose` means the stack plugin is missing specialists, which costs multiples per task.
- **Unattributed dispatches** — should be near zero now that `log-agent.sh` falls back to the subagent transcript. If it is high again, the hook regressed.

## 3 — Say what the numbers do not cover

State the limits every time, because a report that hides them reads as more authoritative than it is:

- The sample size, and whether it is large enough to mean anything.
- Whether this session did implementation at all — delegation is meaningless in a session that only read files.
- How many edits had an **unknown** thread. Thread detection is a heuristic on the hook payload; if unknowns dominate, the report describes the detector.

## 4 — One recommendation, or none

If a number is clearly off the baseline in the wrong direction, name **one** concrete change and stop. If everything is in range, say so plainly and recommend nothing — a report that always finds something to fix trains people to ignore it.

Do not edit any file. This command reports; acting on it is a separate decision.

**Invariant:** never present a number this command did not read from a log. If a metric in the baseline has no corresponding measurement (`/orchestrate` run count, main-thread token share), say it is **not instrumented** rather than estimating it.
