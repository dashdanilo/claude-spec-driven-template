# Postmortem template

Copy this into `docs/postmortems/YYYY-MM-DD-<slug>.md`. Delete a section only if it truly does not apply (e.g. no customer impact); do not delete a section because filling it out is hard.

## Severity table

Classify against this table before writing anything else. Escalate up a level if any trigger in "Escalation" fires, and never escalate down without a fact that rules it out.

| Level | Meaning | Escalation triggers |
|---|---|---|
| SEV1 | Full outage, data loss, security breach, or any doubt about data integrity or cross-tenant exposure | Any cross-tenant data exposure, confirmed or suspected. Any data loss or corruption. Full service outage. |
| SEV2 | Degraded service for a meaningful share of users, or a key feature fully down | Impact scope doubles while investigating. No root cause after 2 hours. Any paying customer affected. |
| SEV3 | Minor feature broken, workaround exists | No root cause after a working day. |
| SEV4 | Cosmetic, no user impact | N/A |

## Header

```markdown
# Postmortem: <incident title>

Date: YYYY-MM-DD
Severity: SEV<1-4>
Duration: <start time> to <end time> (<total duration>)
Author: <name>
Status: Draft / Reviewed / Final
```

## Summary

Two to three sentences: what happened, who was affected, how it ended. No jargon a new hire could not follow.

## Timeline

Reconstructed from artifacts (commits, deploy logs, alerts, the incident channel), in the order things actually happened, with times. Mark anything you could not verify from an artifact as `(unverified, from memory)`.

| Time | Event |
|---|---|
| 14:02 | Alert fires: <symptom> |
| 14:05 | Incident declared, <severity> |
| ... | ... |
| 14:45 | Resolved, all-clear sent |

## Impact

Numbers, not adjectives.

- Users/tenants affected: <count or percentage>
- Data exposed or lost: <what, how much, confirmed how>
- Downtime: <duration>
- Customer-facing tickets/reports: <count>

## Causes

Three layers. Do not stop at the first one.

- **Immediate cause**: the direct trigger.
- **Underlying cause**: why the trigger was possible.
- **Systemic cause**: the organizational or process gap that let the underlying cause ship.

## The 3-5 changes that would have prevented or caught this

Cap at five. Tag each CONFIRMED (verified against code/config/a test you ran) or ASSESSMENT (judgment, not yet verified).

1. [CONFIRMED/ASSESSMENT] <change>
2. [CONFIRMED/ASSESSMENT] <change>
3. [CONFIRMED/ASSESSMENT] <change>

## What went well / what went poorly

- What went well: <things that worked during response>
- What went poorly: <things that slowed detection or resolution>

## Action items

| ID | Action | Owner | Due date | Status |
|---|---|---|---|---|
| 1 | <action> | <owner> | YYYY-MM-DD | Not Started |
| 2 | <action> | <owner> | YYYY-MM-DD | Not Started |

## Lessons learned

What should this change about how the team builds, reviews, or operates, beyond this one incident.
