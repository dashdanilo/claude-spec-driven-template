# Polymorphic Components

Components that render as different HTML elements or other components while preserving type safety.

## The `as` Prop Pattern

Allow consumers to choose the rendered element:

```tsx
type PolymorphicProps<T extends React.ElementType> = {
  as?: T;
} & Omit<React.ComponentPropsWithoutRef<T>, 'as'>;

function Box<T extends React.ElementType = 'div'>({
  as,
  ...rest
}: PolymorphicProps<T>) {
  const Component = as || 'div';
  return <Component {...rest} />;
}

// Usage — fully type-safe
<Box>Default div</Box>
<Box as="a" href="/home">Link</Box>        // ✅ href is valid
<Box as="button" onClick={handleClick}>Btn</Box>  // ✅ onClick is valid
<Box as="a" onClick={handleClick}>Link</Box> // ✅ anchor supports onClick
```

## With Custom Props

Extend the polymorphic base with your own props:

```tsx
type TextProps<T extends React.ElementType = 'span'> = PolymorphicProps<T> & {
  variant: 'body' | 'heading' | 'caption';
  truncate?: boolean;
};

function Text<T extends React.ElementType = 'span'>({
  as,
  variant,
  truncate,
  className,
  ...rest
}: TextProps<T>) {
  const Component = as || 'span';
  return (
    <Component
      className={clsx(variant, truncate && 'truncate', className)}
      {...rest}
    />
  );
}

// Usage
<Text variant="heading" as="h1">Page Title</Text>
<Text variant="body" as="p" truncate>Long paragraph...</Text>
```

## With Ref Forwarding

Full polymorphic component with ref support:

```tsx
type PolymorphicRef<T extends React.ElementType> = React.ComponentPropsWithRef<T>['ref'];

type PolymorphicPropsWithRef<T extends React.ElementType, Props = {}> = Props &
  Omit<React.ComponentPropsWithoutRef<T>, keyof Props | 'as'> & {
    as?: T;
    ref?: PolymorphicRef<T>;
  };

// Helper to fix forwardRef generic inference
function polyForwardRef<
  DefaultElement extends React.ElementType,
  Props = {},
>(
  render: <T extends React.ElementType = DefaultElement>(
    props: PolymorphicPropsWithRef<T, Props>,
    ref: PolymorphicRef<T>
  ) => React.ReactNode
) {
  return forwardRef(render as any) as <T extends React.ElementType = DefaultElement>(
    props: PolymorphicPropsWithRef<T, Props>
  ) => React.ReactNode;
}

// Usage
interface ButtonOwnProps {
  variant: 'primary' | 'ghost';
  isLoading?: boolean;
}

const Button = polyForwardRef<'button', ButtonOwnProps>(
  ({ as, variant, isLoading, children, ...rest }, ref) => {
    const Component = as || 'button';
    return (
      <Component ref={ref} data-variant={variant} {...rest}>
        {isLoading ? <Spinner /> : children}
      </Component>
    );
  }
);

<Button variant="primary" ref={buttonRef}>Click</Button>
<Button variant="ghost" as="a" href="/home" ref={linkRef}>Home</Button>
```

## The `asChild` Pattern (Radix-Style)

Instead of rendering a specific element, merge props into the consumer's child:

```tsx
import { cloneElement, isValidElement, type ReactElement } from 'react';

interface SlotProps extends React.HTMLAttributes<HTMLElement> {
  children: ReactElement;
}

function Slot({ children, ...props }: SlotProps) {
  if (!isValidElement(children)) return null;

  return cloneElement(children, {
    ...mergeProps(props, children.props),
    ref: (children as any).ref,
  });
}

// Component using asChild
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  asChild?: boolean;
}

function Button({ asChild, children, ...props }: ButtonProps) {
  if (asChild && isValidElement(children)) {
    return <Slot {...props}>{children}</Slot>;
  }
  return <button {...props}>{children}</button>;
}

// Usage — render as a Link
<Button asChild>
  <a href="/home">Home</a>
</Button>
```

**When to use `as` vs `asChild`**:
- `as` — simpler, works well for HTML elements and basic components
- `asChild` — better for complex components (e.g., router Links), avoids generic type complexity

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Casting ref as `any` | Use `polyForwardRef` helper above |
| Allowing `as={SomeComplexComponent}` without restriction | Constrain `T extends 'a' \| 'button' \| 'div'` if limited set |
| Prop conflicts between custom and native props | Use `Omit` to exclude conflicting native props |
