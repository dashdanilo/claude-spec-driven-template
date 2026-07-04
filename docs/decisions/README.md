# docs/decisions/

Architecture Decision Records (ADRs). An immutable history of significant decisions.

## What an ADR is

A short document that captures one decision:

- The context (what forced the decision)
- Options considered
- The choice
- Consequences (positive, negative, risks)

Once accepted, an ADR does not change. If the decision later shifts, a new ADR supersedes it. Both stay in the repo - the history of reasoning is the value.

## When to write one

Yes:

- Choice of a core technology (framework, database, ORM)
- Change in trust model or architecture
- A constraint that will shape future features
- "We are NOT doing X" when X looks tempting

No:

- Naming conventions (that goes in `CONVENTIONS.md` or `.claude/rules/`)
- Small library choices (lodash, date-fns)
- Anything easily reversible in a day

## Naming and numbering

`NNNN-slug-curto.md` where:

- `NNNN` is a 4-digit sequential number (0001, 0002, ...)
- `slug-curto` is kebab-case, max 5 words

Examples:

- `0001-use-postgres-not-mysql.md`
- `0002-no-redis-for-mvp.md`
- `0003-adopt-trpc-over-rest.md`

See [`0001-example.md`](./0001-example.md) for the template.

## Integration with AI agents

ADRs become valuable context. Agents in this template use them:

- `explore` skill reads ADRs before proposing options - surfaces prior decisions
- `code-reviewer` checks that changes don't silently violate accepted ADRs
- `researcher` cites ADRs when explaining "why is it this way?"

To integrate well, ADRs must be:

- Concrete (specific decision, not vague direction)
- Discoverable (short, clear title in the filename)
- Reversible via new ADR, never by silent code change

## When someone asks "why?" more than twice

If a question comes up more than twice in Slack/Discord/PR reviews - turn the answer into an ADR. That's the leading indicator of missing decision history.
