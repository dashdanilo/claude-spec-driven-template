# Controls Overview

Reference for configuring interactive controls and customizing arg types in Storybook.

## Auto-inferred Controls

Storybook automatically generates controls from component TypeScript types via `react-docgen`. Set the `component` property in meta and controls appear automatically:

```tsx
const meta: Meta<typeof Button> = {
  component: Button, // Controls are auto-generated from Button's prop types
};
```

- `boolean` props → toggle
- `string` props → text input
- `number` props → number input
- Union types (`'primary' | 'secondary'`) → select dropdown
- Enum types → select dropdown

## Custom ArgTypes

Override or enhance auto-inferred controls with `argTypes`.

### Radio buttons for enum props

```tsx
const meta: Meta<typeof Button> = {
  component: Button,
  argTypes: {
    variant: {
      control: 'radio',
      options: ['primary', 'secondary', 'outline'],
    },
  },
};
```

### Select dropdown

```tsx
argTypes: {
  size: {
    control: { type: 'select' },
    options: ['sm', 'md', 'lg'],
  },
}
```

### Number with constraints

```tsx
argTypes: {
  width: {
    control: { type: 'number', min: 100, max: 800, step: 50 },
  },
}
```

### Range slider

```tsx
argTypes: {
  opacity: {
    control: { type: 'range', min: 0, max: 1, step: 0.1 },
  },
}
```

### Color picker

```tsx
argTypes: {
  backgroundColor: {
    control: { type: 'color' },
  },
}
```

## Available control types

| Data Type | Control | Description |
|-----------|---------|-------------|
| boolean | `boolean` | Toggle switch |
| number | `number` | Numeric input (supports `min`, `max`, `step`) |
| number | `range` | Range slider |
| object | `object` | JSON editor |
| array | `object` | JSON editor |
| string | `text` | Free text input |
| string | `color` | Color picker (supports `presetColors`) |
| string | `date` | Date picker |
| enum | `radio` | Radio buttons |
| enum | `inline-radio` | Inline radio buttons |
| enum | `check` | Checkboxes (multi-select) |
| enum | `inline-check` | Inline checkboxes |
| enum | `select` | Dropdown select |
| enum | `multi-select` | Multi-select dropdown |

## Disabling Controls

### Hide a prop from controls table entirely

```tsx
argTypes: {
  internalProp: {
    table: { disable: true },
  },
}
```

### Show prop documentation but remove the control

```tsx
argTypes: {
  readOnlyProp: {
    control: false,
  },
}
```

## Filtering Controls

Show or hide controls using `include`/`exclude` in the `controls` parameter:

```tsx
export const Minimal: Story = {
  parameters: {
    controls: { include: ['variant', 'size', 'label'] },
  },
};

export const Simple: Story = {
  parameters: {
    controls: { exclude: ['className', 'style'] },
  },
};
```

Accepts arrays of strings or regex patterns.

## Sorting Controls

```tsx
const meta: Meta<typeof Component> = {
  component: Component,
  parameters: {
    controls: { sort: 'requiredFirst' }, // 'none' | 'alpha' | 'requiredFirst'
  },
};
```
