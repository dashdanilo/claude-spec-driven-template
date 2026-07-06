# State Management

Where to put state: local, shared, or server. Decision trees for choosing the right tool.

## State Categories

| Category | Examples | Tools |
|----------|----------|-------|
| **Local** | Form input, toggle, animation | `useState`, `useReducer` |
| **Shared** | Theme, auth, locale, sidebar open | Context, Zustand, Jotai |
| **Server** | API responses, paginated lists | TanStack Query, SWR |
| **URL** | Filters, pagination, search query | React Router `useSearchParams` |

**Rule**: Start local. Promote to shared only when a sibling or distant component needs it.

## Local State

### useState vs useReducer

| Use `useState` | Use `useReducer` |
|---------------|-----------------|
| 1-2 independent values | 3+ related values |
| Simple toggle/counter | State machine (idle → loading → success/error) |
| Next state independent of previous | Next state depends on previous + action type |

### Derived State

Never store what you can compute:

```tsx
// ❌ Syncing derived state with useEffect
const [items, setItems] = useState<Item[]>([]);
const [filteredItems, setFilteredItems] = useState<Item[]>([]);
useEffect(() => setFilteredItems(items.filter(i => i.active)), [items]);

// ✅ Compute during render
const [items, setItems] = useState<Item[]>([]);
const filteredItems = useMemo(() => items.filter(i => i.active), [items]);
```

### State Colocation

Keep state as close to where it's used as possible:

```
Component needs it alone → useState in that component
Two siblings need it → lift to parent
Distant components need it → Context or external store
```

## Context (Low-Frequency Shared State)

Best for state that changes infrequently: theme, locale, auth, feature flags.

```tsx
interface AuthContextValue {
  user: User | null;
  login: (credentials: Credentials) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}

function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);

  const value = useMemo<AuthContextValue>(() => ({
    user,
    login: async (creds) => { const u = await api.login(creds); setUser(u); },
    logout: () => { setUser(null); api.logout(); },
  }), [user]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
```

**Performance rule**: Wrap context value in `useMemo`. Every consumer re-renders when the value reference changes.

### Split Contexts by Update Frequency

```tsx
// ❌ One context for everything — all consumers re-render on any change
const AppContext = createContext({ user, theme, locale, notifications });

// ✅ Separate by frequency
const AuthContext = createContext(/* user, login, logout */);    // rare changes
const ThemeContext = createContext(/* theme, toggleTheme */);     // rare changes
const NotificationContext = createContext(/* notifications */);   // frequent changes
```

## Zustand (High-Frequency Shared State)

When Context re-renders too much, or you need subscriptions to slices of state:

```tsx
import { create } from 'zustand';

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  total: () => number;
}

const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  addItem: (item) => set(state => ({ items: [...state.items, item] })),
  removeItem: (id) => set(state => ({ items: state.items.filter(i => i.id !== id) })),
  total: () => get().items.reduce((sum, i) => sum + i.price * i.quantity, 0),
}));
```

### Zustand Patterns

**Slices** (for larger stores):

```tsx
const createCartSlice = (set: SetState, get: GetState) => ({
  items: [],
  addItem: (item: CartItem) => set(state => ({ items: [...state.items, item] })),
});

const createUserSlice = (set: SetState, get: GetState) => ({
  user: null,
  setUser: (user: User) => set({ user }),
});

const useStore = create((...a) => ({
  ...createCartSlice(...a),
  ...createUserSlice(...a),
}));
```

## TanStack Query (Server State)

Server data is NOT your state — it's a cache. Use TanStack Query for fetching, caching, and synchronization:

```tsx
function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => api.getUser(id),
    staleTime: 5 * 60 * 1000, // 5 min
  });
}

function useUpdateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: api.updateUser,
    onSuccess: (data) => {
      queryClient.setQueryData(['user', data.id], data);    // optimistic
      queryClient.invalidateQueries({ queryKey: ['users'] }); // refetch list
    },
  });
}
```

## Decision Tree

```
Is it from an API/server?
  → TanStack Query (never put server data in Zustand/Context)

Is it URL state (filters, pagination, search)?
  → useSearchParams from React Router

Does only ONE component use it?
  → useState / useReducer (local)

Do 2-3 nearby components need it?
  → Lift state to closest common parent

Do distant components need it AND it changes rarely?
  → Context + useMemo

Do distant components need it AND it changes often?
  → Zustand (selector-based subscriptions)

Is it a complex state machine (multi-step wizard, media player)?
  → useReducer (local) or XState (if truly complex)
```

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Server data in Redux/Zustand | TanStack Query — server state is a cache, not app state |
| Context for high-frequency updates | Zustand with selectors |
| One giant global store | Split by domain (auth, cart, ui) |
| `useEffect` to sync derived state | Compute with `useMemo` during render |
