---
paths: "**"
---

# Code quality

Cross-cutting quality conventions. Language-agnostic; the `code-reviewer` subagent should enforce them.

## Naming

- Names describe what a thing DOES, not what it IS
- Booleans read as predicates: `is` / `has` / `can` / `should` prefixes
- No abbreviations unless universal (`id`, `url`, `api` ok; `usr`, `mgr`, `btn` not)
- A file's name matches the main thing it defines

## Structure

- Prefer composition over inheritance
- Prefer pure functions; push side effects to the edges
- One module, one responsibility
- Use early returns to cut nesting
- Keep functions small — split when one grows past ~40 lines or does several things
- Inject dependencies instead of hard-coding them, so units can be tested in isolation

## Error handling

- Use specific, named error types, not bare strings or generic errors
- Never swallow errors silently — no empty catch blocks
- Error messages carry context: what failed, why, and with what input
- Let errors surface to the layer that can handle them — don't catch too early

## Imports and dependencies

- Order imports: standard library → third-party → local
- Prefer absolute or root-relative paths over deep `../../..` chains
- No wildcard imports
