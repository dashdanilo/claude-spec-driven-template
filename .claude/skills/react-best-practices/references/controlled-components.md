# Controlled & Uncontrolled Components

Patterns for building components that work in both controlled and uncontrolled modes.

## Controlled vs Uncontrolled

| Aspect | Controlled | Uncontrolled |
|--------|-----------|-------------|
| State lives in | Parent (via props) | Component (internal) |
| Updates via | Parent's `onChange` handler | Component manages itself |
| Use when | Form validation, dependent fields, shared state | Simple forms, third-party integration |
| Example | `<Input value={val} onChange={setVal} />` | `<Input defaultValue="hi" />` |

## useControllableState

The key pattern — support BOTH modes with a single implementation. Based on Radix UI's approach:

```tsx
import { useState, useCallback, useRef, useEffect } from 'react';

interface UseControllableStateParams<T> {
  prop?: T;                    // controlled value
  defaultProp?: T;             // initial uncontrolled value
  onChange?: (value: T) => void;
}

function useControllableState<T>({
  prop,
  defaultProp,
  onChange,
}: UseControllableStateParams<T>) {
  const [uncontrolledValue, setUncontrolledValue] = useState(defaultProp);
  const isControlled = prop !== undefined;
  const value = isControlled ? prop : uncontrolledValue;
  const onChangeRef = useRef(onChange);

  useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  const setValue = useCallback(
    (nextValue: T | ((prev: T | undefined) => T)) => {
      if (isControlled) {
        const resolved = typeof nextValue === 'function'
          ? (nextValue as (prev: T | undefined) => T)(prop)
          : nextValue;
        onChangeRef.current?.(resolved);
      } else {
        setUncontrolledValue(nextValue);
        const resolved = typeof nextValue === 'function'
          ? (nextValue as (prev: T | undefined) => T)(uncontrolledValue)
          : nextValue;
        onChangeRef.current?.(resolved);
      }
    },
    [isControlled, prop, uncontrolledValue]
  );

  return [value, setValue] as const;
}
```

## Using useControllableState

```tsx
interface SelectProps<T> {
  options: { value: T; label: string }[];
  // Controlled
  value?: T;
  onChange?: (value: T) => void;
  // Uncontrolled
  defaultValue?: T;
  // Common
  placeholder?: string;
}

function Select<T>({ options, value: valueProp, defaultValue, onChange, placeholder }: SelectProps<T>) {
  const [value, setValue] = useControllableState({
    prop: valueProp,
    defaultProp: defaultValue,
    onChange,
  });

  return (
    <select
      value={String(value ?? '')}
      onChange={(e) => {
        const option = options.find(o => String(o.value) === e.target.value);
        if (option) setValue(option.value);
      }}
    >
      {placeholder && <option value="">{placeholder}</option>}
      {options.map(opt => (
        <option key={String(opt.value)} value={String(opt.value)}>
          {opt.label}
        </option>
      ))}
    </select>
  );
}

// Controlled usage
const [color, setColor] = useState('red');
<Select value={color} onChange={setColor} options={colors} />

// Uncontrolled usage
<Select defaultValue="red" options={colors} />
```

## Headless Hook Pattern

Separate logic from UI entirely. The hook provides state and handlers; the consumer provides all markup:

```tsx
interface UseToggleReturn {
  isOpen: boolean;
  open: () => void;
  close: () => void;
  toggle: () => void;
  triggerProps: {
    onClick: () => void;
    'aria-expanded': boolean;
  };
  contentProps: {
    hidden: boolean;
    role: string;
  };
}

function useToggle(initial = false): UseToggleReturn {
  const [isOpen, setIsOpen] = useState(initial);

  return {
    isOpen,
    open: useCallback(() => setIsOpen(true), []),
    close: useCallback(() => setIsOpen(false), []),
    toggle: useCallback(() => setIsOpen(prev => !prev), []),
    triggerProps: {
      onClick: () => setIsOpen(prev => !prev),
      'aria-expanded': isOpen,
    },
    contentProps: {
      hidden: !isOpen,
      role: 'region',
    },
  };
}

// Consumer controls ALL rendering
function FAQ({ question, answer }: { question: string; answer: string }) {
  const { triggerProps, contentProps } = useToggle();

  return (
    <div>
      <button {...triggerProps}>{question}</button>
      <div {...contentProps}>{answer}</div>
    </div>
  );
}
```

**When to use headless hooks**:
- Design system with multiple visual themes sharing logic
- Components where consumers need full render control
- Accessible widget logic reused across different UIs

## Headless + Compound (Advanced)

Combine headless logic with compound components: use a headless hook (`useDialog`) for state/behavior, wrap it in a Context-based compound component (`Dialog`, `Dialog.Trigger`, `Dialog.Content`) for ergonomic API.

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Checking `onChange && value` to detect controlled mode | Check `value !== undefined` (value can be falsy) |
| Switching between controlled/uncontrolled at runtime | Decide once at mount — warn in dev if it changes |
| Headless hook returning JSX | Return only data + handlers, never JSX |
| Missing `aria-*` in headless hooks | Include accessibility attributes in returned prop objects |
