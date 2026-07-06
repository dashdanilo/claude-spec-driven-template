---
name: storybook-stories
description: >-
  Write Storybook component documentation using CSF3 and TypeScript with @storybook/react-vite.
  Use when creating, updating, or fixing .stories.tsx files, component docs, argTypes, decorators,
  or Storybook controls. Not specific to any single monorepo layout.
---

# Storybook Stories (CSF3)

Write component stories using Component Story Format 3 (CSF3) with TypeScript. Default stack: **Storybook 8.x–10.x** with `@storybook/react-vite` (adapt imports if your repo pins a different major).

## Project Conventions

| Convention | Value |
|-----------|-------|
| Framework import | `@storybook/react-vite` (NEVER `@storybook/react`) |
| Meta type | `const meta: Meta<typeof Component>` (NOT `satisfies`) |
| Story type | `type Story = StoryObj<typeof Component>` (local alias) |
| File naming | `ComponentName.stories.tsx` (co-located with component) |
| Title pattern | `Area/ComponentName` (use your design system or product area as the prefix) |
| Required tags | `['autodocs']` always; add `'visual-regression'` for stable components |
| Component import | From barrel files (`'../main'`) unless deeply nested |
| Mock data | From `../../data` modules, never inline in stories |
| Example copy | **English** for all placeholder labels, titles, and body text in stories (consistent docs and screenshots across the team) |
| Default export | `export default meta` (after meta definition) |

## Workflow

### Step 1: Identify the component

Read the component source to understand:
- All props and their TypeScript types
- Which props have variants/enums (these become individual stories)
- Whether it needs context providers (wrapping decorators)
- Whether it has callback props (need `fn()` for actions)

### Step 2: Create the story file

Place the file next to the component (or your repo’s agreed stories directory). Monorepo example: `packages/<package>/src/lib/<Component>/<Component>.stories.tsx`

### Step 3: Write the meta

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';

import { ComponentName } from '../main';

type Story = StoryObj<typeof ComponentName>;

const meta: Meta<typeof ComponentName> = {
  title: 'AreaOrPackage/ComponentName',
  component: ComponentName,
  tags: ['autodocs'],
  args: {
    // Default args applied to all stories
  },
};

export default meta;
```

### Step 4: Write the stories

Create one story per meaningful state:

```tsx
export const Default: Story = {};

export const VariantName: Story = {
  args: { variant: 'secondary' },
};
```

### Step 5: Verify

- [ ] File builds without TypeScript errors
- [ ] All significant component states have a story
- [ ] `tags: ['autodocs']` is present
- [ ] Args cover all required props with sensible defaults
- [ ] Callback props use `fn()` from `storybook/test` when action logging is needed

## Story Coverage Checklist

Create stories for:
1. **Default** — Component with default/minimal props
2. **Each variant** — One story per variant value (e.g. `primary`, `secondary`)
3. **Each size** — If the component has size variants
4. **Disabled/loading states** — If applicable
5. **With/without optional content** — Icons, labels, children
6. **Edge cases** — Long text, empty content, many items

## Documenting Typed Props with argTypes

When component props have **known literal values** (union types, enums, or tv() variants), Storybook cannot automatically infer the available options for controls. You MUST document them manually with `argTypes`.

### When to use argTypes

- Props typed with `VariantProps<typeof componentStyles>` from `tailwind-variants` (or your design-system re-export)
- Props with union types of literal strings: `type Size = 'sm' | 'md' | 'lg'`
- Props with TypeScript enums
- Props that accept specific known values

### When NOT to use argTypes

- Props with open-ended string values: `className`, `placeholder`, `title`
- Props that accept any string/number
- Props that are truly dynamic

### Why argTypes?

- Storybook controls default to text input for string types
- Without argTypes, users see a text input instead of a dropdown select
- Users need to see all available options in the Storybook UI

### How to add argTypes

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';
import type { ComponentProps } from './Component';

import { Component } from '../main';

type Story = StoryObj<ComponentProps>;

const meta: Meta<ComponentProps> = {
  title: 'Components/Component',
  component: Component,
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['option1', 'option2', 'option3'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
  },
  args: {
    children: 'Label',
    size: 'md',
  },
};

export default meta;
```

### Finding prop options

**From tv() variants:**
```tsx
const component = tv({
  variants: {
    variant: {
      option1: '...',
      option2: '...',
    },
  },
});
```

**From union types:**
```tsx
type Size = 'sm' | 'md' | 'lg';  // → options: ['sm', 'md', 'lg']
type Status = 'pending' | 'active' | 'completed';  // → options: ['pending', 'active', 'completed']
```

Extract all keys from each variant and add them to `argTypes.control.options`.

## Key Rules

1. **One story = one visual state** — Avoid cramming multiple states into one story
2. **Args over render** — Use `args` for simple prop variations; use `render` only when the component needs special setup (providers, wrapper elements, custom interaction)
3. **Compose args** — Reuse args between stories via spread: `args: { ...Primary.args, size: 'lg' }`
4. **Decorators for providers** — Wrap with context providers in `decorators`, not in `render`
5. **Figma link** — Add `parameters.design` with Figma URL when available
6. **No play functions** — This project does not use interaction tests in stories
7. **Generic components** — Pass the generic type explicitly: `Meta<typeof Component<GenericType>>`
8. **Actions** — Use `fn()` from `storybook/test` for callback args: `args: { onClick: fn() }`
9. **Background override** — Use `globals: { backgrounds: { value: 'gray' } }` when needed
10. **Export order** — Define `meta`, then `export default meta`, then named story exports
11. **Document typed props with argTypes** — When component props are typed via `VariantProps` from `tailwind-variants` (or a wrapper), add `argTypes` so every discrete variant appears in Storybook controls
12. **Example strings in English** — Use English for sample `args`, mock labels, and any visible placeholder text in `render`; reserve locale-specific copy for app i18n, not Storybook fixtures
13. **Type mock data on the constant, not on usage** — declare `const fixture: PropType = { … }` instead of casting `{ … } as PropType` at the call site. Avoid `as const` on mock objects passed to components: it narrows literals and forces a redundant cast later. For generated types (GraphQL/codegen) with `Maybe<T>` fields, an annotation on the constant is enough — TS accepts `null` and plain literals without an `as` assertion (see [references/simple-stories.md](references/simple-stories.md))

## References

| Topic | File |
|-------|------|
| Simple story templates | [references/simple-stories.md](references/simple-stories.md) |
| Complex templates (render, decorators, Figma) | [references/render-functions.md](references/render-functions.md) |
| Decorators, parameters, globals, tags | [references/decorators-and-parameters.md](references/decorators-and-parameters.md) |
| MDX, generics, composition | [references/mdx-composition.md](references/mdx-composition.md) |
| Controls overview | [references/controls-overview.md](references/controls-overview.md) |
| Conditional controls, actions, argTypes docs | [references/conditional-and-actions.md](references/conditional-and-actions.md) |
| Typed props with VariantProps and argTypes | [references/typed-props-argtypes.md](references/typed-props-argtypes.md) |
