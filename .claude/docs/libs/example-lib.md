# Example Lib (rename this file)

> Last reviewed: YYYY-MM-DD
> Lib version: X.Y.Z
> Official docs: <url>

> This is a template. Rename the file to the actual lib (e.g., the name of the service or package) and replace the content.

## Why we use it

One line. The role this lib plays in the system.

## How we authenticate

- Env var names
- Token storage location
- Token rotation schedule
- Who has access

## Endpoints / features we use

| Method | Endpoint or feature | Used for |
|---|---|---|
| POST | `/v1/example` | example operation |
| GET | `/v1/example/:id` | fetch example |

## Custom configuration

Configuration that is specific to this project, not the lib defaults:

- ...

## Gotchas

Things we have hit in production that are not obvious from the docs:

- **Pagination behavior:** the API returns 100 items per page by default
- **Rate limits:** 50 req/min on free tier, scales with tier
- **Idempotency:** required for write operations to handle retries safely
- **Timezone:** all timestamps are UTC, must convert at the boundary

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 401 Unauthorized | Token expired | Run token refresh |
| 429 Rate Limit | Exceeded quota | Exponential backoff, consider upgrade |
| Timeout | Network or backend slow | Retry with longer timeout |

## What NOT to do

- Do not call this lib directly from the frontend
- Do not log full payloads (may contain PII)
- Do not hardcode IDs that should be configurable

## When to update this doc

- Lib version bumps (even patches sometimes change behavior)
- New gotcha discovered during debugging
- New endpoint or feature added to project usage

Skim the official docs quarterly for breaking changes.
