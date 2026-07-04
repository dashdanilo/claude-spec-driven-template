# docs/patterns/

Living examples of "how we solved X in this project". A pattern is a small, real snippet showing how a specific problem was solved here, so future solutions can follow the same shape.

## Why patterns beat prose

Three paragraphs describing "we use functional patterns and prefer composition over inheritance" teach almost nothing. One 15-line snippet showing an actual composition in this codebase teaches everything.

Patterns are the highest-signal-per-token documentation you can write. Agents especially benefit from them: they show conventions in action, not in the abstract.

## Format for one pattern

Each pattern is a short markdown file:

```markdown
# <Pattern name>

**When to use:** <the situation this pattern addresses>
**Where in the codebase:** <example paths>
**Related:** <other patterns or docs>

## Problem

One paragraph. What situation triggers this pattern.

## Solution

The pattern itself, shown as a real (or realistic) code snippet.

`​``ts
// Actual code demonstrating the pattern
`​``

## When NOT to use this

Cases where this pattern is the wrong choice.

## Alternatives considered

Briefly, other approaches and why this one won.

## References

Files in the codebase that follow this pattern:

- `src/path/file1.ts`
- `src/path/file2.ts`
```

## Suggested pattern topics

Only add patterns when you have a real, solved example. Some common candidates:

- Error handling in server code
- Loading state in UI
- Form validation flow
- API request wrapper
- Feature flag check
- Retry logic
- Structured logging call site
- Caching strategy for a specific data type

## Anti-patterns

You can also document anti-patterns: things that look tempting but are wrong here. Prefix with `anti-` in the filename:

- `anti-nested-useeffect.md`
- `anti-any-in-typescript.md`

## Integration with AI agents

The `explore` and `find-existing-first` skills read this folder before proposing solutions. When a user asks "how should I handle X?", agents check here first. Keep patterns current - outdated patterns actively mislead.

## Naming convention

`kebab-case-noun.md`. Names should read as "this file describes X".

Good: `structured-logging.md`, `optimistic-updates.md`, `feature-flag-check.md`
Bad: `logging.md` (too vague), `how-to-log.md` (verbose), `LoggingPattern.md` (wrong case)
