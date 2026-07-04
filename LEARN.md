# LEARN.md

A guided course through this repository's AI structure. Read [`README.md`](./README.md) first for the high-level overview. This file goes deeper.

## Table of contents

- [Chapter 1: The cost of context](#chapter-1-the-cost-of-context)
- [Chapter 2: The five subsystems](#chapter-2-the-five-subsystems)
- [Chapter 3: Layered instructions](#chapter-3-layered-instructions)
- [Chapter 4: Skills vs rules vs agents](#chapter-4-skills-vs-rules-vs-agents)
- [Chapter 5: Subagents and isolated context](#chapter-5-subagents-and-isolated-context)
- [Chapter 6: Subagent memory](#chapter-6-subagent-memory)
- [Chapter 7: Knowledge about libraries](#chapter-7-knowledge-about-libraries)
- [Chapter 8: Spec-driven development](#chapter-8-spec-driven-development)
- [Chapter 9: Architecture Decision Records](#chapter-9-architecture-decision-records)
- [Chapter 10: Hooks and lifecycle events](#chapter-10-hooks-and-lifecycle-events)
- [Chapter 11: Greenfield vs brownfield](#chapter-11-greenfield-vs-brownfield)
- [Chapter 12: Common mistakes](#chapter-12-common-mistakes)

---

## Chapter 1: The cost of context

Every Claude Code session has an overhead before you type the first message: tool definitions, system prompt, and project-level instructions (`CLAUDE.md`) all load into the context window. This adds up to thousands of tokens.

The implication: what loads always must be small. What is detailed must load on demand.

This single insight drives the entire structure of this template:

- `CLAUDE.md` root is short
- Rules are scoped by path
- Docs only load when a skill references them
- Subagents work in isolated context windows

Internalize this rule and the rest of the structure makes sense.

---

## Chapter 2: The five subsystems

The `.claude/` directory has five distinct subsystems:

1. **Settings** (`settings.json`) define permissions and hook registrations
2. **Skills** (`skills/`) are reusable workflows loaded by description match
3. **Agents** (`agents/`) are specialists with isolated context
4. **Rules** (`rules/`) are scoped conventions that auto-load by glob
5. **Hooks** (`hooks/`) are scripts triggered by tool lifecycle events

Plus a non-official but extremely useful directory: **Docs** (`docs/`), which holds knowledge consulted on demand.

Most projects use all six. Each has a different cost and trigger.

| Subsystem | When it loads | Context cost |
|---|---|---|
| `settings.json` | Always, at session start | Minimal |
| `skills/` | When description matches task | Loaded only when active |
| `agents/` | When invoked or auto-delegated | Isolated, does not pollute main |
| `rules/` | When path matches glob | Loaded when relevant |
| `hooks/` | On lifecycle event | Zero |
| `docs/` | When skill references explicitly | Zero until read |

---

## Chapter 3: Layered instructions

There are four places where instructions can live, in order of how they load:

### Layer 0: `AGENTS.md`

The shared source of truth. Read by all AI coding agents that support the AGENTS.md convention (Claude Code, Codex, Cursor, Gemini CLI, GitHub Copilot, and others). Contents:

- Tech stack (one line per item)
- Build and test commands
- Top-level directory map
- Conventions that apply everywhere
- Feature workflow
- Non-negotiables
- Pointers to where detailed info lives

What does NOT go here: tool-specific extras, long explanations, library docs, examples that span 20+ lines.

### Layer 1: Root `CLAUDE.md` (as a stub)

Loads at the start of every Claude Code session. In this template, `CLAUDE.md` is a **stub** that points to `AGENTS.md` for the shared content, and then adds only what is specific to Claude Code:

- Which skills, subagents, hooks, and rules ship in this project
- Where nested CLAUDE.md files live
- Where personal overrides go (`CLAUDE.local.md`)

The stub pattern removes duplication: you update the stack in `AGENTS.md`, all agents see it, `CLAUDE.md` never falls out of sync because it does not own that content.

### Layer 2: Nested `CLAUDE.md`

A `CLAUDE.md` placed inside a folder loads automatically when Claude navigates that folder. Invisible when Claude is elsewhere. **Nested CLAUDE.md files are NOT stubs** - they have full content, because they describe conventions specific to that folder that no other file owns.

Use for conventions specific to that layer:

- "this folder is server-side, never import from client"
- "files expected here: foo.ts, bar.ts, each with .test.ts"
- "source of truth is spec at /specs/.../spec.md"

### Layer 3: Path-scoped rules

In `.claude/rules/`, rules with `paths:` in frontmatter load only when the glob matches the file Claude is touching.

```markdown
---
paths: "**/*.{tsx,jsx}"
---

# React conventions

- Named exports only
- Props interface above the component
- No default exports
```

When to choose nested CLAUDE.md vs rule?

- **Nested CLAUDE.md** when the convention is tied to a folder and lives next to the code
- **Rule** when the convention applies across multiple folders by file type

---

## Chapter 4: Skills vs rules vs agents

Three things that look similar but do different jobs.

### Rule

- **What:** scoped guidance text
- **Trigger:** path matches glob
- **Output:** Claude reads it as context
- **Use when:** convention that must be remembered while editing certain files

### Skill

- **What:** reusable workflow
- **Trigger:** description matches the task at hand
- **Output:** Claude follows the workflow
- **Use when:** repeated multi-step process across sessions

### Agent (subagent)

- **What:** specialist with isolated context
- **Trigger:** explicit invocation or auto-delegation via description
- **Output:** returns a final summary; intermediate work stays isolated
- **Use when:** deep investigation, review, or task that should not pollute main context

A common mistake is using a rule for what should be a skill. If you find yourself writing "when you do X, follow these 7 steps" in a rule, it should be a skill.

---

## Chapter 5: Subagents and isolated context

A subagent runs in its own fresh context window. The orchestrator hands it a prompt, the subagent works (reads files, runs tools, reasons), and only the final message returns to the orchestrator.

This is powerful because:

- Code review can read 50 files without polluting your session
- Research on a library can explore docs without filling your context
- Parallel subagents can run simultaneously (security audit + code review + performance check)

The frontmatter:

```markdown
---
name: code-reviewer
description: Reviews code against the plan. Use PROACTIVELY after each task.
tools: Read, Grep, Glob, Bash
model: sonnet
memory: project
---
You are a senior code reviewer...
```

Key fields:

- **`name`** is the identifier
- **`description`** is the auto-delegation trigger; write it as a condition of use
- **`tools`** restricts what the subagent can do (smaller = safer)
- **`model`** picks the model tier; use `opus` for review/research, `sonnet` or `haiku` for execution
- **`memory`** opts in to persistent memory (see next chapter)

### The "Use PROACTIVELY" convention

Claude auto-delegates based on `description`. To push automatic delegation without you asking, the community convention is to write descriptions like:

- "Use PROACTIVELY after each task is implemented"
- "Use immediately when reviewing code changes"
- "Use when investigating an unfamiliar library"

Without these phrases, Claude tends to wait for an explicit request.

---

## Chapter 6: Subagent memory

Introduced in Claude Code v2.1.33, the `memory:` frontmatter field gives a subagent a persistent directory:

```markdown
---
memory: user        # ~/.claude/agent-memory/<name>/
# OR
memory: project     # .claude/agent-memory/<name>/ (gitignored)
# OR
memory: local       # session-only
---
```

The first 200 lines of `MEMORY.md` in that directory are auto-injected into the subagent's system prompt every invocation. The subagent has Read, Write, and Edit tools enabled to manage its own notes.

This is real persistence. A `researcher` subagent that investigated five libraries last week will remember the gotchas this week.

### The catch

Each subagent has its own memory. The `code-reviewer`'s `MEMORY.md` is invisible to the `security-auditor`. Knowledge does not flow between subagents.

If you need shared memory across subagents, look at plugins like `hindsight-memory`. For most cases, siloed memory is fine.

### When memory is gold

- A `researcher` that investigates many libraries (deep, accumulating expertise)
- A `code-reviewer` that learns project-specific anti-patterns
- A `security-auditor` that builds a catalog of past vulnerabilities

### When memory is noise

- Subagents invoked once or rarely
- Subagents whose context is fully captured in the spec or plan they read
- Anything where stale memory would mislead more than help

---

## Chapter 7: Knowledge about libraries

This is where most projects break down: they dump all library knowledge into `CLAUDE.md` and pay the context cost every session.

The right answer: four layers, from cheap to detailed.

### Layer 1: One-liner in `CLAUDE.md`

```
## Tech stack
- <Your framework> + <Your language>
- <Your styling approach>
- <Your package manager> + <Your test runner>
- <Your database and ORM>
```

Just the name and role. No details.

### Layer 2: Convention rules in `.claude/rules/`

For conventions tied to a library that apply across the codebase:

```markdown
---
paths: "**/*.{tsx,jsx}"
---

# UI framework conventions
- Use design tokens, not arbitrary values
- Follow the existing component patterns
```

### Layer 3: Project-specific lib doc in `.claude/docs/libs/`

Not the official docs. The subset you use, with your gotchas:

```markdown
# Payment provider

## How we authenticate
- Live keys stored in the orchestration layer, never in app code
- Test keys in .env.local

## Endpoints we use
- POST /v1/payment_intents
- POST /v1/webhooks (signature verification required)

## Gotchas
- Idempotency keys required for retries
- Test webhooks need a tunnel (e.g., ngrok)
```

### Layer 4: Subagent memory for accumulating discoveries

A `researcher` subagent with `memory: user` builds expertise across sessions.

### When to use which

| You need to know... | Layer |
|---|---|
| What stack is this? | `CLAUDE.md` |
| What naming convention applies to .tsx files? | `.claude/rules/` |
| How do we use a specific external service? | `.claude/docs/libs/<name>.md` |
| What gotchas have I hit with this lib before? | `researcher` subagent memory |
| Full official API reference? | Context7 MCP, do not duplicate |

---

## Chapter 8: Spec-driven development

The `specs/` folder follows a three-file pattern that separates WHAT, HOW at high level, and HOW at execution level. Each feature is a folder with `spec.md`, `plan.md`, and `tasks.md`.

### The three files

```
specs/YYYY-MM-DD-feature-slug/
├── spec.md      # WHAT + WHY (source of truth, imutable after approval)
├── plan.md      # HOW at high level (architecture, tech, phases)
└── tasks.md     # HOW at execution level (atomic checkboxes, TDD)
```

This mirrors what Kiro (Amazon), Spec Kit (GitHub), and Junie (JetBrains) all converged on. It works because the three files have different purposes, audiences, and update rates:

| File | Answers | Update rate |
|---|---|---|
| `spec.md` | "What are we building? Why?" | Rare, only if the feature itself changes |
| `plan.md` | "What's the technical approach? Which phases?" | Occasional, if the strategy shifts |
| `tasks.md` | "Where did I stop? What's next?" | Constant, updated after each task |

If you collapse them into one file, you lose the ability to answer "where did I stop?" quickly. `tasks.md` alone answers that: the first unchecked box.

### The flow

```
1. Brainstorm in chat (skill: explore)
       ↓
2. spec.md written and committed
       ↓
3. spec-reviewer subagent audits
       ↓
4. plan.md filled: architecture, tech choices, phases
       ↓
5. tasks.md filled: atomic checkboxes with TDD steps
       ↓
6. Execute task by task (subagent-driven or manual)
       ↓
7. code-reviewer subagent gates between tasks
       ↓
8. Merge when all boxes are checked
```

Each step is a gate. The next does not happen until the current is approved.

### Why it works

The biggest source of rework in AI-assisted development is implicit decisions. The agent starts coding, makes an assumption, and the assumption silently shapes the design. Two days later you discover the assumption was wrong.

Spec-driven development surfaces every decision before code. Brainstorming asks questions. Spec writes them down. Plan turns them into architecture. Tasks turn architecture into atomic steps. Code follows tasks. When something goes wrong, you can trace back to the exact decision and fix it.

### Where did I stop?

The most common question mid-feature. Open `tasks.md`. The first unchecked `- [ ]` is where you stopped. If you paused inside a task, the inline `Notes:` under that task tells you why.

Example:

```markdown
- [x] Task 6: normalize phone number
- [ ] Task 7: API route for lead submission
   Notes: paused here. Zod v4 changed union types API,
   need to confirm shape with team before continuing.
- [ ] Task 8: retry queue
```

You (or another agent) opens this file and knows: task 7, blocker is Zod v4, resume when confirmed.

### Why it feels slow at first

The spec + plan phase costs an hour or two before any code runs. The first three or four features feel slower than vibe-coding. The break-even is usually around the fifth feature, when the specs start catching design mistakes that would otherwise ship and be rewritten.

### When NOT to use this flow

- Trivial bug fixes (typos, label changes)
- Mechanical refactors (rename, move, extract)
- Throwaway prototypes (but if the prototype ships, run the flow before merging)

### Two non-negotiables

1. **Spec is source of truth.** When code and spec diverge, ask, do not assume.
2. **Test before code.** Every task in `tasks.md` starts with a failing test, then minimal code, then refactor.

---

## Chapter 9: Architecture Decision Records

Specs describe what a feature does. ADRs describe why the system is shaped the way it is. Both are needed, and they answer different questions.

An ADR is a short, immutable document capturing a single significant decision:

- The context that forced it
- The options considered
- The choice made
- Consequences (positive, negative, accepted risks)

Once accepted, an ADR does not change. If the decision later shifts, a new ADR supersedes the old one. Both remain in the repo. The full history of reasoning is the value.

### Five concrete benefits

**1. Preserves context that disappears.**
Six months from now you'll look at a strange choice and wonder why. The ADR explains the constraints that shaped it - constraints that may no longer be obvious. Without it, someone "corrects" the decision and breaks something because they didn't know why it was that way.

**2. Prevents re-litigation.**
Someone asks "why aren't we using Redis?" Instead of debating from scratch, you point to ADR 0003 and get back to work. Discussion cost collapses.

**3. Onboarding gets faster.**
A new developer reads 10 ADRs and understands the architectural reasoning without interviewing everyone. That's often the difference between "productive in two weeks" and "productive in two months."

**4. Traceability during failures.**
When something breaks because of an old decision, the ADR shows the premises it was made under. You check whether the premises still hold. If not, that's your fix.

**5. Writing the ADR exposes fragility.**
Often you start writing and realize the decision doesn't hold up. Better to discover that now than in production.

### When to write one

Yes, write an ADR when:

- Choosing a core technology (framework, database, ORM, auth provider)
- Changing the trust model or architecture
- Setting a constraint that will shape future features
- Deciding "we are NOT doing X" when X looks tempting

No, don't write one for:

- Naming conventions (those go in `docs/CONVENTIONS.md` or `.claude/rules/`)
- Trivial library choices (lodash, date-fns)
- Anything reversible in a day

### Format

The template ships at `docs/decisions/0001-example.md`. Structure:

```markdown
# NNNN - Title

**Status:** Proposed | Accepted | Superseded by NNNN
**Date:** YYYY-MM-DD
**Decider:** name or team

## Context
What forced the decision. Constraints, problem, trigger.

## Options considered
1. A - pros, cons
2. B - pros, cons

## Decision
We chose X because...

## Consequences
### Positive / Negative / Risks accepted

## Revisit when
Conditions that would trigger reopening.
```

Numbered sequentially (0001, 0002, ...) with short kebab-case slugs.

### Four ways to integrate ADRs with AI agents

**1. Read ADRs during exploration.**
The `explore` skill in this template reads `docs/decisions/` before proposing options. Past decisions surface naturally. Add to your CLAUDE.md: "Before proposing architecture, check `docs/decisions/` for related ADRs."

**2. Enforce during code review.**
Add to the `code-reviewer` subagent prompt: "Verify this change does not silently violate any accepted ADR in `docs/decisions/`." Failed check becomes a report item.

**3. Cite in explanations.**
The `researcher` subagent, when asked "why is X this way?", cites ADRs directly. Add to its prompt: "When explaining an existing design choice, look for an ADR that documents it and cite it by number."

**4. Propose new ADRs proactively.**
When you find yourself explaining "why we did X" more than twice in Slack/PRs/reviews, that's the trigger. Ask an agent: "Turn this explanation into an ADR draft in `docs/decisions/`." Review, number it, commit.

### One habit worth building

If a decision is contested in a PR and the code will change based on the discussion, write the ADR *first*, then approve the PR. This prevents "we agreed something in a chat that nobody documented" - the most common source of decision drift.

---

## Chapter 10: Hooks and lifecycle events

Hooks are deterministic scripts that run on tool lifecycle events. They do not load context, they cause side effects.

### Available events

| Event | When it fires | Use for |
|---|---|---|
| `PreToolUse` | Before any tool runs | Block dangerous commands, validate input |
| `PostToolUse` | After a tool completes | Auto-format, lint, notification |
| `Stop` | When Claude finishes its turn | Desktop notification, metric logging |
| `SessionStart` | At the start of a session | Inject extra context |
| `Notification` | When Claude needs your input | Visual or sound alert |

### Anatomy

A hook is any executable that reads JSON from stdin. Exit code 0 allows, non-zero blocks (for Pre events).

```bash
#!/usr/bin/env bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ "$command" =~ "cat .env" ]]; then
  echo "BLOCKED: cannot read .env files" >&2
  exit 1
fi

exit 0
```

Registered in `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/block-secrets.sh" }
        ]
      }
    ]
  }
}
```

### Good fits for hooks

- Blocking destructive commands (`rm -rf /`, `git push --force`)
- Preventing secret leakage (reading `.env`, printing tokens)
- Auto-formatting on file write
- Desktop notification on long-running task completion

### Bad fits for hooks

- Loading context (use rules or docs)
- Network calls (slow and unreliable)
- Anything that depends on global state

---

## Chapter 11: Greenfield vs brownfield

The terms come from construction. **Greenfield** is empty land: you start from scratch, no constraints from prior work. **Brownfield** is land where buildings already exist: you have to reckon with what's there before you can build.

In code:

- A brand new repo on day one is greenfield
- Almost every real project a month later is brownfield
- Legacy codebases (years old, many hands, sparse docs) are extreme brownfield

Why this matters for AI agents: models are trained mostly on code that gets presented in "here's how you build X from scratch" tutorials. When you ask a fresh session to add a feature, the default behavior is greenfield thinking - install a lib, create abstractions, write everything from zero. In brownfield, that produces parallel implementations of things that already exist, drift from established patterns, and slow, expensive rework.

### The brownfield mindset

Before any code, three questions:

1. Does this already exist here?
2. If not, what's the closest analog and how is it structured?
3. Which conventions apply to the area I'll be touching?

Skipping these turns every task into greenfield. Following them keeps the codebase coherent.

### How this template supports brownfield

Six mechanisms work together:

**`analyze-codebase` skill (one-time)**
When you adopt this template on an existing project, this skill scans the codebase, samples files, detects stack and conventions, and generates baseline docs (`CONSTITUTION.md`, `CONVENTIONS.md`, `architecture/overview.md`). It also generates a Repomix snapshot for projects with 100+ source files.

**Repomix snapshot (`.claude/context/repomix-snapshot.md`)**
Repomix packs the entire codebase into one file that AI subagents can consume. Cheaper than reading dozens of files individually. The snapshot has metadata (commit SHA, generated date, file count) that lets the template check staleness.

**Staleness check (`.claude/scripts/check-snapshot.sh`)**
Classifies the snapshot as `fresh`, `stale-mild`, or `stale-major` by comparing the metadata against current HEAD. Considers commits ahead, files changed, days elapsed, and whether config files changed (weighted heavier because they signal convention drift).

**`codebase-explorer` subagent**
Read-only. Reads the snapshot for panoramic questions, uses grep/glob for scoped ones. When the snapshot is `stale-major`, it refreshes automatically before proceeding. Reports what it read and what it found.

**`SessionStart` hook**
Warns you at the start of a session if the snapshot is stale-major. Silent otherwise. Never blocks.

**`find-existing-first` skill**
Fires immediately before creating any new file. Searches synonyms, checks patterns, reports findings. Only proceeds to creation if nothing exists.

### The staleness thresholds

Default classification, all overridable in `.claude/context/config.json`:

| Status | Trigger |
|---|---|
| fresh | < 5 files changed AND < 3 days AND no config change |
| stale-mild | 5-29 files OR 3-13 days |
| stale-major | 30+ files OR 14+ days OR config file changed |

"Config changed" means `tsconfig.json`, `package.json`, `.eslintrc*`, `tailwind.config.*`, etc. These indicate convention shifts, so they weight heavier.

### The workflow

Adopting the template on a brownfield project:

```
1. Clone the template into the project
2. Run /skill analyze-codebase (generates baseline docs and snapshot)
3. Review the generated docs, fix TODOs, commit
4. Optional: install Ponytail plugin for cross-tool YAGNI enforcement
5. From now on, use /skill explore before /skill write-spec for new features
6. Codebase-explorer runs silently when depth is needed
7. Snapshot refreshes automatically when stale
```

You don't manage the snapshot manually after step 2. The system takes care of it.

### External tools that complement this

- **[Ponytail](https://github.com/DietrichGebert/ponytail)** - cross-tool plugin applying a YAGNI ladder before writing any code
- **[Repomix](https://github.com/yamadashy/repomix)** - the packer used for snapshots (already integrated)
- **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** - full spec-driven toolkit with `/opsx:explore` command, cross-tool (30+ agents). Compatible with the template's `specs/` location via config
- **[Superpowers](https://github.com/obra/superpowers)** - Claude-only plugin with enforced brainstorm → spec → plan → TDD flow

---

## Chapter 12: Common mistakes

### 1. CLAUDE.md becomes a wiki

The symptom: `CLAUDE.md` grows past 200 lines with sections on every library and convention. The cost: every session pays for all of it, and content duplicates with `AGENTS.md`.

The fix: make `CLAUDE.md` a **stub** that points to `AGENTS.md` for shared content (stack, commands, conventions, structure), and keep it lean with only Claude-specific extras (which skills/agents/hooks ship in this project). Move detailed reference material to `.claude/docs/`, scope conventions to `.claude/rules/` with `paths:`, and put folder-specific guidance in nested `CLAUDE.md`.

### 2. Skills with vague descriptions

The symptom: a skill exists but Claude never auto-invokes it.

The fix: the `description` is the trigger, not documentation. Write it as a condition: "Use when adding a new webhook handler" beats "Helps with webhook integrations".

### 3. Rules without `paths:`

The symptom: a rule auto-loads in every session, becoming a hidden CLAUDE.md.

The fix: always add `paths:` to scope rules. Otherwise they belong in `CLAUDE.md` (and probably should be shorter).

### 4. Library docs duplicated from official sources

The symptom: `.claude/docs/libs/<lib>.md` is a copy of the official API reference. It goes stale fast.

The fix: `.claude/docs/libs/` should only contain the project-specific subset and gotchas. Use Context7 MCP for live official docs.

### 5. Spec gets ignored mid-implementation

The symptom: code drifts from spec, nobody notices until QA.

The fix: when code and spec diverge, stop and ask which is right. Use the `code-reviewer` subagent between tasks to catch drift early.

### 6. Subagent memory becomes outdated

The symptom: subagent gives advice based on a pattern that no longer exists in the codebase.

The fix: review `MEMORY.md` periodically (every month or two). After major refactors, clear it: `rm -rf .claude/agent-memory/<name>/`.

### 7. Subagent permissions too broad

The symptom: a `code-reviewer` accidentally edits files instead of reporting.

The fix: scope the `tools:` field tightly. A reviewer needs `Read, Grep, Glob`, not `Edit`.

---

## What to read next

- The [official Claude Code docs](https://code.claude.com/docs/en/claude-directory)
- The [Superpowers repo](https://github.com/obra/superpowers) for spec-driven development
- The [AGENTS.md convention](https://agents.md) for cross-tool guidance
- Open this repo's [`CLAUDE.md`](./CLAUDE.md), [`AGENTS.md`](./AGENTS.md), and [`.claude/`](./.claude/) and read them as reference
