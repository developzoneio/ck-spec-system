# ADR 0003: a sanctioned mid-execution re-plan loop, gated and append-only

- Status: proposed
- Date: 2026-07-22
- Source spec: Jira SW-14 (`FEAT-adaptive-replan`)
- Relates to: SW-13 (ADR 0002, pre-execution complexity triage); SW-4 (`/sd:spec validate`)
- Supersedes: none

## Context

The Planning pattern's core strength is **adaptivity** - re-planning when execution reveals new
information. specwright's immutability rule is right for audit, but it left the adaptive path
**undefined**. When an implementer discovers mid-Execute that `02-tasks.md` is wrong, the sanctioned
move did not exist: a model silently hack-edits the plan (violating sequencing, leaving no trail) or
stalls. ADR 0002 blocked oversized plans *before* execution; this is the second half of the
complex-task accuracy problem - fixing wrong plans *during* execution so errors stop compounding.

The measured evidence reshaped the ticket. In `asian-sportsbook-v2`, the only live repo running
specwright, 29 tasks across 5 specs contain exactly **one** real case of a wrong plan
(`FEAT-ASF-251`, retro line 27): *"My spec decision B was wrong to copy euro's CASESENSITIVE ...
Updated T8 to assert NO CASESENSITIVE. Spec Scenario 1 / decision B corrected."* Two facts matter:

1. The discovery surfaced at **batch review (Phase 5b)**, not mid-task. The gate must be reachable
   from the review phase, not only from the Execute loop.
2. The fix was a **hand-edit of T8 plus a spec correction, recorded as one retro sentence** - exactly
   the un-sanctioned path this work replaces. Immutability was already violated there, and nothing
   stopped it. No `## Revisions` log exists anywhere in the corpus.

Reading the workflow files corrected the ticket's stated scope. The ticket named "commands/feature.md
(+ bug/refactor/perf Execute phases)". But only **feature** and **refactor** produce a `01-plan.md` +
`02-tasks.md` pair (confirmed by `/sd:spec validate`'s own artifact-presence rule). `/sd:bug` and
`/sd:rca` have no atomic task list to re-plan; `/sd:perf` already carries its own adaptive loop
(Phase 4 reverts a failed hypothesis and re-selects at Gate 4). So the real scope is the two
plan+tasks workflows - and because both need the *identical* protocol for a shared linter to parse,
the protocol is defined once, not copy-pasted.

## Decision

1. **A shared skill, not a 12th command.** The re-plan protocol lives in one place -
   `skills/sd-replan-loop/SKILL.md` - read at runtime by `/sd:feature` and `/sd:refactor` (the same
   pattern by which `/sd:spec validate` reads `sd-severity-taxonomy`). The ticket's preferred
   in-workflow loop is honored *and* the copy-paste-drift the CLAUDE.md "one SKILL.md" rule forbids
   is avoided. Command count stays 12; skill count goes 7 -> 8.

2. **Gate Re-plan is a conditional HARD gate, reachable from Execute and review.** Like Gate
   Complexity (ADR 0002), it is not a new always-on gate: it fires only on a plan-invalidating
   discovery (Phase 4 self-check, or a Phase 5/6 review BLOCK that the *plan* - not the code - was
   wrong). When it fires it is HARD: explicit user approval, no override. A run that never hits a
   plan-invalidating discovery never sees it, so `/sd:feature` still advertises 3 hard gates and
   `/sd:refactor` still advertises 6.

3. **Append-only `## Revisions` log in `01-plan.md`.** On approval, a revision entry `R<n>` is
   appended below the original plan prose (never editing it): `Trigger`, `Phase`, `Gate: re-plan`,
   `Affected tasks`, `Delta`, `revised-from`. Numbering is contiguous from `R1`; a prior entry is
   never rewritten. Only the affected task blocks in `02-tasks.md` are regenerated (by
   `sd-spec-architect` via `TASK = plan` with a `REPLAN_SCOPE`), each marked `Revised-by: R<n>`; every
   other block stays byte-for-byte unchanged.

4. **No new architect mode.** Re-plan reuses `TASK = plan` with a `REPLAN_SCOPE` / `REVISION` pair
   rather than a fourth mode - a re-plan is a scoped plan, and it runs at most a handful of times per
   spec. `Revised-by` is a conditional field (like refactor's `Parallel batch`), present only on a
   regenerated task, never authored speculatively.

5. **`SL070`-`SL073` in `/sd:spec validate`.** A new **revision-log integrity** band, distinct from
   the `SL06x` task-content band and the `SL05x` link band (though it borrows the latter's two-sided
   symmetry shape). `SL070` dangling marker, `SL071` one-sided/unreferenced revision, `SL072` broken
   append-only history - all BLOCK (a lying audit trail). `SL073` malformed entry - WARN (poor record,
   still decidable). The checks run only when a `## Revisions` section or a `Revised-by` marker
   exists, so the common never-re-planned spec produces no finding.

## Consequences

**Positive.** The adaptive path is now sanctioned and audited. The one real corpus failure mode - a
plan proved wrong at review, then hand-patched with a retro sentence - now routes through a gate that
records the delta append-only and regenerates only the affected tasks, with the original plan intact.
Reuse of the existing `TASK = plan` mode, the `linked_specs`-style symmetry check, and the runtime
skill-read pattern means no new mechanism is invented. `/sd:perf` and `/sd:bug` are correctly left
alone.

**Negative.** `01-plan.md` and `02-tasks.md` are now a two-sided record that can disagree; the linter
carries `SL070`-`SL072` to catch that, which is more surface to maintain. `Revised-by` adds a
conditional field a careless author could sprinkle onto a Plan-phase task (where it is wrong); the
skill and the validate rule together catch it.

**Unresolved (stated, not hidden).** `/sd:spec validate` is a **static linter** with no Plan-phase
snapshot of `02-tasks.md`. It enforces the *internal consistency* of the revision record; it
**cannot** detect an undocumented silent edit by diffing. An edit that adds neither a `Revised-by`
marker nor a `## Revisions` entry is invisible to the lint and is prevented by the HARD gate, not by
`SL07x`. This is the honest boundary: the AC "validate rejects a `02-tasks.md` changed after Plan
phase with no revision log" is decidable precisely when the change is *marked*, and a compliant
re-plan always marks its work. Like `SL060` and the ADR-0002 gate, the gate itself is model-executed
prose with no CI driving a live `/sd:feature` run; conformance is asserted by the fixtures in
`tests/revision-log/` (a valid record passes, a dangling marker BLOCKs), not by a runner exercising a
full workflow.
