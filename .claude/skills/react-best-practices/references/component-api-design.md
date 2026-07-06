# Component API Design

Patterns for designing clear, type-safe, and ergonomic component props.

## Extending Native Elements

Always extend native HTML props when wrapping elements:

```tsx
// ✅ Extends native button — consumers get onClick, disabled, type, etc.
interface ButtonProps extends React.ComponentPropsWithoutRef<'button'> {
  variant: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
}

// ✅ With ref support
interface InputProps extends React.ComponentPropsWithRef<'input'> {
  error?: string;
}

// ❌ Don't re-declare native props manually
interface BadButtonProps {
  onClick?: () => void;
  disabled?: boolean;
  children: React.ReactNode;
  variant: 'primary' | 'secondary';
}
```

## Prop Spreading

Spread remaining props onto the underlying element. Extract custom props first:

```tsx
function Input({ error, className, ...rest }: InputProps) {
  return (
    <div>
      <input
        className={clsx('input', error && 'input--error', className)}
        aria-invalid={!!error}
        {...rest}
      />
      {error && <span role="alert">{error}</span>}
    </div>
  );
}
```

**Rule**: Spread `...rest` LAST so consumer props override defaults. Spread your explicit props first when you need guaranteed control (e.g., `role`, `aria-*`).

## Discriminated Union Props

Use when a component has mutually exclusive variants with different required props:

```tsx
// ❌ Boolean props — unclear, allows invalid combos
interface BadProps {
  isLink?: boolean;
  href?: string;      // only valid when isLink
  onClick?: () => void; // only valid when NOT isLink
}

// ✅ Discriminated union — invalid combos are compile errors
type ActionProps =
  | { variant: 'link'; href: string; external?: boolean }
  | { variant: 'button'; onClick: () => void; isLoading?: boolean };

type CallToActionProps = ActionProps & {
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg';
};

function CallToAction(props: CallToActionProps) {
  const { children, size = 'md' } = props;

  if (props.variant === 'link') {
    return (
      <a href={props.href} target={props.external ? '_blank' : undefined}>
        {children}
      </a>
    );
  }

  return (
    <button onClick={props.onClick} disabled={props.isLoading}>
      {props.isLoading ? <Spinner /> : children}
    </button>
  );
}

// Usage
<CallToAction variant="link" href="/docs">Docs</CallToAction>
<CallToAction variant="button" onClick={save}>Save</CallToAction>
<CallToAction variant="link" onClick={save}>Error</CallToAction> // ❌ TS error
```

## Exclusive Props (XOR)

When exactly one of several props must be provided:

```tsx
type XOR<A, B> = (A & { [K in keyof B]?: never }) | (B & { [K in keyof A]?: never });

type IconButtonProps = XOR<
  { icon: React.ReactNode; 'aria-label': string },
  { children: React.ReactNode }
>;

// Either icon + aria-label OR children, never both
```

## RequireAtLeastOne

When at least one prop from a set is required:

```tsx
type RequireAtLeastOne<T, Keys extends keyof T = keyof T> = Omit<T, Keys> &
  { [K in Keys]-?: Required<Pick<T, K>> & Partial<Pick<T, Exclude<Keys, K>>> }[Keys];

interface FilterBase {
  byName?: string;
  byDate?: Date;
  byStatus?: Status;
}

type FilterProps = RequireAtLeastOne<FilterBase, 'byName' | 'byDate' | 'byStatus'>;
```

## Default Props via Destructuring

```tsx
interface TooltipProps {
  content: React.ReactNode;
  position?: 'top' | 'bottom' | 'left' | 'right';
  delay?: number;
  children: React.ReactElement;
}

function Tooltip({ content, position = 'top', delay = 200, children }: TooltipProps) {
  // position and delay always have values — no undefined checks needed
}
```

## Callback Prop Conventions

```tsx
interface DataTableProps<T> {
  data: T[];
  // ✅ on + Noun + Verb (describes what happened)
  onRowClick: (row: T, index: number) => void;
  onSelectionChange: (selected: T[]) => void;
  onSortChange: (column: keyof T, direction: 'asc' | 'desc') => void;

  // ❌ Avoid vague names
  // handleClick, onChange, callback
}
```

**Internal handler naming**: Prefix with `handle`:

```tsx
function DataTable<T>({ data, onRowClick }: DataTableProps<T>) {
  const handleRowClick = (row: T, index: number) => {
    // internal logic (analytics, etc.)
    onRowClick(row, index);
  };
}
```

## Merging Consumer Props

When you need to compose handlers or class names with consumer-provided ones:

```tsx
function Button({ onClick, className, ...rest }: ButtonProps) {
  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
    // Internal logic first
    trackEvent('button_click');
    // Then call consumer's handler
    onClick?.(e);
  };

  return (
    <button
      className={clsx('btn', className)} // merge classNames
      onClick={handleClick}              // compose handlers
      {...rest}
    />
  );
}
```

## Checklist

- [ ] Extend `ComponentPropsWithoutRef<element>` (or `WithRef` if forwarding)
- [ ] Spread `...rest` onto the underlying element
- [ ] Use discriminated unions instead of boolean prop combinations
- [ ] Default values via destructuring, not `defaultProps`
- [ ] `on` + noun + verb for callbacks, `handle` prefix for internal handlers
- [ ] Compose (don't replace) consumer's `className` and event handlers
