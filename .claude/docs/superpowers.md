# Superpowers and the spec-driven flow

> Last reviewed: YYYY-MM-DD
> Reference: https://github.com/obra/superpowers

## What is Superpowers

Superpowers is an official Claude Code plugin by Jesse Vincent (obra/superpowers). It installs a set of skills that **enforce** a structured development flow through quality gates.

Core philosophy: AI agents respond to structure, not suggestions. "Always write tests first" in `CLAUDE.md` is a suggestion. A skill with enforcement is a gate.

## Installation

```bash
# Inside Claude Code
/plugin install superpowers@claude-plugins-official
```

The `using-superpowers` skill auto-loads via a SessionStart hook after install.

## The canonical flow

```
Brainstorm  →  spec.md   →  plan.md   →  TDD execution  →  Code review  →  Ship
   (chat)      (commit)    (commit)      (subagents)        (agent)
```

Each gate **blocks** the next until resolved.

### 1. Brainstorming

When you describe a feature, the `brainstorming` skill activates automatically. Claude does NOT write code. Instead, it asks socratic questions until the feature is clear.

Output: a design document presented in chunks for you to approve.

### 2. Spec

After the brainstorm is approved, it becomes `specs/<date>-<slug>/spec.md`. This is the **source of truth**. Any future divergence between code and spec is resolved by reading the spec, not the code.

### 3. Plan

The `writing-plans` skill breaks the spec into **2-5 minute tasks** with:

- File path
- Exact commands
- Failing test to write first
- Minimal code to make it pass

Output: `specs/<date>-<slug>/plan.md`.

### 4. Execution via subagent-driven-development

The `subagent-driven-development` skill dispatches a subagent **per task**, with fresh context. Each subagent:

1. Reads the spec
2. Reads the task in the plan
3. Writes the failing test (red)
4. Implements minimum to pass (green)
5. Refactors if needed
6. Reports back

### 5. Code review as gate

Between each task, the `code-reviewer` subagent (in `.claude/agents/`) reviews against:

- Spec
- Plan
- Conventions

CRITICAL issues **block** progress. Without resolution, the next task does not run.

### 6. Ship

The `finishing-a-development-branch` skill verifies everything passes, then presents options: merge, PR, keep branch, discard.

## How this template integrates

- **`specs/`** follows the Superpowers format (spec.md + plan.md per feature)
- **`.claude/agents/spec-reviewer.md`** complements brainstorming: audits the spec before it becomes a plan
- **`.claude/agents/code-reviewer.md`** acts as the gate between tasks
- **`src/<folder>/CLAUDE.md`** nested files provide conventions the code-reviewer uses

## When NOT to use the full flow

- **Exploratory prototyping:** when you do not know what you want yet, prototype without specs. But the prototype does NOT become production code without running the flow first.
- **Trivial bug fix:** typo, color tweak, label update.
- **Mechanical refactor:** rename, move, extract function. No behavior change.

For everything else: brainstorm, then spec, then plan, then execution.

## Non-negotiable discipline

Three things that, if you skip, the flow loses value:

1. **Spec is source of truth.** Every "is this right?" question gets resolved by reading the spec. No exceptions.
2. **Test before code.** Always. Red, green, refactor.
3. **Task checkboxes are recovery.** If you get interrupted, they tell you where you stopped. Do not skip.

## Common mistakes

- "Can I just implement and write the spec after?" No. The spec captures decisions that get lost in implementation.
- "This task is too small for a spec." Probably it is a trivial fix. But if you are asking, it probably is not.
- "The plan is huge." Sign the feature is too big. Break it into smaller features, each with its own spec.

## Links

- Plugin: https://github.com/obra/superpowers
- Marketplace install: `/plugin install superpowers@claude-plugins-official`
- Spec-driven tutorial: https://www.datacamp.com/tutorial/spec-driven-development-with-claude-code
