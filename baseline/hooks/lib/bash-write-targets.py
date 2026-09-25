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
#   - recognizes EVERY redirect operator that can write a file: `>`, `>>`,
#     `>|` (force-write, bypasses noclobber), `&>`/`&>>` (stdout+stderr to a
#     file, always a file, never an fd), `2>`/`2>>` (stderr alone — this
#     STILL creates or truncates the target file even if nothing is ever
#     written to stderr) and `>&` (write UNLESS the following word is a bare
#     fd reference like `1`, `2` or `-`, e.g. `cmd >&2` — no file at all —
#     as opposed to `cmd >& file`, a real write, treated by bash exactly
#     like `&>`). An earlier version of this file excluded ALL of `2>`,
#     `2>>`, `&>`, `&>>` and `>&` outright on the theory that they are
#     "stderr-to-fd or combined-stream redirects, not a new file" — measured
#     wrong: `echo pwned &> target`, `echo pwned >& target` and
#     `echo pwned 2> target` all write `target` exactly like plain `>`,
#     verified against a real shell before fixing this comment together with
#     the code it used to justify. Only a BARE fd-duplication form
#     (`2>&1`, `>&2`, `1>&-`) has no file target at all — that is the one
#     shape still excluded, and only for `>&`'s own following word, not for
#     the operator itself;
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
# Remaining declared gaps:
#   - `OPEN_CALL_RE` does not understand nested parentheses in the first
#     argument: `open(os.path.join('a', 'b.json'), 'w')` does not match the
#     regex AT ALL (the inner `(...)`/`,` breaks its no-paren/no-comma `arg`
#     group), so this call is silently invisible — not even reported as
#     unresolvable ("?"), unlike every other unresolvable shape this file
#     handles. Accepted rather than fixed with a real (nested-paren-aware)
#     scanner, which this single regex is not equipped to become without
#     turning into a small parser of its own.
#   - the heredoc-stripping pass (above, before the main tokenizer runs) does
#     NOT track `cd`/`pushd`: a directory change appearing before a heredoc
#     is not seen across that separate pass, only within the main segment
#     loop below. `cd <harness> && python3 - <<'PY' ... PY` is covered (the
#     "cd" segment and the heredoc's OPENER line both go through the main
#     loop); a `cd` placed so that only the heredoc BODY's own open() calls
#     are affected is not.
#   - `popd` is not tracked at all (the directory stack it pops back to is
#     not something this parser maintains), and `pushd`/`popd` used
#     together to return to the ORIGINAL directory read as still having
#     moved, same as any other cd this parser cannot fully model.
#   - a command is split into segments at `; && || | & (newline)`, so a `;`
#     or `&&` embedded inside a quoted argument (rare, but legal shell) can
#     mis-split.
#   - other interpreters and commands that can write a file are not
#     recognized at all: `bash -c "..."`, `node -e`, `perl -pi`, `awk`
#     (`> file` inside an awk program, or `print > "file"`), `dd of=`,
#     `ln -sf` (creates/replaces a path). These used to be a pure
#     observability gap when only log-edit.sh depended on this file; now
#     that protect-harness.sh and protect-critical.sh use the same parser to
#     DECIDE whether to block, each one is a live way to write a governed
#     path through Bash and have neither guard see it, not just an
#     undercount in a log nobody is blocked by. Left unaddressed for now,
#     on purpose, not because the risk shrank.

import sys
import os
import json
import re

ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

# Every redirect operator that ALWAYS writes a file when followed by a WORD
# (see the header for why `2>`/`2>>`/`&>`/`&>>`/`>|` are write shapes, not
# just `>`/`>>`). `>&` is handled separately, right below the loop that uses
# this set: it writes a file UNLESS its target is a bare fd reference.
WRITE_REDIRECT_OPS = {">", ">>", ">|", "2>", "2>>", "&>", "&>>"}
# A bare file-descriptor reference as the word following `>&` — a plain
# number (`1`, `2`, `10`) or a lone `-` (closes the fd) — meaning `>&` here
# duplicates a file descriptor and touches no file at all. Anything else
# following `>&` (a filename) is a real write, handled by bash exactly like
# `&>`.
FD_REF_RE = re.compile(r"^-$|^[0-9]+$")

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
#
# `(?P<opener>...)[^\n]*` after the delimiter, not a bare `\r?\n` right after
# it: the opening line can carry MORE after the delimiter word, most notably
# a redirect (`python3 - <<'PY' > out.txt`). An earlier version required the
# newline immediately after the delimiter, so a heredoc with anything
# trailing its own opening line simply never matched HEREDOC_RE at all —
# proven both ways: `python3 - <<'PY' > out.txt` with a governance-path
# `open(..., "w")` in the body passed with exit 0 (the body was never
# stripped, so it was never scanned either — a FALSE NEGATIVE in exactly the
# case this parser exists for), and `cat <<'EOF' > notes.md` whose body only
# MENTIONS a dangerous command as prose got blocked, because the unstripped
# body fell through to the general tokenizer and one of its lines looked
# like a real command (a FALSE POSITIVE that teaches an agent to route
# around this guard). `opener` is kept out of the stripped text below
# (unlike the body and the closing delimiter line, which are removed) so a
# real redirect on the heredoc's own opening line is still seen by the
# general tokenizer afterward.
HEREDOC_RE = re.compile(
    r"(?P<opener><<-?[ \t]*(?P<q>['\"]?)(?P<delim>[A-Za-z_][A-Za-z0-9_]*)(?P=q)[^\n]*)\r?\n"
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


def _is_cwd_relative(raw):
    # True for a target whose resolution actually depends on cwd: not
    # absolute, and not `~`/`~/...` (those resolve against $HOME instead).
    return not os.path.isabs(raw) and raw != "~" and not raw.startswith("~/")


def resolve_target(raw, base, base_unresolvable=False):
    # Returns (is_unresolvable, absolute_path_or_None). absolute_path is
    # None only when is_unresolvable is False and raw is empty — callers
    # never see that case in practice since the tokenizer never emits an
    # empty WORD as a target.
    #
    # base / base_unresolvable: the EFFECTIVE current directory for this
    # point in the command, not necessarily the payload's own cwd anymore —
    # see the "cd" dispatch in extract_targets for how an earlier `cd`/
    # `pushd` in this SAME command updates it. base_unresolvable is True
    # only when an earlier cd/pushd target could not itself be resolved (a
    # shell variable, `cd -`, a bare `pushd` swap): a relative target from
    # here on cannot be pinned to a real path at all, not "resolved against
    # a slightly stale cwd" — `cd "$VAR" && echo pwned > x` genuinely could
    # land anywhere. A resolvable cd/pushd argument updates `base` instead
    # of setting this flag, which is the whole point of tracking it: `cd
    # <harness> && echo pwned > .claude/settings.json` now resolves against
    # the harness checkout, the directory the write actually lands in, not
    # against the payload's cwd (which used to read this as an ordinary
    # file in the session's own repo and pass) and not against a bare "?"
    # either (which used to pass by abstention, safer than a wrong verdict
    # but still a gap: the write itself went undetected). An absolute
    # target (or `~`) is unaffected either way — those never depended on
    # any cwd in the first place.
    if any(c in raw for c in ("$", "`", "*", "?")):
        return True, None
    if base_unresolvable and _is_cwd_relative(raw):
        return True, None
    return False, resolve_absolute(raw, base)


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
            elif cmd[i:i+2] == ">|":
                op, ln = ">|", 2
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
    # Single-element cells (not plain values) so the nested functions below
    # can both READ and, at the "cd"/"pushd" dispatch further down, WRITE
    # the same state without a `nonlocal` declaration in each one.
    # base_dir: the EFFECTIVE current directory for whatever point in the
    # command we are at — starts as the payload's own cwd, and is updated
    # in place by a resolvable `cd`/`pushd` argument encountered along the
    # way (see the "cd" dispatch below).
    # base_unresolvable: True once a `cd`/`pushd` argument could not itself
    # be resolved (a shell variable, `cd -`, a bare `pushd` swap) — every
    # relative target from there on is unresolvable, UNTIL a later cd/pushd
    # with a resolvable (in particular, absolute) argument re-establishes a
    # known base regardless of the unresolvable one in between.
    base_dir = [cwd]
    base_unresolvable = [False]

    def handle(kind_label, raw):
        unresolvable, target = resolve_target(raw, base_dir[0], base_unresolvable[0])
        out.append((kind_label, unresolvable, target))

    def handle_open_calls(kind_label, code):
        for unresolvable, path in extract_open_call_targets(code):
            if unresolvable:
                out.append((kind_label, True, None))
            elif base_unresolvable[0] and _is_cwd_relative(path):
                # Same reasoning as resolve_target's own base_unresolvable
                # check: an `open(...)` call inside a `python3 -c`/heredoc
                # that runs AFTER an earlier cd/pushd whose destination this
                # parser could not resolve is itself unresolvable, not
                # silently guessed at against a stale base.
                out.append((kind_label, True, None))
            else:
                out.append((kind_label, False, resolve_absolute(path, base_dir[0])))

    # --- heredoc bodies handed to python3/python: scanned here, then
    # stripped from the text before the general shell tokenizer ever sees
    # it. A heredoc body is not shell-quoted at all, so leaving it in would
    # let an ordinary line of Python source (e.g. `if a > b:`) be misread as
    # a shell redirect by the tokenizer below. Matches are found against the
    # ORIGINAL command and removed back-to-front, so earlier offsets stay
    # valid while later ones are being cut out.
    #
    # Only the BODY and the closing delimiter line are removed — the OPENER
    # (`<<DELIM` through the end of its own line, e.g. `python3 - <<'PY' >
    # out.txt`) is kept in stripped_command exactly where it was, so a
    # redirect sitting on the heredoc's own opening line is still seen by
    # the general tokenizer below. Dropping the opener too (an earlier
    # version did) silently erased that redirect's target along with the
    # heredoc syntax around it.
    stripped_command = command
    for m in reversed(list(HEREDOC_RE.finditer(command))):
        line_start = command.rfind("\n", 0, m.start())
        line_start = 0 if line_start == -1 else line_start + 1
        preceding = command[line_start:m.start()]
        if PYTHON_PRECEDES_RE.search(preceding):
            handle_open_calls("Bash:python-heredoc", m.group("body"))
        stripped_command = (
            stripped_command[:m.start()]
            + stripped_command[m.start():m.end("opener")]
            + stripped_command[m.end():]
        )

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

        # --- redirects: every operator shape that writes a file (see header)
        for idx, (kind, val) in enumerate(seg):
            if kind != "OP":
                continue
            if val in WRITE_REDIRECT_OPS:
                if idx + 1 < len(seg) and seg[idx + 1][0] == "WORD":
                    handle("Bash:redirect", seg[idx + 1][1])
            elif val == ">&":
                if idx + 1 < len(seg) and seg[idx + 1][0] == "WORD":
                    target = seg[idx + 1][1]
                    if not FD_REF_RE.match(target):
                        handle("Bash:redirect", target)

        cmd_idx, cmd_word = find_command(seg)
        if cmd_word is None:
            continue
        base = cmd_word.rstrip("/").split("/")[-1]
        words = [v for k, v in seg[cmd_idx + 1:] if k == "WORD"]

        if base in ("cd", "pushd"):
            # Resolve cd's/pushd's OWN argument and use it as the new base
            # for every relative target from HERE ON in this same command —
            # see resolve_target's own base_unresolvable note for why this
            # is better than just marking everything after it unresolvable.
            # `cd`/`pushd` allow flags before the directory (-L/-P for cd,
            # +N/-N/-n for pushd, none of which name a directory), so the
            # first word that is neither a flag nor cd's own destination
            # marker is the one we want. A bare "-" is NOT a flag here — for
            # `cd` it IS the destination (meaning $OLDPWD) — so it is kept
            # even though it starts with "-"; only a LONGER "-something" is
            # treated as a flag and skipped.
            dest_words = [w for w in words if w == "-" or not (w.startswith("-") or w.startswith("+"))]
            if not dest_words:
                # `cd` with no argument goes to $HOME — a real, resolvable
                # base. `pushd` with no argument SWAPS with the top of the
                # directory stack, which this parser does not track.
                if base == "cd":
                    base_dir[0] = os.environ.get("HOME", base_dir[0])
                    base_unresolvable[0] = False
                else:
                    base_unresolvable[0] = True
            else:
                dest = dest_words[0]
                if dest == "-" or any(c in dest for c in ("$", "`", "*", "?")):
                    # `cd -`/`pushd -` goes to $OLDPWD, not tracked. A
                    # shell variable or command substitution in the
                    # destination is exactly as unresolvable as any other
                    # target this parser cannot pin to a literal path —
                    # trusting a SECOND unresolvable value to fix the first
                    # one is how a guard ends up confidently wrong instead
                    # of honestly unsure.
                    base_unresolvable[0] = True
                elif os.path.isabs(dest) or dest == "~" or dest.startswith("~/"):
                    # An absolute (or ~) destination does not depend on the
                    # CURRENT base at all, so it can safely re-establish a
                    # known base even if we were unresolvable a moment ago
                    # (`cd "$VAR" && cd <harness> && ...` recovers here).
                    base_dir[0] = resolve_absolute(dest, base_dir[0])
                    base_unresolvable[0] = False
                elif not base_unresolvable[0]:
                    # A relative destination only resolves safely against a
                    # base we actually know; if we do not, this cd cannot
                    # fix that either, and base_unresolvable stays True.
                    base_dir[0] = resolve_absolute(dest, base_dir[0])
        elif base == "sed":
            has_i = any(w == "-i" or w.startswith("-i") or w.startswith("--in-place") for w in words)
            if has_i:
                # ALL non-flag FILE words, not just the last one:
                # `sed -i s/a/b/ <governance-file> README.md` used to report
                # only "README.md", missing the earlier file entirely. GNU
                # sed's own rule for telling the SCRIPT apart from FILEs:
                # if -e/--expression or -f/--file appears anywhere, every
                # non-flag word is a file; otherwise the FIRST non-flag word
                # is the script, and every non-flag word after it is a file.
                #
                # The SEPARATED form (`-e SCRIPT`, `-f FILE`, one space, two
                # words) needs the word immediately after the flag CONSUMED
                # as that flag's own operand, not counted as a file:
                # `sed -i -e /node_modules/d .gitignore` used to report
                # "/node_modules/d" (the -e expression itself, never written
                # to) as a write target, alongside the real file, purely
                # because SOME -e was present anywhere in the word list.
                # `-f script.sed` was worse: that file is READ by sed, never
                # written, and got reported as a write target regardless.
                # The GLUED forms (`-escript`, `--expression=script`,
                # `-fscript.sed`, `--file=script.sed`) carry no separate
                # word to consume; they still mark has_explicit_script and
                # are excluded from the file list, same as before.
                has_explicit_script = False
                positionals = []
                consume_next = False
                for w in words:
                    if consume_next:
                        consume_next = False
                        continue
                    if w in ("-e", "--expression", "-f", "--file"):
                        has_explicit_script = True
                        consume_next = True
                        continue
                    if w.startswith("--expression=") or w.startswith("--file="):
                        has_explicit_script = True
                        continue
                    if (w.startswith("-e") and w != "-e") or (w.startswith("-f") and w != "-f"):
                        has_explicit_script = True
                        continue
                    if w.startswith("-"):
                        continue
                    positionals.append(w)
                files = positionals if has_explicit_script else positionals[1:]
                for w in files:
                    handle("Bash:sed-i", w)
        elif base == "tee":
            for w in words:
                if not w.startswith("-"):
                    handle("Bash:tee", w)
        elif base in ("cp", "mv"):
            # -t DIR / --target-directory=DIR / --target-directory DIR:
            # every remaining positional word is a SOURCE being copied or
            # moved INTO DIR, not a destination — the naive "last non-flag
            # argument" would report the LAST SOURCE as if it were where
            # the write lands, which is backwards. Report DIR joined with
            # each source's own basename instead, one target per source, so
            # `cp -t baseline/hooks src.sh` is seen as a write into
            # baseline/hooks/src.sh, not as a (harmless) write to "src.sh".
            target_dir = None
            sources = []
            skip_next = False
            for w in words:
                if skip_next:
                    target_dir = w
                    skip_next = False
                    continue
                if w in ("-t", "--target-directory"):
                    skip_next = True
                    continue
                if w.startswith("--target-directory="):
                    target_dir = w[len("--target-directory="):]
                    continue
                if w.startswith("-t") and w != "-t" and not w.startswith("--"):
                    target_dir = w[2:]  # -tDIR, no space
                    continue
                if w.startswith("-"):
                    continue
                sources.append(w)
            if target_dir is not None:
                for src in sources:
                    basename = src.rstrip("/").split("/")[-1]
                    if basename:
                        handle("Bash:" + base, target_dir.rstrip("/") + "/" + basename)
            elif len(sources) >= 2:
                # No -t: the LAST positional is cp's/mv's destination, but
                # that destination is a DIRECTORY, not the file actually
                # written, whenever cp/mv syntax says so (more than one
                # source — cp/mv itself requires the last argument to be a
                # directory then) or a trailing slash says so (the command
                # itself wrote `dest/`), or the filesystem says so (it
                # already exists as a directory — checked directly, since
                # this parser runs synchronously on the same machine as the
                # session, right before the real command would execute, so
                # there is no meaningful window for the answer to change
                # out from under it). Without this, the COMMON shape of
                # this write, `cp file <governed-dir>/` or into a directory
                # that already exists with no trailing slash, reported the
                # bare directory as the target — which `os.path.normpath`
                # then strips the trailing slash from, so it stopped
                # matching a directory-shaped governance/critical pattern
                # (one with no trailing `$`) that the SAME write, spelled
                # with an explicit destination filename, still caught.
                dest = sources[-1]
                real_sources = sources[:-1]
                dest_is_dir = (
                    len(real_sources) > 1
                    or dest.endswith("/")
                    or os.path.isdir(resolve_absolute(dest, base_dir[0]))
                )
                if dest_is_dir:
                    for src in real_sources:
                        basename = src.rstrip("/").split("/")[-1]
                        if basename:
                            handle("Bash:" + base, dest.rstrip("/") + "/" + basename)
                else:
                    handle("Bash:" + base, dest)
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
