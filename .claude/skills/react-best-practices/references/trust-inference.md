# Trust the inference

When TypeScript already knows the type, restating it is noise. Recurring review feedback flags four habits worth breaking.

## 1. Drop explicit generics when a prop infers them

If a generic component constrains its type parameter through a prop you're passing, TS infers it. Adding the generic by hand is redundant and easy to drift from reality.

```tsx
type Option = { label: string; value: string };

// ❌ explicit generics
<Select<Option, false>
  options={options}      // already typed Option[]
  value={selected}
  onChange={...}
/>

// ✅ inferred
<Select
  options={options}
  value={selected}
  onChange={...}
/>
```

Same applies to most `@agentguru/select` usages, `<Combobox<T>>`, `<DataTable<Row>>`, etc. Only pass generics explicitly when:
- The prop that would carry the type is **optional** and not present at the call site.
- You need to **widen** the inferred type intentionally (rare).

## 2. Derive form types from the yup schema, don't redeclare

Re-export the inferred type from the validator file and use it as the `useForm` generic:

```ts
// src/ui/modules/booking/validators/featureXValidation.ts
export function makeFeatureXValidation() {
  return yup.object({
    items: yup.array().of(makeItemValidation()).required(),
  });
}

export type FeatureXValidation = yup.InferType<ReturnType<typeof makeFeatureXValidation>>;
```

```tsx
// ❌ local duplicate that will drift from the schema
type FormValues = { items: { id: string; value: string }[] };
useForm<FormValues>({ resolver: yupResolver(makeFeatureXValidation()), ... });

// ✅ single source of truth
useForm<FeatureXValidation>({ resolver: yupResolver(makeFeatureXValidation()), ... });
```

When you add/remove a field in the schema, TS errors propagate everywhere automatically.

## 3. Import schema types directly; don't path-derive from query types

GraphQL codegen emits both:
- **Inline query response shapes** (e.g. `GetBookingQuery['getBooking']['booking']['slices'][number]`) — narrow but fragile, change when you tweak the query.
- **Global schema types** (e.g. `BookingSliceItem`) — stable, the source of truth.

Prefer the global type for component props and shared interfaces:

```ts
// ❌ deep-derived from the query path
type Slice = NonNullable<GetBookingQuery['getBooking']['booking']['slices']>[number];

// ✅ direct from the schema
import type { BookingSliceItem } from '@/graphql';
```

If the inline type is **incompatible** with the global type (the query selected fewer fields than the global requires), see #4 — don't fix it by inventing a derived alias.

## 4. Centralize unavoidable casts at the boundary

Sometimes the GraphQL inline shape isn't structurally assignable to the global type because nested types (e.g. `LocationInfo`) have required fields the query doesn't select. Adding every required field to every query is bloat. The pragmatic fix: **one** cast inside the data-fetching boundary, not at every consumer.

```ts
// ❌ cast at every consumer
const slices = (getBooking.data?.slices as BookingSliceItem[]) ?? [];
// … later in another component …
const passengers = (other.data?.passengers as BookingPassengerItem[]) ?? [];

// ✅ cast inside the select callback, once
const getBooking = useGetBooking({
  refetchOnMount: false,
  select: data => (data.getBooking.booking.slices ?? []) as BookingSliceItem[],
});

// downstream is clean
const slices = getBooking.data ?? [];
slices.forEach(s => {...}); // s: BookingSliceItem
```

Consumers stay typed against the global schema; the cast is auditable in one place; reviewers can ignore type concerns at every call site.

## When you genuinely need an explicit type

- Generic function arguments when the call site is symmetric and TS can't pick a side (`Array.from<T>(set)`).
- Bridging an opaque external type into your domain type — but consider a constructor function with the cast inside, not a raw `as`.
- Test fixtures: declare the constant `const fixture: Type = {…}` instead of `({…} as Type)`. See `storybook-stories` rule 13.
