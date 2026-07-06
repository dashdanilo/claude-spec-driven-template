---
name: skill-best-practices
description: >-
  Authoring standards for Agent Skills in the shared ui-agents submodule. Use when creating,
  editing, or reviewing SKILL.md files, frontmatter, progressive disclosure, descriptions, repo
  scope, or branched operational flows. Use when the user asks for skill best practices, skill
  templates, parity across sky-ds and SPAs, or where team skills should live.
---

# Skill best practices

Guide for creating, editing, and reviewing shared Agent Skills without losing project-specific behavior.

## Team skills location

Canonical organization skills live under `skills/` in this `ui-agents` repository. Consumer repos embed this repository as a Git submodule. Edit skills here, then bump the submodule pointer in parent repositories.

## Submodule rollout

After merging changes here, tag a baseline (`skills-dedup-<date>`) then bump the submodule pointer in each consumer repo (`sky-ds`, `ui-app`, `ui-cockpit`, `ui-control-panel`). That is the only way changes reach agents in those repos. To revert, restore the prior submodule commit in the consumer repo and re-run `git submodule update`.

## Conflict check before you edit

Before creating or updating a skill:

1. Read all relevant `SKILL.md` files under `skills/`.
2. Check equivalent rules in other skills for consistency.
3. Detect contradictions and stop for user decision.
4. Delete superseded rules instead of keeping revoked behavior in active skills.

## Scope before you edit

When a skill's behavior differs by repository type:

1. Read the parent repo `package.json` `name` and check for `workspaces` / `pnpm-workspace.yaml`.
2. If the name is not in the mapping below, ask the user whether the skill is generic, sky-ds monorepo, or React SPA. Do not guess.

## Package name mapping

If consumer package names are not available in this checkout, do not invent values; instruct the agent to ask the user.

| Package name | Repo type |
|---|---|
| sky-ds workspace root (no published name) | pnpm monorepo |
| `ui-app` / `ui-cockpit` / `ui-control-panel` | React SPA |

## Parity gate for branched operational skills

Before merging two variants into one skill, write a parity matrix that lists outcomes, steps, commands, artifacts, and CI gates for each repo type. Preserve existing refined behavior by moving detailed flow rules to `references/`, not by deleting them.

## Reference path policy

| Context | Path style |
|---|---|
| Cross-skill link inside a `SKILL.md` or `references/` | `skills/<name>/SKILL.md` (repo-relative; GitHub-clickable) |
| Sibling `references/` link (same skill) | bare filename `other-ref.md` |
| Inside `agents/*.md` (consumer POV) | `.agents/skills/<name>/SKILL.md` |

Never use absolute paths. Consumer agents mount the submodule under `.agents/skills/`, so paths inside `agents/*.md` must use that prefix. Paths inside `skills/` use the repo-relative form.

## What Skills Provide

1. **Specialized workflows** — Multi-step procedures for specific domains
2. **Tool integrations** — Instructions for working with file formats or APIs
3. **Domain expertise** — Company-specific knowledge, schemas, business logic
4. **Bundled resources** — Scripts, references, and assets for repetitive tasks

## Skill Structure

```
skill-name/
├── SKILL.md              # Required, <200 lines
│   ├── YAML frontmatter  # name + description (required)
│   └── Markdown body     # Core instructions
└── Bundled Resources     # Optional
    ├── scripts/          # Executable code
    ├── references/       # Documentation loaded on-demand
    └── assets/           # Files used in output (templates, images)
```

See [references/structure-and-metadata.md](references/structure-and-metadata.md) for full details on frontmatter, naming, and bundled resources.

## Progressive Disclosure (Critical)

SKILL.md must be under **200 lines**. Split detailed content into `references/` files.

### Three-Level Loading

1. **Metadata** (name + description) — Always in context (~100 words)
2. **SKILL.md body** — Loaded when skill triggers (<200 lines)
3. **Bundled resources** — Loaded on-demand by agent (unlimited)

This achieves ~85% reduction in context load vs putting everything in the skill body. See [references/progressive-disclosure.md](references/progressive-disclosure.md) for patterns.

## Core Principles

1. **Always in English** — All skill files must be written in English, regardless of the user's language.
2. **Concise is key** — The context window is shared. Challenge every paragraph: "Does this justify its token cost?"
3. **Degrees of freedom** — High (text) for flexible tasks, Medium (pseudocode) for preferred patterns, Low (scripts) for fragile operations.
4. **Imperative writing** — Use verb-first: "Extract text with..." not "You should extract..."
5. **One default, not many options** — Provide a recommended approach with an escape hatch, not a menu of choices.
6. **Test with multiple models** — Effectiveness varies by model.
7. **Delete superseded rules** — When editing a skill, delete rules that describe superseded behavior. Do not keep revoked/deprecated sections inside active skills.

See [references/writing-guidelines.md](references/writing-guidelines.md) for detailed guidance.

## Creation Workflow

### Step 0: Conflict check (mandatory before writing)

1. Read ALL `SKILL.md` files in `skills/`
2. For each rule in the target skill:
   - Check equivalent rules in other skills for consistency
   - Detect direct contradictions and stop for user decision
   - Remove stale rules that reference removed behavior
3. Present all detected conflicts to the user before writing content
4. Proceed only after conflict resolution

### Step 1: Gather Requirements

Understand the skill's purpose through concrete examples:

- What specific task or workflow should this skill help with?
- When should the agent automatically apply it? (trigger scenarios)
- What domain knowledge does the agent need that it wouldn't already know?

Use the `AskQuestion` tool when available to gather requirements interactively. If context from a previous conversation already exists, infer the skill from what was discussed.

### Step 2: Plan Resources

Analyze each use case and identify reusable resources:

- **Scripts** — Code that would be rewritten each time
- **References** — Documentation the agent should consult
- **Assets** — Files used in output, not loaded into context

### Step 3: Write the Skill

1. Create the directory structure
2. Write SKILL.md with frontmatter: `name` (lowercase, hyphens, max 64 chars) + `description` (WHAT + WHEN, max 1024 chars)
3. Write concise body (<200 lines)
4. Create reference files for detailed content (<200 lines each)
5. Add scripts/assets as needed

### Step 4: Validate

- [ ] All files written in English
- [ ] SKILL.md under 200 lines
- [ ] Description is specific, third-person, includes WHAT and WHEN
- [ ] Consistent terminology throughout
- [ ] References are one level deep (no nested references)
- [ ] No time-sensitive information
- [ ] Examples are concrete, not abstract
- [ ] Scripts tested and working

### Step 5: Iterate

1. Use the skill on a real task
2. Note any friction or missed edge cases
3. Patch SKILL.md or references to address them
4. Retest with a fresh agent instance

## Editing Workflow

Before editing an existing skill, run the conflict + cross-reference scan from Step 0 above. For the full editing procedure (E0–E5 steps), preservation discipline, split/unify decision table, and editing validation checklist, see [references/editing-workflow.md](references/editing-workflow.md).

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Vague names (`helper`, `utils`) | Specific names (`processing-pdfs`, `code-review`) |
| Verbose explanations | Challenge every paragraph's token cost |
| Too many options | One default + escape hatch |
| Superseded behavior retained in file | Delete obsolete rule entirely |
| Monolithic 1000+ line SKILL.md | Split into references (<200 lines each) |
| Windows paths (`scripts\file.py`) | Forward slashes (`scripts/file.py`) |
| Inconsistent terminology | Pick one term, use it everywhere |
| Over-fragmented (50+ tiny files) | 5–10 focused reference files |

## References

| Topic | File |
|-------|------|
| Structure and metadata | [references/structure-and-metadata.md](references/structure-and-metadata.md) |
| Writing guidelines | [references/writing-guidelines.md](references/writing-guidelines.md) |
| Patterns and examples | [references/patterns-and-examples.md](references/patterns-and-examples.md) |
| Progressive disclosure | [references/progressive-disclosure.md](references/progressive-disclosure.md) |
| Skills from project docs | [references/from-project-docs.md](references/from-project-docs.md) |
| Editing workflow | [references/editing-workflow.md](references/editing-workflow.md) |
