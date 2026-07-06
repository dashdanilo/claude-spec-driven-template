# TypeScript Patterns in FSD

## Type Placement Rules

| Type Category | Where to Place | Example |
|---------------|---------------|---------|
| Component props | Same file as component | `type UserCardProps = { ... }` in `UserCard.tsx` |
| Business entity types | `entities/*/model/types.ts` | `User`, `Product`, `Order` |
| API DTOs | Next to the request function | `api/userApi.ts` or `api/types.ts` |
| Zod schemas | Same segment as validation/request | `model/schema.ts` |
| Utility types | `shared/lib/` or next to usage | `shared/lib/utility-types.ts` |
| Enums (display) | `ui/` segment | Display-related enums |
| Enums (data) | `api/` or `model/` segment | Loading states, API statuses |

### Anti-Pattern: Never Create `shared/types`

```
❌ shared/types/      ← groups unrelated things by "being a type"
❌ features/auth/types/ ← same problem at slice level

✅ shared/lib/utility-types.ts    ← if truly generic utilities
✅ entities/user/model/types.ts   ← domain types with their domain
```

### Anti-Pattern: Never Add a `types` Segment

Segments describe **purpose**, not **essence**. Types belong in the segment of their purpose:
- UI types → `ui/`
- Business logic types → `model/`
- API types → `api/`

## Cross-Entity Type References (@x)

When Entity A needs Entity B's types, use `@x` notation to create a controlled cross-reference.

### Directory Structure

```
entities/
  song/
    @x/
      artist.ts     ← special public API for artist slice
      playlist.ts   ← special public API for playlist slice
    model/
      song.ts
    ui/
    index.ts        ← regular public API (does NOT export @x)
  artist/
    model/
      artist.ts     ← imports from entities/song/@x/artist
    ui/
    index.ts
```

### Implementation

```ts
// entities/song/@x/artist.ts
// Exposes ONLY what artist entity needs from song
export type { Song } from "../model/song";

// entities/artist/model/artist.ts
import type { Song } from "entities/song/@x/artist";

export interface Artist {
  name: string;
  songs: Song[];
}
```

### Rules for @x Files

1. Each `@x` file is named after the **consuming** slice
2. Export only the minimal subset needed by that consumer
3. The regular `index.ts` does NOT re-export `@x` contents
4. `@x` is a **last resort** — prefer lifting shared types to `shared/` or using generics

## Generic Types for Decoupling

Prefer generic parameters over direct cross-entity imports when the relationship is loose.

```ts
// entities/song/model/types.ts
// GOOD: Generic — no dependency on Artist
interface Song<TArtist extends { id: string; name: string }> {
  id: number;
  title: string;
  artists: TArtist[];
}

// Usage in features or pages (where both entities are available)
import type { Song } from "entities/song";
import type { Artist } from "entities/artist";

type FullSong = Song<Artist>;
```

### When to Use Generics vs @x

| Scenario | Use |
|----------|-----|
| Loose relationship, consumer fills in details | Generics |
| Tight relationship, always used together | @x notation |
| Shared by many slices | Extract to `shared/` |
| Types diverging over time | Duplicate (copy) |

## Global Store Types (Redux)

Redux requires global `RootState` and `AppDispatch` types, which creates a circular reference problem with FSD layers.

### Solution: Global Type Declaration

```ts
// app/store/index.ts
import { configureStore } from "@reduxjs/toolkit";
import userReducer from "entities/user/model/slice";
import productReducer from "entities/product/model/slice";

export const store = configureStore({
  reducer: { user: userReducer, product: productReducer },
});

// Declare global types (accessible everywhere without import)
declare global {
  type RootState = ReturnType<typeof store.getState>;
  type AppDispatch = typeof store.dispatch;
}
```

```ts
// shared/lib/store.ts — typed hooks (no circular import)
import { useDispatch, useSelector } from "react-redux";

export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
export const useAppSelector = useSelector.withTypes<RootState>();
```

### Zustand Alternative (Simpler)

Zustand stores are self-contained — no global type issue:

```ts
// entities/user/model/store.ts
import { create } from "zustand";

interface UserState {
  user: User | null;
  setUser: (user: User) => void;
}

export const useUserStore = create<UserState>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
}));
```

## Shared API Types (openapi-fetch / codegen)

Generated API types belong in `shared/api/`:

```
shared/
  api/
    client.ts      ← createClient instance
    schema.ts      ← generated OpenAPI types (output of codegen)
    index.ts       ← re-exports client + types
```

Entity-specific query hooks import from `shared/api` and live in entity `api/` segments:

```ts
// entities/product/api/queries.ts
import { client } from "shared/api";
import type { paths } from "shared/api";

export function useProducts() {
  return useQuery({
    queryKey: ["products"],
    queryFn: () => client.GET("/products"),
  });
}
```
