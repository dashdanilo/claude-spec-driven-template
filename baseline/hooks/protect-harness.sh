#!/usr/bin/env bash
# protect-harness.sh
# PreToolUse hook for Edit and Write. Blocks modifications to the harness's own
# governance surface: the hooks, the config that registers them, and the rules
# an agent is supposed to be following.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Edit|Write|MultiEdit|NotebookEdit".
#
# Split out of protect-critical.sh: that hook is deliberately excluded from
# install-harness.sh's portable set (it knows about lockfiles and applied
# migrations, which belong to a repository's own settings, not to something
# linked over it). This hook is the opposite case — it exists specifically to
# stop a session in a CONSUMING project from reaching across, by absolute
# path, into the shared harness checkout and disarming the guard every project
# depends on — so it has to be registered everywhere, including by
# install-harness.sh into every adopting project.
#
# Rationale: install-harness.sh registers hooks in a consuming project's
# .claude/settings.local.json by ABSOLUTE PATH into the harness checkout — so
# a session running in, say, njord-back can Edit
# /Users/.../claude-spec-driven-template/baseline/hooks/protect-main.sh
# directly, no .claude/ in the path at all, and disarm the guard every project
# sharing this harness depends on. That absolute-path reach is real, not
# hypothetical, because that is how install-harness.sh wires hooks.

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

# Extract the file_path from JSON (Edit and Write both have file_path in tool_input)
file_path=$(printf '%s' "$input" | "$PYTHON_BIN" -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input') or {};print(d.get('file_path') or ti.get('file_path') or '')" 2>/dev/null || echo "")

if [[ -z "$file_path" ]]; then
  exit 0
fi

# .env.example / .env.test.example / etc are templates whose entire purpose is
# to hold NO secret. The same exemption applies here so a governance-shaped
# template — e.g. .claude/settings.json.example — is not treated the same as
# the real file it documents. Matched by FILENAME before either governance
# group below ever sees it.
if echo "$file_path" | grep -qE '\.example$'; then
  exit 0
fi

# The governance machinery itself: the hooks, the config that registers them,
# and the rules an agent is supposed to be following. Split into two groups
# with different blocking rules, because "governance" means two different
# things in THIS repo (the harness's own source checkout):
#
#   Group A — runtime config that registers hooks (.claude/settings.json,
#   .claude/settings.local.json). Blocked unconditionally, in every repo, no
#   exceptions: this file IS the trust boundary. Editing it changes what the
#   CURRENT session's hooks do, in the same repo the session is already in —
#   there is no "same repo, so it's fine" here, because same-repo is exactly
#   the attack.
#
#   Group B — governance SOURCE CODE (baseline/hooks/*.sh, .claude/hooks/*.sh,
#   baseline/rules/**, .claude/rules/**). In THIS repo, baseline/hooks/ and
#   baseline/rules/ are the product being built, not installed governance —
#   editing protect-harness.sh on a feature branch, behind this repo's own
#   PR and review, is the intended workflow (this file was edited exactly
#   that way for this task). What has to be blocked instead is a DIFFERENT
#   repo reaching in: install-harness.sh registers hooks in a consuming
#   project's .claude/settings.local.json by ABSOLUTE PATH into this
#   checkout's baseline/hooks/ — so a session running in, say, njord-back can
#   Edit /Users/.../claude-spec-driven-template/baseline/hooks/protect-main.sh
#   directly, no .claude/ in the path at all, and disarm the guard every
#   project sharing this harness depends on. That absolute-path reach is real,
#   not hypothetical, because that is how install-harness.sh wires hooks.
#
#   Group B is therefore blocked only when the session's cwd and the edited
#   file resolve to DIFFERENT git repositories, and allowed when they are the
#   SAME repo (that edit is governed by that repo's own PR process, which is
#   this hook's job to stay out of).
governance_config_patterns=(
  '(^|/)\.claude/settings\.json$'
  '(^|/)\.claude/settings\.local\.json$'
)

governance_source_patterns=(
  '(^|/)baseline/hooks/.*\.sh$'
  '(^|/)\.claude/hooks/.*\.sh$'
  '(^|/)baseline/rules/'
  '(^|/)\.claude/rules/'
)

_block_governance() {
  # $1 = pattern that matched, $2 = extra reason line (may be empty)
  echo "BLOCKED by protect-harness.sh: '$file_path' matches governance pattern '$1'" >&2
  echo "" >&2
  echo "This is part of the harness's own governance surface: a hook, the config" >&2
  echo "that registers hooks, or a rule agents are held to. An agent editing it" >&2
  echo "would let the supervised session disarm its own supervisor." >&2
  if [[ -n "${2:-}" ]]; then
    echo "" >&2
    echo "$2" >&2
  fi
  echo "" >&2
  echo "This change is for the human operator to make outside this agent session," >&2
  echo "not something to route around from inside it. If it genuinely needs to" >&2
  echo "change, stop and ask the human to make the edit themselves." >&2
  exit 2  # 2 = block. Exit 1 is a non-blocking error: the tool call proceeds.
}

for pattern in "${governance_config_patterns[@]}"; do
  if echo "$file_path" | grep -qE "$pattern"; then
    _block_governance "$pattern" ""
  fi
done

# Only pay for git subprocess calls when the path already matched a Group B
# pattern — a path that is not governance source must not pay anything here,
# since this hook runs on every Edit/Write in the session.
matched_pattern=""
for pattern in "${governance_source_patterns[@]}"; do
  if echo "$file_path" | grep -qE "$pattern"; then
    matched_pattern="$pattern"
    break
  fi
done

if [[ -n "$matched_pattern" ]]; then
  # Identify a git repo by its COMMON git dir, not by `rev-parse
  # --show-toplevel`. Two worktrees of the SAME repo have different
  # toplevels (each worktree is its own directory) but share one common git
  # dir, so toplevel would report them as different repos — which is exactly
  # backwards for this hook's purpose (a feature-branch worktree editing this
  # repo's own hooks must still count as "same repo") and is how this very
  # task was carried out.
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

  # Degraded-environment policy, decided and fixed here rather than left to
  # fall out of whatever git happens to return: every case where this hook
  # CANNOT positively confirm "same repo" fails CLOSED (blocks). The
  # alternative — pass when uncertain — would make the exact cross-repo
  # attack this group exists to stop into a silent bypass on any machine
  # missing git, or for any target path that does not yet exist. A false
  # positive here costs one blocked edit and a human decision; a false
  # negative here is a disarmed shared guard.
  #   - git missing from PATH entirely: cannot resolve either side -> block.
  #   - cwd is not inside a git repo: cannot resolve the session's side -> block.
  #   - target's directory does not exist or is not inside a git repo
  #     (includes writing a brand-new file into a brand-new, not-yet-created
  #     directory): cannot resolve the target's side -> block.
  if ! command -v git >/dev/null 2>&1; then
    _block_governance "$matched_pattern" \
      "Could not verify this is a same-repo edit: no 'git' on PATH. Failing closed."
  fi

  cwd_repo="$(_repo_id "$PWD" || true)"
  target_repo="$(_repo_id "$(dirname -- "$file_path")" || true)"

  if [[ -z "$cwd_repo" || -z "$target_repo" ]]; then
    _block_governance "$matched_pattern" \
      "Could not verify this is a same-repo edit: the session's cwd or the target's directory is not inside a resolvable git repository. Failing closed."
  elif [[ "$cwd_repo" != "$target_repo" ]]; then
    _block_governance "$matched_pattern" \
      "The session is in a different git repository than the file being edited — this looks like an absolute-path reach into another repo's governance surface, not a same-repo change under that repo's own review."
  fi
  # Same repo (including two worktrees of it): fall through, not blocked.
fi

exit 0
