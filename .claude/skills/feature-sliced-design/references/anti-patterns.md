# Anti-Patterns

## Structural Anti-Patterns

### Desegmentation

Using generic folder names instead of FSD segments.

```
❌ Bad
features/auth/
├── components/     ← generic
├── hooks/          ← generic
└── helpers/        ← generic

✅ Good
features/auth/
├── ui/             ← FSD segment
├── model/          ← FSD segment
└── lib/            ← FSD segment
```

**Why**: Generic names bypass FSD's segment semantics. Tooling can't enforce rules on `components/`.

### Excessive Entities

Splitting every database table into its own entity.

```
❌ Too granular
entities/
├── user/
├── user-settings/     ← just a sub-concern of user
├── user-avatar/       ← same
├── user-preferences/  ← same
```

```
✅ Coalesced
entities/
├── user/
│   ├── model/
│   │   ├── types.ts        # includes settings, avatar, prefs
│   │   └── store.ts
│   └── ui/
│       ├── UserCard.tsx
│       └── UserAvatar.tsx
```

**Rule of thumb**: If it doesn't have its own lifecycle in the UI, it's not a separate entity.

### Cross-Imports Between Same-Layer Slices

```
❌ Forbidden
// features/checkout/ui/CheckoutForm.tsx
import { useCart } from "features/cart";  // same-layer import!

✅ Correct approaches
// Option 1: Lift shared logic to entities
import { useCart } from "entities/cart";

// Option 2: Compose in a widget
// widgets/checkout-flow/ui/CheckoutFlow.tsx
import { CheckoutForm } from "features/checkout";
import { CartSummary } from "features/cart";
```

### Upward Imports

```
❌ Forbidden
// entities/user/model/store.ts
import { LoginForm } from "features/login-form"; // importing UP

// shared/lib/analytics.ts
import { useUser } from "entities/user"; // importing UP
```

**Fix**: Pass dependencies down via props, callbacks, or dependency injection.

## Code Organization Smells

### God Shared Layer

Dumping everything into `shared/` because "it's reusable."

```
❌ Bloated shared
shared/
├── components/    ← 50+ components
├── hooks/         ← 30+ hooks
├── utils/         ← catch-all junk drawer
```

**Fix**: If it has business logic, it belongs in `entities/` or `features/`. Only truly generic, domain-agnostic code belongs in `shared/`.

### Missing Public API

Importing directly from a slice's internals.

```
❌ No barrel file
import { UserCard } from "entities/user/ui/UserCard";
import { useUser } from "entities/user/model/hooks/useUser";

✅ Via public API
import { UserCard, useUser } from "entities/user";
```

### Logic in Barrel Files

```
❌ Business logic in index.ts
// entities/user/index.ts
export const formatUserName = (user: User) => `${user.first} ${user.last}`;

✅ Clean barrel
// entities/user/index.ts
export { formatUserName } from "./lib/formatUserName";
export { UserCard } from "./ui/UserCard";
```

### Generic Segment Names

```
❌ Avoid
features/auth/
├── utils/          ← too generic
├── helpers/        ← too generic
├── types/          ← put types in model/
└── constants/      ← put in config/

✅ Use standard segments
features/auth/
├── lib/            ← scoped helpers
├── model/          ← types + logic
└── config/         ← constants
```

## Circular Dependencies

### Barrel-to-Barrel Cycles

Entity A exports from a module that imports Entity B's barrel, which imports Entity A.

**Diagnosis**: Run `madge --circular src/` or check Steiger output.

**Solutions**:
1. Extract shared types to `shared/` layer
2. Use `@x` cross-reference notation (see [slices-and-public-api.md](slices-and-public-api.md))
3. Break the cycle by restructuring which entity owns the shared concept

### Feature-to-Feature Cycles

Two features that depend on each other.

**Fix**: Extract shared logic into a new entity, or merge the features if they're truly inseparable.
