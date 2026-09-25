#!/usr/bin/env bash
# protect-harness.sh
# PreToolUse hook for Edit/Write AND for Bash. Blocks modifications to the
# harness's own governance surface: the hooks, the config that registers
# them, and the rules an agent is supposed to be following.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Edit|Write|MultiEdit|NotebookEdit" and with matcher "Bash".
#
# Split out of protect-critical.sh: that hook is deliberately excluded from
# install-harness.sh's portable set (it knows about lockfiles and applied
# migrations, which belong to a repository's own settings, not to something
# linked over it). This hook is the opposite case — it exists specifically to
# stop a session from reaching, by absolute path, into the SHARED HARNESS
# CHECKOUT and disarming the guard every project depends on — so it has to be
# registered everywhere, including by install-harness.sh into every adopting
# project.
#
# Rationale: install-harness.sh registers hooks in a consuming project's
# .claude/settings.local.json by ABSOLUTE PATH into the harness checkout — so
# a session running in, say, njord-back can Edit
# /Users/.../claude-spec-driven-template/baseline/hooks/protect-main.sh
# directly, no .claude/ in the path at all, and disarm the guard every project
# sharing this harness depends on. That absolute-path reach is real, not
# hypothetical, because that is how install-harness.sh wires hooks.
#
# What counts as reviewable, restated after the cross-repo rule below was
# loosened: editing a CONSUMING project's own tracked governance file from a
# session rooted somewhere else is reviewable exactly like a same-repo edit —
# it lands in THAT project's own diff and PR, whoever wrote it. It is editing
# the shared HARNESS CHECKOUT itself, from ANY session, that is never
# reviewable: per the marketplace's ADR 0003, a consuming project links
# straight into its working tree, so the edit is live in every project
# sharing it the instant it is written, with no commit and no reviewer ever
# in the loop. That is the one case this hook still blocks unconditionally
# across repos.
#
# Bash coverage, added after the fact: this hook originally only looked at
# Edit/Write payloads, so `python3 -c "..."` or a heredoc writing to
# .claude/settings.json — or `sed -i`/`tee`/`cp`/`mv`/a plain redirect
# against any other governance path — sailed straight through it. Detection
# is shared with log-edit.sh and protect-critical.sh:
# lib/bash-write-targets.py, next to this hook, is the ONE implementation of
# "what does this Bash command write to". A target it cannot resolve to a
# literal path is skipped here, not blocked — the same "never block on
# could-not-tell" posture protect-critical.sh takes, because a guard that
# blocks on confusion gets disabled outright instead of fixed. A single Bash
# command can write to MULTIPLE targets (e.g. `cp a b && mv c d`); every one
# of them is checked against the SAME governance rule below, and blocking
# stops at the first match.
#
# Session-side repository resolution (used to decide same-repo vs
# cross-repo) reads the payload's own top-level "cwd" when present, falling
# back to this process's own $PWD only when the payload omits it — never the
# reverse. A hook process's own cwd can be stale relative to what the
# session believes it is working in (a dispatched subagent's Bash tool has
# been observed keeping the ORIGINAL repo as its process cwd even when the
# payload's own "cwd" already points at a worktree), and resolving the
# session side against the wrong directory is exactly the kind of confusion
# that turned protect-unpushed.sh into a no-op once already — this hook must
# not repeat it.

set -euo pipefail

# Read JSON input from Claude Code via stdin
input=$(cat)

# Extract the file_path with python3, falling back to `python` (some Windows
# shells only have `python` on PATH, where `python3` is missing or a broken
# alias). If neither is available, this guard cannot read the payload at all
# — warn loudly on stderr and let the edit through rather than blocking every
# single Edit/Write call on this machine, which is the failure that gets a
# guard disabled outright instead of fixed.
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "WARNING: protect-harness.sh: no python3 or python on PATH — cannot read the tool payload, so this guard is DISABLED for this call. Install Python to restore it." >&2
  exit 0
fi

# NUL-separated, not line-separated: a Bash command handed to this hook can
# itself contain embedded newlines (a multi-line command, a heredoc), so a
# newline is not a safe field separator here. NUL bytes cannot live in a bash
# VARIABLE at all (command substitution strips them), so these are read
# directly off the python process's stdout via process substitution instead
# of being captured into one variable first.
tool_name=""; file_path=""; command=""; payload_cwd=""
{
  IFS= read -r -d '' tool_name || true
  IFS= read -r -d '' file_path || true
  IFS= read -r -d '' command || true
  IFS= read -r -d '' payload_cwd || true
} < <(printf '%s' "$input" | "$PYTHON_BIN" -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
ti = d.get('tool_input') or {}
for v in (d.get('tool_name') or '', d.get('file_path') or ti.get('file_path') or '', ti.get('command') or '', d.get('cwd') or ''):
    sys.stdout.write(v)
    sys.stdout.write(chr(0))
" 2>/dev/null)

# The session's own side of the same-repo/cross-repo comparison below — see
# the header note on why this prefers the payload's "cwd" over $PWD.
session_cwd="${payload_cwd:-$PWD}"

# The governance machinery itself: the hooks, the config that registers them,
# and the rules an agent is supposed to be following. Every one of these
# paths is judged by the SAME rule now — see below for why the earlier
# two-group split (config blocked always, source blocked only cross-repo) was
# wrong, not just differently organized.
governance_patterns=(
  '(^|/)\.claude/settings\.json$'
  '(^|/)\.claude/settings\.local\.json$'
  '(^|/)baseline/hooks/.*\.sh$'
  '(^|/)\.claude/hooks/.*\.sh$'
  '(^|/)baseline/rules/'
  '(^|/)\.claude/rules/'
)

_block_governance() {
  # $1 = file_path that matched, $2 = pattern that matched, $3 = extra
  # reason line (may be empty), $4 = extra context suffix for the first line
  # (may be empty — used by the Bash branch to say which command found it)
  local fp="$1" pattern="$2" reason="${3:-}" context="${4:-}"
  echo "BLOCKED by protect-harness.sh: '$fp' matches governance pattern '$pattern'$context" >&2
  echo "" >&2
  echo "This is part of the harness's own governance surface: a hook, the config" >&2
  echo "that registers hooks, or a rule agents are held to. An agent editing it" >&2
  echo "would let the supervised session disarm its own supervisor." >&2
  if [[ -n "$reason" ]]; then
    echo "" >&2
    echo "$reason" >&2
  fi
  echo "" >&2
  echo "This change is for the human operator to make outside this agent session," >&2
  echo "not something to route around from inside it. If it genuinely needs to" >&2
  echo "change, stop and ask the human to make the edit themselves." >&2
  exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
}

# Identify a git repo by its COMMON git dir, not by `rev-parse
# --show-toplevel`. Two worktrees of the SAME repo have different toplevels
# (each worktree is its own directory) but share one common git dir, so
# toplevel would report them as different repos — which is exactly backwards
# for this hook's purpose (a feature-branch worktree editing this repo's own
# hooks must still count as "same repo") and is how this very task was
# carried out.
_repo_id() {
  local dir="$1" common_dir rel
  [[ -d "$dir" ]] || return 1
  common_dir=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || true
  if [[ -z "$common_dir" ]]; then
    # Fallback for git < 2.31, which has no --path-format and may print a
    # path relative to $dir instead of absolute.
    rel=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
    [[ -n "$rel" ]] || return 1
    if [[ "$rel" = /* ]]; then common_dir="$rel"; else common_dir="$dir/$rel"; fi
  fi
  # Canonicalize (resolve any ".." left in the path) so two different
  # spellings of the same directory compare equal.
  (cd "$common_dir" 2>/dev/null && pwd) || return 1
}

# Is a repo (given its WORKTREE TOPLEVEL, not its common git dir) the harness
# checkout itself, as opposed to an ordinary project that merely links into
# one? Judged structurally: its root holds both install-harness.sh and a
# baseline/ directory, the two things every harness checkout has and no
# consuming project does.
#
# Two alternatives were considered and rejected:
#   - A hardcoded absolute path (this machine's own
#     .../claude-spec-driven-template) works for exactly one person's one
#     clone and breaks for every fork, every other developer, and CI.
#   - Resolving the .claude/rules/harness symlink only says whether the
#     CWD repo is LINKED to a harness; it says nothing about the TARGET
#     repo, which is the side this check needs to classify, and it is
#     silent for a session rooted in the harness checkout itself (there is
#     no symlink to resolve — the rules live there directly).
# The structural test is two cheap `-f`/`-d` stats, no subshell and no git
# call, and it classifies any harness checkout anywhere, on this machine or
# anyone else's.
_is_harness_checkout() {
  # $1 = a repo's WORKTREE TOPLEVEL (not its common git dir — install-
  # harness.sh and baseline/ live in the working tree, not in .git). If the
  # directory cannot be read at all, both tests report false and this
  # classifies as "not a harness checkout" — but that path is only reached
  # after the caller already failed closed on an unresolvable toplevel, so
  # an unreadable structure never silently falls through to a pass.
  local root="$1"
  [[ -f "$root/install-harness.sh" && -d "$root/baseline" ]]
}

# $1 = file_path. Run from the file's own directory so this resolves the
# same way whether file_path is relative or absolute, and whether or not the
# file exists yet — check-ignore works on paths, not inodes.
_is_gitignored() {
  git -C "$(dirname -- "$1")" check-ignore -q -- "$1" >/dev/null 2>&1
}

# $1 = file_path, $2 = extra context suffix for the block message (may be
# empty, e.g. " (found via Bash: Bash:redirect)"). Exits 2 (blocks) the same
# way _block_governance always has; returns normally (falls through, caller
# continues checking the next target) when the path passes.
_check_path() {
  local file_path="$1" context="${2:-}"
  [[ -n "$file_path" ]] || return 0

  # .env.example / .env.test.example / etc are templates whose entire purpose
  # is to hold NO secret. The same exemption applies here so a
  # governance-shaped template — e.g. .claude/settings.json.example — is not
  # treated the same as the real file it documents. Matched by FILENAME
  # before the governance patterns below ever see it.
  if echo "$file_path" | grep -qE '\.example$'; then
    return 0
  fi

  # Only pay for git subprocess calls once a governance pattern has actually
  # matched — a path that is not governance must not pay anything here,
  # since this hook runs on every Edit/Write/Bash call in the session.
  local matched_pattern="" pattern
  for pattern in "${governance_patterns[@]}"; do
    if echo "$file_path" | grep -qE "$pattern"; then
      matched_pattern="$pattern"
      break
    fi
  done

  [[ -n "$matched_pattern" ]] || return 0

  # Degraded-environment policy, decided and fixed here rather than left to
  # fall out of whatever git happens to return: every case where this hook
  # CANNOT positively confirm "same repo" or "not a harness checkout" fails
  # CLOSED (blocks). The alternative — pass when uncertain — would make the
  # exact cross-repo attack this hook exists to stop into a silent bypass on
  # any machine missing git, or for any target path that does not yet exist.
  # A false positive here costs one blocked edit and a human decision; a
  # false negative here is a disarmed shared guard.
  #   - git missing from PATH entirely: cannot resolve either side -> block.
  #   - session_cwd is not inside a git repo: cannot resolve the session's
  #     side -> block.
  #   - target's directory does not exist or is not inside a git repo
  #     (includes writing a brand-new file into a brand-new, not-yet-created
  #     directory): cannot resolve the target's side -> block.
  #   - target's repo toplevel cannot be resolved (needed only cross-repo, to
  #     classify the target as a harness checkout or not): block.
  if ! command -v git >/dev/null 2>&1; then
    _block_governance "$file_path" "$matched_pattern" \
      "Could not verify this is a same-repo edit: no 'git' on PATH. Failing closed." "$context"
  fi

  local cwd_repo target_repo
  cwd_repo="$(_repo_id "$session_cwd" || true)"
  target_repo="$(_repo_id "$(dirname -- "$file_path")" || true)"

  if [[ -z "$cwd_repo" || -z "$target_repo" ]]; then
    _block_governance "$file_path" "$matched_pattern" \
      "Could not verify this is a same-repo edit: the session's cwd or the target's directory is not inside a resolvable git repository. Failing closed." "$context"
  fi

  if [[ "$cwd_repo" != "$target_repo" ]]; then
    # Cross-repo edit. What actually makes THIS unsafe is not "different
    # repo" by itself — it is whether the TARGET is the shared harness
    # checkout (see the header for why that one repo is never reviewable
    # from any session) versus an ordinary consuming project, whose own
    # tracked governance file is reviewed exactly like a same-repo edit: in
    # THAT project's own diff and PR, regardless of which repo the session
    # editing it happened to start in.
    local target_toplevel
    target_toplevel="$(git -C "$(dirname -- "$file_path")" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$target_toplevel" ]]; then
      _block_governance "$file_path" "$matched_pattern" \
        "Could not verify whether the target repository is a harness checkout ('git rev-parse --show-toplevel' failed on the target's directory). Failing closed." "$context"
    fi

    if _is_harness_checkout "$target_toplevel"; then
      _block_governance "$file_path" "$matched_pattern" \
        "The target is inside a HARNESS CHECKOUT (a repo root holding both install-harness.sh and a baseline/ directory), edited from a different repository. Per the marketplace's ADR 0003, a consuming project links straight into a harness checkout's working tree, so this edit would be live in every project sharing it the moment it is written, no commit, no PR, no reviewer. This is the one case that stays blocked across repos regardless of which repo the session started in." "$context"
    fi
    # Target is an ordinary consuming project, not the harness itself: falls
    # through to the same gitignored check every same-repo edit gets below.
  fi

  if _is_gitignored "$file_path"; then
    _block_governance "$file_path" "$matched_pattern" \
      "This path is gitignored in its own repository — it would never appear in a 'git diff' or a PR there, so no reviewer would ever see the change. Gitignored is worse than new: a brand-new file still lands in a commit and a diff. Failing closed." "$context"
  else
    local ignore_rc=$?
    if [[ "$ignore_rc" -ne 1 ]]; then
      _block_governance "$file_path" "$matched_pattern" \
        "Could not determine whether this path is gitignored ('git check-ignore' exited $ignore_rc, expected 0 or 1). Failing closed." "$context"
    fi
    # exit 1 from check-ignore: genuinely not ignored (tracked, or untracked
    # but not covered by any .gitignore pattern) -> reviewable -> pass.
  fi
  return 0
}

if [[ "$tool_name" == "Bash" ]]; then
  [[ -n "$command" ]] || exit 0
  LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib/bash-write-targets.py"
  targets=$(printf '%s' "$input" | "$PYTHON_BIN" "$LIB" 2>/dev/null || echo "")
  while IFS=$'\t' read -r kind target; do
    [[ -n "$kind" ]] || continue
    [[ "$target" != "?" ]] || continue  # unresolvable: skip, never block on "could not tell"
    _check_path "$target" " (found via Bash: $kind)"
  done <<< "$targets"
  exit 0
fi

_check_path "$file_path"
exit 0
