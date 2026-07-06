# Tooling

## Steiger (Official FSD Linter)

Dedicated linting tool for FSD architecture compliance. Runs as a standalone CLI or in CI.

### Installation

```bash
npm install -D steiger @feature-sliced/steiger-plugin
```

### Configuration (steiger.config.ts)

```ts
import fsd from "@feature-sliced/steiger-plugin";

export default {
  plugins: [fsd],
};
```

### Usage

```bash
npx steiger src/      # Lint entire FSD structure
npx steiger --fix     # Auto-fix where possible
```

### Key Rules

| Rule | What It Checks |
|------|---------------|
| `forbidden-imports` | No upward or same-layer imports |
| `public-api` | Every slice has index.ts barrel |
| `segments-by-purpose` | Standard segment names used |
| `no-public-api-sidestep` | No direct internal imports |
| `no-layer-public-api` | Layers don't have barrel files (only slices do) |
| `no-segmentless-slices` | Slices must have at least one segment |
| `no-reserved-folder-names` | No `components/`, `hooks/`, `utils/` |
| `no-deprecated-layers` | Flags `processes/` usage |
| `insignificant-slice` | Flags slices with only 1 file (consider flat slice) |
| `no-cross-imports` | No same-layer slice imports (unless @x) |

### Disabling Rules

```ts
// steiger.config.ts
import fsd from "@feature-sliced/steiger-plugin";

export default {
  plugins: [fsd],
  rules: {
    "fsd/no-segmentless-slices": "off",
    "fsd/insignificant-slice": "warn",
  },
};
```

## ESLint Configuration

### Official ESLint Config

```bash
npm install -D @feature-sliced/eslint-config
```

```js
// .eslintrc.js
module.exports = {
  extends: ["@feature-sliced"],
};
```

Enforces:
- Import order (layers top → bottom)
- Public API boundary (no internal imports)
- Layer dependency direction

### Community Plugin (eslint-plugin-import-fsd)

```bash
npm install -D eslint-plugin-import-fsd
```

```js
// eslint.config.js (flat config)
import fsdPlugin from "eslint-plugin-import-fsd";

export default [
  {
    plugins: { fsd: fsdPlugin },
    rules: {
      "fsd/forbidden-imports": "error",
      "fsd/public-api": "error",
    },
  },
];
```

### Manual ESLint Setup (import/order)

If not using the official config, configure `eslint-plugin-import` manually:

```js
// .eslintrc.js
module.exports = {
  plugins: ["import"],
  rules: {
    "import/order": ["error", {
      groups: ["builtin", "external", "internal"],
      pathGroups: [
        { pattern: "@/app/**", group: "internal", position: "before" },
        { pattern: "@/pages/**", group: "internal", position: "before" },
        { pattern: "@/widgets/**", group: "internal", position: "before" },
        { pattern: "@/features/**", group: "internal", position: "before" },
        { pattern: "@/entities/**", group: "internal", position: "before" },
        { pattern: "@/shared/**", group: "internal", position: "before" },
      ],
    }],
    "import/no-cycle": "error",
  },
};
```

## FSD CLI (Scaffolding)

```bash
npm install -D @feature-sliced/cli
```

### Commands

```bash
# Create a new slice with segments
npx fsd pages home --segments ui model api
npx fsd features auth --segments ui model api lib
npx fsd entities user --segments ui model api

# Create shared segments
npx fsd shared --segments ui api lib config
```

Each command creates the folder structure and an `index.ts` barrel file.

## CI Integration

### GitHub Actions Example

```yaml
name: FSD Lint
on: [push, pull_request]
jobs:
  steiger:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npx steiger src/
```

### Circular Dependency Check

```bash
npx madge --circular --extensions ts,tsx src/
```

Add to CI to catch circular imports before merge.
