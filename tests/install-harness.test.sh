#!/usr/bin/env bash
# install-harness.test.sh
# Fixture suite for install-harness.sh's per-item linking of skills and agents.
#
# The point of per-item links: a skill or agent the repo versions itself keeps
# loading next to the harness's, instead of vanishing behind one link that
# replaced the whole .claude/skills folder. These tests pin that, plus what it
# costs (an item the harness adds or renames needs a re-run), the collision
# rules, the conversion from the old whole-folder layout, --unlink, the per-item
# .git/info/exclude block, and check-baseline.sh reporting a missing item.
#
# Builds a throwaway FAKE harness (a copy of the installer next to a tiny
# baseline/) and throwaway consumer repos in a mktemp dir. Never touches this
# checkout's files, your real harness clone, or ~/.claude.
#
# Run: bash tests/install-harness.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP="$(mktemp -d)"; TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

PASS_COUNT=0; FAIL_COUNT=0
_pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
_ok()   { if eval "$2"; then _pass "$1"; else _fail "$1  [$2]"; fi; }
_has()  { if grep -qF -- "$3" "$2"; then _pass "$1"; else _fail "$1 (looked for: $3)"; echo "----- $2"; cat "$2"; echo "-----"; fi; }
_hasnt(){ if grep -qF -- "$3" "$2"; then _fail "$1 (should not contain: $3)"; else _pass "$1"; fi; }

# ---------------------------------------------------------------- fixtures
H="$TMP/harness"
mk_skill() { mkdir -p "$1/$2"; printf -- '---\nname: %s\ndescription: fixture skill %s\n---\nbody\n' "$2" "$2" > "$1/$2/SKILL.md"; }
mk_agent() { printf -- '---\nname: %s\ndescription: fixture agent\n---\nbody\n' "${2%.md}" > "$1/$2"; }
build_harness() {
  rm -rf "$H"; mkdir -p "$H/baseline"/{skills,agents,rules,docs,scripts,hooks}
  cp "$ROOT/install-harness.sh" "$H/install-harness.sh"
  cp "$ROOT/baseline/scripts/check-baseline.sh" "$H/baseline/scripts/check-baseline.sh"
  mk_skill "$H/baseline/skills" alpha; mk_skill "$H/baseline/skills" beta
  mk_agent "$H/baseline/agents" a1.md
  printf -- '---\npaths: ["**"]\n---\nrule\n' > "$H/baseline/rules/delegation.md"
  echo doc > "$H/baseline/docs/d.md"
  for h in block-secrets.sh protect-main.sh protect-harness.sh log-agent.sh log-edit.sh; do printf '#!/bin/sh\nexit 0\n' > "$H/baseline/hooks/$h"; done
  printf '#!/bin/sh\nexit 0\n' > "$H/baseline/scripts/check-index.sh"
  ( cd "$H" && git init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
}
# A consumer repo that versions its own skill and its own agent.
new_repo() {
  local r="$TMP/$1"; rm -rf "$r"; mkdir -p "$r/.claude/skills" "$r/.claude/agents"
  mk_skill "$r/.claude/skills" repo-skill
  mk_agent "$r/.claude/agents" mine.md
  ( cd "$r" && git init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
  printf '%s' "$r"
}
inst() { ( cd "$1" && shift && bash "$H/install-harness.sh" "$@" ) > "$TMP/out" 2>&1; echo $? > "$TMP/rc"; }
rc() { cat "$TMP/rc"; }

build_harness

# ---------------------------------------------------------------- 1. fresh install
R=$(new_repo fresh)
inst "$R"
_ok  "fresh: installs without --adopt although .claude/skills is a real folder" '[[ $(rc) -eq 0 ]]'
_ok  "fresh: .claude/skills stays a real folder"                 '[[ -d $R/.claude/skills && ! -L $R/.claude/skills ]]'
_ok  "fresh: each harness skill is its own link into baseline"   '[[ $(readlink $R/.claude/skills/alpha) == $H/baseline/skills/alpha ]]'
_ok  "fresh: agents are linked per item too"                     '[[ $(readlink $R/.claude/agents/a1.md) == $H/baseline/agents/a1.md ]]'
_ok  "fresh: the repo's own skill is untouched"                  '[[ -f $R/.claude/skills/repo-skill/SKILL.md && ! -L $R/.claude/skills/repo-skill ]]'
_ok  "fresh: the repo's own agent is untouched"                  '[[ -f $R/.claude/agents/mine.md && ! -L $R/.claude/agents/mine.md ]]'
_ok  "fresh: git status clean (links excluded, nothing reported deleted)" '[[ -z $(git -C $R status --porcelain) ]]'
_ok  "fresh: no .pre-harness created"                             '[[ ! -e $R/.claude/skills.pre-harness ]]'
_has "fresh: exclude lists items one by one"                     "$R/.git/info/exclude" ".claude/skills/alpha"
_ok  "fresh: exclude does NOT ignore the whole skills folder"    '! grep -qx ".claude/skills" $R/.git/info/exclude'
mk_skill "$R/.claude/skills" brand-new
_ok  "fresh: a new skill the repo adds is not git-ignored"       '[[ -n $(git -C $R status --porcelain -- .claude/skills/brand-new) ]]'
rm -rf "$R/.claude/skills/brand-new"

( cd "$R" && bash "$H/install-harness.sh" --status ) > "$TMP/st" 2>&1
_has "status: reports skills linked with the repo's own alongside" "$TMP/st" "linked (2/2), 1 of the repo's own alongside"
_has "status: agents too"                                          "$TMP/st" "agents         linked (1/1), 1 of the repo's own alongside"

# ---------------------------------------------------------------- 2. idempotent
cp "$R/.git/info/exclude" "$TMP/ex1"
inst "$R"
_ok    "rerun: exit 0"                                 '[[ $(rc) -eq 0 ]]'
_hasnt "rerun: links nothing new"                      "$TMP/out" "link       .claude/skills/"
_has   "rerun: says already linked"                    "$TMP/out" "ok         .claude/skills (2 already linked)"
_ok    "rerun: exclude byte-identical (no pile-up)"    'cmp -s $TMP/ex1 $R/.git/info/exclude'

# ---------------------------------------------------------------- 3. harness adds and renames
mk_skill "$H/baseline/skills" gamma
mv "$H/baseline/skills/beta" "$H/baseline/skills/beta2"; sed -i.bak 's/name: beta/name: beta2/' "$H/baseline/skills/beta2/SKILL.md"; rm -f "$H/baseline/skills/beta2/SKILL.md.bak"
( cd "$R" && bash "$H/install-harness.sh" --status ) > "$TMP/st" 2>&1
_has "added: status flags the gap and says to re-run"  "$TMP/st" "PARTIAL"
( cd "$R" && bash "$H/baseline/scripts/check-baseline.sh" ) > "$TMP/cb" 2>&1
_has "added: check-baseline names the item with no link" "$TMP/cb" ".claude/skills/gamma"
_has "renamed: check-baseline flags the dangling link"   "$TMP/cb" ".claude/skills/beta ->"
inst "$R"
_ok  "added: re-run links the new skill"               '[[ -L $R/.claude/skills/gamma ]]'
_ok  "renamed: re-run links the new name"              '[[ -L $R/.claude/skills/beta2 ]]'
_ok  "renamed: re-run drops the stale link"            '[[ ! -e $R/.claude/skills/beta && ! -L $R/.claude/skills/beta ]]'
_has "added: exclude now lists it"                     "$R/.git/info/exclude" ".claude/skills/gamma"
_ok  "renamed: exclude no longer lists the old name"   '! grep -qx ".claude/skills/beta" $R/.git/info/exclude'
_ok  "added/renamed: repo skill still untouched"       '[[ -f $R/.claude/skills/repo-skill/SKILL.md ]]'
( cd "$R" && bash "$H/baseline/scripts/check-baseline.sh" ) > "$TMP/cb" 2>&1
_hasnt "after re-run: check-baseline quiet about items" "$TMP/cb" "no link for them"
build_harness

# ---------------------------------------------------------------- 4. same-name collision
R=$(new_repo clash)
mk_skill "$R/.claude/skills" alpha
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m own-alpha )
inst "$R"
_ok  "clash: stops without --adopt"                    '[[ $(rc) -eq 2 ]]'
_has "clash: names the colliding item"                 "$TMP/out" ".claude/skills/alpha"
_ok  "clash: nothing changed (no link made)"           '[[ ! -L $R/.claude/skills/beta && ! -L $R/.claude/agents/a1.md ]]'
_ok  "clash: nothing changed (no exclude written)"     '! grep -q "claude harness" $R/.git/info/exclude'
inst "$R" --adopt
_ok  "clash --adopt: exit 0"                           '[[ $(rc) -eq 0 ]]'
_ok  "clash --adopt: only the colliding item set aside" '[[ -f $R/.claude/skills.pre-harness/alpha/SKILL.md ]]'
_ok  "clash --adopt: linked over it"                    '[[ -L $R/.claude/skills/alpha ]]'
_ok  "clash --adopt: the repo's other skill stays and loads" '[[ -f $R/.claude/skills/repo-skill/SKILL.md && ! -L $R/.claude/skills/repo-skill ]]'
_has "clash --adopt: warns that git now sees a deletion" "$TMP/out" "Do not commit while adopted"
inst "$R" --unlink
_ok  "clash --unlink: our links gone"                  '[[ ! -L $R/.claude/skills/beta && ! -L $R/.claude/agents/a1.md ]]'
_ok  "clash --unlink: set-aside item restored"         '[[ -f $R/.claude/skills/alpha/SKILL.md && ! -L $R/.claude/skills/alpha ]]'
_ok  "clash --unlink: .pre-harness gone"               '[[ ! -e $R/.claude/skills.pre-harness ]]'
_ok  "clash --unlink: git status clean again"          '[[ -z $(git -C $R status --porcelain) ]]'
_ok  "clash --unlink: exclude block removed"           '! grep -q "claude harness" $R/.git/info/exclude'

# ---------------------------------------------------------------- 5. old whole-folder layout
# What the previous installer left behind after --adopt: the whole folder moved
# to skills.pre-harness/ (repo-owned skill included) and one link over it.
R=$(new_repo old)
( cd "$R" && mv .claude/skills .claude/skills.pre-harness && ln -s "$H/baseline/skills" .claude/skills \
  && mk_skill .claude/skills.pre-harness old-vendored && mk_skill .claude/skills.pre-harness alpha )
_ok  "old: precondition, git sees the repo skill as deleted" 'git -C $R status --porcelain | grep -q "D .claude/skills/repo-skill"'
( cd "$R" && bash "$H/install-harness.sh" --status ) > "$TMP/st" 2>&1
_has "old: status names the old layout"                "$TMP/st" "whole-folder link (old layout"
inst "$R" --dry-run
_ok  "old --dry-run: changes nothing"                   '[[ -L $R/.claude/skills ]]'
_has "old --dry-run: announces the conversion"          "$TMP/out" "convert    .claude/skills"
inst "$R"
_ok  "old: converted to a real folder"                  '[[ -d $R/.claude/skills && ! -L $R/.claude/skills ]]'
_ok  "old: tracked repo skill restored from .pre-harness" '[[ -f $R/.claude/skills/repo-skill/SKILL.md && ! -L $R/.claude/skills/repo-skill ]]'
_ok  "old: git no longer sees it deleted"               '! git -C $R status --porcelain | grep -q "repo-skill"'
_ok  "old: untracked old vendored copy stays buried"    '[[ -d $R/.claude/skills.pre-harness/old-vendored && ! -e $R/.claude/skills/old-vendored ]]'
_ok  "old: a harness name stays buried, link wins"      '[[ -d $R/.claude/skills.pre-harness/alpha && -L $R/.claude/skills/alpha ]]'
_ok  "old: old exclude line for the whole folder gone"  '! grep -qx ".claude/skills" $R/.git/info/exclude'

# ---------------------------------------------------------------- 6. repo with no skills of its own
R="$TMP/bare"; mkdir -p "$R"; ( cd "$R" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
inst "$R"
_ok  "bare: creates .claude/skills with the links"      '[[ -L $R/.claude/skills/alpha ]]'
_ok  "bare: git status clean"                            '[[ -z $(git -C $R status --porcelain) ]]'
inst "$R" --unlink
_ok  "bare --unlink: removes the now-empty folders"      '[[ ! -e $R/.claude/skills && ! -e $R/.claude/agents ]]'

# ---------------------------------------------------------------- 7. copy fallback
# A platform that will not symlink: a fake `ln` on PATH that always fails.
R=$(new_repo copies)
mkdir -p "$TMP/noln"; printf '#!/bin/sh\nexit 1\n' > "$TMP/noln/ln"; chmod +x "$TMP/noln/ln"
( cd "$R" && PATH="$TMP/noln:$PATH" bash "$H/install-harness.sh" ) > "$TMP/out" 2>&1
_has "copy: says COPIED per item"                       "$TMP/out" "COPIED     .claude/skills/alpha"
_ok  "copy: a real copy, listed in the manifest"        '[[ -f $R/.claude/skills/alpha/SKILL.md && ! -L $R/.claude/skills/alpha ]] && grep -qx alpha $R/.claude/skills/.harness-copies'
_ok  "copy: git status clean (copies and manifest excluded)" '[[ -z $(git -C $R status --porcelain) ]]'
echo changed >> "$H/baseline/skills/alpha/SKILL.md"
( cd "$R" && bash "$H/baseline/scripts/check-baseline.sh" ) > "$TMP/cb" 2>&1
_has "copy: check-baseline flags a copy that fell behind" "$TMP/cb" ".claude/skills/alpha"
inst "$R" --unlink
_ok  "copy --unlink: copies removed, repo skill kept"   '[[ ! -e $R/.claude/skills/alpha && -f $R/.claude/skills/repo-skill/SKILL.md && ! -e $R/.claude/skills/.harness-copies ]]'
build_harness

# ---------------------------------------------------------------- 8. spec-worktree carries the links
# The links are gitignored, so a new worktree gets the repo's own skills from
# the checkout but not the harness's; spec-worktree.sh has to carry them over.
cp "$ROOT/baseline/scripts/spec-worktree.sh" "$H/baseline/scripts/spec-worktree.sh"
R="$TMP/wtrepo"; mkdir -p "$R/.claude/skills"; mk_skill "$R/.claude/skills" repo-skill
( cd "$R" && git init -q -b main . && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
inst "$R"
( cd "$R" && bash "$H/baseline/scripts/spec-worktree.sh" probe ) > "$TMP/wt" 2>&1
WT="$TMP/wtrepo.probe"
_ok  "worktree: created"                                '[[ -d $WT/.claude ]]'
_ok  "worktree: harness skill link carried over"        '[[ $(readlink $WT/.claude/skills/alpha) == $H/baseline/skills/alpha ]]'
_ok  "worktree: harness agent link carried over"        '[[ -L $WT/.claude/agents/a1.md ]]'
_ok  "worktree: repo skill arrives from the checkout"   '[[ -f $WT/.claude/skills/repo-skill/SKILL.md && ! -L $WT/.claude/skills/repo-skill ]]'
_ok  "worktree: git status clean"                       '[[ -z $(git -C $WT status --porcelain) ]]'

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ $FAIL_COUNT -eq 0 ]]
