# Simple Story Templates

Complete CSF3 story templates for simple components with variants.

## Simple Component — Multiple Variants via Args

Use when the component has a variant/enum prop and each value deserves its own story.

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';

import { Tag } from '../main';

type Story = StoryObj<typeof Tag>;

const meta: Meta<typeof Tag> = {
  title: 'Components/Tag',
  component: Tag,
  tags: ['autodocs'],
  args: {
    label: 'Label',
    textVariant: 'defaultSize',
    iconLeft: '',
    iconRight: '',
  },
};

export default meta;

export const Default: Story = {
  args: { variant: 'default' },
};

export const Confirmed: Story = {
  args: { variant: 'confirmed' },
};

export const Warning: Story = {
  args: { variant: 'warning' },
};

export const Error: Story = {
  args: { variant: 'error' },
};
```

Key points:
- One `export const` per variant value
- Default args on `meta.args` apply to all stories
- Story-level `args` override only the varying prop

## Component with Actions (Callback Props)

Use when the component has callback props that should be logged in the Actions panel.

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';
import { fn } from 'storybook/test';

import { Button } from '../main';

type Story = StoryObj<typeof Button>;

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  tags: ['autodocs'],
  args: {
    onClick: fn(),
    label: 'Click me',
  },
};

export default meta;

export const Primary: Story = {
  args: { variant: 'primary' },
};

export const Secondary: Story = {
  args: { variant: 'secondary' },
};

export const Disabled: Story = {
  args: { variant: 'primary', disabled: true },
};
```

Key points:
- Import `fn` from `storybook/test` (NOT from `@storybook/test`)
- Assign `fn()` to callback args at the meta level so all stories log actions
- Each click will appear in the Actions panel with the function arguments

## Typing Mock Data Without Casts

When stories build mock objects (especially from generated GraphQL/codegen types), annotate the constant — never cast at the call site. `as Type` on every usage multiplies by story count; `as const` on a shared base narrows literals and forces that cast in the first place.

```tsx
// ✅ Annotate the constant. TS accepts plain literals and `null` against Maybe<T>.
const baseRule: PricingDebugRule = {
  id: '2226',
  commission: 5,
  over: 2.5,
  tour_code: 'ABC123',
};

export const Matched: Story = {
  args: { rule: { ...baseRule, matched: true } },
};
```

```tsx
// ❌ `as const` on the base + `as Type` per story. Casts spread across every variant.
const baseRule = { id: '2226', commission: 5 } as const;

export const Matched: Story = {
  args: { rule: { ...baseRule, matched: true } as PricingDebugRule },
};
```

Key points:
- One annotation on the source constant covers every story that spreads it
- For arrays, type the constant: `const conditions: PricingDebugCondition[] = [...]`
- If a single inline object needs help, lift it to a typed constant rather than casting in place
