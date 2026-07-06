# Testing Patterns in FSD

## Test Placement by Layer

| Layer | Test Type | What to Test | Placement |
|-------|-----------|-------------|-----------|
| **shared** | Unit | Pure functions, formatters, validators | Next to source file |
| **entities** | Unit + Snapshot | Props contract, rendering, selectors | Next to source file |
| **features** | Integration | User interactions, mutations, side-effects | Slice-level `__tests__/` |
| **widgets** | Integration | Composition of features + entities | Slice-level `__tests__/` |
| **pages** | E2E | Full user flows, route transitions | `tests/` or `e2e/` outside `src/` |
| **app** | E2E | Provider setup, routing, global behavior | `tests/` or `e2e/` outside `src/` |

## Testing Pyramid

```
           ┌───────────┐
           │    E2E    │  ← Pages: critical user journeys only
           └─────┬─────┘
          ┌──────┴──────┐
          │ Integration │  ← Features/Widgets: interaction tests
          └──────┬──────┘
        ┌────────┴────────┐
        │      Unit       │  ← Entities/Shared: snapshots, pure logic
        └─────────────────┘
```

## File Placement Strategy

### Colocated Tests (default)

Place test files next to the source they test:

```
entities/
  user/
    model/
      store.ts
      store.test.ts        ← unit test
    ui/
      UserCard.tsx
      UserCard.test.tsx     ← snapshot/render test
    api/
      queries.ts
      queries.test.ts      ← API mock test
    index.ts
```

### Integration Tests at Slice Boundary

Test the slice through its **public API** (`index.ts`), not internal modules:

```
features/
  auth/
    ui/
    model/
    api/
    __tests__/
      login-flow.test.tsx    ← integration: test the full login feature
    index.ts
```

### E2E Tests Outside `src/`

```
project-root/
├── src/                     ← FSD structure
├── e2e/                     ← E2E tests (Playwright/Cypress)
│   ├── auth.spec.ts
│   ├── checkout.spec.ts
│   └── fixtures/
└── vitest.config.ts
```

## What to Test at Each Layer

### shared/

```ts
// shared/lib/formatDate.test.ts
import { formatDate } from "./formatDate";

test("formats ISO date to readable string", () => {
  expect(formatDate("2024-01-15")).toBe("Jan 15, 2024");
});
```

Test pure functions, edge cases, error handling. No mocking needed.

### entities/

```tsx
// entities/user/ui/UserCard.test.tsx
import { render, screen } from "@testing-library/react";
import { UserCard } from "./UserCard";

test("renders user name and avatar", () => {
  render(<UserCard name="John" avatarUrl="/john.jpg" />);
  expect(screen.getByText("John")).toBeInTheDocument();
  expect(screen.getByRole("img")).toHaveAttribute("src", "/john.jpg");
});
```

Test props contract: given specific props, verify correct rendering. Entity components are pure — same input, same output.

### features/

```tsx
// features/auth/__tests__/login-flow.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LoginForm } from "../index";

test("submits login form with valid credentials", async () => {
  const onSubmit = vi.fn();
  render(<LoginForm onSubmit={onSubmit} />);

  await userEvent.type(screen.getByLabelText("Email"), "test@example.com");
  await userEvent.type(screen.getByLabelText("Password"), "password123");
  await userEvent.click(screen.getByRole("button", { name: "Login" }));

  expect(onSubmit).toHaveBeenCalledWith({
    email: "test@example.com",
    password: "password123",
  });
});

test("shows validation error for invalid email", async () => {
  render(<LoginForm onSubmit={vi.fn()} />);
  await userEvent.type(screen.getByLabelText("Email"), "not-an-email");
  await userEvent.click(screen.getByRole("button", { name: "Login" }));
  expect(screen.getByText(/invalid email/i)).toBeInTheDocument();
});
```

Test interactions: user actions, form validation, API calls (mocked), state changes.

## Key Principle: Test the Public API

> Don't test internal segment structure — test the slice through its public API.

```ts
// ✅ Import from public API
import { LoginForm, useAuth } from "features/auth";

// ❌ Import from internals
import { LoginForm } from "features/auth/ui/LoginForm";
import { useAuth } from "features/auth/model/useAuth";
```

This ensures tests survive internal refactors (moving files between segments).

## Mocking Strategy

| What to Mock | How | Why |
|-------------|-----|-----|
| API calls | MSW (Mock Service Worker) | Realistic network layer |
| Lower-layer slices | Mock the public API barrel | Slice isolation |
| Stores (Zustand/Redux) | Provide test store | Controlled state |
| Router | `MemoryRouter` wrapper | Route testing |

### MSW Example for Feature Tests

```ts
// features/auth/__tests__/handlers.ts
import { http, HttpResponse } from "msw";

export const handlers = [
  http.post("/api/login", async ({ request }) => {
    const body = await request.json();
    if (body.email === "test@example.com") {
      return HttpResponse.json({ token: "fake-jwt" });
    }
    return HttpResponse.json({ error: "Invalid" }, { status: 401 });
  }),
];
```

## CI Configuration

```yaml
# .github/workflows/test.yml
jobs:
  test:
    steps:
      - run: npx vitest run --reporter=verbose
      - run: npx playwright test  # E2E
```

Run unit + integration tests on every PR. Run E2E on merge to main.
