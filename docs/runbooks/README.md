# docs/runbooks/

Step-by-step procedures for operational tasks. When you're on-call at 3am, you follow a runbook, not an architecture diagram.

## What a runbook is

A checklist for a specific operational task:

- Deploy to production
- Roll back a failed deploy
- Rotate credentials
- Respond to an incident type
- Onboard a new integration

The rule: someone unfamiliar with the system should be able to execute the runbook by following it literally. If they need to think, the runbook is incomplete.

## Format

```markdown
# <Task name>

**When to use:** <the specific situation>
**Estimated time:** <realistic estimate>
**Requires:** <access, tools, credentials>

## Pre-flight checks

1. Confirm you have <access>
2. Notify #ops in Slack
3. Verify no active incidents

## Procedure

1. Step one
   ```bash
   exact command
   ```
   Expected output: <what you should see>

2. Step two
   ...

## Verification

How to confirm the task succeeded.

## Rollback

If step N fails, do this to revert.

## Common failures

- Symptom → cause → fix
- Symptom → cause → fix

## Contacts

Who to call if this runbook fails.
```

## Suggested runbooks to create

- `deploy.md` - production deploy
- `rollback.md` - undo a deploy
- `incident-response.md` - first 30 minutes when something breaks
- `credential-rotation.md` - rotating API keys
- `db-migration.md` - running a schema migration safely

## Runbook hygiene

- Test every runbook at least once quarterly (dry run in staging)
- Update immediately after an incident reveals a gap
- Date the last verified run at the top

## Integration with AI agents

Agents read runbooks when the user asks operational questions ("how do I deploy?", "what if the deploy fails?"). Keep them scannable - a wall of prose is useless at 3am.
