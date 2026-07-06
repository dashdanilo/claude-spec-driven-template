---
name: react-best-practices
description: >-
  React component design patterns and best practices for TypeScript SPAs.
  Use when writing new components, refactoring existing ones, reviewing component
  architecture, choosing between composition strategies, designing component APIs,
  implementing custom hooks, optimizing render performance, or deciding where to
  place state. Covers React 18 functional components only.
---

# React Best Practices

Production-quality React component patterns for TypeScript SPAs. React 18 functional components only — no class components (except Error Boundaries, wrapped with hook interface).

## Core Principles

1. **Composition over inheritance** — combine small components, never extend
2. **Single responsibility** — one reason to change per component
3. **Colocation** — keep state, logic, and styles close to where they're used
4. **Explicit APIs** — discriminated unions > boolean props, named props > positional
5. **Type safety** — generic components, no `any`, no `@ts-ignore`

## Pattern Quick-Reference

| Problem | Pattern | Reference |
|---------|---------|-----------|
| Share UI structure with variable content | Compound components | [composition-patterns](references/composition-patterns.md) |
| Wrap native HTML elements with extra behavior | Polymorphic `as` prop | [polymorphic-components](references/polymorphic-components.md) |
| Design clear, type-safe component props | Discriminated union props | [component-api-design](references/component-api-design.md) |
| Extract reusable stateful logic | Custom hooks | [custom-hook-patterns](references/custom-hook-patterns.md) |
| Build form-like components (both controlled & uncontrolled) | useControllableState | [controlled-components](references/controlled-components.md) |
| Avoid unnecessary re-renders | React.memo + key prop reset | [performance-patterns](references/performance-patterns.md) |
| Handle runtime errors gracefully | Error Boundary + hook wrapper | [error-handling](references/error-handling.md) |
| Choose between Context, Zustand, TanStack Query | State decision tree | [state-management](references/state-management.md) |
| Type generic, polymorphic, or conditional props | Advanced TS patterns | [typescript-for-components](references/typescript-for-components.md) |
| Avoid restating types TS already knows | Trust the inference (drop explicit generics, use yup InferType, prefer schema types over derived paths, centralize casts) | [trust-inference](references/trust-inference.md) |

## Component Checklist

Before writing a component, verify:

- [ ] **Props**: Use `type` (not `interface`) for component props. Extend native element props when wrapping HTML (`type X = ComponentPropsWithoutRef<'button'> & { ... }`).
- [ ] **Composition**: Prefer `children` and slots over config props. Use compound components for related groups.
- [ ] **State**: Start local. Lift only when sibling needs it. Use custom hook if logic is reusable.
- [ ] **Generics**: If component renders user-provided data, make it generic (`<T>`).
- [ ] **Ref forwarding**: Always `forwardRef` for components wrapping native elements.
- [ ] **Naming**: `onAction` for callback props, `handleAction` for internal handlers.

## Component Anatomy

```tsx
// 1. Imports
import { forwardRef, type ComponentPropsWithoutRef } from 'react';

// 2. Types (exported for consumers)
export type ButtonProps = ComponentPropsWithoutRef<'button'> & {
  variant: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
};

// 3. Component
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant, size = 'md', isLoading, children, disabled, ...rest }, ref) => {
    return (
      <button
        ref={ref}
        disabled={disabled || isLoading}
        data-variant={variant}
        data-size={size}
        {...rest}
      >
        {isLoading ? <Spinner /> : children}
      </button>
    );
  }
);

Button.displayName = 'Button';
```

## When to Use Each Pattern

```
Need reusable logic without UI?
  → Custom hook

Need a group of related components sharing state?
  → Compound components (Context-based)

Need a component that renders as different HTML elements?
  → Polymorphic `as` prop (or `asChild` for Radix-style)

Need both controlled and uncontrolled usage?
  → useControllableState pattern

Need to inject cross-cutting concerns (auth, logging)?
  → HOC (rare — prefer hooks when possible)

Need render-time flexibility without exposing internals?
  → Render prop / headless hook
```

## Anti-Patterns (Quick)

| Anti-Pattern | Fix |
|-------------|-----|
| Boolean prop soup (`isX`, `hasY`, `showZ`) | Discriminated union or compound components |
| Prop drilling > 2 levels | Context + custom hook, or composition |
| `useEffect` for derived state | Compute during render with `useMemo` |
| `React.memo` everywhere | Profile first, memo only bottlenecks |
| Giant component (300+ lines) | Extract custom hooks and sub-components |
| `any` or `as unknown as X` | Generic components, proper type narrowing |
| Explicit generics when a prop infers them (`<Select<T, false> options={tArray}>`) | Drop the generics — let `options` infer `T` |
| Local `type FormValues` duplicating a yup schema | `yup.InferType` re-exported from the validator file |
| Deep-derived types like `NonNullable<Query['x']['y']>[number]` | Import the schema type directly (`Type` from `@/graphql`) |
| Casts at every consumer (`as BookingSliceItem[]`) | One cast inside the data-fetching `select` boundary |

## References

| Topic | File |
|-------|------|
| Composition, compound components, slots, render props | [references/composition-patterns.md](references/composition-patterns.md) |
| Polymorphic `as` prop, `asChild`, generic forwarded refs | [references/polymorphic-components.md](references/polymorphic-components.md) |
| Prop design, discriminated unions, exclusive props | [references/component-api-design.md](references/component-api-design.md) |
| Custom hooks: composition, factories, return patterns | [references/custom-hook-patterns.md](references/custom-hook-patterns.md) |
| Controlled/uncontrolled, headless UI, useControllableState | [references/controlled-components.md](references/controlled-components.md) |
| React.memo, useMemo/useCallback, key reset, lazy loading | [references/performance-patterns.md](references/performance-patterns.md) |
| Error boundaries, async errors, fallback UI | [references/error-handling.md](references/error-handling.md) |
| Local/shared/server state, decision trees | [references/state-management.md](references/state-management.md) |
| Generic components, polymorphic types, advanced TypeScript | [references/typescript-for-components.md](references/typescript-for-components.md) |
| Trust the inference — drop redundant generics, yup InferType, schema types, centralized casts | [references/trust-inference.md](references/trust-inference.md) |
