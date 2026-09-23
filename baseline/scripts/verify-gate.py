#!/usr/bin/env python3
"""verify-gate.py

Validates a verification REPORT and exits 0 (pass) or 1 (fail). Python 3
stdlib only, no dependencies. The deterministic half of "done": a report
can only pass by showing its work, never by asserting it.

    baseline/scripts/verify-gate.py [REPORT] [--json]

REPORT defaults to `.claude/verification/latest.md`. Pass `-` to read the
report from stdin instead of a file.

CONTRACT
--------
The report is a Markdown file with two required sections, `## Commands`
and `## Claims`. Anything outside them (a title, a summary paragraph) is
ignored. A report missing a section, with an empty section, or with no
content at all FAILS — this gate never passes silently on a report that
proves nothing.

## Commands

One bullet per command actually run, in this exact, greppable format:

    - `<command>` -> exit <N>

Example:

    - `yarn test` -> exit 0
    - `yarn typecheck` -> exit 0

A bullet that does not match the format, or whose exit code is missing or
non-zero, fails the gate. A `## Commands` section with zero recognized
bullets fails the gate — no commands run is not evidence of anything.

## Claims

One bullet per claim the report's author makes about the change (for
example "the form validates E.164 phone numbers", "task 3's acceptance
criterion is covered"), each carrying evidence in this format:

    - <claim text> (evidence: <evidence>)

<evidence> is one of:

  - A `file:line` citation, e.g. `src/lead-form.ts:42`. The gate checks the
    shape (a non-space token, a colon, a line number) — not that the file
    exists or the line says what the claim says. That judgment call stays
    with whoever reviews the report; the gate only refuses "no evidence at
    all".
  - A reference to a command already listed under `## Commands`, backtick-
    quoted and identical to that command's text, e.g. `` `yarn test` ``.
    The referenced command still has to appear, verbatim, in `## Commands`
    — a reference to a command that was never run is a violation.

Examples:

    - phone normalizes to E.164 before submit (evidence: src/lead-form.ts:88)
    - the test suite is green (evidence: `yarn test`)

A claim with no evidence, malformed evidence, or evidence referencing a
command that was never declared, fails the gate. A `## Claims` section with
zero recognized bullets fails the gate — this is the "evidence or zero"
rule: an assertion with nothing behind it counts as zero, not as done.

OUTPUT
------
Exit 0: one line on stdout, `OK: N commands, M claims`.
Exit 1: one line per violation on stdout, `FAIL: <reason>: <offending line>`,
then a one-line summary.
`--json` (either exit code): a single JSON object on stdout instead of the
text above — `{"ok": bool, "commands": N, "claims": M, "violations": [...]}`.

Kept deliberately small: this script parses text, it does not run
anything, execute the report's commands, or touch the filesystem beyond
reading the report itself.
"""

import json
import re
import sys

DEFAULT_REPORT = ".claude/verification/latest.md"

HEADER_RE = re.compile(r"^#{1,6}\s+(.+?)\s*$")
COMMAND_RE = re.compile(r"^-\s+`(.+)`\s+->\s+exit\s+(-?\d+)\s*$")
CLAIM_RE = re.compile(r"^-\s+(.+?)\s+\(evidence:\s*(.+?)\)\s*$")
COMMAND_REF_RE = re.compile(r"^`(.+)`$")
FILE_LINE_RE = re.compile(r"^\S+:\d+$")


def parse_args(argv):
    report = None
    as_json = False
    for arg in argv:
        if arg == "--json":
            as_json = True
        elif report is None:
            report = arg
        else:
            sys.stderr.write(f"verify-gate.py: unexpected extra argument: {arg}\n")
            sys.exit(2)
    return report or DEFAULT_REPORT, as_json


def read_report(path):
    """Returns (content, error). error is a human string, or None."""
    if path == "-":
        try:
            return sys.stdin.read(), None
        except Exception as exc:  # pragma: no cover - stdin read rarely fails
            return None, f"could not read report from stdin: {exc}"
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read(), None
    except FileNotFoundError:
        return None, f"report not found: {path}"
    except OSError as exc:
        return None, f"could not read report {path}: {exc}"


def split_sections(content):
    """Returns {section_title: [line, ...]} for every H1-H6 heading found.

    Only the exact titles "Commands" and "Claims" are consumed by the
    caller; other sections (a title, a summary) are captured too but
    ignored, so no error is raised for content the contract does not care
    about.
    """
    sections = {}
    current = None
    for raw_line in content.splitlines():
        m = HEADER_RE.match(raw_line)
        if m:
            current = m.group(1).strip()
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append(raw_line)
    return sections


def parse_commands(lines, violations):
    """Returns the set of verbatim command strings declared, valid or not.

    A command that failed (non-zero exit) or is malformed still gets
    recorded as "declared" for the purpose of the parser continuing, but
    only a well-formed, zero-exit command is counted toward `commands` and
    is eligible as claim evidence.
    """
    declared = set()
    valid = 0
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        if not line.startswith("-"):
            violations.append(
                f"unrecognized line in ## Commands (expected `- \\`cmd\\` -> exit N`): {line}"
            )
            continue
        m = COMMAND_RE.match(line)
        if not m:
            violations.append(
                f"malformed command line (expected `- \\`cmd\\` -> exit N`): {line}"
            )
            continue
        cmd, code = m.group(1), int(m.group(2))
        declared.add(cmd)
        if code != 0:
            violations.append(f"command exited non-zero ({code}): `{cmd}`")
            continue
        valid += 1
    return declared, valid


def parse_claims(lines, known_commands, violations):
    valid = 0
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        if not line.startswith("-"):
            violations.append(
                f"unrecognized line in ## Claims (expected `- <claim> (evidence: ...)`): {line}"
            )
            continue
        m = CLAIM_RE.match(line)
        if not m:
            violations.append(
                f"claim has no evidence (expected `- <claim> (evidence: ...)`): {line}"
            )
            continue
        claim, evidence = m.group(1), m.group(2)
        ref_m = COMMAND_REF_RE.match(evidence)
        if ref_m:
            ref_cmd = ref_m.group(1)
            if ref_cmd not in known_commands:
                violations.append(
                    f"claim references a command not listed in ## Commands: \"{claim}\" -> `{ref_cmd}`"
                )
                continue
            valid += 1
            continue
        if FILE_LINE_RE.match(evidence):
            valid += 1
            continue
        violations.append(
            f"claim has unrecognized evidence (expected `file:line` or a backtick-quoted command): "
            f"\"{claim}\" -> {evidence}"
        )
    return valid


def run(report_path):
    violations = []
    content, error = read_report(report_path)
    if error:
        return False, 0, 0, [error]

    if content is None or not content.strip():
        return False, 0, 0, ["report is empty"]

    sections = split_sections(content)

    if "Commands" not in sections:
        violations.append("missing section: ## Commands")
        commands, commands_ok = set(), 0
    else:
        commands, commands_ok = parse_commands(sections["Commands"], violations)
        if commands_ok == 0:
            violations.append("## Commands has no valid commands recorded")

    if "Claims" not in sections:
        violations.append("missing section: ## Claims")
        claims_ok = 0
    else:
        claims_ok = parse_claims(sections["Claims"], commands, violations)
        if claims_ok == 0:
            violations.append("## Claims has no valid claims recorded")

    ok = len(violations) == 0
    return ok, commands_ok, claims_ok, violations


def main(argv):
    report_path, as_json = parse_args(argv)
    ok, commands_ok, claims_ok, violations = run(report_path)

    if as_json:
        print(json.dumps({
            "ok": ok,
            "commands": commands_ok,
            "claims": claims_ok,
            "violations": violations,
        }))
        return 0 if ok else 1

    if ok:
        print(f"OK: {commands_ok} commands, {claims_ok} claims")
        return 0

    for v in violations:
        print(f"FAIL: {v}")
    print(f"FAILED: {len(violations)} violation(s), {commands_ok} valid commands, {claims_ok} valid claims")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
