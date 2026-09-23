---
name: refresh-snapshot
description: Manually regenerates a Repomix export at `.claude/context/repomix-snapshot.md` for handing to a tool that has no filesystem access. This is NOT the harness's panoramic-context mechanism (that is the repo map, see `baseline/scripts/repo-map.sh` and `codebase-explorer`) and is never read automatically by any agent. Use only when the user explicitly asks for a single-file export, e.g. "give me a Repomix dump" or "export the codebase for tool X".
disable-model-invocation: true
---

# Refresh snapshot

Force-regenerate a Repomix export. Fast to run, but the output itself is
often too large to be useful as context on a real repo, see
`docs/decisions/0003-repo-map-over-snapshot.md` for the measurements that
led to demoting this from automatic to manual-only.

## What this is, and what it is not

- **Is:** a manual, opt-in, single-file export of the codebase's contents,
  for a tool that cannot read the filesystem directly (pasting into a chat
  UI, feeding a different agent, etc).
- **Is not:** context this harness reads. No skill or subagent auto-generates
  or auto-reads this file anymore. If you want "what exists / where does X
  live", that is the repo map (`.claude/scripts/harness/repo-map.sh`,
  `.claude/context/repo-map.md`), which is small enough to always fit and
  regenerates in under a second.

## When to invoke

- The user explicitly asks for a Repomix export, or to "refresh the snapshot"
- `disable-model-invocation` is set, so an agent never triggers this on its
  own inference alone; it only runs when the user (or a skill acting on the
  user's explicit instruction) asks for it by name

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

### 4. Run the size-budget check and report it

```bash
.claude/scripts/check-snapshot.sh
```

Report the `status` field to the user honestly. If it comes back `too-large`
(over 300,000 bytes, ~75k tokens), say so plainly, do not read the file
yourself, and point at the size in the report rather than silently
succeeding.

### 5. Report

```
Snapshot refreshed.
- Commit: <sha>
- Files captured: <count>
- Size: <size> (<status> per check-snapshot.sh - too-large means do not read it whole)
```

## What NOT to do

- Do not read this file as context for your own investigation. Use the repo map for that.
- Do not commit the snapshot file (it's in `.gitignore`)
- Do not skip the metadata header - the size/staleness check depends on it
- Do not run Repomix in a sub-directory unless you mean to snapshot only that part
- Do not present a `too-large` result as a success without the caveat
