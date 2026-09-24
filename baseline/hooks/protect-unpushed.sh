#!/usr/bin/env bash
# protect-unpushed.sh
# PreToolUse hook for Bash. Blocks deleting work that exists ONLY locally:
# a branch whose commits are reachable from nowhere else, or a worktree
# carrying uncommitted changes. protect-main.sh stops a commit/push/merge
# from landing on a protected branch; nothing stopped an agent from erasing
# work that was never protected in the first place, by running
# `git branch -D <branch>` on a branch with commits reachable only through
# it, or `git worktree remove` on a worktree with uncommitted changes. Both
# commands report success either way, so the loss is silent.
#
# Two commands recognized, each walked per invocation the same shape
# protect-main.sh walks git invocations: its own `git -C <path>` if present,
# otherwise the most recent literal `cd <path>` seen before it, otherwise the
# BASE directory this run resolved. The base is the payload's own top-level
# "cwd" (the directory Claude Code actually ran the command from, e.g. a
# feature worktree, not this hook's own process), falling back to the hook
# process's own `pwd` only when the payload omits "cwd" entirely. This is a
# deliberate divergence from protect-main.sh, which never reads "cwd" and
# resolves an un-cd'd, un--C'd invocation against its own process directory
# instead: reproduced as a real false pass while building this hook (a
# fixture repo given only via the payload's "cwd", with the process itself
# launched from this repo, walked right past the fixture entirely and
# checked this repo's own working tree for the branch instead, found
# nothing, and let the delete through). See the same accepted gap around a
# cd/-C target built from a variable, command substitution, or a glob below.
#
#   git branch -D/-d/--delete <branch...>   (a `-r`/`--remotes` flag is
#     exempted: deleting a local remote-tracking ref never loses work, it
#     only forgets a pointer to something the remote still has)
#
#   git worktree remove [--force] <path>
#
# A branch delete is SAFE, and let through, when EITHER holds:
#   (a) none of its commits are reachable ONLY through it: `git log <branch>
#       --not --exclude=<branch> --branches --remotes --tags` is empty. This
#       is deliberately not "not on any remote" — an earlier version used
#       `--not --remotes`, which reported a branch's whole history as at
#       risk (including a commit that is also the tip of another local
#       branch, reachable there regardless of this delete) rather than just
#       what is actually exclusive to it. Overstating the loss trains
#       whoever reads the message to stop trusting it, which is the same
#       failure mode as blocking too often: the guard gets ignored, then
#       disabled. `--exclude` takes the branch's short name, not
#       `refs/heads/<branch>`; git's ref-glob matching for --branches
#       operates on short names, and the fully qualified form silently
#       excludes nothing (reproduced while building this check: it let
#       every commit through as "unique" even the ones on other branches).
#   (b) its content is already on the integration branch, even if its
#       commits are not ancestors of it. This is not an edge case, it is the
#       common case this repo (squash-merge) produces on every single merged
#       PR: the branch's commits are gone from history, only their squashed
#       content survives, so `git branch --contains` gives a false negative
#       on every branch that already shipped. Checked TWO ways, either one
#       sufficient (see the functions themselves for why neither alone is
#       enough): a numstat-based content diff against the integration
#       branch's CURRENT tip, and a `git cherry` patch-id comparison against
#       integration's commit history. The integration branch is resolved
#       from `origin/HEAD` (its target verified to actually exist, not just
#       resolved as a symref), falling back to the first of main/master/
#       trunk/develop that exists as `origin/<name>` or, failing that, as a
#       local branch — never hardcoded to "main". If no integration branch
#       can be resolved at all, a branch that fails (a) is blocked rather
#       than risking a false pass, since (b) could not be evaluated either
#       way — sustainable only together with the escape hatch below, since a
#       block with no way out just gets the guard disabled.
#
# A worktree remove is SAFE, and let through, only when `git status
# --porcelain` in that worktree is empty. `--force` on the command being
# inspected does NOT exempt it: `--force` is exactly the flag that removes a
# worktree git would otherwise refuse over uncommitted changes, so honoring
# it here would defeat the guard on the one case it exists for. A worktree's
# own branch is not re-checked against the safe-delete criteria above:
# removing the worktree directory does not touch the branch or its commits,
# those stay reachable through `git branch` regardless, only the checkout
# itself (and anything never committed in it) is at risk.
#
# Escape hatch, branch delete only: a rejected delete may be genuinely
# wanted (a throwaway local branch in a repo with no remote at all, for
# instance, where there is nowhere to push it and nothing to squash-merge
# it into). Recognized as `HARNESS_ALLOW_UNPUSHED_DELETE=<value>` where
# <value> is non-empty and not literally `0`, in either of two shapes:
#   - inline, directly in front of the git invocation it applies to:
#     `HARNESS_ALLOW_UNPUSHED_DELETE=1 git branch -D <branch>`
#   - as its own segment earlier in the same command (a bare assignment or
#     `export NAME=value`), the same way a literal `cd` persists for the
#     rest of the walk: `HARNESS_ALLOW_UNPUSHED_DELETE=1 && git branch -D
#     <branch>`
# Only ONE leading env-assignment token is recognized in the inline shape;
# combined with another env var ahead of it on the same line
# (`FOO=1 HARNESS_ALLOW_UNPUSHED_DELETE=1 git ...`) it is not recognized,
# same conservative-on-purpose posture as the rest of this file. The block
# message always names this escape hatch: one nobody discovers protects
# nothing better than no escape hatch at all.
#
# Accepted gaps, same posture as protect-main.sh: this is a heuristic over
# the command TEXT, not a shell parser, and it does not block what it cannot
# resolve with confidence, because a guard that blocks on confusion gets
# disabled by its own users.
#   - a `cd` (or `git -C`) target that is not a literal path (a variable, a
#     command substitution, a glob) resets tracking to the resolved base
#     (the payload's "cwd", or the hook's own process cwd as a last resort),
#     the same conservative fallback protect-main.sh uses for its own cwd
#   - a `git worktree remove <name>` where `<name>` is the worktree's short
#     name rather than a literal resolvable path is not looked up against
#     `git worktree list`; it fails to resolve to an existing directory and
#     passes unchecked
#   - a branch name that does not exist locally at the time this hook runs
#     is not something the delete command can lose either, so it passes
#     unchecked
#   - `rm -rf <path>` on a worktree or repo directory, and `git worktree
#     prune`, are not intercepted at all: this hook only recognizes the two
#     command shapes named above. Both are real ways to lose the same kind
#     of work this hook exists to protect, left to a human's judgment for
#     now rather than this hook's, same as any command it does not parse
#   - a `git -C <path>` whose path contains a space, even quoted
#     (`git -C "a b" branch -D x`), is not read correctly: the explicit-dir
#     capture stops at the first whitespace, same limitation protect-main.sh
#     accepts for the identical construct. The invocation then resolves
#     against the running current_dir instead of the quoted path, which is
#     conservative in the common case (checks the wrong, but still real,
#     directory) rather than silently skipping the check
#   - a branch that was squash-merged and LATER REVERTED on the integration
#     branch: `git cherry` still finds the original patch-id in
#     integration's history and reports clean, and that alone is enough to
#     pass criterion (b), the OR composition above, even though numstat on
#     its own would (correctly, on its own reading) call it unsafe. Left
#     open on purpose rather than adding a third criterion: if the revert
#     was deliberate, the branch's content is still sitting in its own
#     history either way, reachable through the branch itself, so deleting
#     it loses an obsolete branch, not real work — and each criterion added
#     to this OR so far has cost a full review round of new false-positive
#     surface, which is the more expensive failure mode for a guard people
#     need to keep trusting
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Bash". Also in install-harness.sh's portable set: losing local-only work
# is a risk in any repo, not specific to this one.

set -uo pipefail

input=$(cat)

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: protect-unpushed.sh: no python3 or python on PATH — cannot read the tool payload, so this guard is DISABLED for this call. Install Python to restore it." >&2
  exit 0
fi

command=$(printf '%s' "$input" | "$PYTHON_BIN" -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('command') or ti.get('command') or '')" 2>/dev/null || echo "")

[[ -z "$command" ]] && exit 0

# The payload's own "cwd" (top-level, the directory Claude Code actually ran
# this command from) is the base every relative path in this hook resolves
# against. A separate, single-purpose python call, like the one above for
# "command": "command" can be a multi-line script, and printing it alongside
# other fields on their own lines (the way protect-machine-config.sh reads
# several fields from one call) would silently truncate it to its first line
# when picked back apart with sed. The process's own `pwd` is only the
# fallback for when the payload omits "cwd" entirely, never the default.
payload_cwd=$(printf '%s' "$input" | "$PYTHON_BIN" -c "import sys,json;d=json.load(sys.stdin);print(d.get('cwd') or '')" 2>/dev/null || echo "")
if [[ -n "$payload_cwd" ]]; then
  base_cwd="$payload_cwd"
else
  base_cwd="$(pwd)"
fi

_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Resolves $1 against $2 (the base for a relative path): the payload's cwd
# for anything not yet redirected by a literal cd/-C in the command, or the
# running current_dir once one has been seen.
_resolve_path() {
  local p="$1" base="$2"
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
    *) p="${base}/$p" ;;
  esac
  printf '%s' "$p"
}

# Same posture as protect-main.sh: a cd/-C target built from a variable,
# command substitution, or a glob is not a literal path, and this hook does
# not expand it.
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

# Parses `git branch ...` tokens (index 2 onward, tokens[0]=git tokens[1]=branch)
# into three globals: _bd_is_delete, _bd_is_remote, _bd_branches. Not a shell
# parser: a combined short-flag cluster (-D, -d, -rd, -Dr, ...) is read one
# character at a time, an unrecognized long flag is skipped rather than
# understood.
_bd_is_delete=0
_bd_is_remote=0
_bd_branches=()

_parse_branch_line() {
  local line="$1"
  local -a tokens
  read -ra tokens <<< "$line"
  _bd_is_delete=0
  _bd_is_remote=0
  _bd_branches=()
  local n=${#tokens[@]}
  local i tok j c
  for ((i = 2; i < n; i++)); do
    tok="${tokens[$i]}"
    case "$tok" in
      --delete) _bd_is_delete=1 ;;
      --remotes|--remote) _bd_is_remote=1 ;;
      --force) : ;;
      --*) : ;;
      -*)
        for ((j = 1; j < ${#tok}; j++)); do
          c="${tok:$j:1}"
          case "$c" in
            D) _bd_is_delete=1 ;;
            d) _bd_is_delete=1 ;;
            r) _bd_is_remote=1 ;;
            *) : ;;
          esac
        done
        ;;
      *)
        _bd_branches+=("$tok")
        ;;
    esac
  done
}

# Parses `git worktree remove ...` tokens (index 3 onward, tokens 0-2 are
# "git worktree remove") for the first non-flag argument, its path.
_parse_worktree_remove_path() {
  local line="$1"
  local -a tokens
  read -ra tokens <<< "$line"
  local n=${#tokens[@]}
  local i tok path=""
  for ((i = 3; i < n; i++)); do
    tok="${tokens[$i]}"
    case "$tok" in
      -*) : ;;
      *)
        [[ -z "$path" ]] && path="$tok"
        ;;
    esac
  done
  printf '%s' "$path"
}

# Resolves the integration branch as a ref this hook can diff against
# directly: prefers origin/HEAD, then the first of main/master/trunk/develop
# that exists as origin/<name>, then the first that exists as a local
# branch. Never hardcodes "main". Prints the ref and returns 0, or returns 1
# if nothing resolves. origin/HEAD's target is verified to actually exist,
# not just resolved as a symref: a stale origin/HEAD pointing at a remote
# branch that was since renamed or deleted (a real, reproduced case, not
# hypothetical) would otherwise hand back a ref that resolves to nothing,
# blocking a genuinely safe delete and, worse, telling the person to run a
# `git diff --numstat` that itself errors out with nowhere to go.
_resolve_integration_ref() {
  local repo="$1"
  local head_ref name c

  head_ref=$(git -C "$repo" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo "")
  if [[ -n "$head_ref" ]]; then
    name="${head_ref#refs/remotes/origin/}"
    if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$name" >/dev/null 2>&1; then
      printf 'origin/%s' "$name"
      return 0
    fi
  fi

  for c in main master trunk develop; do
    if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$c" >/dev/null 2>&1; then
      printf 'origin/%s' "$c"
      return 0
    fi
  done
  for c in main master trunk develop; do
    if git -C "$repo" rev-parse --verify --quiet "refs/heads/$c" >/dev/null 2>&1; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

# Criterion (a): commits reachable from the branch but from no OTHER ref
# (local branch, remote-tracking ref, or tag). `--exclude` takes the
# branch's short name (not `refs/heads/<branch>`, see header note) so it
# only removes the branch itself from the `--branches` expansion, leaving
# every other branch, remote-tracking ref and tag as the negative side.
_branch_unique_log() {
  local repo="$1" branch="$2"
  git -C "$repo" log --oneline "$branch" --not --exclude="$branch" --branches --remotes --tags 2>/dev/null
}

# Criterion (b), test 1 of 2: nothing the branch holds is missing from the
# integration ref's current content. `git diff --numstat <integration>
# <branch>` reads as "changes to go from integration to branch" — an added
# line is content the branch has that integration does not (unsafe), a
# deleted line only means integration moved on independently since
# (irrelevant to this branch's safety). A binary file that differs cannot be
# judged this way and is treated as unsafe, conservatively.
#
# A rename, a newly added empty file, and a mode-only change (chmod +x) all
# produce a numstat line of "0<TAB>0<TAB><path>" — zero insertions, zero
# deletions, same as a file with no change at all, because numstat counts
# LINES, and none of those three touch a line. Reproduced as a real false
# pass: a branch that does nothing but rename a.txt to b.txt, never pushed,
# read as "nothing added" and was let through. A 0/0 line is real, unproven
# content (git still listed the path as changed), so it is treated as
# unsafe, the same as an actual addition, rather than silently skipped.
_content_already_in_integration() {
  local repo="$1" integration="$2" branch="$3"
  local numstat added _rest
  numstat=$(git -C "$repo" diff --numstat "$integration" "$branch" 2>/dev/null) || return 1
  [[ -z "$numstat" ]] && return 0
  while IFS=$'\t' read -r added _rest; do
    [[ -z "$added" ]] && continue
    [[ "$added" == "-" ]] && return 1
    [[ "$added" -gt 0 ]] && return 1
    [[ "$added" -eq 0 && "$_rest" == 0* ]] && return 1
  done <<< "$numstat"
  return 0
}

# Criterion (b), test 2 of 2: `git cherry <integration> <branch>` compares
# each of the branch's own commits by PATCH-ID (a hash of the diff itself,
# not of tree state) against integration's commits, marking one `-` when an
# equivalent patch is already there and `+` when it is not. No `+` line
# means every commit's content already landed. This exists ALONGSIDE the
# numstat test, neither replaces the other, because each covers a case the
# other misses:
#   - numstat alone false-positives (blocks a genuinely safe delete) once
#     integration's tip diverges from the branch on a line the branch also
#     touched, even from unrelated later work — a real, reproduced case: a
#     one-commit branch squash-merged cleanly, then a LATER, unrelated
#     integration commit edits that same line, and numstat compares CURRENT
#     tips, so it sees that edit as the branch "missing" content that is
#     actually just integration having moved on. cherry is immune to this,
#     because a patch-id is fixed to the historical commit's own diff and
#     does not move when integration advances afterward.
#   - cherry alone false-positives on a squash of MULTIPLE commits: the one
#     squash commit's combined patch-id matches none of the branch's
#     several individual commits' patch-ids, so cherry marks all of them
#     `+` even though the final content is identical. numstat catches this
#     one instead, since it compares tree content, not per-commit patches.
# The two tests are OR'd: EITHER passing is enough to call the delete safe,
# and only both failing blocks it. That is weaker than "these two cover
# each other's blind spots" might suggest: the guarantee is that at least
# one of them correctly says unsafe, not that the pair together catches
# every way a delete could be unsafe. A squash-merged branch later REVERTED
# on integration is exactly that gap: cherry sees the original patch-id in
# integration's history and says clean, numstat sees the revert as the
# branch now holding a line integration lacks and says unsafe on its own,
# but only ONE has to accidentally agree with numstat's "unsafe" reading
# for the block to hold — here cherry's "clean" is the one that leaks
# through, on its own, and the OR lets the delete pass. Deliberately not
# closed; see the accepted-gaps note below for why.
_cherry_clean() {
  local repo="$1" integration="$2" branch="$3"
  local cherry_out
  cherry_out=$(git -C "$repo" cherry "$integration" "$branch" 2>/dev/null) || return 1
  printf '%s\n' "$cherry_out" | grep -q '^+' && return 1
  return 0
}

# Criterion (a) then (b). Returns 0 (safe to delete) or 1 (blocked).
_branch_delete_is_safe() {
  local repo="$1" branch="$2"
  if [[ -z "$(_branch_unique_log "$repo" "$branch")" ]]; then
    return 0
  fi
  local integ
  integ="$(_resolve_integration_ref "$repo")" || return 1
  _content_already_in_integration "$repo" "$integ" "$branch" && return 0
  _cherry_clean "$repo" "$integ" "$branch"
}

# Split into one "atomic" command per line at command-position separators,
# same normalization as protect-main.sh.
_normalized="${command//&&/$'\n'}"
_normalized="${_normalized//||/$'\n'}"
_normalized="${_normalized//;/$'\n'}"
_normalized="${_normalized//|/$'\n'}"
_normalized="${_normalized//&/$'\n'}"

current_dir="$base_cwd"
allow_unpushed_delete=0
blocked=0
block_kind=""
blocked_repo=""
blocked_branch=""
blocked_worktree=""

while IFS= read -r _line; do
  _t=$(_trim "$_line")
  [[ -z "$_t" ]] && continue

  # A standalone escape-hatch assignment (bare or `export NAME=value`)
  # persists for the rest of the walk, the same way a literal `cd` does.
  if [[ "$_t" =~ ^(export[[:space:]]+)?HARNESS_ALLOW_UNPUSHED_DELETE=([^[:space:]]*)$ ]]; then
    _hv="${BASH_REMATCH[2]}"
    if [[ -n "$_hv" && "$_hv" != "0" ]]; then
      allow_unpushed_delete=1
    else
      allow_unpushed_delete=0
    fi
    continue
  fi

  if [[ "$_t" =~ ^cd[[:space:]]+(.+)$ ]]; then
    _cd_target="${BASH_REMATCH[1]}"
    if _is_unresolvable_cd_target "$_cd_target"; then
      current_dir="$base_cwd"
    else
      current_dir=$(_resolve_path "$_cd_target" "$current_dir")
    fi
    continue
  fi

  # An inline escape-hatch prefix scopes to this one invocation only. Only
  # a single leading token is recognized (see header accepted-gap note).
  inline_allow=0
  git_check_line="$_t"
  if [[ "$git_check_line" =~ ^HARNESS_ALLOW_UNPUSHED_DELETE=([^[:space:]]*)[[:space:]]+(.*)$ ]]; then
    _hv="${BASH_REMATCH[1]}"
    git_check_line="${BASH_REMATCH[2]}"
    if [[ -n "$_hv" && "$_hv" != "0" ]]; then
      inline_allow=1
    fi
  fi

  [[ "$git_check_line" =~ ^git([[:space:]]|$) ]] || continue

  git_line="$git_check_line"
  explicit_dir=""
  git_line_normalized="$git_line"
  if [[ "$git_line" =~ ^git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]*(.*)$ ]]; then
    explicit_dir="${BASH_REMATCH[1]}"
    git_line_normalized="git ${BASH_REMATCH[2]}"
  fi

  if [[ -n "$explicit_dir" ]]; then
    target_dir=$(_resolve_path "$explicit_dir" "$current_dir")
  else
    target_dir="$current_dir"
  fi

  [[ -d "$target_dir" ]] || continue

  if [[ "$git_line_normalized" =~ ^git[[:space:]]+branch([[:space:]]|$) ]]; then
    _parse_branch_line "$git_line_normalized"
    if [[ "$_bd_is_delete" -eq 1 && "$_bd_is_remote" -eq 0 && "${#_bd_branches[@]}" -gt 0 ]]; then
      if [[ "$allow_unpushed_delete" -eq 1 || "$inline_allow" -eq 1 ]]; then
        : # explicit escape hatch for this invocation, skip the safety check
      else
        for b in "${_bd_branches[@]}"; do
          git -C "$target_dir" rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1 || continue
          if ! _branch_delete_is_safe "$target_dir" "$b"; then
            blocked=1
            block_kind="branch"
            blocked_repo="$target_dir"
            blocked_branch="$b"
            break
          fi
        done
      fi
    fi
  elif [[ "$git_line_normalized" =~ ^git[[:space:]]+worktree[[:space:]]+remove([[:space:]]|$) ]]; then
    wt_arg="$(_parse_worktree_remove_path "$git_line_normalized")"
    if [[ -n "$wt_arg" ]]; then
      wt_resolved=$(_resolve_path "$wt_arg" "$target_dir")
      if [[ -d "$wt_resolved" ]]; then
        porcelain=$(git -C "$wt_resolved" status --porcelain 2>/dev/null)
        if [[ $? -eq 0 && -n "$porcelain" ]]; then
          blocked=1
          block_kind="worktree"
          blocked_worktree="$wt_resolved"
        fi
      fi
    fi
  fi

  [[ "$blocked" -eq 1 ]] && break
done <<< "$_normalized"

if [[ "$blocked" -eq 1 && "$block_kind" == "branch" ]]; then
  integ="$(_resolve_integration_ref "$blocked_repo" 2>/dev/null || echo "")"
  unique_log="$(_branch_unique_log "$blocked_repo" "$blocked_branch")"
  tip_sha="$(git -C "$blocked_repo" rev-parse "$blocked_branch" 2>/dev/null)"
  has_remote=0
  [[ -n "$(git -C "$blocked_repo" remote 2>/dev/null)" ]] && has_remote=1

  {
    echo "BLOCKED by protect-unpushed.sh: deleting branch '$blocked_branch' would lose"
    echo "commits that exist nowhere else."
    echo ""
    echo "Commits only reachable from '$blocked_branch':"
    printf '%s\n' "$unique_log" | head -10 | while IFS= read -r l; do echo "  $l"; done
    echo ""
    if [[ "$has_remote" -eq 1 ]]; then
      echo "Push the branch first:"
      echo "  git -C $blocked_repo push -u origin $blocked_branch"
      echo ""
      if [[ -n "$integ" ]]; then
        echo "If this content already landed on '$integ' through a squash merge, confirm it"
        echo "with the same content test this hook uses, not 'git branch --contains' (that"
        echo "gives a false negative after a squash):"
        echo "  git -C $blocked_repo diff --numstat $integ $blocked_branch"
        echo "Nothing printed, or only deletions with no additions, means the content is"
        echo "already there and it is safe to delete."
      else
        echo "Could not resolve an integration branch (no origin/HEAD, and none of main,"
        echo "master, trunk or develop exist either), so the squash-merge content check"
        echo "could not run."
      fi
    else
      echo "This repository has no remote configured, so there is nowhere to push this"
      echo "branch to. Archive it under a tag first, then delete it:"
      echo "  git -C $blocked_repo tag archive/$blocked_branch $blocked_branch"
    fi
    echo ""
    echo "'git branch -D' does not destroy these commits right away, they stay reachable"
    echo "through the reflog until garbage collection. To get '$blocked_branch' back:"
    echo "  git -C $blocked_repo branch $blocked_branch $tip_sha"
    echo ""
    echo "If this is genuinely meant to be discarded, say so explicitly:"
    echo "  HARNESS_ALLOW_UNPUSHED_DELETE=1 git branch -D $blocked_branch"
  } >&2
  exit 2
fi

if [[ "$blocked" -eq 1 && "$block_kind" == "worktree" ]]; then
  {
    echo "BLOCKED by protect-unpushed.sh: '$blocked_worktree' has uncommitted changes."
    echo ""
    echo "Removing the worktree does not commit them anywhere first, they would be lost,"
    echo "not just left unpushed. --force does not change this, it is exactly the flag"
    echo "that would lose them."
    echo ""
    echo "See what would be lost:"
    echo "  git -C $blocked_worktree status"
    echo ""
    echo "Commit or stash it, then remove the worktree:"
    echo "  git -C $blocked_worktree add -A && git -C $blocked_worktree commit -m \"...\""
    echo "  git worktree remove $blocked_worktree"
  } >&2
  exit 2
fi

exit 0
