#!/usr/bin/env bash
# block-new-em-dashes.test.sh
# Standalone fixture suite for baseline/hooks/block-new-em-dashes.sh. Feeds the
# hook synthetic JSON-on-stdin payloads shaped like Claude Code's Edit/Write/
# MultiEdit PreToolUse calls, builds real fixture files on disk (the hook reads
# the CURRENT file content itself to compute the before-count), and asserts
# the exit code (2 = blocked, 0 = passes).
#
# Run: bash baseline/hooks/tests/block-new-em-dashes.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
HOOK="$SCRIPT_DIR/../block-new-em-dashes.sh"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "block-new-em-dashes.test.sh: no python3 or python on PATH, cannot build test payloads" >&2
  exit 1
fi

# Canonicalize: on macOS, mktemp -d returns a /var/folders path that is
# itself a symlink to /private/var/folders. This hook's own Python side
# resolves file_path with a plain open(), which does not care about the
# symlink, but keeping the fixture root canonical here avoids any string
# comparison surprise if a future case starts comparing paths directly.
TMPDIR_ROOT="$(mktemp -d)"
TMPDIR_ROOT="$(cd "$TMPDIR_ROOT" && pwd -P)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_run() {
  # $1 = name, $2 = expected exit code, $3 = JSON payload (already built)
  local name="$1" expected="$2" payload="$3"
  local actual
  actual=$(printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (exit $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name (expected $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

_write_payload() {
  # $1 = file_path, $2 = content
  "$PYTHON_BIN" -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}}))
' "$1" "$2"
}

_edit_payload() {
  # $1 = file_path, $2 = old_string, $3 = new_string, $4 = replace_all (true/false, optional)
  "$PYTHON_BIN" -c '
import json, sys
ra = len(sys.argv) > 4 and sys.argv[4] == "true"
ti = {"file_path": sys.argv[1], "old_string": sys.argv[2], "new_string": sys.argv[3]}
if ra:
    ti["replace_all"] = True
print(json.dumps({"tool_name": "Edit", "tool_input": ti}))
' "$1" "$2" "$3" "${4:-}"
}

_multiedit_payload_2() {
  # $1 = file_path, $2 = old1, $3 = new1, $4 = old2, $5 = new2
  "$PYTHON_BIN" -c '
import json, sys
edits = [
    {"old_string": sys.argv[2], "new_string": sys.argv[3]},
    {"old_string": sys.argv[4], "new_string": sys.argv[5]},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": sys.argv[1], "edits": edits}}))
' "$1" "$2" "$3" "$4" "$5"
}

EM="—"   # U+2014, the character this hook detects
EN="–"   # U+2013, deliberately NOT covered (see hook header)

# --- 1: Write of a brand-new file without an em-dash passes ---
f1="$TMPDIR_ROOT/1.md"
_run "1: Write new file without em-dash passes" 0 \
  "$(_write_payload "$f1" "plain sentence, no dash here.")"

# --- 2: Write of a brand-new file WITH an em-dash blocks ---
f2="$TMPDIR_ROOT/2.md"
_run "2: Write new file with em-dash blocks" 2 \
  "$(_write_payload "$f2" "a sentence ${EM} with a dash.")"

# --- 3: Write overwriting a file that had 3 em-dashes with content that has the same 3 passes ---
f3="$TMPDIR_ROOT/3.md"
printf 'a %s b %s c %s d\n' "$EM" "$EM" "$EM" > "$f3"
_run "3: Write with same em-dash count as current file passes" 0 \
  "$(_write_payload "$f3" "a ${EM} b ${EM} c ${EM} d, reformatted")"

# --- 4: Edit swapping a plain sentence for another plain sentence passes, even though the file has em-dashes elsewhere (debt does not block) ---
f4="$TMPDIR_ROOT/4.md"
printf 'kept line has a dash %s here.\nreplace this plain line.\n' "$EM" > "$f4"
_run "4: Edit of an unrelated plain line passes despite debt elsewhere" 0 \
  "$(_edit_payload "$f4" "replace this plain line." "this plain line is now different.")"

# --- 5: Edit that ADDS an em-dash blocks ---
f5="$TMPDIR_ROOT/5.md"
printf 'a plain line.\n' > "$f5"
_run "5: Edit adding an em-dash blocks" 2 \
  "$(_edit_payload "$f5" "a plain line." "a line ${EM} with a dash.")"

# --- 6: Edit that REMOVES an em-dash passes ---
f6="$TMPDIR_ROOT/6.md"
printf 'a line %s with a dash.\n' "$EM" > "$f6"
_run "6: Edit removing an em-dash passes" 0 \
  "$(_edit_payload "$f6" "a line ${EM} with a dash." "a line, now without one.")"

# --- 7: Edit with replace_all multiplying an em-dash-bearing snippet blocks ---
f7="$TMPDIR_ROOT/7.md"
printf 'x %s y\nx %s y\n' "$EM" "$EM" > "$f7"
_run "7: Edit replace_all multiplying an em-dash snippet blocks" 2 \
  "$(_edit_payload "$f7" "x ${EM} y" "x ${EM} y ${EM} z" "true")"

# --- 8: MultiEdit where one edit removes and another adds, net zero, passes ---
f8="$TMPDIR_ROOT/8.md"
printf 'first line %s has a dash.\nsecond line is plain.\n' "$EM" > "$f8"
_run "8: MultiEdit net-zero em-dash change passes" 0 \
  "$(_multiedit_payload_2 "$f8" \
      "first line ${EM} has a dash." "first line has no dash." \
      "second line is plain." "second line ${EM} now has one.")"

# --- 9: a .sh file gaining a new em-dash passes: out of scope ---
f9="$TMPDIR_ROOT/9.sh"
printf '#!/usr/bin/env bash\necho hi\n' > "$f9"
_run "9: .sh file with new em-dash passes (out of scope)" 0 \
  "$(_write_payload "$f9" "#!/usr/bin/env bash
echo hi ${EM} there")"

# --- 10: old_string not found: exits 0 and lets Edit fail on its own ---
f10="$TMPDIR_ROOT/10.md"
printf 'the only line here.\n' > "$f10"
_run "10: old_string not found exits 0" 0 \
  "$(_edit_payload "$f10" "this text is not in the file" "replacement")"

# --- 11: malformed payload exits 0 ---
_run "11: malformed JSON payload exits 0" 0 "not valid json at all"

# --- 12: en-dash (U+2013) is NOT covered by this hook: a new en-dash passes ---
# Decision, documented in the hook's own header: AGENTS.md's rule names
# "em-dashes" specifically, and en-dash has legitimate uses in this repo's
# prose (numeric ranges) that are a different typographic question. Only
# widen this hook's scope if AGENTS.md's convention line itself is widened.
f12="$TMPDIR_ROOT/12.md"
_run "12: Write introducing a new en-dash passes (out of scope by design)" 0 \
  "$(_write_payload "$f12" "see pages 10${EN}20 for details.")"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
