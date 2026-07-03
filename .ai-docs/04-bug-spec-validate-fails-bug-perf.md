# BUG: /sd:spec validate fails every correct bug and perf spec

- Priority: P1
- Area: `commands/spec.md` (validate behavior)
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/spec-validate-type-aware`

## Problem

`commands/spec.md:205` (validate rules):

```text
- status >= `in-progress` -> `01-plan.md` and `02-tasks.md` exist (except RCA).
```

Only RCA is exempted. But the bug and perf workflows NEVER create `01-plan.md` or
`02-tasks.md`:

- `/sd:bug` goes symptom -> repro -> investigate -> failing test -> fix; its artifacts are
  `00-spec.md`, `03-decisions.md`, `04-artifacts/`, `05-retro.md` (see `commands/bug.md`).
- `/sd:perf` goes target -> baseline -> hotspot loop; same artifact set (see `commands/perf.md`).

So `/sd:spec validate` reports FAIL for every correctly executed bug/perf spec once it reaches
in-progress. This matters doubly because `commands/release.md:50` tells users to run
`/sd:spec validate <ID>` whenever index/spec drift is detected — the recommended remediation
path produces false failures.

## Fix

Make the file-presence check type-aware in `commands/spec.md` validate behavior. Suggested
wording:

```text
- status >= `in-progress` -> `01-plan.md` and `02-tasks.md` exist (feature and refactor only;
  bug, perf, and rca do not produce plan/tasks artifacts).
```

Before writing, confirm the exact artifact set per type by reading each workflow command
(`feature.md`, `bug.md`, `refactor.md`, `perf.md`, `rca.md`) — the fix must match what the
workflows actually create, not this document. Also check whether `templates/specs/*.template.md`
or `docs/usage.md` state the per-type artifact sets and keep them consistent.

## Acceptance criteria

1. Validate rules in `spec.md` require `01-plan.md`/`02-tasks.md` only for spec types whose
   workflow actually creates them.
2. The `status == done -> 05-retro.md exists` rule is untouched (all workflows write a retro).
3. No other command references the old blanket rule (grep for `01-plan.md` across `commands/`).

## Verification

```bash
grep -rn "01-plan" commands/ docs/ templates/
./scripts/validate.sh
```

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
