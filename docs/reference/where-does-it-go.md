# Where does this instruction go?

> Moved out of `README.md` to keep the front door short. Linked from there.

## Decision table: where does this instruction go?

| Question | Place |
|---|---|
| Cross-tool guidance for any agent (stack, commands, conventions)? | `AGENTS.md` |
| Claude-specific extras (which skills/agents/hooks ship here)? | `CLAUDE.md` (stub + Claude-only content) |
| Shared schemas across services? | `ECOSYSTEM.md` |
| Project DNA and non-negotiable principles? | `docs/CONSTITUTION.md` |
| Style, naming, structure conventions? | `docs/CONVENTIONS.md` |
| System architecture overview? | `docs/architecture/overview.md` |
| Only applies inside a specific folder? | `src/<folder>/CLAUDE.md` (nested, full content) |
| Applies when editing a file type? | `baseline/rules/*.md` with `paths:` |
| Long reference doc, AI-only? | `baseline/docs/` |
| Human-facing project docs? | `docs/` |
| Repeatable multi-step process? | `baseline/skills/<name>/SKILL.md` |
| Specialist with its own perspective? | `baseline/agents/<name>.md` |
| Knowledge that grows over time? | Subagent with `memory:` field |
| What to build for this feature? | `specs/YYYY-MM-DD-<slug>/spec.md` |
| Architecture and phases for it? | `specs/YYYY-MM-DD-<slug>/plan.md` |
| Where did I stop? Atomic tasks? | `specs/YYYY-MM-DD-<slug>/tasks.md` |
| Operational procedure (deploy, incident)? | `docs/runbooks/` |
| Tutorial or onboarding guide? | `docs/guides/` |
| "How we solved X" pattern? | `docs/patterns/<pattern>.md` |
| Permanent architectural choice? | `docs/decisions/NNNN-*.md` |
| External lib docs that change often? | Context7 MCP, do not duplicate here |
| Personal preferences? | `CLAUDE.local.md` (gitignored) |

---
