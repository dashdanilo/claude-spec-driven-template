---
name: refresh-snapshot
description: Manually regenerates the Repomix snapshot at `.claude/context/repomix-snapshot.md`. Use when the user asks to "refresh the snapshot", when they know the codebase changed significantly, or before starting a session that will need broad codebase context. The codebase-explorer subagent also refreshes automatically when the snapshot is stale-major, so most of the time you do not need to invoke this manually.
---

# Refresh snapshot

Force-regenerate the Repomix snapshot. Fast, deterministic, no analysis.

## When to invoke

- User explicitly asks
- Before an important session that will need panoramic codebase context
- After a big refactor or merge where you know convention shifts happened

If you find yourself invoking this often, that's a signal the staleness thresholds in `.claude/context/config.json` might need tuning.

## Steps

### 1. Check that Repomix is available

```bash
if ! command -v npx > /dev/null 2>&1; then
  echo "npx not found. Install Node.js 20+ first."
  exit 1
fi
# Repomix v1.16+ requires Node 20. Node 18 passes the npx check but produces an empty snapshot.
node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null)
if [ "${node_major:-0}" -lt 20 ]; then
  echo "Node ${node_major} detected. Repomix needs Node 20+ (older Node yields an empty snapshot)."
  exit 1
fi
```

### 2. Generate the raw snapshot

```bash
npx repomix --output .claude/context/repomix-snapshot.md.tmp
```

If the project has a `.repomixignore` or `repomix.config.json`, Repomix respects it. Consider adding one if the output is too large.

### 3. Prepend metadata header

```bash
current_commit=$(git rev-parse HEAD)
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
current_branch=$(git branch --show-current)
files_count=$(grep -c "^## File:" .claude/context/repomix-snapshot.md.tmp || echo "?")

cat > .claude/context/repomix-snapshot.md <<EOF
# Repomix snapshot

generated_at: $current_date
commit_sha: $current_commit
branch: $current_branch
files_captured: $files_count

---

EOF
cat .claude/context/repomix-snapshot.md.tmp >> .claude/context/repomix-snapshot.md
rm .claude/context/repomix-snapshot.md.tmp
```

### 4. Report

```
Snapshot refreshed.
- Commit: <sha>
- Files captured: <count>
- Size: <size>
```

## What NOT to do

- Do not commit the snapshot file (it's in `.gitignore`)
- Do not skip the metadata header - the staleness check depends on it
- Do not run Repomix in a sub-directory unless you mean to snapshot only that part
