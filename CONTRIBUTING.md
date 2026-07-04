# Contributing

Thanks for considering a contribution. This template's value comes from being a clear, accurate reference. Contributions should preserve that quality.

## What kinds of contributions are welcome

- **Corrections** to wrong or outdated information
- **Improvements** to clarity in `README.md`, `LEARN.md`, or any explanatory text
- **New examples** that illustrate a pattern not yet covered
- **Bug reports** for inconsistencies between docs and structure
- **Updates** when Claude Code releases features that change best practices

## What is out of scope

- Project-specific opinions tied to a single stack (this template stays agnostic)
- New layers or subsystems unless there is a clear teaching benefit
- Cosmetic changes that do not improve clarity

## Before opening a pull request

1. **Read `README.md` and `LEARN.md` end to end.** A change in one often requires a change in the other.
2. **Check `CLAUDE.md` and `AGENTS.md`.** If your change affects conventions, both files may need updates.
3. **Verify the decision table in `README.md`.** New subsystems or files should fit somewhere in it.
4. **Make sure the directory tree comments in `README.md` still match the actual structure.** Run `tree` or `find` and compare.

## Style guide

- **English** for all documentation
- **Markdown** for all files (no MDX, no special preprocessing)
- **No em-dashes** in copy
- **One H1 per file**, used as the title
- **Code blocks have language tags** (` ```bash `, ` ```markdown `, etc)
- **File paths in inline code:** `.claude/skills/example-skill/SKILL.md`
- **Directory paths end with slash:** `.claude/skills/` not `.claude/skills`
- **Dates in ISO format:** `2026-06-21`

## Commit messages

Conventional Commits format:

- `docs:` for documentation changes
- `feat:` for new examples or new subsystems
- `fix:` for corrections
- `chore:` for tooling, gitignore, etc

Examples:

```
docs: clarify when to use rules vs nested CLAUDE.md
feat: add example for hooks PostToolUse pattern
fix: correct path in subagents section of LEARN.md
```

## Validation checklist

Before submitting:

- [ ] All internal links work (relative paths)
- [ ] Directory tree in `README.md` matches `find . -type d`
- [ ] No project-specific stack assumptions (specific frameworks or vendors) leak into core files
- [ ] Decision table in `README.md` includes any new file types you added
- [ ] `LEARN.md` table of contents matches its sections

## Adding a new example

If you add a new example (rule, skill, agent, etc), follow this pattern:

1. Make the example **generic** but **realistic**. Avoid `foo` and `bar`. Use something like `example-skill` or `code-reviewer`.
2. Add a short paragraph in `README.md` explaining what the example shows
3. Reference the example in `LEARN.md` if it illustrates a concept
4. Make sure the example file ITSELF teaches: comments inline that explain why the structure is the way it is

## Adding a new skill, subagent, or hook

The template ships several ready-to-use skills and subagents. If you add new ones:

- Skills go in `.claude/skills/<name>/SKILL.md`. Descriptions must be triggering conditions (`Use when...`), not documentation.
- Subagents go in `.claude/agents/<name>.md`. Set `tools:` narrowly to reduce surface area.
- Hooks go in `.claude/hooks/<name>.sh` (or another executable). Register in `.claude/settings.json`.
- Utility scripts shared by multiple hooks or agents go in `.claude/scripts/`.
- Update the tree diagram in `README.md` to include the new file.

## Changing paths

Paths appear in many places (READMEs, CLAUDE.md, AGENTS.md, skills, subagents, hooks). If you rename or move a file:

1. Run `grep -rn "<old-path>" .` to find all references
2. Update each one
3. Update the tree diagrams in `README.md` and any relevant README
4. Test that hooks and scripts still work in the new location

## Testing shell scripts

Scripts in `.claude/scripts/` and `.claude/hooks/` should be tested standalone before merging:

```bash
# Simulate the JSON stdin a hook receives
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | ./.claude/hooks/block-secrets.sh
echo "Exit: $?"

# Utility scripts should be runnable directly
./.claude/scripts/check-snapshot.sh
```

Both should be deterministic. Random flakiness means users get random behavior.

## Questions

Open an issue with the `question` label. For larger discussions, open a discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
