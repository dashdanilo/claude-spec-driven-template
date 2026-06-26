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
- [Chapter 9: Hooks and lifecycle events](#chapter-9-hooks-and-lifecycle-events)
- [Chapter 10: Common mistakes](#chapter-10-common-mistakes)

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

There are three places where instructions can live, in order of how often they load:

### Layer 1: Root `CLAUDE.md`

Loads every session. Should be small and dense. Contents:

- Tech stack (one line per item)
- Build and test commands
- Top-level directory map
- Conventions that apply everywhere
- Pointers to where detailed info lives

What does NOT go here: long explanations, library docs, examples that span 20+ lines.

### Layer 2: Nested `CLAUDE.md`

A `CLAUDE.md` placed inside a folder loads automatically when Claude navigates that folder. Invisible when Claude is elsewhere.

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

When to choose nested vs rule?

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
- Next.js 15 (App Router) + TypeScript strict
- Tailwind v4
- pnpm + Vitest
- Postgres via Drizzle ORM
```

Just the name and role. No details.

### Layer 2: Convention rules in `.claude/rules/`

For conventions tied to a library that apply across the codebase:

```markdown
---
paths: "**/*.{tsx,jsx}"
---

# Tailwind v4 conventions
- Tokens in @theme, not tailwind.config.*
- No arbitrary values, define in @theme first
```

### Layer 3: Project-specific lib doc in `.claude/docs/libs/`

Not the official docs. The subset you use, with your gotchas:

```markdown
# Stripe

## How we authenticate
- Live keys in n8n, never in code
- Test keys in .env.local

## Endpoints we use
- POST /v1/payment_intents
- POST /v1/webhooks (signature verification required)

## Gotchas
- Idempotency keys required for retries
- Test webhooks need ngrok tunnel
```

### Layer 4: Subagent memory for accumulating discoveries

A `researcher` subagent with `memory: user` builds expertise across sessions.

### When to use which

| You need to know... | Layer |
|---|---|
| What stack is this? | `CLAUDE.md` |
| What naming convention applies to .tsx files? | `.claude/rules/` |
| How do we use Stripe in this project? | `.claude/docs/libs/stripe.md` |
| What gotchas have I hit with Stripe before? | `researcher` subagent memory |
| Full Stripe API reference? | Context7 MCP, do not duplicate |

---

## Chapter 8: Spec-driven development

The `specs/` folder follows the pattern popularized by the Superpowers plugin. Each feature is three documents in order: spec, plan, code.

### The flow

```
1. Brainstorm in chat
       ↓
2. Spec gets written and committed (specs/<date>-<slug>/spec.md)
       ↓
3. spec-reviewer subagent audits the spec
       ↓
4. Plan breaks the spec into 2-5 minute TDD tasks (plan.md)
       ↓
5. subagent-driven-development executes one task at a time
       ↓
6. code-reviewer subagent gates between tasks
       ↓
7. Merge when all tasks pass
```

Each step is a gate. The next does not happen until the current is approved.

### Why it works

The biggest source of rework in AI-assisted development is implicit decisions. The agent starts coding, makes an assumption, and the assumption silently shapes the design. Two days later you discover the assumption was wrong.

Spec-driven development surfaces every decision before code. Brainstorming asks questions. Spec writes them down. Plan turns them into tasks. Code follows the plan. When something goes wrong, you can trace back to the exact decision and fix it.

### Why it feels slow at first

The spec phase costs an hour or two before any code runs. The first three or four features feel slower than vibe-coding. The break-even is usually around the fifth feature, when the specs start catching design mistakes that would otherwise ship and be rewritten.

### When NOT to use this flow

- Trivial bug fixes (typos, label changes)
- Mechanical refactors (rename, move, extract)
- Throwaway prototypes (but if the prototype ships, run the flow before merging)

### Two non-negotiables

1. **Spec is source of truth.** When code and spec diverge, ask, do not assume.
2. **Test before code.** Every plan task has a failing test before the implementation.

---

## Chapter 9: Hooks and lifecycle events

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

## Chapter 10: Common mistakes

### 1. CLAUDE.md becomes a wiki

The symptom: `CLAUDE.md` grows past 200 lines with sections on every library and convention. The cost: every session pays for all of it.

The fix: move detailed sections to `.claude/docs/`, scope conventions to `.claude/rules/` with `paths:`, and put folder-specific guidance in nested `CLAUDE.md`.

### 2. Skills with vague descriptions

The symptom: a skill exists but Claude never auto-invokes it.

The fix: the `description` is the trigger, not documentation. Write it as a condition: "Use when adding a Stripe webhook handler" beats "Helps with Stripe integration".

### 3. Rules without `paths:`

The symptom: a rule auto-loads in every session, becoming a hidden CLAUDE.md.

The fix: always add `paths:` to scope rules. Otherwise they belong in `CLAUDE.md` (and probably should be shorter).

### 4. Library docs duplicated from official sources

The symptom: `.claude/docs/libs/stripe.md` is a copy of the Stripe API reference. It goes stale fast.

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
