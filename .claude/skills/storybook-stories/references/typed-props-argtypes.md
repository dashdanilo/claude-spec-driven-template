# Typed Props and argTypes

When props have known literal values, Storybook cannot automatically infer the available options. You must document them manually with `argTypes`.

## When to Use argTypes

- Props typed with `VariantProps<typeof tv()>` — see **tailwind-styling** skill for VariantProps details
- Props with union types of literal strings: `type Size = 'sm' | 'md' | 'lg'`
- Props with TypeScript enums
- Any prop that accepts specific known values

## When NOT to Use argTypes

- Props with open-ended string values: `className`, `placeholder`, `title`
- Props that accept any string/number
- Props that are truly dynamic

## The Solution: argTypes

```tsx
const meta: Meta<ButtonProps> = {
  title: 'Components/Button',
  component: Button,
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'ghost'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
  },
};

export default meta;
```

Without argTypes, Storybook shows a **text input** instead of a **select dropdown** because it doesn't know the available options.

## Available Control Types

| Control | Use For |
|---------|---------|
| `select` | Enum/variant props with known options |
| `boolean` | Boolean props |
| `number` | Numeric props |
| `color` | Color-related props |
| `date` | Date props |

## Finding Options from Source

**From tv() variants** — extract the keys:
```tsx
const component = tv({
  variants: {
    variant: { optionA: '...', optionB: '...' },  // → options: ['optionA', 'optionB']
    size: { sm: '...', md: '...', lg: '...' },     // → options: ['sm', 'md', 'lg']
  },
});
```

**From union types:**
```tsx
type Size = 'sm' | 'md' | 'lg';  // → options: ['sm', 'md', 'lg']
```

**From TypeScript enums:**
```tsx
enum ButtonVariant { Primary = 'primary', Secondary = 'secondary' }
// → options: ['primary', 'secondary'] (use Object.values)
```

## Multiple Variant Props

Document each prop with known values separately:

```tsx
argTypes: {
  variant: { control: 'select', options: ['primary', 'secondary', 'ghost'] },
  size: { control: 'select', options: ['sm', 'md', 'lg'] },
  state: { control: 'select', options: ['default', 'loading', 'disabled'] },
}
```

## Boolean Props

Boolean props don't need explicit options:

```tsx
argTypes: {
  disabled: { control: 'boolean' },
  loading: { control: 'boolean' },
}
```
