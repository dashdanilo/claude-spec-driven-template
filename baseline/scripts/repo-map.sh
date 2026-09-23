#!/usr/bin/env bash
# repo-map.sh
# Generates a small, deterministic map of the repo's shape: directory tree
# with per-directory file counts, entry points, where tests live, and the
# commands block lifted from AGENTS.md.
#
# Unlike a Repomix snapshot (a packed copy of every file's *contents*), this
# grows with directory count, not file content — it stays in the low
# thousands of tokens on repos where the snapshot is several megabytes.
# Deterministic and cheap: no npx, no network, a handful of `git`/`find`
# calls. See docs/decisions/0003-repo-map-over-snapshot.md for why this
# replaced the snapshot as the panoramic-context artifact.
#
# File universe comes from `git ls-files` (tracked + untracked-but-not-
# ignored), so node_modules/, dist/, .git/ etc are excluded automatically —
# same exclusion the repo already maintains in .gitignore, no second list to
# keep in sync.
#
#   .claude/scripts/harness/repo-map.sh                  # print to stdout
#   .claude/scripts/harness/repo-map.sh --output PATH     # write to PATH
#   .claude/scripts/harness/repo-map.sh --max-depth 4     # default 3
#
# Exit codes:
#   0 - success
#   3 - not a git repository

set -uo pipefail

OUTPUT=""
MAX_DEPTH=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --max-depth)
      MAX_DEPTH="${2:-3}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 3
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 3

# Tracked + untracked-but-not-ignored files. This is the file universe for
# everything below, so anything .gitignore already excludes (node_modules,
# dist, build artifacts) is excluded here for free.
FILES_FILE="$(mktemp)"
trap 'rm -f "$FILES_FILE"' EXIT
git ls-files --cached --others --exclude-standard > "$FILES_FILE"
total_files=$(wc -l < "$FILES_FILE" | tr -d ' ')

current_commit=$(git rev-parse HEAD 2>/dev/null || echo "no-commits-yet")
current_branch=$(git branch --show-current 2>/dev/null || echo "")
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ------------------------------------------------------------- directory tree
# Aggregate file counts per directory up to MAX_DEPTH. Leaf files at depth 0
# (repo root) are listed individually; directories are listed once with a
# count, never their individual files, so this stays flat regardless of how
# many files live inside.
tree_section=$(python3 - "$FILES_FILE" "$MAX_DEPTH" <<'PY'
import sys, collections

files_path, max_depth = sys.argv[1], int(sys.argv[2])
with open(files_path) as f:
    paths = [line.rstrip("\n") for line in f if line.strip()]

counts = collections.Counter()
root_files = []
for p in paths:
    parts = p.split("/")
    if len(parts) == 1:
        root_files.append(p)
        continue
    limit = min(len(parts) - 1, max_depth)
    # Bubble the file up to every ancestor prefix, not just the deepest one
    # truncation reaches, so an intermediate directory (e.g. "skills/" when
    # every file lives two levels deeper, in "skills/<name>/SKILL.md") still
    # shows up with its own recursive count instead of vanishing from the tree.
    for d in range(1, limit + 1):
        prefix = "/".join(parts[:d])
        counts[prefix] += 1

lines = []
for f in sorted(root_files):
    lines.append(f"{f}")

for d in sorted(counts):
    depth = d.count("/")
    indent = "  " * depth
    name = d.split("/")[-1]
    lines.append(f"{indent}{name}/ ({counts[d]})")

print("\n".join(lines) if lines else "(no tracked files)")
PY
)

# ------------------------------------------------------------- entry points
# Deliberately excludes barrel `index.*` files - in a repo with one module per
# feature folder (the common case), every module has one and the list would
# be all noise and no signal. Bootstrap files only.
entry_points=$(grep -E '(^|/)(main|app|server|wsgi|asgi)\.(ts|tsx|js|jsx|py|go|rb)$|(^|/)manage\.py$|(^|/)Cargo\.toml$|(^|/)go\.mod$' "$FILES_FILE" | sort | head -20)
[[ -z "$entry_points" ]] && entry_points="(none matched the common patterns; check package.json main/bin, or the framework's own bootstrap convention)"

# ------------------------------------------------------------- test locations
# "specs/" (plural) is deliberately excluded: in this template's own
# ecosystem it is the spec-driven feature-spec folder (spec.md/plan.md/
# tasks.md), not test code. RSpec's convention is the singular "spec/",
# which is still matched.
test_dirs=$(grep -E '(^|/)(test|tests|__tests__|spec)/|\.(test|spec)\.[a-z]+$' "$FILES_FILE" \
  | sed -E 's#/[^/]+$##' \
  | sort | uniq -c | sort -rn | head -15 \
  | awk '{count=$1; $1=""; print $0" ("count")"}' \
  | sed 's/^ //')
[[ -z "$test_dirs" ]] && test_dirs="(none found by the *test*/*.test.* / *.spec.* heuristic)"

# ------------------------------------------------------------- commands from AGENTS.md
commands_block=""
if [[ -f AGENTS.md ]]; then
  commands_block=$(awk '
    /^##.*[Bb]uild|^##.*[Cc]ommand|^##.*[Tt]est.*[Ll]int|^##.*[Ss]cripts/ { infence=0; found=1; next }
    found && /^```/ { infence = !infence; if (infence) { next } else { exit } }
    found && infence { print }
  ' AGENTS.md)
fi
[[ -z "$commands_block" ]] && commands_block="(no fenced command block found under a Build/Test/Lint heading in AGENTS.md; read AGENTS.md directly)"

# ------------------------------------------------------------------- assemble
body=$(cat <<EOF
# Repo map

generated_at: $current_date
commit_sha: $current_commit
branch: $current_branch
tracked_files: $total_files
max_depth: $MAX_DEPTH

This is a deterministic map, not a copy of file contents. It regenerates in
under a second and never goes stale in a way worth warning about — re-run it
instead of trusting an old copy. For anything beyond "where does this live",
Grep/Glob/Read the files directly.

## Directory tree (depth $MAX_DEPTH, file counts per directory)

\`\`\`
$tree_section
\`\`\`

## Entry points

\`\`\`
$entry_points
\`\`\`

## Where tests live

\`\`\`
$test_dirs
\`\`\`

## Commands (from AGENTS.md)

\`\`\`
$commands_block
\`\`\`
EOF
)

if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$(dirname "$OUTPUT")"
  printf '%s\n' "$body" > "$OUTPUT"
  echo "Repo map written to $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes, $total_files tracked files)" >&2
else
  printf '%s\n' "$body"
fi

exit 0
