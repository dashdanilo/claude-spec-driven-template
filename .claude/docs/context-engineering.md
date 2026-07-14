# Context discipline for agents

Context is a **finite resource with diminishing returns**. The goal is the smallest set of high-signal tokens that gets the job done. The platform handles the heavy machinery (history compaction, tool-result clearing, memory); **your job is to not generate bloat in the first place.**

Portable — applies to any repo. Every agent here should follow it.

## Principles

- **Return conclusions, not raw material.** Notes, not essays. A summary/diff-stat/decision, not a transcript or a file dump. If you read 10 files, report what you found, not their contents.
- **Read narrowly.** Prefer `grep`/targeted `Read` (offset/limit) over reading whole files. Read the part you need, not the file "for context".
- **Isolate bulky work in subagents.** Dispatch heavy reading or implementation to a subagent and take back only its **summary**. One task's bloat must not pollute the parent's context.
- **Externalize state.** Use `tasks.md`, `lessons.md`, or short notes as durable memory instead of carrying everything in the conversation.
- **Re-fetchable beats stored.** If you can re-read a file or re-run a query later, don't keep its full output around — keep the pointer (path, id) and re-fetch on demand.
- **Steer the output shape when you dispatch.** Tell the worker exactly the minimal shape you need back (e.g. "return the files changed and a one-paragraph summary", not "show your work").

## Quick checklist

- [ ] Did I paste file/tool output I could have summarized or pointed to?
- [ ] Did I read a whole file when a `grep` + targeted read would do?
- [ ] Could this bulky step be a subagent that returns only a summary?
- [ ] Am I keeping state in the conversation that belongs in `tasks.md`/`lessons.md`?

## Reference

Anthropic cookbook — context engineering for tools/agents (compaction, tool-result clearing, memory). This doc distills the actionable part for a spec-driven, subagent-based workflow.
