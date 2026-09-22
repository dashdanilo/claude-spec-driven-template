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
#   - ff-only merge of a protected branch's own upstream, blocked like any
#     other merge: `git merge --ff-only origin/main` while on `main` is what
#     `git pull --ff-only` does under the hood — it can only fast-forward or
#     fail, never create a commit — but the old hook matched `git\s+merge`
#     unconditionally and blocked it anyway, next to `git pull --ff-only`
#     itself, which was never in the dangerous-pattern list and always
#     passed. Fixed: a `git merge` invocation on a protected branch is now
#     exempted ONLY when it carries `--ff-only` AND its single merge target
#     is the branch's own upstream (`@{u}`, `@{upstream}`, `origin/<branch>`,
#     or `<remote>/<branch>` generally). A merge of any other ref, more than
#     one target, or a merge without `--ff-only`, is still blocked exactly as
#     before.
#   - deleting a non-protected remote branch, blocked like any other push:
#     `git push origin --delete fix/x` while the CURRENT branch is `main`
#     never pushes `main` — it only removes a remote ref for a feature branch
#     that already merged — but the old hook matched `git\s+push`
#     unconditionally and blocked every push regardless of what it actually
#     names. Fixed: a `git push` invocation on a protected branch is now
#     exempted ONLY when EVERY ref it names is a deletion (`--delete`/`-d`
#     followed by branch names, or a `:<branch>` refspec) of a branch that is
#     itself NOT in the protected list. A push that also names a real ref
#     (`git push origin :fix/x main`), deletes a protected branch itself
#     (`git push origin --delete main`), carries no ref at all (plain
#     `git push`/`git push origin`), or carries `--force`/`-f` or any other
#     flag this check doesn't recognize as harmless, is still blocked exactly
#     as before — the parser is conservative on purpose: an unrecognized flag
#     is treated as unsafe rather than assumed harmless.
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

# A `git merge` invocation on a protected branch is safe, and exempted from
# the dangerous-pattern block below, only when it is `--ff-only` AND its one
# merge target is the branch's own upstream — same shape `git pull --ff-only`
# already produces. Not a shell parser: flags other than `--ff-only` are
# skipped rather than understood, so a flag that itself takes a value (e.g.
# `-m <msg>`) is misread as an extra positional target, which only makes this
# check MORE conservative (falls through to "not safe", still blocked) — see
# the defect note at the top of this file.
_is_safe_ff_only_upstream_merge() {
  local line="$1"
  local branch="$2"
  local -a tokens
  read -ra tokens <<< "$line"

  local has_ff_only=0
  local -a targets=()
  local i tok
  for ((i = 2; i < ${#tokens[@]}; i++)); do
    tok="${tokens[$i]}"
    case "$tok" in
      --ff-only) has_ff_only=1 ;;
      -*) : ;;
      *) targets+=("$tok") ;;
    esac
  done

  [[ "$has_ff_only" -eq 1 ]] || return 1
  [[ "${#targets[@]}" -eq 1 ]] || return 1

  local target="${targets[0]}"
  case "$target" in
    '@{u}'|'@{upstream}') return 0 ;;
    */"$branch")
      local remote_part="${target%/*}"
      case "$remote_part" in
        ''|*/*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# A `git push` invocation on a protected branch is safe, and exempted from
# the dangerous-pattern block below, only when EVERY ref it names is a
# deletion of a branch that is NOT itself in the protected list: `--delete`/
# `-d` followed by one or more branch names, or a `:<branch>` refspec.
# Deleting an already-merged remote feature branch never pushes the current
# (protected) branch. Not a shell parser: the first positional token is
# always treated as the remote name (as `git push` requires), and any flag
# other than `--delete`/`-d`/`-q`/`--quiet`/`-v`/`--verbose` is treated as
# unsafe rather than assumed harmless — most importantly `--force`/`-f`,
# `--mirror`, `--all`, `--tags`, `--prune`, which change what the invocation
# actually does and must stay blocked even alongside a `--delete`.
_is_safe_delete_only_push() {
  local line="$1"
  local -a tokens
  read -ra tokens <<< "$line"

  local has_delete_flag=0
  local remote_seen=0
  local -a ref_names=()
  local -a ref_is_delete=()
  local i tok

  for ((i = 2; i < ${#tokens[@]}; i++)); do
    tok="${tokens[$i]}"
    case "$tok" in
      --delete|-d) has_delete_flag=1 ;;
      -q|--quiet|-v|--verbose) : ;;
      -*) return 1 ;;
      *)
        if [[ "$remote_seen" -eq 0 ]]; then
          remote_seen=1
          continue
        fi
        if [[ "$tok" == :* ]]; then
          ref_names+=("${tok#:}")
          ref_is_delete+=(1)
        elif [[ "$has_delete_flag" -eq 1 ]]; then
          ref_names+=("$tok")
          ref_is_delete+=(1)
        else
          ref_names+=("$tok")
          ref_is_delete+=(0)
        fi
        ;;
    esac
  done

  [[ "${#ref_names[@]}" -eq 0 ]] && return 1

  local j name is_del
  for ((j = 0; j < ${#ref_names[@]}; j++)); do
    is_del="${ref_is_delete[$j]}"
    [[ "$is_del" -eq 1 ]] || return 1

    name="${ref_names[$j]}"
    name="${name#refs/heads/}"
    [[ -z "$name" ]] && return 1

    for b in $protected_branches; do
      [[ "$name" == "$b" ]] && return 1
    done
  done

  return 0
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
        if [[ "$pattern" == 'git\s+merge(\s|$)' ]] \
           && _is_safe_ff_only_upstream_merge "$git_line_normalized" "$inv_branch"; then
          continue
        fi
        if [[ "$pattern" == 'git\s+push(\s|$)' ]] \
           && _is_safe_delete_only_push "$git_line_normalized"; then
          continue
        fi
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
