# Layers and Segments

## Layer Definitions

### app

Application entry point. No slices — only segments.

- `providers/` — React context providers, store initialization, theme
- `styles/` — Global CSS, resets, design tokens
- `router/` — Route configuration (if not handled by framework)
- `index.tsx` — App root component

Responsibilities: compose all layers, initialize app-wide concerns (i18n, error boundaries, analytics).

### pages

Route-level compositions. Each page slice assembles widgets, features, and entities into a full view.

```tsx
// src/pages/home/ui/HomePage.tsx
import { Header } from "widgets/header";
import { ProductList } from "features/product-list";
import { Banner } from "entities/banner";

export const HomePage = () => (
  <>
    <Header />
    <Banner />
    <ProductList />
  </>
);
```

Pages contain minimal logic — they compose, not implement.

### widgets

Large self-contained UI blocks that combine features and entities. A widget is autonomous — it manages its own data and state.

Examples: `header`, `sidebar`, `user-profile-card`, `product-carousel`.

Widgets differ from features: a **widget** is a UI region, a **feature** is a user action.

### features

Interactive scenarios users perform. Each feature owns the UI + logic for one user interaction.

Examples: `login-form`, `add-to-cart`, `search-filter`, `toggle-theme`.

Features import from entities and shared — never from other features or pages.

### entities

Business domain objects with their data model, API calls, and presentational components.

Examples: `user`, `product`, `order`, `comment`, `notification`.

Each entity provides:
- `model/` — Types, store slices, selectors
- `ui/` — Presentational card/row/badge components
- `api/` — CRUD calls for this entity

Entities are the most reusable layer after shared.

### shared

Library code with no business logic. No slices — only segments.

- `ui/` — Generic components (Button, Input, Modal, Typography)
- `api/` — HTTP client setup (axios/fetch instance), interceptors
- `lib/` — Pure utility functions, date formatters, validators
- `config/` — Environment variables, constants, routes map

## Segment Details

Standard segments recognized by FSD tooling:

| Segment | Purpose | Examples |
|---------|---------|---------|
| `ui/` | React components, styles | `LoginForm.tsx`, `UserCard.module.css` |
| `model/` | State management, business logic | `store.ts`, `selectors.ts`, `types.ts` |
| `api/` | Data fetching, server communication | `userApi.ts`, `queries.ts` |
| `lib/` | Scoped helpers (NOT generic utils) | `formatDate.ts`, `validateEmail.ts` |
| `config/` | Constants, feature flags | `routes.ts`, `featureFlags.ts` |

### Custom Segments

Create custom segments only when standard ones don't fit. Steiger linter flags non-standard segments — configure exceptions explicitly.

```
features/editor/
├── ui/
├── model/
├── api/
├── lib/
├── codemirror/  ← custom segment for editor-specific setup
└── index.ts
```

## Import Rules (Strict)

### Layer Hierarchy

```
app (7) → pages (6) → widgets (5) → features (4) → entities (3) → shared (1)
```

Each layer can ONLY import from layers with a **lower** number. No same-level, no upward.

### Why No Same-Layer Imports?

Same-layer slices represent parallel concerns at the same abstraction level. Importing between them creates coupling that breaks independent deployability and testability.

**Exception**: Cross-entity references via `@x` notation. See [slices-and-public-api.md](slices-and-public-api.md).

### Enforcement

Configure ESLint or Steiger to catch violations at CI time. See [tooling.md](tooling.md).
