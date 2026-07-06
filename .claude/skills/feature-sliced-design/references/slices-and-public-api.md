# Slices and Public API

## Slices

A slice is a business-domain grouping within a layer. It groups all code related to one domain concept.

```
entities/
├── user/        ← slice
├── product/     ← slice
└── order/       ← slice
```

### Naming Rules

- Use singular nouns for entities: `user`, `product`, `order`
- Use verb-noun for features: `login-form`, `add-to-cart`, `search-products`
- Use descriptive names for widgets: `header`, `sidebar`, `product-carousel`
- Use route-matching names for pages: `home`, `profile`, `settings`

### Layers Without Slices

`app` and `shared` have **no slices** — they contain segments directly.

```
shared/
├── ui/        ← segment (no slice wrapper)
├── api/
├── lib/
└── config/
```

## Public API (Barrel Exports)

Every slice MUST have an `index.ts` at its root. This is the **only** entry point for external consumers.

### Correct Pattern

```ts
// entities/user/index.ts (public API)
export { UserCard } from "./ui/UserCard";
export { useUser } from "./model/useUser";
export type { User } from "./model/types";
```

```ts
// features/auth/ui/LoginPage.tsx
import { UserCard, useUser } from "entities/user"; // ✅ via public API
// import { UserCard } from "entities/user/ui/UserCard"; // ❌ internal path
```

### Rules

1. Export only what other slices need — hide internal implementation.
2. Re-export types explicitly (avoid `export *`).
3. Keep the barrel flat — no logic in `index.ts`.
4. Never import from another slice's internals.

### Barrel File Pitfalls

- **Circular imports**: Barrel A re-exports from module that imports Barrel B, which re-exports from module importing Barrel A. Fix: extract shared type to `shared/` or use `@x` notation.
- **Bundle bloat**: `export *` pulls everything. Export named items explicitly.
- **Tree-shaking**: Named exports enable proper dead-code elimination.

## @x Cross-Reference Notation

Cross-entity imports are forbidden by default. When entity A needs data from entity B, use `@x` notation:

### Setup

```
entities/
├── user/
│   ├── @x/
│   │   └── product.ts   ← cross-ref from user to product
│   ├── ui/
│   ├── model/
│   └── index.ts
└── product/
    ├── ui/
    ├── model/
    └── index.ts
```

### How It Works

```ts
// entities/user/@x/product.ts
// This file defines how "user" relates to "product"
import type { Product } from "entities/product";

export function getUserProducts(userId: string): Promise<Product[]> {
  // API call combining user + product domains
}
```

```ts
// entities/user/index.ts
export { getUserProducts } from "./@x/product";
```

### When to Use @x

- Entity A needs to reference Entity B's types
- Composing two entity models (e.g., user's orders)
- Shared domain logic spanning two entities

### When NOT to Use @x

- Simple UI composition → do it in a widget or feature instead
- Complex multi-entity orchestration → belongs in a feature
- One-off usage → consider lifting to the consuming layer

## Flat Slices (Shorthand)

For simple slices with few files, flatten the structure:

```
features/
└── theme-toggle/
    ├── ThemeToggle.tsx    ← combines ui + model
    └── index.ts
```

Valid when: slice has ≤ 3 files and no complex internal structure. As complexity grows, introduce segments.

## Group Folders (Optional)

Organize many slices with group folders. Group folders are NOT slices — they're organizational containers.

```
entities/
├── @auth/           ← group folder (prefix with @)
│   ├── user/
│   └── session/
└── @commerce/
    ├── product/
    └── order/
```

Group folders don't affect imports — the slice public API path stays `entities/user`, not `entities/@auth/user`.
