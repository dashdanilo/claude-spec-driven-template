---
name: postmortem
description: Write a blameless postmortem after an incident has ended (a cross-tenant data leak, a prod outage, a failed deploy, a security exposure). Use when the user says "postmortem", "incident review", "retro on the incident", "what went wrong in prod", or asks to document an incident that already happened. NOT for debugging a live, ongoing bug: that is `diagnosing-bugs`. Use this only once the incident itself is over.
license: MIT
metadata:
  adapted_from: "engineering-incident-response-commander by msitarzewski (github.com/msitarzewski/agency-agents, MIT)"
  portable: true
  version: 1
---

# Postmortem: blameless incident review

The incident is already over. This skill turns it into a document the org learns from, not a record of who to blame. Fix the system, not the person: findings name what the system lacked (a check, an alert, a boundary), never who made the mistake.

## Workflow

```text
Postmortem Progress:
- [ ] Classify severity (SEV1-SEV4) and confirm it, do not downgrade under pressure
- [ ] Reconstruct the timeline from logs/commits/messages, not memory alone
- [ ] State impact in concrete numbers, not "some users"
- [ ] Split causes into immediate / underlying / systemic
- [ ] Name the 3-5 changes that would have prevented or caught this, tagging each CONFIRMED or ASSESSMENT
- [ ] Write action items, each with one owner and one due date
- [ ] Write the file to docs/postmortems/
```

## Severity

Classify first; severity decides escalation and how much rigor the rest of the document needs. Use [references/postmortem-template.md](references/postmortem-template.md)'s severity table.

**Any doubt about data integrity or cross-tenant exposure is SEV1, no exceptions.** A "probably contained" cross-tenant leak is still SEV1 until proven otherwise; downgrading on a hunch is exactly the failure mode this rule exists to block.

## During-incident hypotheses were time-boxed

If the incident record shows hypotheses being chased without a time box, call that out as a finding. The rule for a live incident: 15 minutes per hypothesis, then pivot or escalate, mirroring `diagnosing-bugs`' Phase 3 discipline. A postmortem that finds no time-boxing happened is itself an actionable finding ("responders followed a single hypothesis for 90 minutes with no checkpoint").

## Timeline and impact

Reconstruct the timeline from artifacts (commit timestamps, deploy logs, monitoring alerts, the incident channel), not from what someone remembers thinking. Impact is a number: users affected, records exposed, minutes of downtime, revenue at risk. "Some users experienced issues" is not impact; it is the absence of impact analysis.

## Causes: three layers, not one

Never stop at the first plausible cause. Split into:

- **Immediate cause**: the direct trigger (the query that leaked, the deploy that broke).
- **Underlying cause**: why the trigger was possible (missing tenant-scoping check, no rollback tested).
- **Systemic cause**: what organizational or process gap let the underlying cause ship (no review checklist for auth changes, no canary stage).

Stopping at "immediate" produces an action item that prevents this exact bug and nothing like it.

## The 3-5 preventive/detective changes

Name the changes that would have prevented the incident or caught it faster, capped at five so the list stays prioritized instead of exhaustive. Tag each one:

- **CONFIRMED**: verified against the code, config, or a test you actually ran (e.g. "a tenant-id assertion in this query would have raised on the exact failing input, verified by adding it and rerunning the repro").
- **ASSESSMENT**: your judgment, not yet verified (e.g. "a canary stage would likely have caught this before full rollout").

Do not blend the two without the tag. A reader deciding what to fund needs to know which claims are load-bearing fact and which are opinion.

## Action items

Every action item has exactly one owner and one due date; "the team" and "soon" are not values. Track status (Not Started / In Progress / Done) so a follow-up postmortem can check whether the last one's items actually landed, not just whether the meeting happened.

## Output

Write to `docs/postmortems/YYYY-MM-DD-<slug>.md` in the affected repo (create the directory if it does not exist). Use [references/postmortem-template.md](references/postmortem-template.md) as the shape; do not invent a different structure per incident, so postmortems stay comparable over time.

## Boundaries (avoid duplication)

- Diagnosing the bug while it is still live, building a red-capable repro, hypothesis testing during active troubleshooting: `diagnosing-bugs`.
- Recording a durable architectural decision that comes out of a postmortem's action items: an ADR under `docs/decisions/` (see `baseline/rules/adr.md`), not the postmortem file itself.
- Recording durable domain knowledge that changed as a result of the fix: `documenting-domains`.
