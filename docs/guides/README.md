# docs/guides/

Onboarding, how-tos, and tutorials for humans working on this project.

## What goes here

- Getting started (local setup, first PR)
- Testing guide (how to write tests here, what to test)
- Debugging guide (common issues, tools)
- Contribution guide (if not in root `CONTRIBUTING.md`)
- Feature-specific guides ("how to add a new API route")

## What does NOT go here

- Operational procedures - those go in `docs/runbooks/`
- Architectural context - that goes in `docs/architecture/`
- Design decisions - those go in `docs/decisions/`
- API reference - auto-generated or hosted separately

## Format

Guides are more narrative than runbooks. They can be prose, tutorial-style. They explain "why" as well as "how".

A good guide has:

- A clear audience (who this is for)
- Prerequisites (what you should know first)
- Concrete examples with real file paths
- A "next steps" section pointing to related material

## Suggested guides to create

- `getting-started.md` - clone, install, first successful run
- `local-setup.md` - environment variables, database, external services
- `testing.md` - test structure, conventions, how to write good tests
- `adding-a-feature.md` - walkthrough of the spec-driven workflow with a small example

## Integration with AI agents

Agents read guides when they need to help the user with a workflow they haven't done before. Well-written guides mean the agent gives accurate, project-specific answers instead of generic advice.
