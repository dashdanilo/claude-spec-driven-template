# Decision Guide: Where Does This Code Belong?

Practical decision trees for placing code in an FSD architecture. Use this as the primary reference when answering "where should I put X?" questions.

## Master Flowchart

```
Is it reusable, business-agnostic code? (Button, formatDate, HTTP client)
├─ YES → shared/
└─ NO ↓

Is it a business domain object? (user, product, order)
├─ YES → entities/{name}/
└─ NO ↓

Is it a user action/interaction? (login, add-to-cart, search)
├─ YES → features/{name}/
└─ NO ↓

Is it a large reusable UI block? (header, sidebar, dashboard-panel)
├─ YES: used on multiple pages? → widgets/{name}/
├─ YES: used on ONE page only? → keep in pages/{page}/ui/
└─ NO ↓

Is it a route-level screen composition?
├─ YES → pages/{name}/
└─ NO → app/ (providers, router, global config)
```

## Entity vs Feature (Read/Write Boundary)

The single most important distinction in FSD. Source: GitHub Discussion #863.

### Quick Test

| Question | Entity | Feature |
|----------|--------|---------|
| Has `on*` event handlers? | ❌ | ✅ |
| Mutates data/state/URL? | ❌ | ✅ |
| Same input → same output always? | ✅ | ❌ |
| Displays a business concept? | ✅ | — |
| Performs a user action? | — | ✅ |

### Decision Tree

```
Does this code trigger any WRITE?
(DB mutation, URL change, state change, clipboard, socket, prefetch)
├─ YES → features/
└─ NO ↓

Is it PURE? (same props → same markup every time)
├─ YES → entities/ (or shared/ui if no business domain)
└─ NO → features/ (it decides conditions, injects props)
```

### Examples by Category

**Entities (READ-only)**:
- Resource card/table/list display, user avatar, product badge
- Static breadcrumbs, SEO/OG metadata output
- Loading skeletons (pure, no logic)
- Links where `href` is passed via props (entity renders, doesn't decide)

**Features (WRITE/interactive)**:
- Filter/sort/search/pagination, infinite scroll
- Create/update/delete forms, optimistic updates, drafts/autosave
- File upload/download, selection/bulk actions
- Route guards/redirects, A/B switches, analytics events
- Toasts with retry logic, socket/SSE connections
- Query-based modals/panels (URL mutation = write)

## Layer Self-Check Questions

From the official FSD decomposition cheatsheet:

| Layer | Ask Yourself |
|-------|-------------|
| **shared** | Could this code work in a completely different app (pizza shop, bank)? |
| **entities** | When describing your app, does this word appear as a subject/object? |
| **features** | When telling a stranger what your app does, would you mention this action? |
| **widgets** | Looking at the UI from a distance, does this stand out as a complete block? |
| **pages** | Is this ready to be plugged into the router and work for users? |
| **app** | Is this something the framework/stack needs to function? |

## When to Split vs Merge Slices

### Split When
- Code is **reused across multiple pages**
- Business concept is **stable** (not rapidly changing)
- Concept is **recognized by stakeholders** as distinct
- Team needs **ownership boundaries**

### Keep Together When
- Used on **one page only** → keep in that page slice
- Business requirements **still volatile** → wait until stable
- Entity would serve **only one feature** → keep in the feature
- Splitting causes **cross-imports** between entities

### FSD 2.1 Guidance

> "Keep more code in pages. Large blocks of UI, forms and data logic that are not reused should stay in the page that uses them."

Start with pages. Extract to lower layers only when reuse emerges.

## Widget vs Feature vs Page

| Building... | Layer | Composition Role |
|-------------|-------|-----------------|
| A complete route/screen | **pages** | Orchestrates widgets + features |
| Reusable block on multiple pages | **widgets** | Composes features + entities |
| Single user interaction | **features** | Encapsulates one action |
| Business data display | **entities** | Pure rendering |

### Widget Rules
- **Reused across pages** → extract to widget
- **Used on one page, makes up most of content** → keep in page (NOT a widget)
- Widgets can own stores, business logic, API interactions

## State Placement

| State Type | Where | Tool |
|------------|-------|------|
| Component-local UI | Local state | `useState` |
| Feature workflow (wizard, form) | `features/*/model/` | `useReducer`, Zustand |
| Entity data (shared across features) | `entities/*/model/` | Zustand, Redux slice |
| App-wide global (keep minimal!) | `app/` | Context, providers |
| Server cache | `shared/api/` or entity `api/` | TanStack Query |

## Cross-Import Resolution

```
Need to import from same-layer slice?
├─ STOP. This is forbidden by default.
│
├─ Option 1: Move shared logic DOWN (to entities or shared)
├─ Option 2: Compose UP (widget/page imports both slices)
├─ Option 3: Use @x notation (entities only, last resort)
├─ Option 4: Merge the two slices (if tightly coupled)
└─ Option 5: Duplicate code (valid if concepts will diverge)
```

### @x Decision

```
Two entities need each other's types?
├─ Will they always be used together? → Merge into one entity
├─ Relationship is stable + well-defined? → Use @x notation
├─ Relationship is temporary/evolving? → Duplicate types
└─ Complex multi-entity orchestration? → Lift to features layer
```

## Common "Where Does X Go?" Answers

| Thing | Layer | Segment | Why |
|-------|-------|---------|-----|
| `Button`, `Input`, `Modal` | shared | ui/ | Generic, no business logic |
| HTTP client (axios/fetch) | shared | api/ | Infrastructure |
| `formatDate`, `debounce` | shared | lib/ | Pure utilities |
| Environment variables | shared | config/ | App-wide constants |
| Feature flags (global) | shared | config/ | Cross-cutting |
| `UserCard`, `ProductBadge` | entities | ui/ | Business domain display |
| `useUser`, user store | entities | model/ | Domain state |
| `fetchUser`, user queries | entities | api/ | Domain data fetching |
| Login form + validation | features | ui/ + model/ | User action |
| Add-to-cart button | features | ui/ | User action |
| i18n setup code | shared | i18n/ or lib/ | Infrastructure |
| Feature-specific translations | features | i18n/ | Scoped to feature |
| Page layout (plain markup) | shared | ui/ | Generic layout |
| Layout with header+sidebar | widgets | ui/ | Business composition |
| Protected route wrapper | features | ui/ or lib/ | Auth action |
| Route configuration | app | router/ | App infrastructure |
| Global providers | app | providers/ | App infrastructure |
| Zod form schema | pages or features | model/ | Validation logic |
