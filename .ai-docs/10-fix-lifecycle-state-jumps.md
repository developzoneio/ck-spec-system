# FIX: bug/rca/perf workflows skip lifecycle states defined by /sd:spec

- Priority: P2
- Area: `commands/spec.md`, `commands/bug.md`, `commands/rca.md`, `commands/perf.md`
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/lifecycle-state-jumps`

## Problem

`commands/spec.md:87-93` defines the only legal transitions:
`draft -> approved -> in-progress -> done -> archived`, and `/sd:spec status` refuses illegal
jumps (that refusal UX was deliberately built in PR #5). `commands/release.md:148` also relies
on "validated state-machine transition". But three workflows set frontmatter status directly
and skip states:

- `bug.md:65` sets `draft`, then `bug.md:224` jumps straight to `done` (draft -> done).
- `rca.md:58` sets `draft`, then `rca.md:140` sets `done` (draft -> done).
- `perf.md:62` starts at `approved`, then `perf.md:250` sets `done` (skips in-progress).

Feature and refactor walk the machine cleanly. Result: specs produced by three of five
workflows have histories the spec command itself would refuse, and `/sd:spec validate`'s
"status is in `spec.lifecycle`" checks sit on top of an inconsistent model.

## Fix — decide a policy first, then apply

Two coherent options; pick ONE (option A recommended for simplicity):

**Option A — workflows step through all states.** At the natural points in each workflow, set
the intermediate states explicitly:
- bug: `draft` at creation -> `approved` after the repro gate (Gate 2 approval is the natural
  approval point) -> `in-progress` when the fix implementation starts -> `done` at close.
- rca: `draft` at creation -> `approved` when the user approves the root cause ->
  `in-progress` during report writing (or skip via B for RCA only) -> `done` at close.
- perf: add `draft` before `approved` (creation vs target-approval Gate 1), set `in-progress`
  when the optimization loop starts, `done` at close.

**Option B — document type-specific lifecycles.** Extend `spec.md` (and
`templates/project-config.template.json` `spec.lifecycle` if it encodes transitions) with
per-type legal paths, e.g. bug/rca may go `draft -> done`. This preserves current workflow
text but complicates the state machine and every consumer (release, validate, status).

Whichever option: `spec.md` transitions, the three workflow files, `release.md`'s assumptions,
and `/sd:spec validate` rules must end up mutually consistent.

## Acceptance criteria

1. For each of the 5 workflows, the sequence of `status=` assignments in the command file is a
   legal path under `spec.md`'s (possibly updated) transition rules.
2. `/sd:spec status` applied to a spec at any point mid-workflow would accept the next
   transition the workflow performs.
3. `docs/usage.md` / `docs/architecture.md` lifecycle descriptions (if any) match.

Add a CHANGELOG `### Fixed` (A) or `### Changed` (B) entry under `## [Unreleased]`.
