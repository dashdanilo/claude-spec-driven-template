---
name: feature-sliced-design
description: Feature-Sliced Design (FSD) architecture knowledge base for React SPA projects. Use when the user asks where code belongs in FSD, needs help deciding between entity/feature/widget layers, wants to scaffold FSD slices or segments, review FSD compliance, answer 'where does X go?' questions, plan feature implementation following FSD, or migrate from a custom folder layout.
---

# Feature-Sliced Design

Architectural methodology for frontend projects. Organizes code into **layers**, **slices**, and **segments** with strict uni-directional imports.

## Quick Reference

### Layers (top → bottom, import only from below)

| Layer | Purpose | Has Slices? |
|-------|---------|-------------|
| `app` | Providers, routing, global styles, entry point | No (segments only) |
| `pages` | Full page compositions, route-level components | Yes |
| `widgets` | Large autonomous UI blocks (header, sidebar) | Yes |
| `features` | User interactions (login-form, add-to-cart) | Yes |
| `entities` | Business domain objects (user, product, order) | Yes |
| `shared` | Reusable utilities, UI kit, API client, config | No (segments only) |

> `processes` layer is **deprecated**. Merge its logic into `features` or `app`.

### Segments (within each slice)

| Segment | Contains |
|---------|----------|
| `ui/` | Components, styles, UI-only logic |
| `model/` | State, stores, selectors, business logic |
| `api/` | API calls, data fetching, request types |
| `lib/` | Helpers scoped to this slice |
| `config/` | Slice-level constants, feature flags |

### Import Rule (CRITICAL)

```
app → pages → widgets → features → entities → shared
         ↓ only downward ↓
```

- A module imports ONLY from layers **strictly below** it.
- **Never** import between slices on the same layer.
- Cross-entity imports use `@x` notation. See [references/slices-and-public-api.md](references/slices-and-public-api.md).

### Public API

Every slice MUST export through `index.ts` (barrel file). External consumers import from the barrel — never from internal paths.

```
features/auth/index.ts    ← public API
features/auth/ui/Form.tsx ← internal, never import directly from outside
```

## Scaffolding a New Slice

1. Determine the correct layer (see layer purpose table above).
2. Create the slice directory: `src/{layer}/{slice-name}/`.
3. Add needed segments: `ui/`, `model/`, `api/`, `lib/`.
4. Create `index.ts` barrel exporting the public API.
5. Wire imports — only from layers below.

### Directory Template

```
src/
├── app/            # Providers, router, global styles
│   ├── providers/
│   ├── styles/
│   └── index.tsx
├── pages/
│   └── home/
│       ├── ui/
│       ├── model/
│       └── index.ts
├── widgets/
│   └── header/
│       ├── ui/
│       └── index.ts
├── features/
│   └── auth/
│       ├── ui/
│       ├── model/
│       ├── api/
│       └── index.ts
├── entities/
│   └── user/
│       ├── ui/
│       ├── model/
│       ├── api/
│       └── index.ts
└── shared/
    ├── ui/
    ├── api/
    ├── lib/
    └── config/
```

## Compliance Checklist

Before marking FSD work complete, verify:

- [ ] Every slice has an `index.ts` public API barrel
- [ ] No imports cross upward or sideways between layers
- [ ] No direct imports into slice internals from outside
- [ ] Segments use standard names (`ui`, `model`, `api`, `lib`, `config`)
- [ ] No generic folders (`components/`, `hooks/`, `utils/`) inside slices

## Framework Integration

FSD lives in `src/`. Framework routing files remain at the project root as thin wrappers. See [references/framework-integration.md](references/framework-integration.md).

## "Where Does X Go?" Quick Answers

| Code | Layer | Segment |
|------|-------|---------|
| `Button`, `Input`, `Modal` | shared | ui/ |
| HTTP client, interceptors | shared | api/ |
| `formatDate`, `debounce` | shared | lib/ |
| Env vars, constants | shared | config/ |
| `UserCard`, `ProductBadge` | entities | ui/ |
| User store, selectors | entities | model/ |
| `fetchUser`, query hooks | entities | api/ |
| Login form + validation | features | ui/ + model/ |
| Add-to-cart button | features | ui/ |
| Header, sidebar (reusable) | widgets | ui/ |
| Route-level composition | pages | ui/ |
| Providers, router config | app | providers/ |

For complex decisions, see [references/decision-guide.md](references/decision-guide.md).

## References

| Topic | File |
|-------|------|
| **Decision guide** (where does X go?) | [references/decision-guide.md](references/decision-guide.md) |
| Layers and segments in depth | [references/layers-and-segments.md](references/layers-and-segments.md) |
| Slices, public API, @x notation | [references/slices-and-public-api.md](references/slices-and-public-api.md) |
| Recipes (auth, API, state, forms) | [references/recipes-and-patterns.md](references/recipes-and-patterns.md) |
| TypeScript patterns (types, @x, generics) | [references/typescript-patterns.md](references/typescript-patterns.md) |
| Testing patterns (by layer) | [references/testing-patterns.md](references/testing-patterns.md) |
| Framework integration (Vite SPA) | [references/framework-integration.md](references/framework-integration.md) |
| Anti-patterns and code smells | [references/anti-patterns.md](references/anti-patterns.md) |
| Tooling (Steiger, ESLint, CLI) | [references/tooling.md](references/tooling.md) |
| Migration from custom layouts | [references/migration-guide.md](references/migration-guide.md) |
