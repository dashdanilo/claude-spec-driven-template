---
name: find-existing-first
description: Enforces "reuse before create". Use IMMEDIATELY before creating any new file, component, function, module, or utility. Searches the codebase for existing implementations, related patterns, and prior decisions. Only proceeds to creation if nothing suitable exists. Use PROACTIVELY whenever the user or another skill is about to introduce new code that might already exist somewhere.
---

# Find existing first

The senior developer instinct: before you create it, check whether someone already did. Most of the time in a real codebase, they did.

## When to invoke

Any of these triggers:

- About to create a new file
- About to write a new component, hook, function, or utility
- About to install a new dependency
- User says "let's add X"
- Another skill (write-spec, apply, etc) is scoping new code

## Steps

### 1. Extract the concept

Restate what is about to be created in 3-5 nouns/verbs. If the user asked for "date picker", the concept is `date`, `picker`, `input`, `calendar`. If they asked for "user notification", it is `notification`, `user`, `alert`, `toast`.

### 2. Search the codebase (three passes)

**Pass 1: name and synonym search**

```bash
# search for exact and near matches by grep
grep -riE "(date|picker|calendar|input.*date)" src --include="*.tsx" --include="*.ts" -l
```

Use 3-5 synonyms. Include partial matches.

**Pass 2: file structure search**

```bash
# glob for files that might contain it
find src -name "*date*" -o -name "*picker*" -o -name "*calendar*"
```

**Pass 3: docs and specs**

- Check `docs/patterns/` for an existing pattern
- Check `docs/CONVENTIONS.md` for a mandated approach
- Check `specs/` for a past feature that solved something similar
- Check `.claude/docs/libs/` for a lib doc that mentions the concept
- Check `package.json` for a dependency that provides it

### 3. Classify what you found

Sort findings into three buckets:

**Bucket A: Exact match, reuse as-is**
- The concept already exists as a component/function you can import directly
- Action: use it. Do not recreate.

**Bucket B: Near match, extend or adapt**
- Something similar exists but doesn't quite fit
- Action: consider extending the existing thing (extra prop, additional variant) rather than duplicating

**Bucket C: Nothing similar, create new**
- Nothing in the codebase resembles what's needed
- Action: proceed to creation, but match the style of neighboring code

### 4. Report before creating

Report your findings before writing a single new line:

```
## find-existing-first: <concept>

### Searched for
<synonyms and paths>

### Found
- <path:line> - <what it does> - <bucket>
- <path:line> - <what it does> - <bucket>

### Recommendation
[REUSE | EXTEND | CREATE]

If REUSE: use `<path>` directly.
If EXTEND: modify `<path>` to add `<capability>`.
If CREATE: no existing analog. Proceed. Match style of `<similar-file>`.
```

### 5. Only then proceed

If the recommendation is REUSE or EXTEND, use or modify what exists. Do not create redundant code.

If CREATE, create - but match neighboring conventions (naming, imports, error handling).

## Heuristics for hard cases

**"But mine is slightly different"**
Extend before duplicate. A new prop or variant on an existing component is almost always better than a new component.

**"But the existing one has too much / too little"**
If too much, wrap it. If too little, extend it. Duplicating rarely wins.

**"The existing one is legacy code I want to avoid"**
Say so explicitly in the report. Flag it as candidate for refactor. But do not silently create a parallel implementation - that guarantees drift.

## What NOT to do

- Do not skip the search because "it's obviously not there"
- Do not create files with generic names (`utils.ts`, `helpers.ts`) - those attract dead code
- Do not proceed to creation without reporting first
- Do not extend the search to "let me also refactor everything I found" - that's a separate task

## Relationship to Ponytail

If [Ponytail](https://github.com/DietrichGebert/ponytail) is installed, it runs a superset of this at the plugin level (the YAGNI ladder). This skill is the project-scoped equivalent, always available, no plugin required.
