# Decorators, Parameters, and Tags

Advanced Storybook configuration for decorators, parameters, globals, and tags.

## Decorators

Decorators wrap stories with extra rendering. Define at story, component, or global level.

### Component-level decorator (context provider)

```tsx
const meta: Meta<typeof JourneyForm> = {
  title: 'Shopping/JourneyForm',
  component: JourneyForm,
  tags: ['autodocs'],
  decorators: [
    Story => (
      <SearchFormProvider searchLocations={searchLocations} searchAirlines={searchAirlines}>
        <Story />
      </SearchFormProvider>
    ),
  ],
};
```

### Story-level decorator (extra markup)

```tsx
export const WithPadding: Story = {
  decorators: [
    (Story) => (
      <div style={{ margin: '3em' }}>
        <Story />
      </div>
    ),
  ],
};
```

### Decorator execution order

1. Global decorators (`.storybook/preview.tsx`) — outermost
2. Component decorators (`meta.decorators`) — middle
3. Story decorators (`story.decorators`) — innermost

In this project, the global decorator `withI18next` wraps all stories with i18n and `MemoryRouter`.

## Parameters

Static metadata that controls Storybook features and addons.

### Figma design link

```tsx
const meta: Meta<typeof Component> = {
  // ...
  parameters: {
    design: {
      type: 'figma',
      url: 'https://www.figma.com/file/DktZjwaAj9m6MM7bFzZnpR/...',
    },
  },
};
```

### React Router context

```tsx
const meta: Meta<typeof Component> = {
  // ...
  parameters: {
    reactRouter: { routePath: '/flights' },
  },
};
```

### Parameter inheritance

Story parameters override component parameters, which override global parameters. Parameters are merged (keys overwritten, never dropped).

## Globals

Override global settings at the component level.

### Background override

```tsx
const meta: Meta<typeof Component> = {
  // ...
  globals: {
    backgrounds: { value: 'gray' },
  },
};
```

## Tags

Control story visibility and behavior.

| Tag | Purpose |
|-----|---------|
| `'autodocs'` | Generate automatic documentation page (always include) |
| `'visual-regression'` | Include in visual regression tests |
| `'!dev'` | Hide from sidebar (docs-only story) |
| `'!autodocs'` | Exclude from auto-generated docs page |
| `'!test'` | Exclude from test runs |

### Docs-only stories (hidden from sidebar)

```tsx
const meta: Meta<typeof Component> = {
  component: Component,
  tags: ['autodocs', '!dev'],
};
```

### Exclude a single story from docs

```tsx
export const InternalOnly: Story = {
  tags: ['!autodocs'],
};
```

## Args Composition

Reuse args between stories via object spread.

```tsx
export const Primary: Story = {
  args: {
    primary: true,
    label: 'Button',
  },
};

export const PrimaryLarge: Story = {
  args: {
    ...Primary.args,
    size: 'lg',
  },
};
```

### Cross-file composition

Import stories from other files to compose args:

```tsx
import * as HeaderStories from './Header.stories';

export const LoggedIn: Story = {
  args: {
    ...HeaderStories.LoggedIn.args,
  },
};
```
