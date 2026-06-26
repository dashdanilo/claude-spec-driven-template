---
paths: "**/*.{tsx,jsx,ts,js}"
---

# Example rule (rename this file)

> A rule is a path-scoped convention. The `paths:` glob in the frontmatter determines when this rule auto-loads.
> Without `paths:`, the rule loads always (becoming a hidden CLAUDE.md). Always scope rules.

This is what a rule looks like. Replace the content with your actual conventions.

## Example conventions

- Named exports only, no default exports
- Functional patterns over class-based
- Async/await over .then() chains
- Type imports separated: `import type { Foo } from './foo'`
- Avoid `any`. Use `unknown` and narrow.

## What rules are for

- Path-scoped conventions that apply to multiple files of a type
- Hard rules that a code-reviewer should enforce
- Short, factual statements (not explanations)

## What rules are NOT for

- Long documentation (use `.claude/docs/`)
- Folder-specific conventions (use nested `src/<folder>/CLAUDE.md`)
- Reusable workflows (use `.claude/skills/`)
- Reasoning about why (decisions go in `.claude/docs/decisions/`)

## Keep it short

A good rule is 20-50 lines. If yours is longer, it might be hiding three rules in one file, or it might be doc that belongs in `.claude/docs/`.
