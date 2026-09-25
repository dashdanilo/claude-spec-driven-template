#!/usr/bin/env python3
# bash-write-targets.py
# Shared parser: given a PreToolUse Bash payload on stdin, prints one line per
# file this Bash command would WRITE to, as "<kind>\t<target>".
#
# The single implementation of "what does this Bash command write to", used
# by three hooks that each need it for a different reason:
#   - log-edit.sh (observability: which thread wrote which file)
#   - protect-harness.sh (block a Bash write into the harness's own
#     governance surface, not just an Edit/Write into it)
#   - protect-critical.sh (same, for lockfiles/secrets/generated code)
#
# Before this file existed, log-edit.sh carried this exact lexer inline and
# was the only hook that saw a Bash-performed write at all: a redirect,
# `sed -i`, `tee`, `cp` or `mv` run via Bash was invisible to protect-harness.sh
# and protect-critical.sh, which only ever looked at Edit/Write/MultiEdit
# payloads. `python3 -c "..."` or a heredoc writing to .claude/settings.json
# sailed through both guards. Extracted here so all three hooks improve
# together instead of three copies drifting apart.
#
# Input: the FULL hook JSON payload (the same one Claude Code sends the
# hook), on stdin — not just the command string, because resolving a
# relative write target needs the payload's own "cwd".
#
# Output: zero or more lines "<kind>\t<target>", where:
#   kind   is "Bash:redirect", "Bash:sed-i", "Bash:tee", "Bash:cp", "Bash:mv"
#          — the labels log-edit.sh has always used — or "Bash:python-c" /
#          "Bash:python-heredoc" (see below).
#   target is an ABSOLUTE, normalized path when the write target could be
#          resolved to a literal path, or the literal string "?" when it
#          could not (built from a shell variable, a command substitution,
#          or containing a glob character). Deliberately NOT repo-relative
#          and NOT filtered to "inside some particular directory" — that
#          filtering is each CALLER's decision (log-edit.sh only logs
#          inside-repo writes; protect-harness.sh and protect-critical.sh
#          need to see a target ANYWHERE, including cross-repo, since a
#          write reaching outside the session's own cwd into another
#          checkout entirely is exactly the shape of attack
#          protect-harness.sh exists to stop).
#
# A target this script cannot resolve to a literal path is printed with
# target "?", never dropped and never blocked here — resolving what to DO
# with an unresolvable target (skip it, as protect-harness.sh and
# protect-critical.sh do; log it as a gap, as log-edit.sh does) is each
# caller's decision, not this parser's.
#
# cwd resolution: the payload's own top-level "cwd" (the directory Claude
# Code actually ran the command from) when present, falling back to this
# process's own os.getcwd() only when the payload omits "cwd" entirely. Never
# the other way around — a hook process's own cwd can be stale relative to
# what the session believes it is working in (a dispatched subagent's Bash
# tool has been observed keeping the ORIGINAL repo as its process cwd even
# when the payload's own "cwd" already points at a worktree), and resolving
# against the wrong one turns a real write into an invisible one, or a
# same-repo edit into a false cross-repo alarm.
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
# One gap log-edit.sh used to declare as permanently accepted is now PARTLY
# closed, because it is the exact shape that motivated pulling this parser
# out on its own: `python3 -c "...open(path, 'w')..."` and a heredoc handed
# to `python3`/`python` (`python3 - <<'PY' ... open(path, 'w') ... PY`) are
# both scanned for `open(<literal-or-not path>, <mode>)` calls whose mode
# starts with w/a/x. This is a single regex over the code text, not a Python
# parser: a write performed through anything other than a literal `open(...)`
# call — pathlib, a wrapped helper, a dynamically built mode string, a second
# interpreter (node, ruby, ...) — is still invisible here, the same kind of
# gap cp/mv/sed already accept. When the regex finds a write-mode `open(...)`
# call whose first argument is NOT a simple quoted literal, the target is
# still reported, as unresolvable ("?"), same as any other target this
# parser cannot pin to a literal path — never silently dropped.
#
# `cp`/`mv` targets are read as the LAST non-flag argument, which misses a
# `-t <dir>`-style destination given before its sources; `sed -i` with
# multiple trailing files reports only the last one; a command is split into
# segments at `; && || | & (newline)`, so a `;` or `&&` embedded inside a
# quoted argument (rare, but legal shell) can mis-split. Each of these
# under-covers a shape rather than mis-reporting a common one.

import sys
import os
import json
import re

ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

# A write-mode `open(<arg>, <mode>)` call, anywhere in a code string. <arg> is
# captured RAW (not required to be quoted) so a non-literal first argument
# still matches and can be reported as unresolvable rather than missed
# outright. <mode> must start with w/a/x (read modes never match).
OPEN_CALL_RE = re.compile(
    r"open\(\s*(?P<arg>[^,()]+?)\s*,\s*(?:mode\s*=\s*)?(?P<mq>['\"])(?P<mode>[wax][a-zA-Z+]*)(?P=mq)"
)
# A first argument that is a plain quoted string literal, no concatenation or
# interpolation — the only shape this parser resolves to a path. The middle
# group excludes BOTH quote characters, not just the matching one: a naive
# `(['\"])(.*)\1` also matches `'" + repo_a + "/x.json'` (a real Python
# string-concatenation expression, not a literal) because a greedy `.*`
# happily runs through the embedded quotes to reach the outer one at the
# end, and reports a resolved path built from mangled text instead of
# flagging the argument unresolvable. Excluding inner quotes narrows what
# resolves (a literal legitimately containing the OTHER quote character,
# e.g. an apostrophe inside a double-quoted path, now reports unresolvable
# too) rather than ever resolving to text that was not actually the whole
# argument.
LITERAL_ARG_RE = re.compile(r"^(['\"])([^'\"]*)\1$")

# `<<DELIM`, `<<-DELIM`, `<<'DELIM'`, `<<"DELIM"` through a line that is just
# (optionally indented) the same delimiter. DOTALL so `.` can span the body's
# newlines; the delimiter itself is a plain word, never re-expanded.
HEREDOC_RE = re.compile(
    r"<<-?[ \t]*(?P<q>['\"]?)(?P<delim>[A-Za-z_][A-Za-z0-9_]*)(?P=q)\r?\n"
    r"(?P<body>.*?)\r?\n[ \t]*(?P=delim)(?=\r?\n|$)",
    re.DOTALL,
)
# Is `python3`/`python` the command on the line text immediately before a
# heredoc operator? A plain word-boundary check, not full command parsing —
# consistent with everything else in this file.
PYTHON_PRECEDES_RE = re.compile(r"(^|[\s;&|(])python3?(\s|$)")


def resolve_absolute(path, cwd):
    p = path
    if p == "~":
        p = os.environ.get("HOME", p)
    elif p.startswith("~/"):
        p = os.path.join(os.environ.get("HOME", ""), p[2:])
    if not os.path.isabs(p):
        p = os.path.join(cwd, p)
    return os.path.normpath(p)


def resolve_target(raw, cwd):
    # Returns (is_unresolvable, absolute_path_or_None). absolute_path is
    # None only when is_unresolvable is False and raw is empty — callers
    # never see that case in practice since the tokenizer never emits an
    # empty WORD as a target.
    if any(c in raw for c in ("$", "`", "*", "?")):
        return True, None
    return False, resolve_absolute(raw, cwd)


def extract_open_call_targets(code):
    # Scans a code string (a `python3 -c` argument, or a heredoc body handed
    # to python3/python) for write-mode `open(...)` calls. Returns a list of
    # (is_unresolvable, path_or_None) — same shape as resolve_target, minus
    # the cwd join (callers resolve that themselves).
    out = []
    for m in OPEN_CALL_RE.finditer(code):
        arg = m.group("arg").strip()
        lit = LITERAL_ARG_RE.match(arg)
        if lit:
            out.append((False, lit.group(2)))
        else:
            out.append((True, None))
    return out


def tokenize(cmd):
    # WORD/OP token stream. Quote chars are consumed, not kept, so a WORD's
    # value is the literal text (real shell semantics for adjacent
    # quoted/unquoted fragments concatenating into one word).
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


def find_command(seg):
    # Returns (index, word) of the first WORD that is not a leading
    # VAR=value assignment (e.g. `FOO=bar sed -i ...`), or (None, None).
    # The index matters, not just the word: everything AFTER it is the
    # argument list, and slicing by a fixed offset instead (words[1:]) would
    # misalign the moment there is an assignment prefix, silently treating
    # the command's own name as one of its arguments.
    for idx, (kind, val) in enumerate(seg):
        if kind != "WORD":
            continue
        if ASSIGN_RE.match(val):
            continue
        return idx, val
    return None, None


def extract_targets(command, cwd):
    # Returns a list of (kind_label, is_unresolvable, absolute_path_or_None).
    out = []

    def handle(kind_label, raw):
        unresolvable, target = resolve_target(raw, cwd)
        out.append((kind_label, unresolvable, target))

    def handle_open_calls(kind_label, code):
        for unresolvable, path in extract_open_call_targets(code):
            if unresolvable:
                out.append((kind_label, True, None))
            else:
                out.append((kind_label, False, resolve_absolute(path, cwd)))

    # --- heredoc bodies handed to python3/python: scanned here, then
    # stripped from the text before the general shell tokenizer ever sees
    # it. A heredoc body is not shell-quoted at all, so leaving it in would
    # let an ordinary line of Python source (e.g. `if a > b:`) be misread as
    # a shell redirect by the tokenizer below. Matches are found against the
    # ORIGINAL command and removed back-to-front, so earlier offsets stay
    # valid while later ones are being cut out.
    stripped_command = command
    for m in reversed(list(HEREDOC_RE.finditer(command))):
        line_start = command.rfind("\n", 0, m.start())
        line_start = 0 if line_start == -1 else line_start + 1
        preceding = command[line_start:m.start()]
        if PYTHON_PRECEDES_RE.search(preceding):
            handle_open_calls("Bash:python-heredoc", m.group("body"))
        stripped_command = stripped_command[:m.start()] + stripped_command[m.end():]

    tokens = tokenize(stripped_command)
    for seg in split_segments(tokens):
        # Arithmetic/test context: "((" / "))" (anywhere in the segment) or
        # a "[[" / "]]" / "[" / "]" test-command bracket ANYWHERE in the
        # segment mean a literal ">" here is a comparison, not a redirect.
        # Deliberately not anchored to the first token: a keyword prefix
        # (`if`, `while`, `until`, `elif`, `!`, `{`) or a leading subshell
        # "(" shifts the bracket away from position 0 in the very same
        # segment this parser already walks.
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
                    handle("Bash:redirect", seg[idx + 1][1])

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
                    handle("Bash:sed-i", non_flag[-1])
        elif base == "tee":
            for w in words:
                if not w.startswith("-"):
                    handle("Bash:tee", w)
        elif base in ("cp", "mv"):
            non_flag = [w for w in words if not w.startswith("-")]
            if len(non_flag) >= 2:
                handle("Bash:" + base, non_flag[-1])
        elif base in ("python3", "python") and "-c" in words:
            ci = words.index("-c")
            if ci + 1 < len(words):
                handle_open_calls("Bash:python-c", words[ci + 1])

    return out


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return

    if (payload.get("tool_name") or "") != "Bash":
        return

    ti = payload.get("tool_input") or {}
    command = ti.get("command") or ""
    if not command:
        return

    cwd = payload.get("cwd") or os.getcwd()

    try:
        targets = extract_targets(command, cwd)
    except Exception:
        # Never let a parsing bug turn a shared parser into a blocker for
        # every caller at once, and never emit a half-built line.
        return

    for kind_label, unresolvable, target in targets:
        out = "?" if unresolvable else target
        print(kind_label + "\t" + out)


if __name__ == "__main__":
    main()
