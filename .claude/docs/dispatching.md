# Dispatching subagents

*What* to delegate is `.claude/rules/delegation.md`. *What context* to pass is `.claude/docs/context-engineering.md`. This doc is **how** — parallelism, background, re-review, memory.

AI-only. Portable: no stack assumptions.

## Pick the shape before the mechanics

Six shapes cover almost every dispatch you will plan. Choose the shape from the *work*, then apply the mechanics below. Picking the wrong shape is more expensive than any mechanic can fix: a fan-out over dependent tasks wastes every parallel run, and a pipeline over independent ones wastes wall-clock.

### 1. Pipeline

```
[A] → [B] → [C] → [D]
```

Each stage consumes the previous stage's output.

- **Fits when** each step depends strongly on the artifact before it.
- **Watch out:** one slow stage delays everything behind it. Design stages to be as independent as they can be.
- **With sub-agents:** natural. One dispatch per stage; you pass each result into the next prompt. The cost is that every handoff goes through you.

### 2. Fan-out / Fan-in

```
        ┌→ [A] ─┐
[split] ┼→ [B] ─┼→ [merge]
        └→ [C] ─┘
```

Same input, several independent angles, then one merge.

- **Fits when** the same artifact needs different lenses (correctness, security, tests, performance).
- **Watch out:** the **merge** decides the quality. A lazy merge throws away everything the parallel runs found.
- **With sub-agents:** dispatch all of them **in one message** — this is the shape where that rule pays most. Do the merge yourself, or give it its own dispatch when it is heavy.

### 3. Expert pool

```
[router] → { [A] | [B] | [C] }
```

A router picks the one specialist the input needs.

- **Fits when** the input type decides the handling.
- **Watch out:** the router's classification accuracy *is* the pattern. Everything downstream inherits its mistake.
- **With sub-agents:** ideal. You call only the specialist you need and nothing sits idle.

### 4. Producer-Reviewer

```
[produce] → [review] → (findings) → [produce again]
```

- **Fits when** quality matters and there is an objective criterion to check against.
- **Watch out:** **cap the retries at 2-3.** Without a cap this loops forever, and each turn costs a full pass.
- **With sub-agents:** two dispatches per round, feeding the reviewer's findings into the producer's next prompt. Same loop the gate already runs. Prefer continuing the live reviewer for round 2 (see below) instead of dispatching a fresh one.

### 5. Supervisor

```
          ┌→ [worker A]
[super]  ─┼→ [worker B]     ← assigns as it watches progress
          └→ [worker C]
```

- **Fits when** the workload is variable or only knowable at runtime — a migration where you learn the real shape as you go.
- **Differs from fan-out:** fan-out fixes the split up front; the supervisor adjusts mid-flight.
- **Watch out:** the supervisor becomes the bottleneck if the delegated unit is too small. Delegate in chunks big enough to be worth the round-trip.
- **With sub-agents:** the main thread is the supervisor. Keep the assignment state in the shared task list, not in your context — that is what stops the supervisor from bloating.

### 6. Hierarchical delegation

```
[coordinator] → [lead A] → [worker A1] [worker A2]
              → [lead B] → [worker B1]
```

- **Fits when** the problem decomposes hierarchically on its own.
- **Watch out:** **beyond two levels, latency and context loss dominate.** Keep it to two.
- **With sub-agents:** possible (a dispatched agent may dispatch its own), but prefer flattening to one level plus a merge. Depth buys less than it costs.

### Composites are the norm

| Composite | Shape | Example |
|---|---|---|
| Fan-out + Producer-Reviewer | parallel production, each output reviewed | several modules built in parallel, each reviewed on its own |
| Pipeline + Fan-out | sequential stages with one parallel stage inside | analyze (serial) → implement (parallel) → integration test (serial) |
| Supervisor + Expert pool | supervisor classifies, then calls the right specialist | triage a backlog, route each item to its layer |

### A mode this harness does not have

There is a second execution mode — **agent teams** — where members are independent instances that message each other directly and self-coordinate through a shared task list. It changes the answer for fan-out and producer-reviewer, because one member's discovery can redirect another mid-flight instead of after both have finished.

It is **not available here** (no team-creation tool), so every row above is written for sub-agents. If it ever is, the rule of thumb is one question: *does one worker's discovery change what another should be doing?* Yes → team. No → sub-agents, and the communication would be pure overhead.

> Pattern catalogue adapted from [revfactory/harness](https://github.com/revfactory/harness) (Apache-2.0), rewritten for sub-agent execution.

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
- **Collect what you launch, in the turn that launched it.** On a real project, two background dispatches were only collected **16 days** after being launched — the session was suspended and resumed, and the agents picked up where they left off. They worked for about 40 minutes each; the other 16 days were a session that never closed. Nothing leaked, but nobody was waiting for that result either, which means it was not a gate on anything.

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
