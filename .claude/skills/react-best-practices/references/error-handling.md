# Error Handling

Patterns for catching, displaying, and recovering from runtime errors in React.

## Error Boundaries

The ONLY React pattern that requires a class component. Catch render-time errors in the subtree:

```tsx
import { Component, type ErrorInfo, type ReactNode } from 'react';

interface ErrorBoundaryProps {
  fallback: ReactNode | ((error: Error, reset: () => void) => ReactNode);
  onError?: (error: Error, info: ErrorInfo) => void;
  children: ReactNode;
}

interface ErrorBoundaryState {
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.props.onError?.(error, info);
  }

  reset = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      const { fallback } = this.props;
      return typeof fallback === 'function'
        ? fallback(this.state.error, this.reset)
        : fallback;
    }
    return this.props.children;
  }
}
```

### Hook-Friendly Interface

Wrap the class in a hook-based API for consumers:

```tsx
function useErrorBoundary() {
  const [error, setError] = useState<Error | null>(null);

  if (error) throw error; // triggers nearest ErrorBoundary

  return {
    showError: setError,
    handleAsync: async <T,>(promise: Promise<T>): Promise<T | undefined> => {
      try {
        return await promise;
      } catch (err) {
        setError(err instanceof Error ? err : new Error(String(err)));
        return undefined;
      }
    },
  };
}

// Usage in component
function SaveButton() {
  const { handleAsync } = useErrorBoundary();

  const handleSave = async () => {
    await handleAsync(api.save(data)); // error caught by boundary
  };

  return <button onClick={handleSave}>Save</button>;
}
```

## Placement Strategy

```tsx
function App() {
  return (
    // Top-level: catches fatal errors, shows full-page fallback
    <ErrorBoundary fallback={<FatalError />} onError={reportToSentry}>
      <Layout>
        {/* Feature-level: isolates widget failures */}
        <ErrorBoundary fallback={(error, reset) => <WidgetError error={error} onRetry={reset} />}>
          <Dashboard />
        </ErrorBoundary>

        {/* Non-critical: gracefully degrades */}
        <ErrorBoundary fallback={null}>
          <Recommendations />
        </ErrorBoundary>
      </Layout>
    </ErrorBoundary>
  );
}
```

**Granularity rules:**
- **App root**: Always. Full-page fallback with "reload" button.
- **Per route/page**: Prevent one broken page from crashing the app.
- **Per widget**: Dashboard cards, sidebars — fail independently.
- **Never per-component**: Too granular. Components should not catch their own errors.

## Async Error Handling

Error boundaries only catch render errors. Handle async errors explicitly:

```tsx
function useAsyncAction<T>(action: () => Promise<T>) {
  const [state, setState] = useState<{
    status: 'idle' | 'loading' | 'success' | 'error'; data?: T; error?: Error;
  }>({ status: 'idle' });

  const execute = useCallback(async () => {
    setState({ status: 'loading' });
    try {
      const data = await action();
      setState({ status: 'success', data });
    } catch (err) {
      setState({ status: 'error', error: err instanceof Error ? err : new Error(String(err)) });
    }
  }, [action]);

  return { ...state, execute, reset: useCallback(() => setState({ status: 'idle' }), []) };
}
```

### AsyncBoundary — Combine Suspense + Error Boundary

```tsx
function AsyncBoundary({ children, pendingFallback, errorFallback }: {
  children: ReactNode;
  pendingFallback: ReactNode;
  errorFallback: ReactNode | ((error: Error, reset: () => void) => ReactNode);
}) {
  return (
    <ErrorBoundary fallback={errorFallback}>
      <Suspense fallback={pendingFallback}>
        {children}
      </Suspense>
    </ErrorBoundary>
  );
}

// Usage
<AsyncBoundary
  pendingFallback={<Skeleton />}
  errorFallback={(error, retry) => <ErrorCard error={error} onRetry={retry} />}
>
  <UserProfile />
</AsyncBoundary>
```

## Fallback UI Patterns

### Retry

```tsx
function RetryFallback({ error, onRetry }: { error: Error; onRetry: () => void }) {
  return (
    <div role="alert">
      <p>Something went wrong: {error.message}</p>
      <button onClick={onRetry}>Try again</button>
    </div>
  );
}
```

### Degraded Content — Show partial UI when non-critical data fails:

```tsx
<div>
  <ProductInfo product={product} />
  <ErrorBoundary fallback={<p>Reviews unavailable</p>}>
    <ReviewsSection productId={product.id} />
  </ErrorBoundary>
</div>
```

### Staged Recovery

Track retry count in fallback. After N failures, show escalated message (contact support, reload page). Reset retry count on successful recovery.

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| `try/catch` in render body | Use Error Boundary — render errors need component lifecycle |
| Error boundary around every component | Boundary per feature/route, not per component |
| Swallowing errors silently | Always log/report + show user feedback |
| Generic "Something went wrong" everywhere | Context-specific messages with recovery actions |
| No top-level boundary | App root MUST have an Error Boundary |
