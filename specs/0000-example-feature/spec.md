# Example feature (rename this folder and file)

**Date:** YYYY-MM-DD
**Status:** Draft | In review | Approved | In progress | Done
**Owner:** <name>

> This is the spec template. A spec describes WHAT to build and WHY.
> The companion `plan.md` describes HOW to build it (TDD tasks).
> Together they form the source of truth for the feature.

## Problem

Who has this problem? What is the cost of not solving it?

Write 1-3 paragraphs that establish why this feature matters.

## Proposed solution

Prose description of what the system will do. Avoid implementation details (those go in `plan.md`).

## Functional requirements

Numbered list of capabilities the feature must provide:

1. ...
2. ...
3. ...

## Non-functional requirements

- **Performance:** <metric and target>
- **Availability:** <expectation>
- **Security:** <constraints>
- **Cost:** <budget>

## Out of scope (v1)

Explicitly list what is NOT being built now. This is critical to prevent scope creep mid-implementation.

- ...
- ...

## Use cases

### Happy path
1. ...
2. ...

### Error scenarios
- What happens when X fails?
- What happens when user input is invalid?

## Edge cases

Explicit enumeration. Each edge case becomes a test:

- Empty input
- Maximum value
- Concurrent submissions
- Network failure mid-operation
- ...

## Success metrics

How will we know this feature works?

- Quantitative: ...
- Qualitative: ...

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| ... | Low/Med/High | Low/Med/High | ... |

## References

- ADRs in `.claude/docs/decisions/`
- Related specs
- External documentation
- Conversations or issues that informed this spec
