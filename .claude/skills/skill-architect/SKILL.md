---
name: skill-architect
description: Guided workflow to design and write a new skill (or agent) the way THIS repo does it — small SKILL.md + granular rules/<id>.md with real ok/anti examples, one-owner-per-topic, portable vs stack-assumed. Use when creating a new skill or agent, or reviewing one for quality, so new additions stay consistent and marketplace-ready. Use when the user says "create a skill", "add a skill for X", "author an agent".
license: CC-BY-4.0
metadata:
  adapted_from: "skill-architect by Felipe Rodrigues (tech-leads-club/agent-skills)"
  version: 1
---

# Skill architect — author a skill our way

Understanding precedes building: don't write a `SKILL.md` until you know the outcome, the trigger, and **who owns the topic**. This is the end-to-end workflow; `skill-best-practices` holds the SKILL.md micro-standards, and `.claude/README.md` explains the layers.

## Phase 1 — Discovery

- What outcome/pain does it serve? Write 2–3 concrete use cases (trigger → steps → result).
- **Topic skill** (stack-assumed knowledge, e.g. a `graphql-codefirst` plugin skill) or **workflow skill** (portable, discovers the stack, e.g. `verify-before-done`)? This decides tone and whether it hardcodes stack specifics.
- Trigger accuracy: which phrases/tasks should fire it — and which should **not**.

## Phase 2 — Architecture (anti-duplication first)

- **Who owns this topic?** Search existing skills/rules. A fact lives in **one** place; others cross-link. If it overlaps, extend the owner — do not duplicate. (We keep 0 duplicate rule titles.)
- Shape: a `SKILL.md` (small, with a **Quick Reference** table) + `rules/<id>.md` (one focused rule each) + `rules/_sections.md` index. A pure workflow skill may be a single `SKILL.md`.
- Draft the `description` as **[what] + [when, with trigger phrases] + [what NOT for]**.

## Phase 3 — Craft

- Frontmatter: kebab-case `name`, single-line `description`, exact `---` delimiters, no angle brackets.
- Each rule file: **Rule / Why / ❌ Incorrect / ✅ Correct**, grounded in a **real file** (cite the path). Imperative and specific — one precise instruction beats three vague paragraphs.
- Add a **Boundaries (avoid duplication)** section pointing to the owners of adjacent topics.

## Phase 4 — Validate

- kebab-case folder, `SKILL.md` present, **no `README.md`**, frontmatter valid.
- Duplication audit must be empty: `grep -rh '^# ' .claude/skills/*/rules/*.md | grep -vE '^# Rule index|^# <Rule' | sort | uniq -d`.
- Trigger test: read the description as an agent — does it over- or under-fire?

## Phase 5 — Deliver

- **Update `CLAUDE.md`** (and `.claude/README.md`) to list the new skill, then confirm `.claude/scripts/check-index.sh` reports no drift.
- Commit on a branch, open a PR to `develop`. Never commit to a protected branch.

## Principles

- Skills are for agents, not humans (no README.md).
- Progressive disclosure: `SKILL.md` small; depth in `rules/`/`references/`.
- Composability: assume other skills load too — scope tightly.

## Boundaries (avoid duplication)

- SKILL.md micro-standards / frontmatter details → skill `skill-best-practices`.
- The layer model (agents/skills/rules/hooks/docs) → `.claude/README.md`.
