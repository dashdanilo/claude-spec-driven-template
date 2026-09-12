#!/usr/bin/env bash
# log-edit.sh
# Observability hook. Appends one line to .claude/tool-log.txt every time a
# file is written, recording WHICH THREAD did it — whether the write came
# through Edit/Write/MultiEdit/NotebookEdit, or through Bash.
#
# Wire on PreToolUse for Edit|Write|MultiEdit|NotebookEdit AND for Bash. Never
# blocks (always exit 0, no decision output). The log is gitignored.
#
# Why this exists: `.claude/rules/delegation.md` says the main thread
# coordinates and specialists implement. On a real project that rule was
# already written and 71% of Edit calls still happened in the main thread. A
# rule you cannot see being broken is a rule that decays. This makes it
# countable, and `/harness-report` makes it visible.
#
# Why Bash too, added after the fact: this hook originally only watched
# Edit/Write/MultiEdit/NotebookEdit, so a write done through Bash — a
# redirect, `sed -i`, `tee`, `cp`, `mv` — was invisible to it. Measured
# consequence, recorded in baseline/docs/harness-baseline.md's 2026-09-10 A/B:
# a run whose orchestrator edited its own tracked documents through Bash
# reported 100% delegation, an artifact of the blind spot, not a real number.
# The metric erred OPTIMISTIC — the worse direction for something whose whole
# job is to say whether the harness is being used as designed.
#
# Thread detection (unchanged from before this file grew a Bash branch): read
# the payload directly rather than inferring from `transcript_path`. A
# subagent's `PreToolUse` payload carries `agent_id` (and usually
# `agent_type`) — that alone means "sub", regardless of what `transcript_path`
# points at. Measured: a captured payload from inside an `implementer`
# subagent had `transcript_path` pointing at the *main* session's transcript
# (no `subagents` segment anywhere in it) while `agent_id` and `agent_type`
# were both present. The old heuristic — "sub" only when `transcript_path`
# contains a `subagents` segment, "main" otherwise — read that as `main`, so
# every specialist edit was silently counted as main-thread work, one
# direction only. `?` is reserved for the one case with neither signal: no
# `agent_id` and no `transcript_path` at all.
#
# --- Bash write detection -----------------------------------------------
#
# Not a full shell parser, and it does not try to be one. It is a small
# character-level lexer that:
#   - tracks single/double quote state, so a `>` inside a quoted string (a
#     commit message, an echoed sentence) is text, never an operator;
#   - recognizes the write-relevant redirect operators `>` and `>>`, and
#     explicitly does NOT treat `2>`, `2>>`, `&>`, `&>>` or `>&` as file
#     writes — those are stderr-to-fd or combined-stream redirects
#     (`2>&1` chief among them), not "a new file appeared";
#   - recognizes `sed -i`, `tee`, `cp`, `mv` as write commands by their first
#     word, and reads their target argument(s) off the token stream;
#   - skips `[[ ... ]]` and `(( ... ))` entirely, so a shell string/numeric
#     comparison that happens to contain a literal `>` is never mistaken for
#     a redirect.
#
# Only a target that RESOLVES INSIDE THE REPO (the hook's own cwd) is logged.
# This is the one rule that keeps the noise out: it silently drops
# `/dev/null`, `2>&1` (no file target at all), anything under `/tmp`, the
# session scratchpad, or any other path outside the project — and it does so
# with a single check instead of an ever-growing exclude list, because it
# matches what the metric actually measures: editing the project.
#
# A target this lexer cannot resolve to a literal path — built from a shell
# variable (`$VAR`) or a command substitution (`$(...)`, backticks), or
# containing a glob (`*`, `?`) — is NOT dropped. It is logged with `path`
# equal to the literal string `?`. This matters more than it looks: the
# delegation metric needs THREAD + COUNT, not the path. The thread comes from
# the payload (known regardless of the target), so a write to an unresolvable
# target still corrects the count; it only drops out of `harness-report.sh`'s
# by-extension breakdown, which is explicitly called out as ignoring `?` rows
# rather than silently under-counting them.
#
# Declared, not fixed: a write performed entirely INSIDE a heredoc handed to
# another interpreter (`python - <<PY` ... `open(path, "w")` ... `PY`) has no
# shell-level operator or command name for this lexer to see at all — the
# write happens in a language this hook does not parse. Unlike the
# variable/substitution case above, there is no signal here to even log a `?`
# row against; flagging every heredoc fed to python/node/ruby as a phantom
# write (most of which never touch a file) would trade an undercount for a
# worse overcount. This gap is accepted and left undetected rather than
# guessed at.
#
# Other declared gaps, same spirit as protect-main.sh's accepted gap: `cp`/
# `mv` targets are read as the LAST non-flag argument, which misses a
# `-t <dir>`-style destination given before its sources; `sed -i` with
# multiple trailing files logs only the last one; a command is split into
# segments at `; && || | & (newline)`, so a `;` or `&&` embedded inside a
# quoted argument (rare, but legal shell) can mis-split. Each of these
# under-covers a shape rather than mis-reporting a common one — the same
# trade this file's header has always made for Edit/Write path resolution.
#
# Registered in .claude/settings.json under hooks.PreToolUse with matcher
# "Bash" (in addition to the existing "Edit|Write|MultiEdit|NotebookEdit").

set -uo pipefail

input=$(cat)

# python3, falling back to `python` (some Windows shells only have `python` on
# PATH). Never blocks either way: if neither is present, this observability
# hook just has nothing to log this time.
PYTHON_BIN=python3
command -v python3 >/dev/null 2>&1 || PYTHON_BIN=python
command -v "$PYTHON_BIN" >/dev/null 2>&1 || exit 0

printf '%s' "$input" | "$PYTHON_BIN" -c '
import sys, json, datetime, os

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = d.get("tool_name") or "?"
ti = d.get("tool_input") or {}

agent_type = d.get("agent_type") or ""
agent_id = d.get("agent_id") or ""
tp = d.get("transcript_path") or ""

if agent_id or agent_type:
    thread = "sub"
elif tp and "subagents" in tp.split(os.sep):
    thread = "sub"
elif tp:
    thread = "main"
else:
    thread = "?"

cwd = os.getcwd()
ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

out_lines = []

def emit(kind, path):
    out_lines.append("\t".join([ts, thread, kind, path, agent_type]))

# ---------------------------------------------------------- Edit/Write family
if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
    path = ti.get("file_path") or ti.get("notebook_path") or ""
    # Repo-relative when possible: absolute paths make the log unreadable and
    # leak the checkout location into a file people paste into issues.
    # Unchanged from before this hook learned about Bash: an Edit/Write path
    # outside the repo is still logged as-is, never dropped — the
    # inside-the-repo filter below applies ONLY to Bash-detected writes.
    if path.startswith(cwd + os.sep):
        path = path[len(cwd) + 1:]
    emit(tool, path)

# ------------------------------------------------------------------- Bash
elif tool == "Bash":
    command = ti.get("command") or ""

    def to_repo_relative(raw):
        # None => outside the repo, caller must not log this target at all.
        if not raw:
            return None
        p = raw
        if p == "~":
            p = os.environ.get("HOME", p)
        elif p.startswith("~/"):
            p = os.path.join(os.environ.get("HOME", ""), p[2:])
        if not os.path.isabs(p):
            p = os.path.join(cwd, p)
        p = os.path.normpath(p)
        if p == cwd:
            return "."
        if p.startswith(cwd + os.sep):
            return p[len(cwd) + 1:]
        return None

    def is_unresolvable(tok):
        return any(c in tok for c in ("$", "`", "*", "?"))

    def tokenize(cmd):
        # WORD/OP token stream. Quote chars are consumed, not kept, so a
        # WORD"s value is the literal text (real shell semantics for
        # adjacent quoted/unquoted fragments concatenating into one word).
        tokens = []
        cur = ""
        quote = None
        i = 0
        n = len(cmd)
        while i < n:
            c = cmd[i]
            if quote:
                if c == quote:
                    quote = None
                else:
                    cur += c
                i += 1
                continue
            if c in ("\x27", "\x22"):
                quote = c
                i += 1
                continue
            if c == "\n":
                if cur:
                    tokens.append(("WORD", cur)); cur = ""
                tokens.append(("OP", "\n"))
                i += 1
                continue
            if c.isspace():
                if cur:
                    tokens.append(("WORD", cur)); cur = ""
                i += 1
                continue
            if c == ">":
                fd = cur if cur.isdigit() else None
                if fd is None and cur:
                    tokens.append(("WORD", cur))
                cur = ""
                if cmd[i:i+2] == ">>":
                    op, ln = ("2>>" if fd == "2" else ">>"), 2
                elif cmd[i:i+2] == ">&":
                    op, ln = ">&", 2
                else:
                    op, ln = ("2>" if fd == "2" else ">"), 1
                tokens.append(("OP", op))
                i += ln
                continue
            if c == "&":
                if cur:
                    tokens.append(("WORD", cur)); cur = ""
                if cmd[i:i+3] == "&>>":
                    op, ln = "&>>", 3
                elif cmd[i:i+2] == "&>":
                    op, ln = "&>", 2
                elif cmd[i:i+2] == "&&":
                    op, ln = "&&", 2
                else:
                    op, ln = "&", 1
                tokens.append(("OP", op))
                i += ln
                continue
            if c in "|;()<":
                if cur:
                    tokens.append(("WORD", cur)); cur = ""
                if cmd[i:i+2] == "((" and c == "(":
                    op, ln = "((", 2
                elif cmd[i:i+2] == "))" and c == ")":
                    op, ln = "))", 2
                elif cmd[i:i+2] == "||":
                    op, ln = "||", 2
                elif cmd[i:i+2] == ";;":
                    op, ln = ";;", 2
                elif cmd[i:i+2] == "<<":
                    op, ln = "<<", 2
                else:
                    op, ln = c, 1
                tokens.append(("OP", op))
                i += ln
                continue
            cur += c
            i += 1
        if cur:
            tokens.append(("WORD", cur))
        return tokens

    SEPARATORS = {"&&", "||", ";", ";;", "|", "&", "(", ")", "\n"}

    def split_segments(tokens):
        segments = [[]]
        for kind, val in tokens:
            if kind == "OP" and val in SEPARATORS:
                segments.append([])
            else:
                segments[-1].append((kind, val))
        return [s for s in segments if s]

    import re as _re
    ASSIGN_RE = _re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

    def find_command(seg):
        # Returns (index, word) of the first WORD that is not a leading
        # VAR=value assignment (e.g. `FOO=bar sed -i ...`), or (None, None).
        # The index matters, not just the word: everything AFTER it is the
        # argument list, and slicing by a fixed offset instead (words[1:])
        # would misalign the moment there is an assignment prefix, silently
        # treating the command"s own name as one of its arguments.
        for idx, (kind, val) in enumerate(seg):
            if kind != "WORD":
                continue
            if ASSIGN_RE.match(val):
                continue
            return idx, val
        return None, None

    def handle_target(kind_label, raw):
        if is_unresolvable(raw):
            emit(kind_label, "?")
            return
        rel = to_repo_relative(raw)
        if rel is not None:
            emit(kind_label, rel)
        # else: resolves outside the repo — not logged, by design.

    try:
        if command:
            tokens = tokenize(command)
            for seg in split_segments(tokens):
                # Arithmetic/test context: "((" / "))" (already anywhere in
                # the segment) or a "[[" / "]]" / "[" / "]" test-command
                # bracket ANYWHERE in the segment mean a literal ">" here is
                # a comparison, not a redirect. Deliberately not anchored to
                # the first token: a keyword prefix (`if`, `while`, `until`,
                # `elif`, `!`, `{`) or a leading subshell "(" shifts the
                # bracket away from position 0 in the very same segment this
                # hook already walks (`if [[ 5 > 3 ]]; then ...` is one
                # segment up to the first `;`), so checking only the first
                # WORD missed every one of those and logged a phantom write
                # to a file literally named "3". "((" is skipped by the same
                # "anywhere" rule already, kept together here for one story
                # instead of two anchoring styles.
                if any(
                    (k == "OP" and v in ("((", "))"))
                    or (k == "WORD" and v in ("[[", "]]", "[", "]"))
                    for k, v in seg
                ):
                    continue

                # --- redirects: > and >> only (see header for why not 2>/&>)
                for idx, (kind, val) in enumerate(seg):
                    if kind == "OP" and val in (">", ">>"):
                        if idx + 1 < len(seg) and seg[idx + 1][0] == "WORD":
                            handle_target("Bash:redirect", seg[idx + 1][1])

                cmd_idx, cmd_word = find_command(seg)
                if cmd_word is None:
                    continue
                base = cmd_word.rstrip("/").split("/")[-1]
                words = [v for k, v in seg[cmd_idx + 1:] if k == "WORD"]

                if base == "sed":
                    has_i = any(w == "-i" or w.startswith("-i") or w.startswith("--in-place") for w in words)
                    if has_i:
                        non_flag = [w for w in words if not w.startswith("-")]
                        if non_flag:
                            handle_target("Bash:sed-i", non_flag[-1])
                elif base == "tee":
                    for w in words:
                        if not w.startswith("-"):
                            handle_target("Bash:tee", w)
                elif base in ("cp", "mv"):
                    non_flag = [w for w in words if not w.startswith("-")]
                    if len(non_flag) >= 2:
                        handle_target("Bash:" + base, non_flag[-1])
    except Exception:
        # Never let a parsing bug turn an observability hook into a blocker,
        # and never emit a half-built line. Nothing gets logged this call.
        out_lines = []

for line in out_lines:
    print(line)
' >> .claude/tool-log.txt 2>/dev/null

exit 0
