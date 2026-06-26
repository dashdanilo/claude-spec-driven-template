---
name: example-skill
description: Template for a reusable workflow skill. Rename and adapt to your repeatable processes. Use this anatomy as the starting point for any skill in this repo.
---

# Example Skill

> Rename the folder and this file. The `name` and `description` in the frontmatter are what Claude reads.

## When this skill activates

Claude reads the `description` field above and matches it against the task at hand. The more specific the description, the better the auto-invocation.

**Good description pattern:** "Use when [specific situation]"
**Bad description pattern:** "Helps with [vague area]"

## Workflow

Document the process here. A skill should have clear, ordered steps. Example:

1. Read the spec for the active feature: `specs/<latest>/spec.md`
2. Check the relevant lib doc: `.claude/docs/libs/<lib>.md`
3. Verify conventions in the target folder's nested `CLAUDE.md`
4. Implement following the order: failing test, minimal code, refactor
5. Run `pnpm test` to verify
6. Update `MEMORY.md` if applicable

## Files you can include alongside SKILL.md

```
.claude/skills/<name>/
├── SKILL.md           # this file
├── references/        # docs the skill reads on demand
│   └── checklist.md
├── assets/            # templates the skill outputs
│   └── template.md
└── scripts/           # helper scripts
    └── validate.sh
```

References and assets are not auto-loaded. The skill reads them only when the workflow requires it.

## Anti-patterns

- Dumping the entire skill content into `SKILL.md` (use `references/` for long content)
- Vague descriptions that match too broadly
- Skills that duplicate what already exists in a rule or doc
- Skills that should have been a script (deterministic work is not a skill)

## Writing good skills

- One skill, one purpose
- Steps in order, not a checklist of "things to consider"
- Concrete file paths and commands
- Note explicitly what NOT to do
