# The four layers

> Moved out of `README.md` to keep the front door short. Linked from there.

## Shared root layer

The highest-level explanation layer. These files are read by humans and agents alike.

### [`README.md`](./README.md)

The human entry point. Explains what the repo is, how layers fit together, and how to reuse the structure.

### [`AGENTS.md`](./AGENTS.md)

**Source of truth for all agents.** Cross-tool instructions read by Codex, Cursor, Gemini CLI, Claude Code, GitHub Copilot, and any other coding agent that supports the AGENTS.md convention. Contains the stack, commands, structure, conventions, workflow, and non-negotiables - everything an agent needs to be effective in this repo.

### [`CLAUDE.md`](./CLAUDE.md)

**Stub for Claude Code.** Points to AGENTS.md as the source of truth, then adds Claude-specific extras that don't apply to other agents: which skills, subagents, hooks, and rules ship in this project, plus the location of nested CLAUDE.md files. Loaded automatically at the start of every Claude Code session.

This avoids duplication: the stack lives in AGENTS.md alone. Update it there, all agents see the change. CLAUDE.md never goes out of sync because it doesn't own that content.

### [`.github/copilot-instructions.md`](./.github/copilot-instructions.md)

**Stub for GitHub Copilot.** Same pattern as CLAUDE.md but for the Copilot ecosystem (VS Code, JetBrains, Copilot Chat, Copilot Coding Agent, Copilot on GitHub.com). Points to AGENTS.md as source of truth, then adds Copilot-specific guidance. Loaded automatically when Copilot generates suggestions.

### [`ECOSYSTEM.md`](./ECOSYSTEM.md)

Shared schemas and contracts across surfaces of the system. Critical for multi-platform projects where multiple services must agree on field names, types, and enums.

### [`CONTRIBUTING.md`](./CONTRIBUTING.md)

How to make changes without breaking the repo's teaching value. Workflow rules, validation steps, conventions.

---

## Internal Claude layer

This is what makes Claude effective at this project specifically.

### [`baseline/skills/`](./baseline/skills/)

Reusable workflows. Each skill is a directory with a `SKILL.md`. The `description` in the frontmatter is the trigger: Claude reads it and auto-invokes the skill when it matches a task.

Use skills when you find yourself repeating the same multi-step process across sessions.

### [`baseline/agents/`](./baseline/agents/)

Subagents are specialists with isolated context windows. When invoked, they explore, read, and reason in their own session, then return a final summary. The main conversation stays clean.

Four templates included:

- **`spec-reviewer.md`** audits every spec before it becomes a plan (mandatory; `write-spec` runs it automatically)
- **`code-reviewer.md`** reviews implementation against the plan
- **`researcher.md`** investigates libraries and accumulates a persistent `MEMORY.md`
- **`security-auditor.md`** audits auth, secrets, and input validation

The `description` field is the auto-delegation trigger. Convention: include "Use PROACTIVELY" or "Use when..." to push automatic delegation.

### [`baseline/rules/`](./baseline/rules/)

Path-scoped conventions. The `paths:` frontmatter glob determines when the rule auto-loads. Without `paths:`, the rule loads always (becoming a hidden CLAUDE.md).

### [`baseline/docs/`](./baseline/docs/)

Static knowledge that loads on demand only. Nothing here auto-loads. Skills and agents reference these docs explicitly when they need them.

Sub-folders:

- **`libs/`** one doc per external library or integration, focused on how this project uses it (not the official docs)
- **`decisions/`** architecture decision records, immutable once accepted

### [`baseline/hooks/`](./baseline/hooks/)

Scripts that run on Claude Code lifecycle events: `PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `Notification`. Registered in `settings.json`.

The example `block-secrets.sh` is a `PreToolUse` hook that prevents the agent from reading `.env` files via Bash.

### [`.claude/settings.json`](./.claude/settings.json)

Permissions (`allow` and `deny`), hook registrations, and default model. Commit this. Personal overrides go in `.claude/settings.local.json` (gitignored).

---

## How the AI layers connect

- `README.md` introduces the repo and points to the right places
- `LEARN.md` is the guided course
- `AGENTS.md` is the **shared source of truth** for any coding agent (Codex, Cursor, Gemini CLI, Claude Code, GitHub Copilot) - stack, commands, structure, conventions, workflow
- `CLAUDE.md` is a **stub** pointing to AGENTS.md, with Claude Code-specific additions on top (skills, agents, hooks references)
- `.github/copilot-instructions.md` is another **stub** for GitHub Copilot, same pattern (points to AGENTS.md, adds Copilot-specific extras)
- `ECOSYSTEM.md` defines shared schemas across surfaces
- `CONTRIBUTING.md` explains how to change things without breaking the teaching value
- `.claude/` contains Claude-specific configuration: skills, agents, rules, docs, hooks
- `specs/` contains the spec-driven artifacts: one folder per feature with spec + plan
- `src/<module>/CLAUDE.md` adds nested instructions scoped to a single folder (still full content, not stub)

```
┌──────────────────────────────────────────────────────────────┐
│ Cross-tool source of truth (always loaded by all agents)     │
│   AGENTS.md  ECOSYSTEM.md                                    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓
                    CLAUDE.md (stub → AGENTS.md + Claude extras)
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
   .claude/         specs/             src/<module>/
   ├─ skills/     YYYY-MM-DD-slug/    └─ CLAUDE.md
   ├─ agents/     ├─ spec.md             (nested, full content)
   ├─ rules/      └─ plan.md
   ├─ docs/
   └─ hooks/
   (loaded on demand or by trigger)
```

---

## What hooks are doing here

Hooks are deterministic side effects on tool lifecycle events. They do not load into context.

This template ships four hooks:

- **`block-secrets.sh`** intercepts `Bash` tool calls and blocks commands that try to read `.env` files or print secret-named environment variables
- **`protect-main.sh`** intercepts `Bash` tool calls and blocks `commit`, `push`, `merge`, `rebase`, and `reset --hard` when the current branch is protected (main, master, trunk, develop, production, release)
- **`protect-critical.sh`** intercepts `Edit` and `Write` calls and blocks modifications to lockfiles, applied migrations, generated code, and other critical files
- **`check-snapshot-on-session.sh`** runs at session start, checks Repomix snapshot staleness, and warns you if it's stale-major

That is a good fit for hooks because it is:

- deterministic
- fast (under 100ms)
- safety-critical
- impossible to forget when added as a hook

Bad fits for hooks:

- anything that needs to load into context
- anything that makes network calls
- anything slow or unreliable

---
