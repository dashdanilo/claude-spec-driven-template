#!/usr/bin/env bash
# protect-main.sh
# PreToolUse hook for Bash. Blocks commits, pushes, and force operations
# against the main/master branch of the repository the command actually
# targets — resolved from an explicit `git -C <path>`, or the last `cd <path>`
# before the first `git` invocation in command position, falling back to the
# hook's own cwd only when neither is present. Earlier versions always read
# the branch of the hook's cwd, which both false-positived (blocked a commit
# on another repo's feature branch, because the hook's own cwd happened to be
# on `main`) and false-negatived (`cd <repo-on-main> && git commit` never
# matched the "is this a git command" gate at all, since it only looked at
# the start of the line).
#
# Accepted gap: when the cd target is not a literal path — built from a
# variable, command substitution, or a glob, e.g. `W=<path>` then `cd $W` —
# this hook does not expand it (expanding input taken from the command being
# inspected is how you create the accidental execution this hook exists to
# prevent). It falls back to the branch of the hook's own cwd instead, so
# `cd $VAR && git commit` against a repo on `main`, run from a cwd on a
# feature branch, passes undetected. An earlier version treated every
# unresolvable cd as protected unconditionally instead; that blocked
# legitimate work — a commit in a feature-branch worktree reached through
# `W=<path>` then `cd $W`, and separately a test script that never ran git at
# all, because the pattern check below matches text and the script's JSON
# payload happened to contain the string `cd $S/repo-main && git commit` as
# data, not a command. A guard with that false-positive rate gets disabled by
# its own users, which protects nothing. Anyone who needs the guard to hold
# through a variable cd can make the target resolvable: write the literal
# path, or use `git -C <path>`.
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

# Extract the command from JSON
command=$(printf '%s' "$input" | python3 -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('command') or ti.get('command') or '')" 2>/dev/null || echo "")

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

# --- locate the git invocation and the directory it targets ------------------
# This is a heuristic, not a shell parser: it does not understand quoting, so a
# ';' or '&&' inside a quoted string (e.g. a commit message) could misfire a
# split. A cd target the heuristic can't resolve with confidence (a variable,
# command substitution, or glob) falls back to the hook's own cwd and its
# branch, same as when there is no cd at all — see the accepted-gap note at
# the top of this file.

_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
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

git_line=""
git_line_found=0
cd_target=""

while IFS= read -r _line; do
  _t=$(_trim "$_line")
  [[ -z "$_t" ]] && continue
  if [[ "$git_line_found" -eq 0 ]]; then
    if [[ "$_t" =~ ^git([[:space:]]|$) ]]; then
      git_line="$_t"
      git_line_found=1
    elif [[ "$_t" =~ ^cd[[:space:]]+(.+)$ ]]; then
      cd_target="${BASH_REMATCH[1]}"
    fi
  fi
done <<< "$_normalized"

# Only inspect commands that actually invoke git at a command position.
if [[ "$git_line_found" -eq 0 ]]; then
  exit 0
fi

# git_line_normalized: git_line with a leading '-C <path>' stripped, so the
# dangerous-pattern check below (git\s+commit, etc) still matches
# 'git -C <path> commit' the same way it matches 'git commit'.
explicit_dir=""
git_line_normalized="$git_line"
if [[ "$git_line" =~ ^git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]*(.*)$ ]]; then
  explicit_dir="${BASH_REMATCH[1]}"
  git_line_normalized="git ${BASH_REMATCH[2]}"
fi

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

# Precedence: explicit `git -C <path>` first, then the last `cd <path>` seen
# before the first git invocation, then the hook's own cwd.
if [[ -n "$explicit_dir" ]]; then
  target_dir=$(_resolve_path "$explicit_dir")
elif [[ -n "$cd_target" ]]; then
  # A cd argument built from a variable, command substitution, or a glob
  # (e.g. `W=<path>` then `cd $W`, common in agent-issued commands) is not a
  # literal path, and this hook does not expand it to find out what it
  # resolves to — see the accepted-gap note at the top of this file. Falling
  # back to the hook's own cwd here is the same fallback the `else` branch
  # below uses when there is no cd at all: not a stand-in for the real
  # target, just "we don't know, so check what we're standing in".
  _cd_target_stripped="$cd_target"
  case "$_cd_target_stripped" in
    \"*\") _cd_target_stripped="${_cd_target_stripped#\"}"; _cd_target_stripped="${_cd_target_stripped%\"}" ;;
    \'*\') _cd_target_stripped="${_cd_target_stripped#\'}"; _cd_target_stripped="${_cd_target_stripped%\'}" ;;
  esac
  case "$_cd_target_stripped" in
    *'$'*|*'`'*|*'*'*|*'?'*)
      target_dir="$(pwd)"
      ;;
    *)
      target_dir=$(_resolve_path "$cd_target")
      ;;
  esac
else
  target_dir="$(pwd)"
fi

if [[ ! -d "$target_dir" ]]; then
  # A literal, resolvable path that plainly does not exist: nothing to
  # protect there, same as "not a git repo". This cannot regress into the
  # gap above, because that gap is specifically an UNRESOLVED path (one this
  # hook could not determine at all) — an unresolved path never reaches this
  # branch, since it was already substituted with the hook's own cwd, which
  # always exists.
  exit 0
fi

# Combine the raw command with the -C-stripped git line so the dangerous
# pattern check below sees a plain 'git commit ...' shape either way.
check_target="$command"$'\n'"$git_line_normalized"

# Protected branches
protected_branches="main master trunk develop production release"

# Determine target branch (silent, don't fail if not a repo)
current_branch=$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [[ -z "$current_branch" ]]; then
  # Not in a git repo or detached HEAD, let it pass
  exit 0
fi

# Only enforce on protected branches
is_protected="false"
for b in $protected_branches; do
  if [[ "$current_branch" == "$b" ]]; then
    is_protected="true"
    break
  fi
done

if [[ "$is_protected" != "true" ]]; then
  exit 0
fi

# Patterns that are dangerous on a protected branch
dangerous_patterns=(
  'git\s+commit'
  'git\s+push'
  'git\s+merge'
  'git\s+rebase'
  'git\s+reset\s+--hard'
  'git\s+cherry-pick'
)

for pattern in "${dangerous_patterns[@]}"; do
  if echo "$check_target" | grep -qE "$pattern"; then
    echo "BLOCKED by protect-main.sh: dangerous git operation on protected branch '$current_branch'" >&2
    echo "" >&2
    echo "Create a feature branch first:" >&2
    echo "  git switch -c feature/<slug>" >&2
    echo "" >&2
    echo "Then repeat the operation." >&2
    echo "" >&2
    echo "Protected branches: $protected_branches" >&2
    exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
  fi
done

exit 0
