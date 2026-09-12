#!/usr/bin/env bash
# protect-main.sh
# PreToolUse hook for Bash. Blocks commits, pushes, and force operations
# against the main/master branch of the repository EACH git invocation in a
# command actually targets. A command can invoke git more than once
# (multi-line, `&&`-chained, or interspersed with `cd`), and each invocation
# is resolved and checked independently: its own `git -C <path>` if present,
# otherwise the most recent literal `cd <path>` seen before it while walking
# the command in order, otherwise the hook's own cwd. The command is blocked
# if ANY of its git invocations is a dangerous operation against a protected
# branch — a later invocation targeting a different, unprotected repo does
# not clear an earlier one, and a leading read-only invocation on a protected
# repo does not implicate a later invocation elsewhere.
#
# Two defects fixed after being reproduced, both from evaluating the command
# as one flat blob instead of per invocation:
#   - single running target, whole-command match: earlier versions resolved
#     ONE target directory for the whole command (from the first git, or the
#     last cd before it) and matched the dangerous patterns against the
#     ENTIRE command text. A multi-line command whose first git was a
#     read-only query against a protected repo, followed by a real push to an
#     unrelated feature worktree, was blocked for no reason it deserved
#     (false positive); the mirror case — a read-only first git against a
#     feature worktree followed by a push to a protected repo later in the
#     same command — passed uninspected (false negative, the worse
#     direction, since it is the one that lets damage through). Fixed by
#     walking the normalized lines in order, maintaining a running current
#     directory that only a literal `cd` updates, and resolving + checking
#     each git invocation against its own target as it is encountered, so a
#     later invocation can neither clear nor inherit an earlier one's risk.
#   - unanchored patterns: `git\s+merge` (and the other five) matched as a
#     substring anywhere in the line, so `git merge-base --is-ancestor A B`
#     — a read-only query used to check ancestry, not to merge anything —
#     tripped the same pattern as `git merge <sha>`. Every pattern now
#     requires a word boundary right after the subcommand
#     (`git\s+merge(\s|$)`), so a suffixed subcommand like `merge-base` no
#     longer matches while `git merge <sha>` still does.
#
# Accepted gap: when a cd target is not a literal path — built from a
# variable, command substitution, or a glob, e.g. `W=<path>` then `cd $W` —
# this hook does not expand it (expanding input taken from the command being
# inspected is how you create the accidental execution this hook exists to
# prevent). It resets the running current directory to the hook's own cwd
# instead — the same fallback used before any cd has been seen at all — so a
# git invocation that follows an unresolvable cd is checked against wherever
# the hook itself is standing, not the real target. `cd $VAR && git commit`
# against a repo on `main`, run from a cwd on a feature branch, passes
# undetected; the same construct run from a cwd already on `main` is
# (correctly, if conservatively) blocked. An earlier version treated every
# unresolvable cd as protected unconditionally instead; that blocked
# legitimate work — a commit in a feature-branch worktree reached through
# `W=<path>` then `cd $W`, and separately a test script that never ran git at
# all, because the pattern check matched text and the script's JSON payload
# happened to contain the string `cd $S/repo-main && git commit` as data, not
# a command. A guard with that false-positive rate gets disabled by its own
# users, which protects nothing. Anyone who needs the guard to hold through a
# variable cd can make the target resolvable: write the literal path, or use
# `git -C <path>`.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher "Bash".
#
# It also blocks `gh pr merge --admin`, anywhere, on any branch. That flag
# bypasses branch protection, which removes exactly the review that catches an
# unreviewed commit riding into a PR under someone else's title. Measured: it
# happened once, and the cost was paid by the repo, not by the agent that did it.
#
# Rationale: agents can accidentally commit directly to main. This is the classic
# "I forgot to create a feature branch" mistake. A cheap hook prevents it.

set -euo pipefail

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the command with python3, falling back to `python` (some Windows
# shells only have `python` on PATH, where `python3` is missing or a broken
# alias). If neither is available, this guard cannot read the payload at all
# — warn loudly on stderr and let the command through rather than blocking
# every single Bash call on this machine, which is the failure that gets a
# guard disabled outright instead of fixed (see the false-positive note
# above).
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: protect-main.sh: no python3 or python on PATH — cannot read the tool payload, so this guard is DISABLED for this call. Install Python to restore it." >&2
  exit 0
fi

# Extract the command from JSON
command=$(printf '%s' "$input" | "$PYTHON_BIN" -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('command') or ti.get('command') or '')" 2>/dev/null || echo "")

# --- gh pr merge --admin: blocked everywhere, on any branch -------------------
# Bypassing branch protection is never something to do on someone else's behalf.
# If protection is genuinely in the way, that is a decision for a human.
# Only at a COMMAND POSITION - start of a line, or after ; && || | - because
# matching anywhere fires on the words appearing inside a heredoc or a commit
# message, which is someone documenting the command, not running it. That
# false positive blocked the very commit that introduced this guard.
if echo "$command" | grep -qE '(^|[;&|])[[:space:]]*gh[[:space:]]+pr[[:space:]]+merge' \
   && echo "$command" | grep -qE '(^|[[:space:]])--admin([[:space:]]|$)'; then
  {
    echo "BLOCKED by protect-main.sh: 'gh pr merge --admin' bypasses branch protection."
    echo ""
    echo "That flag removes the review that catches an unreviewed commit riding into"
    echo "a PR under another change's title — which is how it has already gone wrong."
    echo ""
    echo "Check what the PR actually contains first:"
    echo "  gh pr view <n> --json files --jq '.files[].path'"
    echo ""
    echo "If the protection is genuinely in the way, say so and let a human decide."
  } >&2
  exit 2
fi

# --- walk the command one git invocation at a time ----------------------------
# This is a heuristic, not a shell parser: it does not understand quoting, so a
# ';' or '&&' inside a quoted string (e.g. a commit message) could misfire a
# split. A cd target the heuristic can't resolve with confidence (a variable,
# command substitution, or glob) resets the running directory to the hook's
# own cwd — see the accepted-gap note at the top of this file.

_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

_resolve_path() {
  local p="$1"
  case "$p" in
    \"*\") p="${p#\"}"; p="${p%\"}" ;;
    \'*\') p="${p#\'}"; p="${p%\'}" ;;
  esac
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="${HOME}/${p#"~/"}" ;;
  esac
  case "$p" in
    /*) : ;;
    *) p="$(pwd)/$p" ;;
  esac
  printf '%s' "$p"
}

# A cd argument built from a variable, command substitution, or a glob
# (e.g. `W=<path>` then `cd $W`, common in agent-issued commands) is not a
# literal path, and this hook does not expand it to find out what it
# resolves to.
_is_unresolvable_cd_target() {
  local s="$1"
  case "$s" in
    \"*\") s="${s#\"}"; s="${s%\"}" ;;
    \'*\') s="${s#\'}"; s="${s%\'}" ;;
  esac
  case "$s" in
    *'$'*|*'`'*|*'*'*|*'?'*) return 0 ;;
    *) return 1 ;;
  esac
}

# Split into one "atomic" command per line at command-position separators, so
# 'cd x && git y' and 'cd x\ngit y' are walked the same way. Order matters:
# && / || must be split before the single & / | they contain, or a stray & or
# | would be left behind. Deliberately pure-bash (no sed \n trick), which
# behaves differently between GNU and BSD sed.
_normalized="${command//&&/$'\n'}"
_normalized="${_normalized//||/$'\n'}"
_normalized="${_normalized//;/$'\n'}"
_normalized="${_normalized//|/$'\n'}"
_normalized="${_normalized//&/$'\n'}"

# Protected branches
protected_branches="main master trunk develop production release"

# Patterns that are dangerous on a protected branch. Anchored with a word
# boundary right after the subcommand so a suffixed subcommand (`merge-base`,
# a read-only ancestry query) cannot match the same pattern as the real
# subcommand (`merge`) — see defect note at the top of this file.
dangerous_patterns=(
  'git\s+commit(\s|$)'
  'git\s+push(\s|$)'
  'git\s+merge(\s|$)'
  'git\s+rebase(\s|$)'
  'git\s+reset\s+--hard(\s|$)'
  'git\s+cherry-pick(\s|$)'
)

current_dir="$(pwd)"
git_found=0
blocked=0
blocked_branch=""

while IFS= read -r _line; do
  _t=$(_trim "$_line")
  [[ -z "$_t" ]] && continue

  if [[ "$_t" =~ ^cd[[:space:]]+(.+)$ ]]; then
    _cd_target="${BASH_REMATCH[1]}"
    if _is_unresolvable_cd_target "$_cd_target"; then
      current_dir="$(pwd)"
    else
      current_dir=$(_resolve_path "$_cd_target")
    fi
    continue
  fi

  if [[ "$_t" =~ ^git([[:space:]]|$) ]]; then
    git_found=1
    git_line="$_t"

    # explicit_dir: this invocation's own `-C <path>`, stripped from the line
    # so the dangerous-pattern check below sees a plain 'git commit ...'
    # shape either way.
    explicit_dir=""
    git_line_normalized="$git_line"
    if [[ "$git_line" =~ ^git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]*(.*)$ ]]; then
      explicit_dir="${BASH_REMATCH[1]}"
      git_line_normalized="git ${BASH_REMATCH[2]}"
    fi

    # Precedence for THIS invocation: its own `git -C <path>` first, then the
    # running current directory (the last literal `cd` seen, or the hook's
    # own cwd if none has been seen yet).
    if [[ -n "$explicit_dir" ]]; then
      target_dir=$(_resolve_path "$explicit_dir")
    else
      target_dir="$current_dir"
    fi

    if [[ ! -d "$target_dir" ]]; then
      # A literal, resolvable path that plainly does not exist: nothing to
      # protect there for THIS invocation. Skip it and keep walking, rather
      # than aborting the whole check — a later invocation may still target
      # something real.
      continue
    fi

    # Determine this invocation's branch (silent, don't fail if not a repo)
    inv_branch=$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [[ -z "$inv_branch" ]]; then
      # Not a git repo, or detached HEAD: nothing to protect there. Skip.
      continue
    fi

    inv_is_protected="false"
    for b in $protected_branches; do
      if [[ "$inv_branch" == "$b" ]]; then
        inv_is_protected="true"
        break
      fi
    done

    if [[ "$inv_is_protected" != "true" ]]; then
      continue
    fi

    for pattern in "${dangerous_patterns[@]}"; do
      if echo "$git_line_normalized" | grep -qE "$pattern"; then
        blocked=1
        blocked_branch="$inv_branch"
        break
      fi
    done

    if [[ "$blocked" -eq 1 ]]; then
      break
    fi
  fi
done <<< "$_normalized"

# Only inspect commands that actually invoke git at a command position.
if [[ "$git_found" -eq 0 ]]; then
  exit 0
fi

if [[ "$blocked" -eq 1 ]]; then
  echo "BLOCKED by protect-main.sh: dangerous git operation on protected branch '$blocked_branch'" >&2
  echo "" >&2
  echo "Create a feature branch first:" >&2
  echo "  git switch -c feature/<slug>" >&2
  echo "" >&2
  echo "Then repeat the operation." >&2
  echo "" >&2
  echo "Protected branches: $protected_branches" >&2
  exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
fi

exit 0
