# Domain CLAUDE.md Template

Use this template for local domain documentation. Adjust section names to the codebase, but keep the intent.

Write generated domain documentation in English. Translate existing local domain docs to English when maintaining them.

```markdown
# <DomainName>

Local domain documentation for `<DomainName>`. Use this as durable context when temporary specs/plans are gone.

## Purpose

Explain the domain in 2-5 bullets:

- what problem it solves;
- what normalized concepts it owns;
- what future agents must preserve.

## Responsibility map

- `<folder-or-file>/`: stable responsibility.
- `<folder-or-file>/`: stable responsibility.
- `index.ts` or public entrypoint: exported surface.

Avoid line-by-line summaries. Document responsibilities that prevent wrong edits.
For complex domains, group by layer or contract. Do not enumerate every file unless it is a public entrypoint or durable boundary.

## Core model or concepts

List the main entities, value objects, states, events, or contracts.

- `DomainEntity`: durable fields or meaning.
- `DomainState`: state semantics.
- `DomainAction`: mutation contract.

## Invariants

Document rules that must remain true:

- shape invariants;
- ordering/index rules;
- compatibility rules;
- fallback behavior;
- ownership boundaries.

## Data flow / behavior rules

Summarize how data enters, changes, validates, and leaves the domain.

Prefer “when X happens, Y owns Z” over implementation narration.

## Internal integrations

Document stable internal adapters, hooks, UI, stores, or services only when they are part of this domain’s contract.

- Adapter A converts external/source payload into the domain model.
- Hook B owns side effects; pure core does not.
- UI C receives callbacks and must not access global state directly.
```

## Keep / cut rules

| Keep | Cut |
|---|---|
| Domain purpose | Work-session narrative |
| Responsibility map (layer/contract) | Full directory tree or internal helper enumeration |
| Models/contracts and invariants | Function-name or file-path rosters |
| Behavior rules ("when X, Y does Z") | UI render narration |
| Stable integration contracts | Condition lists that duplicate code |
| Boundary rules | External consumer internals |
| - | Meta sections (Design decisions, When changing, Anti-patterns) |

## Good style

- Use imperative or factual bullets.
- Name a type/function only when it is a stable public contract; never to narrate implementation.
- Mention external libraries only when they define a boundary or contract.
- Keep examples minimal; one code snippet is enough when it prevents ambiguity.
