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
# the real file it documents. Matched by FILENAME before the governance
# patterns below ever see it.
if echo "$file_path" | grep -qE '\.example$'; then
  exit 0
fi

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

# Only pay for git subprocess calls once a governance pattern has actually
# matched — a path that is not governance must not pay anything here, since
# this hook runs on every Edit/Write in the session.
matched_pattern=""
for pattern in "${governance_patterns[@]}"; do
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
  # attack this hook exists to stop into a silent bypass on any machine
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

  # Same repo (including two worktrees of it): the earlier version of this
  # hook stopped here and let same-repo through unconditionally for source,
  # while blocking .claude/settings*.json unconditionally regardless of repo.
  # That was backwards. What actually makes an edit safe is not WHERE it
  # happens but whether a human reviewer will ever see it: this repo's own
  # PR process is a real check ONLY for a path that shows up in a diff.
  #
  #   - .claude/settings.json is tracked: an edit here is a line in `git
  #     diff`, and the PR that carries it is the review. Blocking it
  #     unconditionally bought nothing but friction — meanwhile
  #     baseline/hooks/*.sh, arguably more dangerous (it IS the guard code),
  #     passed same-repo with no review requirement at all. An agent could
  #     already rewrite protect-main.sh to `exit 0` in this very repo; a
  #     stricter rule on the config that merely REGISTERS that hook was
  #     protecting something weaker than what it left open next to it.
  #   - .claude/settings.local.json is gitignored: an edit here is invisible
  #     to `git diff`, invisible to the PR, invisible to any reviewer who
  #     only looks at what git tracks. Same-repo does not make this safe —
  #     it makes it undetectable, which is worse than a change nobody has
  #     reviewed YET (a new file). A brand-new governance file that does not
  #     exist on disk yet is not gitignored (unless a .gitignore pattern
  #     already covers it): it will be `git add`-ed and appear in the PR
  #     diff like any other new file, so creating one passes here — only a
  #     path a .gitignore pattern actually excludes is judged unreviewable.
  #
  # git check-ignore is the right test, not "is it tracked yet": a brand-new
  # rule or hook is untracked (it is not in the index) but not ignored, and
  # blocking on "untracked" would stop the exact workflow that created THIS
  # hook. Only a path matched by a .gitignore pattern is judged unreviewable.
  _is_gitignored() {
    # $1 = file_path. Run from the file's own directory so this resolves the
    # same way whether file_path is relative or absolute, and whether or not
    # the file exists yet — check-ignore works on paths, not inodes.
    git -C "$(dirname -- "$1")" check-ignore -q -- "$1" >/dev/null 2>&1
  }

  if _is_gitignored "$file_path"; then
    _block_governance "$matched_pattern" \
      "This path is in the SAME repo but is gitignored — it would never appear in a 'git diff' or a PR, so no reviewer would ever see the change. Gitignored is worse than new: a brand-new file still lands in a commit and a diff. Failing closed."
  else
    ignore_rc=$?
    if [[ "$ignore_rc" -ne 1 ]]; then
      _block_governance "$matched_pattern" \
        "Could not determine whether this path is gitignored ('git check-ignore' exited $ignore_rc, expected 0 or 1). Failing closed."
    fi
    # exit 1 from check-ignore: genuinely not ignored (tracked, or untracked
    # but not covered by any .gitignore pattern) -> reviewable -> pass.
  fi
fi

exit 0
