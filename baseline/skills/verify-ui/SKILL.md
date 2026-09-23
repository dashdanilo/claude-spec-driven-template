---
name: verify-ui
description: Drive the real UI (browser, TUI, rendered template) to prove a change that touches a screen actually works, then write that proof into verify-before-done's evidence report as a driven-flow claim with a screenshot artifact. Use after implementing any change that renders or alters something a human sees (page, component, email template, PDF, CLI TUI output). NOT for a pure backend/API change with no rendered surface - say so and skip it instead of burning tokens driving nothing.
metadata:
  portable: true
  applies_to: any repo with a rendered UI surface
  version: 1
---

# Verify UI

`verify-before-done` proves the code compiles, typechecks, and passes its tests. None of that proves a screen renders correctly - "open it and look" is a separate claim, and today nothing in the gate makes it. This skill is that claim.

## When it applies

Any change that renders or alters something a human sees: a page, a component, an email template, a generated PDF, a CLI TUI screen. If the diff touches JSX/templates/views/styles, or changes what an existing screen shows, this applies.

**Not for pure backend/API changes** - a resolver, a migration, a queue worker with no rendered surface. Say so in the report and skip this skill; running it there proves nothing and costs tokens for no signal.

Fires naturally alongside `verify-before-done` once a task's diff includes a rendered file; it is a separate skill rather than a section of that one because the driver setup and evidence shape are specific enough to earn their own trigger, and most tasks never touch a screen at all.

## Pick the driver, in this order

Check what the repo/session actually has before choosing - don't default to writing a script when the session already has a driver:

1. **The agent tool's own browser, if this session has one.** It can start the app, navigate, act (click, type, submit), read the DOM/console/network, and screenshot. Starting the app is usually the part that needs a repo convention: a project may keep a launch config the agent reads to know the dev command and URL (`njord-front`'s `.claude/launch.json` is a concrete example of one). Check for that convention before assuming there is none.
2. **A Playwright MCP server**, if the repo or user has one configured - same capabilities (navigate, act, read, screenshot), driven through MCP tools instead of the agent's own browser.
3. **A local Playwright/Puppeteer script the repo already has** (check `package.json` scripts and devDependencies before writing one) - run it for the flow you need; don't add a new script for a one-off check.
4. **None of the above:** do not assert the UI works. Say in the report that the UI claim is unproven and why (no driver available in this session or repo), and do not check off a task that depends on it. An unverified assertion is worse than an honest gap.

## What counts as proof

Reuse `verify-before-done`'s exact evidence contract (`baseline/scripts/verify-gate.py`) - do not invent a second report format. A UI claim is a `## Claims` bullet whose evidence is a `## Commands` bullet, except the "command" text is the driven flow itself plus the artifact path, not a shell invocation:

```
## Commands
- `ui: /login -> fill valid creds -> submit; dashboard renders "Welcome back"; 0 console errors; 0 failed requests; screenshot .claude/verification/screenshots/2026-09-23-login-flow.png` -> exit 0

## Claims
- login redirects to /dashboard on valid submit (evidence: `ui: /login -> fill valid creds -> submit; dashboard renders "Welcome back"; 0 console errors; 0 failed requests; screenshot .claude/verification/screenshots/2026-09-23-login-flow.png`)
```

The command text carries what `verify-gate.py` cannot check on its own: the steps actually driven, the assertions actually checked (visible text after the action, state after the action, no console error, no failed request), and the screenshot path. `exit 0` means every assertion in that line held; if one did not, the flow is broken, not proven - fix it or report it red, don't launder a failed assertion into a passing exit code. Save screenshots under `.claude/verification/screenshots/` (already gitignored, same as the rest of `.claude/verification/`).

One `## Commands`/`## Claims` pair per flow, not one pair for the whole page: a screen with a happy path and an error path is two driven flows, two claims, two screenshots. Don't collapse them into one bullet that hides which half was actually checked.

For a non-browser surface, the same shape still applies with a different artifact: a rendered email template's "screenshot" is the rendered HTML/preview output, a PDF's is the generated file, a CLI TUI's is the captured terminal output. The driver differs; the Commands/Claims shape and the "steps, assertions, artifact path" content of the command text do not.

## Do not turn this into a committed e2e suite

Driving the UI once to validate a change is cheap; maintaining a broad, committed end-to-end suite is expensive, slow, and brittle - that tradeoff is the whole reason this is a one-off skill and not a test-writing one. A check earns a **committed** test only when it guards a real regression (something that broke in production) or a money/permission path (checkout, billing, auth, an RBAC gate) - decide that the normal way this repo decides tests, this skill does not change it. Otherwise the driven flow stays a one-off validation: proof for this change, not a fixture someone maintains forever.

## Cost and honesty

A screenshot proves what the screen showed at the moment it was taken, not what it will show tomorrow. Timebox this to the flows the change actually touches - don't drive the whole app to validate one component. Do not paste driven output into a report a reviewer has to page through; the artifact path and the one-line claim are the interface.

## Boundaries (avoid duplication)

- Install/codegen/typecheck/build/unit-and-integration tests, the `## Commands`/`## Claims` report shape, and `verify-gate.py` itself → `verify-before-done`. This skill only adds the driven-UI claim to that same report; it does not replace or re-run the rest of the gate.
- Whether a check earns a committed test at all → this repo's own testing conventions (`AGENTS.md`, nested `CLAUDE.md`). This skill only says when a *driven-UI* check crosses that line, not how the repo writes tests in general.
