#!/usr/bin/env bash
# env-set.sh — safely upsert ONE key in a .env-style file WITHOUT ever printing
# the file's contents.
#
# Why this exists: an agent session is blocked from Read-ing .env (it holds real
# secrets), and rightly so. But it still legitimately needs to ADD or CHANGE a
# single variable (a new webhook URL, a token the human just generated). This
# helper is the narrow, auditable way to do that: it never dumps the file, it
# backs up before writing, it changes exactly one key, and it refuses to shrink
# the file.
#
# This is a BASELINE script (baseline/scripts/), symlinked like every other one
# into an adopting project as `.claude/scripts/harness/env-set.sh` — see
# baseline/scripts/README.md. It makes no assumption about which repo it runs
# in. To use it, a project adds to its OWN committed .claude/settings.json:
#
#   "allow": ["Bash(.claude/scripts/harness/env-set.sh:*)"]
#   "deny":  ["Read(.env)", "Read(.env.local)", "Read(.env.*.local)"]
#
# `Read(.env)` stays denied. The deny narrows from a blanket "Read(.env.*)" to
# just the local/secret-bearing variants, so this helper's own guarantees are
# not undercut by a glob so broad it also blocks reading a non-secret variant
# like .env.example. See ADOPTING.md for the full walkthrough. The harness
# never edits a repo's committed settings.json for you — that line is the
# adopting repo's own one-time change.
#
# The value is read from STDIN, never an argument, so a secret never lands in
# argv, shell history, or an agent transcript.
#
# Usage:
#   .claude/scripts/harness/env-set.sh <file> <KEY> <<'VALUE'
#   the-secret-value
#   VALUE
#
#   printf '%s' "$SOME_VALUE" | .claude/scripts/harness/env-set.sh <file> <KEY>
#
# Guarantees:
#   - never writes the file's contents to stdout/stderr (no cat / no echo of it)
#   - backs up to <file>.bak before any write. A backup is a second copy of
#     whatever secrets <file> holds, so this REFUSES to write one unless git
#     would actually ignore that path (untracked AND gitignore-matched) in the
#     repo <file> lives in. "<file>.bak is gitignored" is a claim about one
#     specific caller repo, not a property of this script — and this script is
#     shared across every project that links the harness, so a claim like that
#     goes stale the moment it is copied somewhere that never made it true.
#     Override with ENV_SET_ALLOW_UNIGNORED_BACKUP=1 once you have verified the
#     risk yourself (e.g. no git repo at all, or a throwaway scratch dir).
#   - upsert: replaces the single line "^KEY=" if present, else appends one line
#   - never truncates; refuses if the result would have fewer LOGICAL lines
#     than before. Counted with `awk 'END{print NR}'`, which counts a final
#     line that is missing its trailing newline as one line. `wc -l` counts
#     embedded newline characters instead, which undercounts exactly that
#     file — and an undercount on the "before" side is what would let this
#     guard be fooled into approving the very shrink it exists to catch.
#   - creates <file> if it does not exist
set -euo pipefail

file="${1:-}"
key="${2:-}"
if [ -z "$file" ] || [ -z "$key" ]; then
  echo "usage: env-set.sh <file> <KEY>   (value on stdin)" >&2
  exit 2
fi

# KEY must be a valid env var name. Guards against a key that would inject
# glob structure into the line-matching case statement below (the value has
# no such restriction — it is never used as a pattern, only ever printf'd).
case "$key" in
  [!A-Za-z_]* | *[!A-Za-z0-9_]*)
    echo "env-set: invalid key '$key' (must match [A-Za-z_][A-Za-z0-9_]*)" >&2
    exit 2
    ;;
esac

# Read the value from stdin. Command substitution strips ALL trailing
# newlines on its own, so a heredoc or `echo` never leaves a stray trailing
# blank line; the value is never printed anywhere.
value="$(cat)"

# A newline anywhere in the value would create a second, bogus line — refuse
# it. (Only an EMBEDDED newline can still be present here — command
# substitution above already removed any trailing ones.)
nl=$'\n'
case "$value" in
  *"$nl"*)
    echo "env-set: value for '$key' contains a newline; refusing" >&2
    exit 2
    ;;
esac

touch "$file"

backup="$file.bak"

# ------------------------------------------------------------- backup safety
# Refuse to write a plaintext backup of a secrets file anywhere git could pick
# it up on its own. Two ways that happens, checked independently:
#   - already TRACKED: a write here shows up as a modified tracked file no
#     matter what .gitignore says (tracking overrides ignore patterns).
#   - untracked but NOT ignored: safe today, but the next `git add -A` would
#     stage it.
# Skipped entirely when the target is not inside a git work tree, or git is
# unavailable — there is nothing to check the write against.
if command -v git >/dev/null 2>&1; then
  backup_dir="$(dirname -- "$backup")"
  backup_base="$(basename -- "$backup")"
  if git -C "$backup_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked=0
    git -C "$backup_dir" ls-files --error-unmatch -- "$backup_base" >/dev/null 2>&1 && tracked=1
    ignored=0
    git -C "$backup_dir" check-ignore -q -- "$backup_base" 2>/dev/null && ignored=1
    if [ "$tracked" -eq 1 ] || [ "$ignored" -eq 0 ]; then
      if [ "${ENV_SET_ALLOW_UNIGNORED_BACKUP:-0}" = "1" ]; then
        echo "env-set: WARNING — $backup is not gitignored (tracked=$tracked); writing anyway (ENV_SET_ALLOW_UNIGNORED_BACKUP=1)" >&2
      else
        {
          echo "env-set: refusing — $backup would not be gitignored in this repo (tracked=$tracked)."
          echo "  A backup of a secrets file must never be something 'git add -A' can pick up."
          echo "  Add a pattern such as '*.bak' or '$(basename -- "$file").bak' to .gitignore,"
          echo "  or set ENV_SET_ALLOW_UNIGNORED_BACKUP=1 once you have verified this is safe."
        } >&2
        exit 1
      fi
    fi
  fi
fi

# Count LOGICAL lines, not embedded newline characters — see the guarantees
# note above for why `wc -l` is the wrong tool for this guard.
count_lines() {
  awk 'END { print NR }' "$1"
}

before_lines=$(count_lines "$file")

cp "$file" "$backup"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
found=0

# Rewrite line by line. Every non-matching line is preserved byte-for-byte;
# the matching key's line is replaced. Nothing is printed to the terminal.
#
# The case pattern is a literal prefix match — "$key=" followed by anything —
# never a search for "$key" alone, so a key that is a prefix of another key
# cannot match the wrong line: with key=FOO, a line "FOOBAR=x" does not start
# with the four characters "FOO=", so it is left untouched. $key itself can
# only ever contain [A-Za-z0-9_] (validated above), so it carries no glob
# metacharacters into this pattern either.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "$key="*)
      printf '%s=%s\n' "$key" "$value" >> "$tmp"
      found=1
      ;;
    *)
      printf '%s\n' "$line" >> "$tmp"
      ;;
  esac
done < "$file"

if [ "$found" -eq 0 ]; then
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
fi

after_lines=$(count_lines "$tmp")

# Clobber guard: an upsert only replaces or appends, so the result can never
# have fewer logical lines than the original.
if [ "$after_lines" -lt "$before_lines" ]; then
  echo "env-set: refusing — result ($after_lines lines) smaller than original ($before_lines). Original untouched; backup at $backup" >&2
  exit 1
fi

mv "$tmp" "$file"
trap - EXIT

if [ "$found" -eq 1 ]; then
  echo "env-set: replaced $key in $file (backup: $backup)"
else
  echo "env-set: added $key to $file (backup: $backup)"
fi
