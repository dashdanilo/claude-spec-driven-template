# Custom Hook Patterns

Patterns for extracting, composing, and structuring reusable hooks.

## Hook Composition

Build complex hooks by composing simpler ones:

```tsx
function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}

function useSearch(items: string[]) {
  const [query, setQuery] = useState('');
  const debouncedQuery = useDebounce(query, 300);

  const results = useMemo(
    () => items.filter(item => item.toLowerCase().includes(debouncedQuery.toLowerCase())),
    [items, debouncedQuery]
  );

  return { query, setQuery, results } as const;
}
```

**Rule**: Compose hooks like functions. Each hook encapsulates one concern.

## useReducer with Discriminated Actions

For complex state transitions — exhaustive checking prevents missed cases:

```tsx
interface FormState {
  status: 'idle' | 'submitting' | 'success' | 'error';
  data: Record<string, string>;
  error: string | null;
}

type FormAction =
  | { type: 'FIELD_CHANGE'; field: string; value: string }
  | { type: 'SUBMIT' } | { type: 'SUCCESS' }
  | { type: 'ERROR'; error: string } | { type: 'RESET' };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'FIELD_CHANGE':
      return { ...state, data: { ...state.data, [action.field]: action.value } };
    case 'SUBMIT': return { ...state, status: 'submitting', error: null };
    case 'SUCCESS': return { ...state, status: 'success' };
    case 'ERROR': return { ...state, status: 'error', error: action.error };
    case 'RESET': return { status: 'idle', data: {}, error: null };
    default: { const _exhaustive: never = action; return state; }
  }
}

function useForm(initialData: Record<string, string> = {}) {
  const [state, dispatch] = useReducer(formReducer, { status: 'idle', data: initialData, error: null });
  const setField = useCallback(
    (field: string, value: string) => dispatch({ type: 'FIELD_CHANGE', field, value }), []
  );
  return { ...state, setField, dispatch } as const;
}
```

**When to use useReducer vs useState**: Multiple related state fields, complex transitions, or when next state depends on previous.

## Hook Factories

Generate hooks with configurable behavior:

```tsx
function createStorageHook(storage: Storage) {
  return function useStorage<T>(key: string, initialValue: T) {
    const [value, setValue] = useState<T>(() => {
      const stored = storage.getItem(key);
      return stored ? (JSON.parse(stored) as T) : initialValue;
    });
    useEffect(() => { storage.setItem(key, JSON.stringify(value)); }, [key, value]);
    const remove = useCallback(() => { storage.removeItem(key); setValue(initialValue); }, [key, initialValue]);
    return [value, setValue, remove] as const;
  };
}

const useLocalStorage = createStorageHook(localStorage);
const useSessionStorage = createStorageHook(sessionStorage);
```

## Return Patterns

**Tuple** (2-3 values) — positional, concise, easy to rename:

```tsx
function useToggle(initial = false) {
  const [on, setOn] = useState(initial);
  const toggle = useCallback(() => setOn(prev => !prev), []);
  return [on, toggle] as const;
}

const [isOpen, toggleOpen] = useToggle();
```

**Object** (4+ values):

```tsx
function usePagination({ totalItems, pageSize }: PaginationConfig) {
  // ... state logic
  return { page, totalPages, next, prev, goTo, hasNext, hasPrev } as const;
}

const { page, next, hasNext } = usePagination({ totalItems: 100, pageSize: 10 });
```

**Rule**: Always use `as const` for tuple returns. This preserves literal types instead of widening.

## Ref Patterns

### useImperativeHandle — Expose specific methods:

```tsx
interface VideoPlayerHandle {
  play: () => void;
  pause: () => void;
  seek: (time: number) => void;
}

const VideoPlayer = forwardRef<VideoPlayerHandle, VideoPlayerProps>(
  ({ src }, ref) => {
    const videoRef = useRef<HTMLVideoElement>(null);

    useImperativeHandle(ref, () => ({
      play: () => videoRef.current?.play(),
      pause: () => videoRef.current?.pause(),
      seek: (time) => { if (videoRef.current) videoRef.current.currentTime = time; },
    }), []);

    return <video ref={videoRef} src={src} />;
  }
);

// Usage
const playerRef = useRef<VideoPlayerHandle>(null);
playerRef.current?.seek(30);
```

### Callback Refs — Run logic when element mounts/unmounts:

```tsx
function useIntersectionObserver(callback: IntersectionObserverCallback) {
  const observer = useRef<IntersectionObserver | null>(null);

  return useCallback((node: HTMLElement | null) => {
    observer.current?.disconnect();
    if (node) {
      observer.current = new IntersectionObserver(callback);
      observer.current.observe(node);
    }
  }, [callback]);
}

<div ref={useIntersectionObserver(([entry]) => {
  if (entry.isIntersecting) loadMore();
})} />
```

## Wrapping Third-Party Libraries

Encapsulate external APIs behind a stable hook interface:

```tsx
function useElementSize<T extends HTMLElement>() {
  const [size, setSize] = useState({ width: 0, height: 0 });
  const ref = useRef<T>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => {
      setSize({ width: entry.contentRect.width, height: entry.contentRect.height });
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return { ref, ...size } as const;
}
```

## Anti-Patterns
| Anti-Pattern | Fix |
|-------------|-----|
| Hook does too many things | Split into smaller hooks, compose them |
| Returning 5+ positional values | Switch to object return |
| `useEffect` for derived data | Compute inline or with `useMemo` |
| Unstable deps in hooks | Move functions inside hook, use refs for callbacks |
