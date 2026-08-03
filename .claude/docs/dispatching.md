# Dispatching subagents

*What* to delegate is `.claude/rules/delegation.md`. *What context* to pass is `.claude/docs/context-engineering.md`. This doc is **how** — parallelism, background, re-review, memory.

AI-only. Portable: no stack assumptions.

## Parallel means one message, several dispatches

Independent work runs **concurrently only when the dispatches go out in a single message**. Several agent calls in one message run at the same time; one call per message runs one after another, no matter how independent the tasks are.

```
Wave with 3 independent tasks
  ✅ one message  → Agent(task A) + Agent(task B) + Agent(task C)   ← concurrent
  ❌ three messages, one Agent each                                  ← sequential, 3× the wall-clock
```

This is the single most-missed mechanic. On a real project, **54 of 54 dispatches went out one per message** — the wave plan existed on paper and never once fanned out. The overlap that did happen came from background dispatches accidentally outliving each other, peaking at 3.

Before dispatching a wave, ask: *are these tasks touching disjoint files?* If yes, they belong in one message. If no, they belong in different waves (see document ownership in `.claude/README.md`).

## Background is for long work you collect this turn

- **Use background** for a long, self-contained run you will collect before the turn ends.
- **Never background a gate.** The gate's whole job is to block; a gate you do not wait for blocks nothing.
- **Collect what you launch.** A background agent nobody reads is pure spend. On the same real project, two background agents stayed open for **16 days** because nothing ever collected them.

If you launch background work, say in the same message what you will do with the result and when.

## Re-review: continue the agent, do not re-dispatch it

| Situation | Do this |
|---|---|
| First pass on an artifact | fresh dispatch |
| Second, third pass on the **same** artifact | **continue the live agent** (`SendMessage`) |

A fresh dispatch re-reads the artifact from zero and has no memory of what it already flagged. A continuation costs a fraction and the reviewer still remembers its own findings — which is exactly what a re-review needs.

Measured: a spec reviewer ran **three times on the same spec in 12 minutes**, each a fresh dispatch on the expensive model, ~57k tokens per pass. Two of those three were continuations wearing a dispatch's costume.

## Concurrency ceiling

Keep a wave to a handful of agents. Past that, they contend for the same files and you spend more time reconciling than you saved. If a wave wants to be large, it is usually two waves.

If you bound coverage — top-N, no retry, sampling — **say what you dropped**. Silent truncation reads as "covered everything" when it did not.

## Diversity beats redundancy

Five copies of the same reviewer find the same thing five times. Reviewers with **different lenses** — correctness, security, tests, performance — find five different things for the same cost. When a wave's review phase fans out, fan out by lens.

A cheap narrow specialist often beats an expensive broad one: a focused security pass can cost a tenth of a full code review and catch what the full review structurally cannot.

## Agent memory

An agent whose frontmatter declares `memory:` has a durable notebook across runs (`.claude/agent-memory/<agent>/`, gitignored). Declaring it is not using it — the agent has to choose to write.

Worth persisting: conventions the agent re-derives every run, gotchas that already bit once, the shape of the area it owns. **Not** worth persisting: anything re-readable from the repo in one grep (see "re-fetchable beats stored" in the context doc).

When you dispatch a repeat-visit specialist, tell it to check its memory first and to append what it learned. Otherwise the folder stays empty and the config is decoration.

## Cost shape (order of magnitude, from real runs)

| Agent kind | Tool calls / run | Note |
|---|---:|---|
| Narrow specialist (security, single-layer) | ~15–20 | cheapest useful pass |
| Stack specialist (implements in its layer) | ~45 | knows the conventions already |
| Full code review | ~58 | broad by design |
| **General-purpose, no stack specialist** | **~122** | re-discovers the repo every run |

That last row is the price of a missing agent in the stack plugin. If you see it, the fix is to write the specialist, not to keep paying.
