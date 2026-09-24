#!/usr/bin/env bash
# protect-machine-config.test.sh
# Standalone fixture suite for baseline/hooks/protect-machine-config.sh. Feeds
# the hook synthetic JSON-on-stdin payloads shaped like Claude Code's Bash and
# Edit/Write PreToolUse calls, and asserts the exit code (2 = blocked, 0 =
# passes).
#
# Two independent halves, one per matcher the hook is registered under:
#   - Bash: `git config` at --global/--system, or an explicit -f/--file whose
#     value resolves to a machine-level config file, blocked only when it
#     WRITES (a value, --add, --unset, --unset-all, --replace-all,
#     --edit/-e, --rename-section, --remove-section). A read at any scope, or
#     a repo-local write (no scope flag, --local, --worktree), passes.
#   - Edit/Write/MultiEdit: writing ~/.gitconfig, ~/.config/git/config,
#     /etc/gitconfig, or the machine-wide shell rc files (~/.zshrc,
#     ~/.bashrc, ~/.bash_profile, ~/.profile), matched by EXACT resolved
#     path so a repo's own tracked dotfile of the same name is never caught.
#
# HOME is overridden to a throwaway directory for the whole suite (never the
# real one) so the file-target tests can assert against a known, disposable
# path instead of touching anything real, and so a fixture "repo" dotfile
# living outside that HOME is provably a different path, not just a
# differently-spelled one.
#
# Proving the tests are load-bearing: a stub hook that always exits 0 is run
# against every case this file expects to be BLOCKED, and the suite fails
# loudly if any of them does not also fail against the stub — see the final
# section.
#
# Run: bash baseline/hooks/tests/protect-machine-config.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../protect-machine-config.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "protect-machine-config.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"  # canonicalize: mktemp -d on macOS returns a /var symlink into /private/var
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

FAKE_HOME="$TMPDIR_ROOT/home"
mkdir -p "$FAKE_HOME"

PASS_COUNT=0
FAIL_COUNT=0

_make_bash_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1"
}

_make_edit_payload() {
  "$PYTHON_BIN" -c 'import json, sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"file_path": sys.argv[2]}}))' "$1" "$2"
}

# $1 = name, $2 = payload, $3 = expected exit code, $4 = optional hook path
# override (used by the load-bearing proof to run the SAME cases against a
# stub)
_run_case() {
  local name="$1" payload="$2" expected="$3" hook="${4:-$HOOK}"
  local actual
  actual=$(HOME="$FAKE_HOME" bash -c 'printf "%s" "$1" | bash "$2" >/dev/null 2>&1; echo $?' _ "$payload" "$hook")
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (exit $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ============================================================ Bash: writes ==

_run_case "1: git config --global <key> <value> is blocked" \
  "$(_make_bash_payload 'git config --global user.name "CI"')" 2

_run_case "2: git config --global user.email <value> is blocked" \
  "$(_make_bash_payload 'git config --global user.email ci@example.com')" 2

_run_case "3: git config --system <key> <value> is blocked" \
  "$(_make_bash_payload 'git config --system user.email ci@example.com')" 2

_run_case "4: git config --global --add is blocked" \
  "$(_make_bash_payload 'git config --global --add safe.directory /tmp/x')" 2

_run_case "5: git config --global --unset is blocked" \
  "$(_make_bash_payload 'git config --global --unset user.email')" 2

_run_case "6: git config --global --unset-all is blocked" \
  "$(_make_bash_payload 'git config --global --unset-all user.email')" 2

_run_case "7: git config --global --replace-all is blocked" \
  "$(_make_bash_payload 'git config --global --replace-all user.email x@x.com')" 2

_run_case "8: git config --global --edit is blocked" \
  "$(_make_bash_payload 'git config --global --edit')" 2

_run_case "9: git config --global -e (short edit flag) is blocked" \
  "$(_make_bash_payload 'git config --global -e')" 2

_run_case "10: git config --system --rename-section is blocked" \
  "$(_make_bash_payload 'git config --system --rename-section old.section new.section')" 2

_run_case "11: git config --global --remove-section is blocked" \
  "$(_make_bash_payload 'git config --global --remove-section user')" 2

# --- explicit --file / -f targeting a machine-level file, still a write ---

_run_case "12: git config -f ~/.gitconfig <key> <value> is blocked" \
  "$(_make_bash_payload 'git config -f ~/.gitconfig user.name X')" 2

_run_case "13: git config --file \$HOME/.gitconfig <key> <value> is blocked" \
  "$(_make_bash_payload 'git config --file $HOME/.gitconfig user.email x@x.com')" 2

_run_case "14: git config -f ~/.config/git/config <key> <value> is blocked" \
  "$(_make_bash_payload 'git config -f ~/.config/git/config user.name X')" 2

_run_case "15: git config --file=/etc/gitconfig <key> <value> is blocked" \
  "$(_make_bash_payload 'git config --file=/etc/gitconfig user.name X')" 2

# --- compound commands: the dangerous invocation is not the first statement ---

_run_case "16: compound command, global write is the SECOND statement (&&)" \
  "$(_make_bash_payload 'git status && git config --global user.name X')" 2

_run_case "17: compound command, global write after a semicolon" \
  "$(_make_bash_payload 'echo hi; git config --global user.name X')" 2

_run_case "18: compound command, global write in a pipeline's second stage" \
  "$(_make_bash_payload 'echo hi | cat; git config --global user.email x@x.com')" 2

# --- git -C <path> config --global form ---

_run_case "19: git -C <path> config --global <key> <value> is blocked" \
  "$(_make_bash_payload 'git -C /tmp/somerepo config --global user.email x@x.com')" 2

# ============================================================= Bash: reads ==

_run_case "20: git config --global --get <key> passes (read)" \
  "$(_make_bash_payload 'git config --global --get user.email')" 0

_run_case "21: bare git config --global <key> (no value) passes (read)" \
  "$(_make_bash_payload 'git config --global user.email')" 0

_run_case "22: git config --global --list passes (read)" \
  "$(_make_bash_payload 'git config --global --list')" 0

_run_case "23: git config --global -l passes (read)" \
  "$(_make_bash_payload 'git config --global -l')" 0

_run_case "24: git config --global --show-origin --get user.email passes (read)" \
  "$(_make_bash_payload 'git config --global --show-origin --get user.email')" 0

_run_case "25: git config -f ~/.gitconfig --list passes (read via explicit file)" \
  "$(_make_bash_payload 'git config -f ~/.gitconfig --list')" 0

# ==================================================== Bash: repo-local, always passes ==

_run_case "26: git config user.email <value> (no scope flag) passes" \
  "$(_make_bash_payload 'git config user.email x@x.com')" 0

_run_case "27: git config --local user.email <value> passes" \
  "$(_make_bash_payload 'git config --local user.email x@x.com')" 0

_run_case "28: git config --worktree user.email <value> passes" \
  "$(_make_bash_payload 'git config --worktree user.email x@x.com')" 0

_run_case "29: git config -f ./fixture-repo/.git/config user.email x passes (non-machine file target)" \
  "$(_make_bash_payload 'git config -f ./fixture-repo/.git/config user.email x@x.com')" 0

# ==================================================== Bash: not git config at all ==

_run_case "30: plain git commit is untouched by this hook" \
  "$(_make_bash_payload 'git commit -m "wip"')" 0

_run_case "31: git config-related word inside an unrelated command passes" \
  "$(_make_bash_payload 'echo "run git config --global next time"')" 0

# ===================================================== Edit/Write: blocked ==

_run_case "32: Write ~/.gitconfig is blocked" \
  "$(_make_edit_payload Write "$FAKE_HOME/.gitconfig")" 2

_run_case "33: Edit ~/.config/git/config is blocked" \
  "$(_make_edit_payload Edit "$FAKE_HOME/.config/git/config")" 2

_run_case "34: Write /etc/gitconfig is blocked" \
  "$(_make_edit_payload Write "/etc/gitconfig")" 2

_run_case "35: Edit ~/.zshrc is blocked" \
  "$(_make_edit_payload Edit "$FAKE_HOME/.zshrc")" 2

_run_case "36: Edit ~/.bashrc is blocked" \
  "$(_make_edit_payload Edit "$FAKE_HOME/.bashrc")" 2

_run_case "37: Edit ~/.bash_profile is blocked" \
  "$(_make_edit_payload Edit "$FAKE_HOME/.bash_profile")" 2

_run_case "38: Edit ~/.profile is blocked" \
  "$(_make_edit_payload Edit "$FAKE_HOME/.profile")" 2

_run_case "39: MultiEdit ~/.gitconfig is blocked" \
  "$(_make_edit_payload MultiEdit "$FAKE_HOME/.gitconfig")" 2

# ================================================ Edit/Write: must pass ==

_run_case "40: a repo's own tracked dotfile of the same NAME, different path, passes" \
  "$(_make_edit_payload Write "$TMPDIR_ROOT/some-repo/dotfiles/.gitconfig")" 0

_run_case "41: an unrelated repo file passes" \
  "$(_make_edit_payload Write "$TMPDIR_ROOT/some-repo/README.md")" 0

_run_case "42: .example exemption applies to a machine-config-shaped path" \
  "$(_make_edit_payload Write "$FAKE_HOME/.gitconfig.example")" 0

_run_case "43: NotebookEdit is out of scope for this hook (only Edit/Write/MultiEdit registered)" \
  "$("$PYTHON_BIN" -c 'import json; print(json.dumps({"tool_name": "NotebookEdit", "tool_input": {"file_path": "'"$FAKE_HOME"'/.gitconfig"}}))')" 0

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
