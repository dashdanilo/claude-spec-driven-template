# MDX, Generic Components, and Render Functions

Advanced patterns for MDX documentation, generic components, and custom render functions.

## Generic Components

Pass the generic type parameter explicitly to `Meta`:

```tsx
import type { Leg } from '../../data';

const meta: Meta<typeof FlightDetails<Leg>> = {
  title: 'Booking/FlightDetails',
  component: FlightDetails,
  // ...
};

type Story = StoryObj<typeof FlightDetails>;
```

## Subcomponents (Autodocs)

Document related components together using `subcomponents`:

```tsx
const meta: Meta<typeof List> = {
  component: List,
  subcomponents: { ListItem },
  tags: ['autodocs'],
};
```

The main component and subcomponents appear in a tabbed ArgTypes table in the docs page.

## MDX Documentation Pages

Use MDX for standalone documentation pages (not component stories). Place in `packages/docs/src/stories/`.

```mdx
import { Meta } from '@storybook/addon-docs/blocks';

<Meta title="Develop/Getting Started" />

# Getting Started

Content here...
```

### Attached MDX (linked to a component's stories)

```mdx
import { Meta, Primary, Controls, Story } from '@storybook/addon-docs/blocks';
import * as ButtonStories from './Button.stories';

<Meta of={ButtonStories} />

# Button

A button component for user interactions.

<Primary />

## Props

<Controls />

## Stories

### Primary

<Story of={ButtonStories.Primary} />

### Secondary

<Story of={ButtonStories.Secondary} />
```

### Available Doc Blocks

| Block | Purpose |
|-------|---------|
| `<Meta>` | Attach MDX to a component or set sidebar position |
| `<Title>` | Render the component title |
| `<Subtitle>` | Secondary heading |
| `<Description>` | Component JSDoc description |
| `<Primary>` | Render the first story |
| `<Controls>` | Interactive args table |
| `<Stories>` | Render all stories |
| `<Story of={...}>` | Render a specific story |
| `<Source>` | Show source code snippet |
| `<Canvas>` | Story with toolbar and source |
| `<ArgTypes>` | Static arg types table |

## Custom Render Functions

Use `render` when the component needs setup beyond simple props.

### Inline render

```tsx
export const WithIcon: Story = {
  args: { variant: 'primary', children: 'With Icon' },
  render: (args) => (
    <Button {...args}>
      <span>★</span> {args.children}
    </Button>
  ),
};
```

### Shared render function

Extract when multiple stories share the same render logic:

```tsx
const render = (args: ArgTypes<typeof Toast>) => (
  <div>
    <Toaster />
    <button type="button" onClick={() => makeToast(args)}>
      show toast
    </button>
  </div>
);

export const Error: Story = { render, args: { variant: 'error' } };
export const Success: Story = { render, args: { variant: 'success' } };
```

### Named render function (for hooks)

Use a named function (not arrow) when you need Storybook hooks like `useArgs`:

```tsx
export const Controlled: Story = {
  args: { isChecked: false, label: 'Toggle me' },
  render: function Render(args) {
    const [{ isChecked }, updateArgs] = useArgs();
    return (
      <Checkbox {...args} isChecked={isChecked} onChange={() => updateArgs({ isChecked: !isChecked })} />
    );
  },
};
```

Import `useArgs` from `storybook/preview-api`. Do NOT mix with React's `useState`/`useEffect` inside render functions that use Storybook hooks.
