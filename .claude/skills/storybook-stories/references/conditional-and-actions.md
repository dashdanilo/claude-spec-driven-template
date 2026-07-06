# Conditional Controls, Actions, and ArgTypes

Advanced configuration for conditional controls, action logging, custom args, and documentation.

## Conditional Controls

Show/hide controls based on other arg values:

```tsx
argTypes: {
  advanced: { control: 'boolean' },
  margin: { control: 'number', if: { arg: 'advanced' } },
  padding: { control: 'number', if: { arg: 'advanced' } },
}
```

Available operators for `if`:
- `{ arg: 'name' }` — show when arg is truthy (default)
- `{ arg: 'name', truthy: false }` — show when arg is falsy
- `{ arg: 'name', exists: true }` — show when arg is defined
- `{ arg: 'name', eq: 'value' }` — show when arg equals value
- `{ arg: 'name', neq: 'value' }` — show when arg does not equal value

## Actions

### Recommended: `fn()` from `storybook/test`

```tsx
import { fn } from 'storybook/test';

const meta: Meta<typeof Button> = {
  component: Button,
  args: {
    onClick: fn(),
    onHover: fn(),
  },
};
```

Events appear in the Actions panel when triggered. `fn()` creates mock functions compatible with interaction testing.

### Auto-matching via regex (global)

Configure in `.storybook/preview.ts` to automatically create actions for args matching a pattern:

```tsx
const preview: Preview = {
  parameters: {
    actions: { argTypesRegex: '^on.*' },
  },
};
```

This matches any arg starting with `on` (e.g., `onClick`, `onChange`, `onSubmit`). However, auto-matched args are NOT available as spies in play functions. Prefer `fn()` when you need testable mocks.

## Custom Args (Non-Component Props)

Add args that are not part of the component's prop type using intersection types:

```tsx
type PagePropsAndCustomArgs = React.ComponentProps<typeof Page> & { footer?: string };

const meta: Meta<PagePropsAndCustomArgs> = {
  component: Page,
  render: ({ footer, ...args }) => (
    <Page {...args}>
      <footer>{footer}</footer>
    </Page>
  ),
};
```

## Complex Arg Values

For non-serializable values (JSX, functions), use `mapping` in `argTypes`:

```tsx
argTypes: {
  icon: {
    options: ['arrow-up', 'arrow-down', 'close'],
    mapping: {
      'arrow-up': <ArrowUpIcon />,
      'arrow-down': <ArrowDownIcon />,
      'close': <CloseIcon />,
    },
    control: {
      type: 'select',
      labels: {
        'arrow-up': 'Arrow Up',
        'arrow-down': 'Arrow Down',
        'close': 'Close',
      },
    },
  },
}
```

`mapping` converts serializable option values to complex arg values. Labels customize the display text in the control dropdown.

## ArgTypes Description and Documentation

Add descriptions to args for better autodocs:

```tsx
argTypes: {
  variant: {
    description: 'The visual style variant of the button',
    table: {
      type: { summary: 'string' },
      defaultValue: { summary: 'primary' },
    },
  },
}
```

Use `parameters.docs.description.component` for the component-level description:

```tsx
parameters: {
  docs: {
    description: {
      component: 'A versatile button component with multiple variants and sizes.',
    },
  },
},
```
