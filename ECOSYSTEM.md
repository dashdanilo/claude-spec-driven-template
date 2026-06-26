# ECOSYSTEM.md

> Shared schemas and contracts across surfaces of the system. Replace the examples below with your real entities.

Source of truth for types that appear in more than one place: framework code, orchestration layer, external integrations, event payloads.

Keep this file **dense and factual**. No history, no rationale. Only contracts.

## Entities

### ExampleEntity

The canonical shape, mirrored in database, API payloads, and external services.

| Field | Type | Origin | Notes |
|---|---|---|---|
| `id` | uuid v4 | server-generated | never exposed to client before submit |
| `name` | string | user input | required, min 2 chars |
| `email` | string | user input | validated, normalized lowercase |
| `created_at` | iso datetime | server | UTC |

Add or remove fields to match your actual entities.

## Enums

Define enums here so all surfaces agree:

- `status`: `pending` | `active` | `archived`
- `tier`: `free` | `pro` | `enterprise`

## Event payloads

Shape of events that cross service boundaries:

```jsonc
{
  "type": "example.created",
  "id": "uuid",
  "entity": { /* ExampleEntity */ },
  "timestamp": "iso",
  "version": 1
}
```

## Naming conventions

- snake_case in JSON payloads (compatible with most external services)
- camelCase in TypeScript internals
- Conversion at the boundary: typically in `src/lib/<domain>/schema.ts`

## Webhook contracts

- Inbound: `POST /api/webhook/<source>` with HMAC signature verification
- Outbound: matching HMAC signature, retry with exponential backoff

## Versioning

Any change to a schema in this file is a breaking change. Bump the version, update all consumers, and migrate. Do not change silently.
