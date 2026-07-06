# Performance Patterns

Component-level optimization techniques. **Profile first, optimize second.** Most React apps don't need these until they measurably do.

## React.memo

Skips re-rendering when props haven't changed (shallow comparison):

```tsx
interface ExpensiveListProps {
  items: Item[];
  onItemClick: (id: string) => void;
}

const ExpensiveList = React.memo(function ExpensiveList({
  items,
  onItemClick,
}: ExpensiveListProps) {
  return (
    <ul>
      {items.map(item => (
        <li key={item.id} onClick={() => onItemClick(item.id)}>
          {item.name}
        </li>
      ))}
    </ul>
  );
});
```

**When to use React.memo:**
- Component renders often with same props (parent re-renders frequently)
- Component is expensive to render (large lists, heavy computation)
- Component is far from state changes in the tree

**When NOT to use:**
- Component is cheap to render
- Props change on every render anyway (new objects/arrays/functions)
- Premature — you haven't profiled

### Custom Comparison

```tsx
const MemoizedChart = React.memo(Chart, (prev, next) => {
  // Return true to SKIP re-render
  return prev.data.length === next.data.length &&
    prev.data.every((d, i) => d.value === next.data[i].value);
});
```

## useMemo / useCallback — Concrete Rules

**useMemo** — cache expensive computations:

```tsx
// ✅ Expensive filtering/sorting
const sortedItems = useMemo(
  () => items.slice().sort((a, b) => a.name.localeCompare(b.name)),
  [items]
);

// ✅ Stable reference for context value (prevents consumer re-renders)
const contextValue = useMemo(() => ({ user, permissions }), [user, permissions]);

// ❌ Cheap computation — useMemo overhead exceeds the computation
const fullName = useMemo(() => `${first} ${last}`, [first, last]);
// ✅ Just compute it
const fullName = `${first} ${last}`;
```

**useCallback** — stable function reference:

```tsx
// ✅ Passed to memoized child
const handleClick = useCallback(
  (id: string) => setSelected(id),
  []
);
<MemoizedList onItemClick={handleClick} /> // Won't break memo

// ✅ Used in useEffect dependency array
const fetchData = useCallback(async () => { /* ... */ }, [query]);
useEffect(() => { fetchData(); }, [fetchData]);

// ❌ Not passed to memoized component — no benefit
const handleClick = useCallback(() => setOpen(true), []);
<button onClick={handleClick}>Open</button> // button is not memoized
```

## Key Prop Reset

Force React to unmount and remount a component by changing its `key`:

```tsx
function UserProfile({ userId }: { userId: string }) {
  // ❌ useEffect to reset state on userId change
  // const [data, setData] = useState(null);
  // useEffect(() => { setData(null); fetch(userId)... }, [userId]);

  // ✅ Key change = fresh component instance, clean state
  return <ProfileForm key={userId} userId={userId} />;
}

// ProfileForm doesn't need to handle userId changes — it always mounts fresh
function ProfileForm({ userId }: { userId: string }) {
  const [formData, setFormData] = useState({});  // starts clean per userId
  // ...
}
```

**When to use**: Resetting all internal state (form values, scroll position, animation state) when a key prop changes.

## Children as Stable Reference

Move children above the re-rendering parent to avoid unnecessary re-renders:

```tsx
// ❌ ExpensiveChild re-renders every time count changes
function Parent() {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>{count}</button>
      <ExpensiveChild />  {/* re-renders on every count change */}
    </div>
  );
}

// ✅ Lift the state-changing part, pass children through
function Counter({ children }: { children: React.ReactNode }) {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>{count}</button>
      {children}  {/* stable reference — doesn't re-render */}
    </div>
  );
}

// ExpensiveChild created outside Counter = stable reference
<Counter><ExpensiveChild /></Counter>
```

## Component Splitting

Extract expensive subtrees to isolate re-renders:

```tsx
// ❌ Entire component re-renders on mouse move
// ✅ Isolate the frequently-changing state
function MouseTracker({ children }: { children: React.ReactNode }) {
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });
  return (
    <div onMouseMove={e => setMousePos({ x: e.clientX, y: e.clientY })}>
      <Cursor position={mousePos} />
      {children}
    </div>
  );
}

// ExpensiveChart is stable — no re-renders from mouse movement
<MouseTracker><ExpensiveChart data={data} /></MouseTracker>
```

## Lazy Loading

Code-split at the route or heavy-component level:

```tsx
import { lazy, Suspense } from 'react';

const HeavyEditor = lazy(() => import('./HeavyEditor'));
const AdminPanel = lazy(() => import('./AdminPanel'));

function App() {
  return (
    <Suspense fallback={<Skeleton />}>
      <Routes>
        <Route path="/editor" element={<HeavyEditor />} />
        <Route path="/admin" element={<AdminPanel />} />
      </Routes>
    </Suspense>
  );
}
```

**Named export**: `lazy(() => import('./charts').then(mod => ({ default: mod.BarChart })))`

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| `React.memo` on every component | Profile first, memo only measured bottlenecks |
| `useMemo` for trivial computations | Just compute inline — memo has overhead too |
| New object/array literal in props to memoized child | Hoist to `useMemo` or module scope |
| `useCallback` for handlers on native elements | Only useful when passed to `React.memo` children |
| Lazy loading tiny components (< 5KB) | Only lazy load chunks > 20KB |
