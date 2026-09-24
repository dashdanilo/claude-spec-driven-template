#!/usr/bin/env bash
# protect-machine-config.sh
# PreToolUse hook for Bash AND for Edit/Write/MultiEdit. Blocks an agent from
# writing machine-level or user-level configuration: the layer that sits
# OUTSIDE every repo, where no diff, no PR and no reviewer will ever see the
# change.
#
# The incident this exists for: an agent building a repo's CI ran
# `git config --global user.name "CI"` and
# `git config --global user.email ci@example.com` on the maintainer's own
# machine so a test fixture could commit. That overwrote his real identity in
# `~/.gitconfig`. Every commit made afterwards on that machine, by every
# session including other people's work, was authored `CI <ci@example.com>`:
# 28 commits across five repos. A deploy provider then refused a deployment
# with "GitHub couldn't verify an account for the commit", which is how it
# was noticed. Nothing had reached an integration branch, and the affected
# PRs were rewritten with the right author, but the class of bug is clear:
# writing to machine-level config leaves no trail any of this harness's other
# guards can see, because none of them look outside a repo at all.
#
# Two matchers, one file, dispatched on tool_name (same pattern as
# log-edit.sh):
#   - Bash: blocks a `git config` invocation, at ANY scope flag OR an
#     explicit `-f`/`--file` target that resolves to a machine-level config
#     file, that WRITES (a value, --add, --unset, --unset-all,
#     --replace-all, --edit/-e, --rename-section, --remove-section). A read
#     at any scope (--get, --get-all, --list/-l, --show-origin,
#     --show-scope, or a bare `git config --global <key>` with no value)
#     always passes, and so does a repo-local write (no scope flag, or
#     --local/--worktree) - that lives in the repo, is visible to whoever
#     looks, and is the legitimate way to set an identity for a fixture.
#   - Edit/Write/MultiEdit: blocks writing the machine-level files
#     themselves - `~/.gitconfig`, `~/.config/git/config`, `/etc/gitconfig`,
#     and the shell rc files that are the same class of machine-wide reach
#     (`~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.profile`) - matched by
#     EXACT resolved path against $HOME, not by filename pattern, so a
#     repo's own tracked dotfile (a dotfiles repo committing a template
#     `gitconfig` under its own directory, for instance) is never caught by
#     this.
#
# `~/.claude/settings.json` (the user-level agent config, distinct from a
# REPO's `.claude/settings*.json`, which protect-harness.sh already covers)
# is deliberately NOT included here. See the PR that introduced this hook for
# the reasoning: overwriting it is a real but different-shaped risk (it holds
# this agent's own permissions and hook registrations, not a cross-cutting
# machine identity used by every tool on the box), and blocking it is a
# separate decision this hook does not make silently.
#
# Not a shell parser, same accepted-gap posture as protect-main.sh and
# log-edit.sh: quoting inside a token is not understood beyond simple
# strip-the-outer-quote, a `-f<path>` short flag with no space is not
# recognized (only `-f <path>` and `--file=<path>` are), and a `-f`/`--file`
# value built from a variable or command substitution cannot be resolved and
# is treated as NOT machine-level (an accepted gap: `V=~/.gitconfig; git
# config -f "$V" user.name x` is not caught). An unrecognized flag on `git
# config` is skipped, not treated as a write - unlike protect-main.sh's push
# check, there is no flag here whose omission from the safe list would
# silently unblock something dangerous, since the union of scope + explicit
# write-flag is what decides, not "everything not proven safe."
#
# The alternative this hook's block message teaches: set the identity for
# ONE command instead of the machine.
#   git -c user.name="Fixture" -c user.email="fixture@example.com" commit -m "..."
# or export GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL / GIT_COMMITTER_NAME /
# GIT_COMMITTER_EMAIL for that one command, or set it INSIDE the repo:
#   git config user.email "fixture@example.com"   # no --global, no --system
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Bash" and with matcher "Edit|Write|MultiEdit|NotebookEdit". Also in
# install-harness.sh's portable set: it protects the MACHINE, not a
# repository's own settings, so like protect-harness.sh it belongs in every
# adopting project.

set -uo pipefail

input=$(cat)

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: protect-machine-config.sh: no python3 or python on PATH — cannot read the tool payload, so this guard is DISABLED for this call. Install Python to restore it." >&2
  exit 0
fi

payload=$(printf '%s' "$input" | "$PYTHON_BIN" -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('')
    sys.exit(0)
ti = d.get('tool_input') or {}
tool = d.get('tool_name') or ''
command = d.get('command') or ti.get('command') or ''
file_path = ti.get('file_path') or ''
print(tool)
print(command)
print(file_path)
" 2>/dev/null || echo "")

tool_name=$(printf '%s\n' "$payload" | sed -n '1p')
command=$(printf '%s\n' "$payload" | sed -n '2p')
file_path=$(printf '%s\n' "$payload" | sed -n '3p')

# ============================================================ Edit/Write ===
if [[ "$tool_name" == "Edit" || "$tool_name" == "Write" || "$tool_name" == "MultiEdit" ]]; then
  if [[ -z "$file_path" ]]; then
    exit 0
  fi

  # Same template exemption every other guard in this file's family uses.
  if echo "$file_path" | grep -qE '\.example$'; then
    exit 0
  fi

  _expand_home() {
    local p="$1"
    case "$p" in
      \"*\") p="${p#\"}"; p="${p%\"}" ;;
      \'*\') p="${p#\'}"; p="${p%\'}" ;;
    esac
    case "$p" in
      "~") p="$HOME" ;;
      "~/"*) p="${HOME}/${p#"~/"}" ;;
    esac
    printf '%s' "$p"
  }

  resolved_target=$(_expand_home "$file_path")

  machine_files=(
    "$HOME/.gitconfig"
    "$HOME/.config/git/config"
    "/etc/gitconfig"
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
  )
  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    machine_files+=("$XDG_CONFIG_HOME/git/config")
  fi

  for mf in "${machine_files[@]}"; do
    if [[ "$resolved_target" == "$mf" ]]; then
      {
        echo "BLOCKED by protect-machine-config.sh: writing '$mf' reaches outside every repo."
        echo ""
        echo "This is machine-level (or user-level) configuration. No diff, no PR and no"
        echo "reviewer will ever see a change here, and it applies to every session and"
        echo "every other tool on this machine from the moment it lands, not just this repo."
        echo ""
        echo "This is a human's decision to make on their own machine, outside this session."
        echo "If a fixture or test needs a git identity, set it per-command or inside the"
        echo "repo instead:"
        echo "  git -c user.name=\"Fixture\" -c user.email=\"fixture@example.com\" commit -m \"...\""
        echo "  GIT_AUTHOR_NAME=\"Fixture\" GIT_AUTHOR_EMAIL=\"fixture@example.com\" git commit -m \"...\""
        echo "  git config user.email \"fixture@example.com\"   # inside the repo, no --global"
      } >&2
      exit 2
    fi
  done

  exit 0
fi

# ==================================================================== Bash ==
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

if [[ -z "$command" ]]; then
  exit 0
fi

_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

_strip_quotes() {
  local p="$1"
  case "$p" in
    \"*\") p="${p#\"}"; p="${p%\"}" ;;
    \'*\') p="${p#\'}"; p="${p%\'}" ;;
  esac
  printf '%s' "$p"
}

# Only the git-config target paths, not the rc files above — a `git config
# -f <path>` can only ever name a git config file, never a shell rc file.
_is_machine_config_file_arg() {
  local p
  p="$(_strip_quotes "$1")"
  case "$p" in
    '~') p="$HOME" ;;
    '~/'*) p="${HOME}/${p#'~/'}" ;;
    '$HOME') p="$HOME" ;;
    '$HOME/'*) p="${HOME}${p#'$HOME'}" ;;
    '${HOME}') p="$HOME" ;;
    '${HOME}/'*) p="${HOME}${p#'${HOME}'}" ;;
  esac
  case "$p" in
    "$HOME/.gitconfig") return 0 ;;
    "$HOME/.config/git/config") return 0 ;;
    "/etc/gitconfig") return 0 ;;
  esac
  if [[ -n "${XDG_CONFIG_HOME:-}" && "$p" == "$XDG_CONFIG_HOME/git/config" ]]; then
    return 0
  fi
  return 1
}

# Decide what ONE `git config ...` invocation (already normalized so tokens[0]
# is literally "git", tokens[1] is "config") does: "write", "read", or
# "not-machine" (scope is --local/--worktree/absent-and-no-machine-file, out
# of this hook's business entirely). Not a shell parser — see header.
_git_config_decision() {
  local line="$1"
  local -a tokens
  read -ra tokens <<< "$line"

  local scope="" is_write=0 is_read_flag=0
  local -a positionals=()
  local i=2
  local n=${#tokens[@]}
  local tok

  while (( i < n )); do
    tok="${tokens[$i]}"
    case "$tok" in
      --global) scope="machine" ;;
      --system) scope="machine" ;;
      --local) scope="local" ;;
      --worktree) scope="local" ;;
      -f|--file)
        i=$((i + 1))
        if _is_machine_config_file_arg "${tokens[$i]:-}"; then
          scope="machine"
        elif [[ -z "$scope" ]]; then
          scope="local"
        fi
        ;;
      --file=*)
        if _is_machine_config_file_arg "${tok#--file=}"; then
          scope="machine"
        elif [[ -z "$scope" ]]; then
          scope="local"
        fi
        ;;
      --add|--unset|--unset-all|--replace-all|--rename-section|--remove-section)
        is_write=1 ;;
      -e|--edit)
        is_write=1 ;;
      --get|--get-all|--get-regexp|--get-urlmatch|--list|-l|--show-origin|--show-scope)
        is_read_flag=1 ;;
      --type|--default|--url|--blob)
        i=$((i + 1)) ;;  # these consume a value token, skip it
      -*)
        : ;;  # unrecognized flag: skip, not scope- or write-affecting (see header)
      *)
        positionals+=("$tok") ;;
    esac
    i=$((i + 1))
  done

  if [[ "$scope" != "machine" ]]; then
    echo "not-machine"
    return
  fi

  if [[ "$is_write" -eq 1 ]]; then
    echo "write"
    return
  fi

  if [[ "$is_read_flag" -eq 1 ]]; then
    echo "read"
    return
  fi

  # No explicit read/write flag: a bare key IS a read, a key+value IS a write.
  if [[ "${#positionals[@]}" -ge 2 ]]; then
    echo "write"
  else
    echo "read"
  fi
}

# Split into one "atomic" command per line at command-position separators,
# same normalization as protect-main.sh (order matters: && / || before the
# single & / | they contain).
_normalized="${command//&&/$'\n'}"
_normalized="${_normalized//||/$'\n'}"
_normalized="${_normalized//;/$'\n'}"
_normalized="${_normalized//|/$'\n'}"
_normalized="${_normalized//&/$'\n'}"

blocked=0
blocked_line=""

while IFS= read -r _line; do
  _t=$(_trim "$_line")
  [[ -z "$_t" ]] && continue
  [[ "$_t" =~ ^git([[:space:]]|$) ]] || continue

  # Strip this invocation's own `git -C <path>` the same way protect-main.sh
  # does, so the rest of this loop always sees a plain "git config ..." shape
  # regardless of whether -C was present.
  git_line="$_t"
  if [[ "$git_line" =~ ^git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]*(.*)$ ]]; then
    git_line="git ${BASH_REMATCH[2]}"
  fi

  [[ "$git_line" =~ ^git[[:space:]]+config([[:space:]]|$) ]] || continue

  decision="$(_git_config_decision "$git_line")"
  if [[ "$decision" == "write" ]]; then
    blocked=1
    blocked_line="$_t"
    break
  fi
done <<< "$_normalized"

if [[ "$blocked" -eq 1 ]]; then
  {
    echo "BLOCKED by protect-machine-config.sh: '$blocked_line' writes machine- or"
    echo "user-level git configuration."
    echo ""
    echo "That reaches outside this repo, into ~/.gitconfig (or /etc/gitconfig), which"
    echo "every session and every other tool on this machine reads afterwards — no diff,"
    echo "no PR, no reviewer will ever see it. That is exactly how one agent's fixture"
    echo "setup once overwrote a maintainer's real git identity machine-wide."
    echo ""
    echo "Set the identity for ONE command instead:"
    echo "  git -c user.name=\"Fixture\" -c user.email=\"fixture@example.com\" commit -m \"...\""
    echo ""
    echo "Or for one command via the environment:"
    echo "  GIT_AUTHOR_NAME=\"Fixture\" GIT_AUTHOR_EMAIL=\"fixture@example.com\" git commit -m \"...\""
    echo ""
    echo "Or set it inside the repo the fixture actually lives in (no --global, no --system):"
    echo "  git config user.email \"fixture@example.com\""
    echo ""
    echo "Reads (--get, --list, or a bare 'git config --global <key>') are never blocked."
  } >&2
  exit 2
fi

exit 0
