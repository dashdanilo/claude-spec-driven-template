# Recipes and Patterns

## Authentication

### Token Storage — shared/api

```ts
// shared/api/client.ts
import createClient from "openapi-fetch";
import type { paths } from "./schema";

const client = createClient<paths>({ baseUrl: "/api" });

export function setAuthToken(token: string) {
  client.use({
    onRequest: ({ request }) => {
      request.headers.set("Authorization", `Bearer ${token}`);
    },
  });
}
export { client };
```

### Auth Entity

```
entities/user/
├── model/
│   ├── types.ts       # User, Session types
│   ├── store.ts       # Auth state (Zustand/Redux)
│   └── useAuth.ts     # Hook: isAuthenticated, user, logout
├── api/
│   └── userApi.ts     # login, register, refresh
├── ui/
│   └── UserAvatar.tsx
└── index.ts
```

### Auth Feature

```
features/login-form/
├── ui/LoginForm.tsx
├── model/schema.ts     # Zod validation schema
└── index.ts
```

## API Layer — TanStack Query

Place query hooks in entity `api/` segments:

```ts
// entities/product/api/queries.ts
import { useQuery } from "@tanstack/react-query";
import { client } from "shared/api";

export const productKeys = {
  all: ["products"] as const,
  detail: (id: string) => ["products", id] as const,
};

export function useProducts() {
  return useQuery({
    queryKey: productKeys.all,
    queryFn: () => client.GET("/products").then((r) => r.data),
  });
}
```

## State Management

### Zustand (per entity)

```ts
// entities/user/model/store.ts
import { create } from "zustand";
import type { User } from "./types";

interface UserStore {
  user: User | null;
  setUser: (user: User) => void;
  clear: () => void;
}

export const useUserStore = create<UserStore>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
  clear: () => set({ user: null }),
}));
```

### Redux Toolkit (per entity)

```ts
// entities/product/model/slice.ts
import { createSlice, PayloadAction } from "@reduxjs/toolkit";

const productSlice = createSlice({
  name: "product",
  initialState: { items: [], loading: false },
  reducers: {
    setProducts: (state, action: PayloadAction<Product[]>) => {
      state.items = action.payload;
    },
  },
});

export const { setProducts } = productSlice.actions;
export default productSlice.reducer;
```

Combine reducers in `app/store.ts` — see [typescript-patterns.md](typescript-patterns.md) for global Redux types.

## Layouts

- **No business logic** → `shared/ui/layouts/MainLayout.tsx`
- **With business logic** (header, sidebar, nav) → `widgets/app-layout/`

```tsx
// widgets/app-layout/ui/AppLayout.tsx
import { Outlet } from "react-router-dom";
import { Header } from "widgets/header";
import { Sidebar } from "widgets/sidebar";

export const AppLayout = () => (
  <div className="app-layout">
    <Header />
    <Sidebar />
    <main><Outlet /></main>
  </div>
);
```

## Forms with Validation

```
pages/register/
├── ui/RegisterPage.tsx
├── model/schema.ts        # Zod schema
└── index.ts
```

```ts
// pages/register/model/schema.ts
import { z } from "zod";

export const registerSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

export type RegisterFormData = z.infer<typeof registerSchema>;
```

## i18n

Setup in `shared/i18n/`. Namespace by layer for large apps:

```
shared/i18n/
├── locales/
│   ├── en.json         # { "entities": {...}, "features": {...}, "pages": {...} }
│   └── pt-BR.json
├── i18n.ts             # i18next setup
└── index.ts
```

## Environment Config

```
shared/
├── config/
│   ├── env.ts           # import.meta.env wrappers
│   ├── routes.ts        # Route path constants
│   └── index.ts
```

```ts
// shared/config/env.ts
export const config = {
  apiUrl: import.meta.env.VITE_API_URL,
  appEnv: import.meta.env.VITE_APP_ENV ?? "development",
} as const;
```
