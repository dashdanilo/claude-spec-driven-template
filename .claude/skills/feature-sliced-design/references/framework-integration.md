# SPA Integration

FSD lives inside `src/`. For React SPAs (Vite, CRA), FSD pages map directly to routes — no wrapper layer needed.

## Vite + React Router

```
project-root/
├── src/                    ← FSD architecture
│   ├── app/
│   │   ├── providers/      # React context providers, store init
│   │   ├── styles/         # Global CSS, resets, tokens
│   │   ├── router.tsx      # Route configuration
│   │   └── index.tsx       # App entry
│   ├── pages/
│   │   ├── home/
│   │   ├── profile/
│   │   └── settings/
│   ├── widgets/
│   ├── features/
│   ├── entities/
│   └── shared/
├── index.html
├── vite.config.ts
└── tsconfig.json
```

### Router Setup

```tsx
// src/app/router.tsx
import { createBrowserRouter } from "react-router-dom";
import { HomePage } from "pages/home";
import { ProfilePage } from "pages/profile";
import { SettingsPage } from "pages/settings";

export const router = createBrowserRouter([
  { path: "/", element: <HomePage /> },
  { path: "/profile", element: <ProfilePage /> },
  { path: "/settings", element: <SettingsPage /> },
]);
```

### App Entry

```tsx
// src/app/index.tsx
import { RouterProvider } from "react-router-dom";
import { AppProviders } from "./providers";
import { router } from "./router";
import "./styles/globals.css";

export const App = () => (
  <AppProviders>
    <RouterProvider router={router} />
  </AppProviders>
);
```

### Lazy Loading Pages

```tsx
// src/app/router.tsx
import { lazy } from "react";

const HomePage = lazy(() => import("pages/home").then(m => ({ default: m.HomePage })));
const ProfilePage = lazy(() => import("pages/profile").then(m => ({ default: m.ProfilePage })));

export const router = createBrowserRouter([
  { path: "/", element: <Suspense fallback={<Spinner />}><HomePage /></Suspense> },
  { path: "/profile", element: <Suspense fallback={<Spinner />}><ProfilePage /></Suspense> },
]);
```

## Path Alias Configuration

### TypeScript (tsconfig.json)

```json
{
  "compilerOptions": {
    "baseUrl": "src",
    "paths": {
      "@/*": ["./*"]
    }
  }
}
```

### Vite (vite.config.ts)

```ts
import { resolve } from "path";
import { defineConfig } from "vite";

export default defineConfig({
  resolve: {
    alias: { "@": resolve(__dirname, "src") },
  },
});
```

Both patterns work: `@/entities/user` or `entities/user` (with `baseUrl`).

## Providers Pattern

```tsx
// src/app/providers/index.tsx
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "shared/api";
import { ThemeProvider } from "shared/ui";

export const AppProviders = ({ children }: { children: React.ReactNode }) => (
  <QueryClientProvider client={queryClient}>
    <ThemeProvider>
      {children}
    </ThemeProvider>
  </QueryClientProvider>
);
```

## Protected Routes

```tsx
// src/app/router.tsx
import { Navigate } from "react-router-dom";
import { useAuth } from "entities/user";

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" />;
};

export const router = createBrowserRouter([
  { path: "/", element: <HomePage /> },
  { path: "/profile", element: <ProtectedRoute><ProfilePage /></ProtectedRoute> },
]);
```

## Layout Composition

```tsx
// src/app/router.tsx
import { AppLayout } from "widgets/app-layout";

export const router = createBrowserRouter([
  {
    element: <AppLayout />,  // layout wraps child routes
    children: [
      { path: "/", element: <HomePage /> },
      { path: "/profile", element: <ProfilePage /> },
    ],
  },
  { path: "/login", element: <LoginPage /> },  // no layout
]);
```

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
