---
name: skill-best-practices
description: >-
  Authoring standards a finished Agent Skill must meet: frontmatter shape, description trigger
  phrasing, progressive disclosure, size limits, writing style, anti-patterns, and the workflow
  for editing, splitting, merging, or deleting an existing skill. Use when writing or reviewing
  any SKILL.md or references file, checking a description for trigger accuracy, or modifying a
  skill that already ships. For designing a brand-new skill end-to-end the way this repo does
  it, use skill-architect instead.
---

# Skill best practices

The standards a finished skill must meet, and the workflow for changing one that already exists. `skill-architect` owns the end-to-end process for designing and writing a *new* skill for this repo; this skill owns the micro-standards both a new and an edited skill are judged against, plus everything specific to editing.

## Conflict check before you edit

Before creating or updating a skill:

1. Read the `SKILL.md` of any skill that might overlap with the change (`git grep -n '<topic>' baseline/skills/*/SKILL.md`).
2. Check equivalent rules in other skills for consistency.
3. Detect contradictions and stop for a decision rather than picking silently.
4. Delete superseded rules instead of keeping revoked behavior in an active skill.

## Skill structure

```
skill-name/
├── SKILL.md              # Required, <200 lines
│   ├── YAML frontmatter  # name + description (required)
│   └── Markdown body     # Core instructions
└── Bundled resources     # Optional
    ├── scripts/          # Executable code
    ├── references/       # Documentation loaded on-demand
    └── assets/           # Files used in output (templates, images)
```

See [references/structure-and-metadata.md](references/structure-and-metadata.md) for frontmatter rules, naming, and bundled-resource details.

## Progressive disclosure (critical)

SKILL.md must be under **200 lines**. Split detailed content into `references/`.

1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when the skill triggers (<200 lines)
3. **Bundled resources** — loaded on-demand by the agent (unlimited)

This achieves roughly an 85% reduction in context load versus putting everything in the body. See [references/progressive-disclosure.md](references/progressive-disclosure.md) for patterns.

## Core principles

1. **Always in English** — all skill files, regardless of the user's language.
2. **Concise is key** — the context window is shared. Challenge every paragraph: "Does this justify its token cost?"
3. **Degrees of freedom** — high (text) for flexible tasks, medium (pseudocode) for a preferred pattern, low (scripts) for fragile operations.
4. **Imperative writing** — verb-first: "Extract text with..." not "You should extract...".
5. **One default, not many options** — a recommended approach with an escape hatch, not a menu.
6. **Delete superseded rules** — when editing a skill, remove sections describing behavior that no longer applies. Do not keep deprecated content inside an active skill.

See [references/writing-guidelines.md](references/writing-guidelines.md) for detailed guidance, and [references/patterns-and-examples.md](references/patterns-and-examples.md) for reusable body patterns (templates, examples, workflows, feedback loops).

## Acceptance checklist

A skill is ready when:

- [ ] All files written in English
- [ ] SKILL.md under 200 lines, each reference file under 200 lines
- [ ] Frontmatter has exactly `name` + `description` (plus `license`/`metadata` only when the content is adapted from elsewhere)
- [ ] Description is specific, third-person, states WHAT and WHEN, and names what it is **not** for when confusion is likely
- [ ] Consistent terminology throughout
- [ ] References are one level deep (no reference chains)
- [ ] No time-sensitive information
- [ ] Examples are concrete, not abstract

## Editing workflow

Use this when modifying, refactoring, splitting, merging, renaming, or deleting a skill that already ships. Creation of a new skill uses `skill-architect` instead.

1. **Conflict + cross-reference scan.** `git grep -n '<skill-name>' -- '*.md'` across the repo. Read every skill that might overlap. List contradictions and resolve them before writing.
2. **Capture a preservation list** in the PR description: commands that must survive verbatim, annotated examples that encode institutional knowledge, anti-patterns still relevant, cross-reference names used elsewhere. Do not delete a refined example without listing why.
3. **Update cross-references.** After a rename or removal, `git grep -n '<old-name>'` and fix every hit, including other skills' `SKILL.md`/`references/`, `CLAUDE.md`, `README.md`, and any external repo that links this harness per item (`baseline/scripts/check-index.sh --strict` is the gate on this side; a dangling name breaks the same check on the linking side).
4. **Validate.** Re-run the acceptance checklist above, plus: no broken cross-references, and every intentional removal is listed in the PR body with its rationale.

See [references/editing-workflow.md](references/editing-workflow.md) for the shape-change decision table (when to unify two skills, when to split one).

## Anti-patterns

| Anti-pattern | Fix |
|-------------|-----|
| Vague names (`helper`, `utils`) | Specific names (`processing-pdfs`, `code-review`) |
| Verbose explanations | Challenge every paragraph's token cost |
| Too many options | One default + escape hatch |
| Superseded behavior retained in file | Delete the obsolete rule entirely |
| Monolithic 1000+ line SKILL.md | Split into references (<200 lines each) |
| Windows paths (`scripts\file.py`) | Forward slashes (`scripts/file.py`) |
| Inconsistent terminology | Pick one term, use it everywhere |
| Over-fragmented (50+ tiny files) | 5-10 focused reference files |

## References

| Topic | File |
|-------|------|
| Structure and metadata | [references/structure-and-metadata.md](references/structure-and-metadata.md) |
| Writing guidelines | [references/writing-guidelines.md](references/writing-guidelines.md) |
| Patterns and examples | [references/patterns-and-examples.md](references/patterns-and-examples.md) |
| Progressive disclosure | [references/progressive-disclosure.md](references/progressive-disclosure.md) |
| Bootstrapping a skill from existing project docs | [references/from-project-docs.md](references/from-project-docs.md) |
| Editing workflow (shape-change decision table) | [references/editing-workflow.md](references/editing-workflow.md) |
