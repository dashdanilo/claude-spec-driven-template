---
name: explore
description: Free-form investigation before writing a spec. Reads the codebase, weighs options, discusses tradeoffs with the user, and produces a shaped idea ready for the write-spec skill. Nothing is committed to disk during exploration. Use when the user has a fuzzy idea and does not yet know the right solution, when the problem is clear but the solution is not, or when the user says "explore", "think through", "let's discuss before we commit to anything", or similar. Do not use when the user already knows what they want (go straight to write-spec).
---

# Explore

A no-stakes conversation. You investigate, you weigh, you propose. You do not create files, edit code, or generate specs during exploration. The output is a shaped idea that can become a spec (via `write-spec`) or be discarded if it did not survive scrutiny.

## When to invoke

- The user has a problem but not a plan
- The user has an idea but is unsure of the best approach
- The user says "explore", "think through", "discuss", "brainstorm"
- Before any `write-spec` or `writing-plans` invocation on a non-trivial feature

If the user already knows what they want and has clear scope, skip exploration and go to `write-spec`.

## Steps

### 1. Understand the problem

Ask the user to describe the problem in their words. Do not jump to solutions.

Useful clarifying questions (ask 1-3, not all):

- Who has this problem and what is the cost of not solving it?
- What triggered this now?
- What have you already tried or considered?
- Is there an existing feature that partially solves it?

### 2. Read the current state

Before proposing anything, understand what exists:

- Read `docs/CONSTITUTION.md` if it exists
- Read `docs/architecture/overview.md`
- Read `docs/CONVENTIONS.md`
- Skim `docs/patterns/` for existing solutions to similar problems
- If the exploration touches multiple files or areas, invoke the `codebase-explorer` subagent for a deep read

### 3. Weigh options

Present 2-4 options that would solve the problem. For each:

- One-line summary
- Pros
- Cons
- Rough effort
- Which existing components or patterns it would reuse

Bias toward reuse (see `find-existing-first`). Options that build on existing patterns get preference over greenfield options.

### 4. Discuss

Ask the user which option resonates. Push back if the choice contradicts existing conventions or ADRs. Refine until the picture is clear.

Signs the exploration is done:

- User can describe the feature in one paragraph without hedging
- Scope boundaries are explicit (what is in, what is out)
- The main technical approach is picked
- Known unknowns are listed

Signs exploration is NOT done:

- User keeps saying "or maybe..." - keep exploring
- You keep discovering new complications - keep exploring
- The scope grew during the conversation - pause, re-scope

### 5. Hand off

When ready, tell the user:

> Exploration complete. Ready to write the spec.
>
> Summary of what we agreed:
> - Problem: ...
> - Chosen approach: ...
> - In scope: ...
> - Out of scope: ...
> - Open questions to resolve during spec: ...
>
> Run `/skill write-spec <slug>` when ready.

## What NOT to do

- Do not create files during exploration
- Do not write code during exploration
- Do not propose a solution without understanding what exists (step 2 is mandatory)
- Do not present only one option - the user needs to see tradeoffs
- Do not force the user through the whole checklist if the exploration is trivial - adapt to the scope

## Relationship to other skills

- Before `explore`: nothing, this is the first step for non-trivial features
- Alternative to `explore`: `/opsx:explore` if OpenSpec is installed, or Superpowers' `brainstorming` skill
- After `explore`: `write-spec` to persist the shaped idea
- Sibling: `codebase-explorer` subagent for deep reads during exploration
