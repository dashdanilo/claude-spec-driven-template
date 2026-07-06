# Migration Guide

Step-by-step migration from a custom folder structure to Feature-Sliced Design.

## Prerequisites

- Understand FSD layers, slices, and segments (see [../SKILL.md](../SKILL.md))
- Have a working CI pipeline (tests, lint) to validate each step
- Commit after each step — never migrate everything at once

## Phase 1: Identify Pages

Map existing routes to FSD page slices.

```
# Before
src/
├── views/
│   ├── Dashboard.tsx
│   ├── UserProfile.tsx
│   └── Settings.tsx

# After
src/
├── pages/
│   ├── dashboard/
│   │   ├── ui/
│   │   │   └── DashboardPage.tsx
│   │   └── index.ts
│   ├── user-profile/
│   │   ├── ui/
│   │   │   └── UserProfilePage.tsx
│   │   └── index.ts
│   └── settings/
│       ├── ui/
│       │   └── SettingsPage.tsx
│       └── index.ts
```

1. Create `src/pages/` directory.
2. Move each route-level component into its own page slice.
3. Add `ui/` segment and `index.ts` barrel.
4. Update router imports to use new paths.
5. Run tests — everything should still work.

## Phase 2: Extract app and shared

### app layer

Move global concerns out of scattered locations:

```
src/app/
├── providers/    # Context providers (was scattered in src/context/)
├── styles/       # Global CSS (was in src/styles/ or src/assets/)
├── router.tsx    # Route config (was in src/routes.tsx)
└── index.tsx     # Entry point
```

### shared layer

Move generic, domain-free utilities:

```
src/shared/
├── ui/          # Generic components (Button, Modal, Input) — was in src/components/common/
├── api/         # HTTP client setup — was in src/services/api.ts
├── lib/         # Utility functions — was in src/utils/
└── config/      # Constants, env vars — was in src/constants/
```

**Rule**: Only move code with ZERO business logic to shared.

## Phase 3: Fix Cross-Imports

After moving to pages/app/shared, you'll have broken imports. Fix them layer by layer:

1. `shared` should import nothing from other layers.
2. Pages should import from shared (and later from entities/features/widgets).
3. Identify circular dependencies with `npx madge --circular src/`.

## Phase 4: Extract Entities

Look for domain objects used across multiple pages.

**Signals that something is an entity:**
- Has its own types/interfaces used in 2+ places
- Has CRUD API calls
- Has presentational UI components (cards, rows, badges)
- Represents a real-world business concept

```
# Identify from existing code
src/components/UserCard.tsx      → entities/user/ui/
src/types/User.ts                → entities/user/model/
src/services/userService.ts      → entities/user/api/
src/hooks/useUser.ts             → entities/user/model/
```

Create the entity slice, move related code, update imports.

## Phase 5: Extract Features

Look for interactive user scenarios.

**Signals that something is a feature:**
- It's a form, dialog, or interactive flow
- It handles a specific user action (login, add-to-cart, search)
- It has its own state + UI + API calls bundled together

```
src/components/LoginForm/        → features/login-form/ui/
src/components/SearchBar/        → features/search/ui/
src/components/AddToCartButton/  → features/add-to-cart/ui/
```

## Phase 6: Extract Widgets

Look for large autonomous UI blocks that compose features and entities.

```
src/components/Header/           → widgets/header/ui/
src/components/Sidebar/          → widgets/sidebar/ui/
src/layouts/DashboardLayout/     → widgets/dashboard-layout/ui/
```

## Phase 7: Validate

1. Run Steiger: `npx steiger src/`
2. Run circular dep check: `npx madge --circular --extensions ts,tsx src/`
3. Run full test suite
4. Review every `index.ts` barrel — ensure public APIs are clean

## Common Migration Pitfalls

| Pitfall | Fix |
|---------|-----|
| Moving everything at once | Migrate one layer at a time, commit after each |
| Skipping barrel files | Every slice needs `index.ts` from day one |
| Leaving orphaned imports | Search for old paths after each move |
| Over-splitting entities | Group related sub-concerns under one entity |
| Rushing to extract features | Get pages + entities right first, features emerge naturally |

## Incremental Strategy

For large codebases, migrate incrementally:

1. New code → write in FSD structure immediately
2. Touched code → migrate when you modify it (boy scout rule)
3. Scheduled → dedicate sprints to migrate remaining legacy modules

Configure Steiger to only lint `src/pages/`, `src/entities/`, etc. — don't force-lint legacy folders.
