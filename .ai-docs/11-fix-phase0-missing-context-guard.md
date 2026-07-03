# FIX: workflow Phase 0 has no error path for missing/malformed Layer-2 context

- Priority: P2
- Area: `commands/feature.md`, `commands/bug.md`, `commands/refactor.md`, `commands/perf.md`,
  `commands/rca.md`
- Status: VERIFIED (agent-audited; re-verify line numbers before editing)
- Suggested branch: `fix/phase0-context-guard`

## Problem

All five workflow commands open with a Phase 0 bootstrap: "Read `CLAUDE.md`,
`.specs/constitution.md`, `.claude/project-config.json`, `.specs/index.md`"
(`feature.md:32-36`, `bug.md:42`, `perf.md:41`, `rca.md:30`, `refactor.md:44`) — with NO
handling when any of these is absent or unparseable. The next phases then reference
`commands.test`, `ticket.pattern`, lifecycle values etc. from a config that was never loaded.

The four utility commands already handle this correctly: `adr.md:18`, `review.md:21`,
`release.md:38`, `spec.md:36` all abort with a "run `/sd:setup` first" style message when
`.specs/`/index/constitution is missing.

## Fix

Add a consistent guard block to Phase 0 of all five workflow commands. Semantics (mirror the
utility commands' wording where possible):

- `.specs/` dir or `.specs/index.md` or `.specs/constitution.md` missing -> STOP: "This project
  is not set up for spec-driven work. Run `/sd:setup` first."
- `.claude/project-config.json` missing -> STOP with the same setup hint (or, if the file is
  documented as optional anywhere, degrade with an explicit warning — check `setup.md` and
  `docs/architecture.md` for whether config is mandatory before choosing).
- `project-config.json` present but malformed JSON -> STOP: name the file, say it failed to
  parse, suggest fixing or re-running `/sd:setup`. Never silently continue.
- Root `CLAUDE.md` missing -> WARN and continue (a repo may legitimately not have one; the
  constitution is the binding Layer-2 contract). Confirm this stance against `setup.md`.

Implementation options:
1. Inline the same short guard block in all five files (simple, but 5 copies — see doc 12 on
   duplication; a shared "phase-0 bootstrap" skill or a shared section referenced by all five
   would honor CLAUDE.md:59).
2. If a shared skill is created (e.g. `sd-phase0-bootstrap`), remember skills install counts:
   `scripts/validate.{ps1,sh}` hardcode 6 skills and README/CLAUDE.md state counts — bump
   everywhere (or land doc 15 first to make counts dynamic).

Option 1 (inline, identical wording) is the low-risk choice; note the duplication tradeoff in
the PR description.

## Acceptance criteria

1. Each of the 5 workflow commands has an explicit STOP path for missing `.specs/` scaffold
   and malformed config, with wording consistent with `spec.md:36` / `release.md:38`.
2. No workflow phase after Phase 0 references config values without the guard having run.
3. `scripts/validate.sh` passes (counts unchanged if inline option chosen).

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
