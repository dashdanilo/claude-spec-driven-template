# TypeScript for Components

Advanced TypeScript patterns for building type-safe, generic, and ergonomic React components.

## Generic Components

Make components work with any data type while preserving type inference:

```tsx
type SelectProps<T> = {
  options: T[];
  value: T | null;
  onChange: (value: T) => void;
  getLabel: (item: T) => string;
  getKey: (item: T) => string;
};

function Select<T>({ options, value, onChange, getLabel, getKey }: SelectProps<T>) {
  return (
    <ul role="listbox">
      {options.map(option => (
        <li
          key={getKey(option)}
          role="option"
          aria-selected={option === value}
          onClick={() => onChange(option)}
        >
          {getLabel(option)}
        </li>
      ))}
    </ul>
  );
}

// Usage — T is inferred as User
<Select
  options={users}
  value={selectedUser}
  onChange={setSelectedUser}
  getLabel={u => u.name}
  getKey={u => u.id}
/>
```

## Discriminated Union Props

Type-safe variant props where TypeScript narrows available props per variant:

```tsx
type NotificationProps =
  | { type: 'success'; message: string }
  | { type: 'error'; message: string; retryAction: () => void }
  | { type: 'loading'; progress?: number };

function Notification(props: NotificationProps) {
  switch (props.type) {
    case 'success': return <div className="success">{props.message}</div>;
    case 'error': return (
      <div className="error">{props.message}<button onClick={props.retryAction}>Retry</button></div>
    );
    case 'loading': return <div className="loading"><ProgressBar value={props.progress} /></div>;
  }
}
```

## Extracting & Extending Native Props

```tsx
// Pick specific native props
type PickedInputProps = Pick<
  React.ComponentPropsWithoutRef<'input'>,
  'placeholder' | 'disabled' | 'autoFocus'
>;

// Extend and override
type TextFieldProps = Omit<React.ComponentPropsWithoutRef<'input'>, 'size'> & {
  size: 'sm' | 'md' | 'lg'; // Override native size (which is number)
  error?: string;
};

// Extend another component's props
type ExtendedButtonProps = React.ComponentPropsWithoutRef<typeof Button> & {
  tooltip?: string;
};
```

## forwardRef with Generics

Standard `forwardRef` breaks generic inference. Use the cast pattern:

```tsx
function fixedForwardRef<T, P = {}>(
  render: (props: P, ref: React.Ref<T>) => React.ReactNode
): (props: P & React.RefAttributes<T>) => React.ReactNode {
  return forwardRef(render as any) as any;
}

// Generic component with ref
const GenericList = fixedForwardRef(
  <T,>(props: { items: T[]; renderItem: (item: T) => React.ReactNode }, ref: React.Ref<HTMLUListElement>) => (
    <ul ref={ref}>{props.items.map((item, i) => <li key={i}>{props.renderItem(item)}</li>)}</ul>
  )
);
```

## Conditional / Exclusive Props

### XOR — Exactly one of two prop sets:

```tsx
type Without<T, U> = { [P in Exclude<keyof T, keyof U>]?: never };
type XOR<T, U> = (T | U) extends object ? (Without<T, U> & U) | (Without<U, T> & T) : T | U;

type ModalProps = XOR<
  { isOpen: boolean; onClose: () => void },  // controlled
  { trigger: React.ReactElement }              // self-managed
>;
```

### RequireAtLeastOne:

```tsx
type RequireAtLeastOne<T, Keys extends keyof T = keyof T> =
  Omit<T, Keys> &
  { [K in Keys]-?: Required<Pick<T, K>> & Partial<Pick<T, Exclude<Keys, K>>> }[Keys];

// At least one of icon, label, or children must be provided
type ButtonProps = RequireAtLeastOne<{
  icon?: React.ReactNode;
  label?: string;
  children?: React.ReactNode;
}, 'icon' | 'label' | 'children'>;
```

## Context Typing

Safe context with no default value — throw at consumption, not creation:

```tsx
function createSafeContext<T>(displayName: string) {
  const Context = createContext<T | null>(null);
  Context.displayName = displayName;

  function useContext_() {
    const ctx = useContext(Context);
    if (ctx === null) {
      throw new Error(`use${displayName} must be used within ${displayName}Provider`);
    }
    return ctx;
  }

  return [Context.Provider, useContext_] as const;
}

// Usage
type ThemeContextValue = { theme: 'light' | 'dark'; toggle: () => void };
const [ThemeProvider, useTheme] = createSafeContext<ThemeContextValue>('Theme');
```

## Strict Event Handler Types

```tsx
// ✅ React's built-in handler types for native elements
type FormFieldProps = {
  onChange: React.ChangeEventHandler<HTMLInputElement>;
  onBlur: React.FocusEventHandler<HTMLInputElement>;
};

// ✅ Custom component events — descriptive callback types
type DatePickerProps = {
  onDateChange: (date: Date) => void;
  onRangeSelect: (range: { start: Date; end: Date }) => void;
};
```

## Template Literal Types for APIs

```tsx
type Size = 'sm' | 'md' | 'lg' | 'xl';
type Breakpoint = 'sm' | 'md' | 'lg';
type ResponsiveSize = Size | `${Breakpoint}:${Size}`;
// Accepts: 'md', 'sm:sm', ['sm:sm', 'md:md', 'lg:lg']
```

## Checklist

- [ ] Use `type` for public component props (intersection `&` when extending native props)
- [ ] Generic components for data-agnostic containers (Select, Table, List)
- [ ] Discriminated unions over boolean prop combinations
- [ ] `ComponentPropsWithoutRef` when extending native elements
- [ ] `fixedForwardRef` when generics + ref forwarding needed
- [ ] `createSafeContext` helper to avoid `null` checks at every consumption
- [ ] `as const` on hook return tuples to preserve literal types
