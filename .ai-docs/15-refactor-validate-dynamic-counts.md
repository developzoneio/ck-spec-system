# REFACTOR: derive validate counts from the source tree instead of hardcoding

- Priority: P3
- Area: `scripts/validate.sh`, `scripts/validate.ps1`
- Status: VERIFIED (counts currently correct: 11/6/6/3/9 — this is maintenance-tax removal,
  not a bug fix)
- Suggested branch: `refactor/validate-dynamic-counts`

## Problem

`scripts/validate.sh:22-26` and `scripts/validate.ps1:35-39` hardcode expected install counts
(11 commands / 6 agents / 6 skills / 3 hooks per platform / 9 templates) as literals in TWO
files. Every new command/agent/skill/template requires editing both scripts or CI fails with
an opaque count mismatch — this already bit PR #12, which had to bump constants in both files.

The check's real purpose is INSTALL FIDELITY: "everything in the source tree arrived at the
install destination." That is better expressed by deriving the expectation from the tree.

## Fix

In both scripts, replace the literal constants with counts computed from the repo:

- expected commands = count of `commands/*.md`
- expected agents = count of `agents/*.md`
- expected skills = count of `skills/*/SKILL.md`
- expected hooks per platform = count of `hooks/bash/*.sh` (and assert it equals the count of
  `hooks/powershell/*.ps1` — the pair-parity check may already do this; do not double-report)
- expected templates = count of files under `templates/` (recursive)

Then compare each against the actual files landed by the temp install, as today.

Guard against the degenerate pass: assert each derived count is > 0 (an empty source dir must
FAIL, not vacuously pass). Optionally keep a single floor sanity check (e.g. commands >= 11)
so a mass-deletion cannot slip through — judgment call; document the choice in the script
comment either way.

Bash/PowerShell implementations must agree (pair discipline applies to scripts here in
spirit; both validators must enforce the same rules).

## Acceptance criteria

1. No literal asset-count constants remain in either validate script (floor checks excepted
   if chosen).
2. Adding a dummy `commands/zz-test.md` and re-running validate passes the count check without
   editing the scripts (remove the dummy afterwards).
3. Emptying a source dir in a scratch copy makes validate FAIL.
4. Both scripts produce the same pass/fail on the same tree; CI green on all platforms.

Add a CHANGELOG `### Changed` entry under `## [Unreleased]`.
