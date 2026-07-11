---
name: write-spec
description: Creates a new feature spec in the canonical location `specs/YYYY-MM-DD-<slug>/`. Use when the user is ready to formalize a shaped idea (after exploration) or when they know exactly what they want to build. Guarantees the spec ends up in the right folder regardless of which spec-driven tool the team uses (Superpowers, OpenSpec, or none). Use when the user says "write the spec", "let's spec this", "create a spec for X", or similar.
---

# Write spec

Persist a shaped idea as `specs/YYYY-MM-DD-<slug>/spec.md`. Consistent format, consistent location, cross-tool compatible.

## When to invoke

- After a successful `explore` session
- When the user has a clear feature in mind and asks to spec it
- When the user says "spec this out" or "create a spec"

If the idea is fuzzy, do NOT jump to spec. Use `explore` first.

## Steps

### 1. Confirm the slug

The slug becomes the folder name. Ask the user (or infer):

- Short (< 40 chars total including date)
- kebab-case
- Descriptive: `add-dark-mode` not `feature-1`
- No year in the slug itself (the date prefix has it)

Example: `2026-06-23-add-dark-mode`

### 2. Check for collision

```bash
today=$(date +%Y-%m-%d)
folder="specs/${today}-<slug>"
if [[ -d "$folder" ]]; then
  # collision - append suffix or ask user
fi
```

### 3. Create the folder structure

```bash
mkdir -p "$folder"
```

### 4. Write spec.md

Start from the template shipped with this skill. Copy it, then fill it in:

```bash
cp .claude/skills/write-spec/references/spec-template.md "$folder/spec.md"
```

Fill in what you know from the exploration. Leave `TODO` markers for anything the exploration did not settle.

Required sections:

- Problem
- Proposed solution
- Functional requirements
- Non-functional requirements
- Out of scope (v1)
- Use cases (happy path + error scenarios)
- Edge cases
- Success metrics
- Risks
- References (link to related ADRs, past specs, external docs)

### 5. Reference the existing docs

At the top of `spec.md`, add pointers so future readers (and other agents) know the context:

```markdown
## Context references

- Constitution: `docs/CONSTITUTION.md` (if present)
- Architecture: `docs/architecture/overview.md` (if present)
- Conventions: `docs/CONVENTIONS.md` (if present)
- Related ADRs: (list any decisions this depends on or challenges)
- Related past specs: (list specs that touch similar areas)
```

### 6. Prepare empty plan.md and tasks.md

The spec is only the first of three artifacts. Create empty scaffolds for the others so the folder structure is complete and later steps know where to write:

```bash
cp .claude/skills/write-spec/references/plan-template.md "$folder/plan.md"
cp .claude/skills/write-spec/references/tasks-template.md "$folder/tasks.md"
```

Then update the headers in the copied files:

- In `plan.md`: replace `example-feature` with the slug
- In `tasks.md`: replace `example-feature`, set `Current status: not started`, set `Last updated: <today>`

Do NOT fill plan.md or tasks.md yet. Those come in the writing-plans step, after the spec is approved.

### 7. Optionally note snapshot dependency

If the feature spans multiple areas of the codebase (3+ folders or 5+ files), add at the bottom of `spec.md`:

```markdown
## Implementation context

This feature touches multiple areas. When implementing:
- Invoke the `codebase-explorer` subagent first to establish full context
- The Repomix snapshot at `.claude/context/repomix-snapshot.md` should be current
```

### 8. Report

```
## write-spec complete

### Created
- specs/YYYY-MM-DD-<slug>/spec.md (filled)
- specs/YYYY-MM-DD-<slug>/plan.md (scaffold, to be filled after spec approval)
- specs/YYYY-MM-DD-<slug>/tasks.md (scaffold, to be filled after plan is written)

### Status
- spec: Draft, needs review before writing the plan

### Next steps
- Review the spec (invoke `spec-reviewer` subagent if you want a formal audit)
- When approved, fill in plan.md (architecture, phases, tech choices)
- Then break the plan into atomic tasks in tasks.md (2-5min each, TDD)
- Change spec status to "Approved" before moving on
```

## What NOT to do

- Do not create the spec outside `specs/YYYY-MM-DD-<slug>/`. There is one canonical location.
- Do not skip the date prefix. Ordering by date matters when you have many specs.
- Do not write plan.md or tasks.md contents at the same time as spec.md. Create scaffolds, fill them later (after review).
- Do not merge plan.md and tasks.md into one file. They serve different purposes and update at different rates.
- Do not invent facts. If exploration did not settle something, mark it TODO explicitly.

## Interop with other tools

The format is universal markdown. It works with:

- Manual reading and PR review
- Superpowers `writing-plans` skill (reads `specs/<slug>/spec.md` and generates `specs/<slug>/plan.md`)
- OpenSpec if you configure it to use `specs/` instead of `openspec/changes/` (see OpenSpec `config.yaml`)
- Codex, Cursor, Gemini reading via AGENTS.md pointer

There is ONE location for specs, regardless of which tool generated them.
