# Recommended ecosystem

> Moved out of `README.md` to keep the front door short. Linked from there.

## Recommended ecosystem

The template works standalone. It also composes well with a small set of external tools that solve orthogonal problems. None are required, but they earn their place.

### Plugins for Claude Code

**[Ponytail](https://github.com/DietrichGebert/ponytail)** - cross-tool plugin that applies a YAGNI ladder before writing any code. Complements `find-existing-first`. Install:
```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

**[Superpowers](https://github.com/obra/superpowers)** - Claude-only plugin with enforced brainstorm → spec → plan → TDD flow. Ships skills like `brainstorming`, `writing-plans`, `subagent-driven-development`, `finishing-a-development-branch`. Compatible with this template's `specs/` layout. Install:
```
/plugin install superpowers@claude-plugins-official
```

### Cross-tool spec frameworks

**[OpenSpec](https://github.com/Fission-AI/OpenSpec)** - CLI plus skills spanning 30+ AI coding tools. Ships `/opsx:explore` for pre-spec investigation and delta specs designed for brownfield. Configure to write to this template's `specs/` folder instead of `openspec/changes/`. Install:
```
npm install -g @fission-ai/openspec@latest
cd your-project && openspec init
```

### Context tools

**[Repomix](https://github.com/yamadashy/repomix)** - packs the entire codebase into a single file that AI agents can consume in one read. Already wired into `analyze-codebase` and `codebase-explorer`. Install:
```
npm install -g repomix
# or use via npx
```

**[Context7 MCP](https://github.com/upstash/context7)** - MCP server that serves versioned, always-current library documentation. Use instead of duplicating official docs into `baseline/docs/libs/`. Point to it in your Claude Code config once, agents query it on demand.

### Choosing your spec-driven tooling

Three sensible setups depending on the team:

| Setup | Tools | Best for |
|---|---|---|
| Claude-only, opinionated | Template + Superpowers + Ponytail | Solo dev or all-Claude team wanting maximum enforcement |
| Cross-tool, flexible | Template + OpenSpec + Ponytail | Team with Cursor/Codex/Gemini alongside Claude |
| Template alone | Just the template's own skills | Trying it out before adding anything else |

All three share the same `specs/YYYY-MM-DD-<slug>/` folder layout, so switching between them mid-project doesn't invalidate existing specs.

---
