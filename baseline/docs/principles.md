# Three principles

These are the rules behind how `.claude/`'s layers (agents, skills, rules,
hooks, commands, docs — see the layer table in the harness repo's own
`README.md`) relate to each other, referenced by name elsewhere (e.g.
`orchestrate`'s "Document ownership" step).

1. **One home per topic.** A fact lives in exactly one skill/rule; others cross-link, never copy.
2. **Rule vs skill.** A **rule** states *what* (one line, path-scoped, always in context for that path). A **skill** shows *how + why + example* (loads by task). Project-specific conventions are rules; the richer teaching is skills.
3. **One owner per document.** When `/orchestrate` or `/wave` runs specialists in parallel, each writes only its own outputs — `tasks.md` belongs to the orchestrator (it checks the boxes), `spec.md`/`plan.md` to the author, and a specialist never edits another wave's files. ADRs are append-only (`.claude/rules/adr.md`). This is what keeps parallel agents from clobbering each other.
