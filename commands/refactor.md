---
description: Coverage-gated refactor workflow. Spec -> impact -> coverage -> plan -> batched execute -> holistic review. 6 hard gates.
argument-hint: <slug> [smell-type]
---

# /sd:refactor

Drives a behavior-preserving restructure. Refuses to touch code until coverage on affected files meets threshold. Each step keeps all tests green. Result under `.specs/REF-<slug>-<YYYYMMDD>/`.

**Arguments**:
- `$1` (required): slug, e.g. `extract-pricing-service`.
- `$2` (optional): smell type. One of `extract-method`, `extract-class`, `rename`, `inline`, `move`, `replace-conditional`, `reduce-coupling`, `other`.

Spec ID = `REF-<slug>-<YYYYMMDD>`.

---

## HARD RULES (read before every phase)

1. **Never refactor without adequate test coverage.** Default threshold: 80% line coverage on affected files. Configurable via `quality.refactorCoverageThreshold` in `project-config.json`.
2. **Each step keeps all tests green.** A red test is a stop condition - revert or fix before continuing.
3. **No opportunistic feature work.** Refactor = restructure. New behavior goes in a separate FEAT-* spec.
4. **Public API preserved unless the spec states otherwise.** If consumers exist, they must continue to work.

---

## State machine (resume behavior)

| Detected state | Action |
|---|---|
| Folder not found | Start at Phase 1 |
| `00-spec.md` status `draft` | Resume Phase 1 |
| status `approved`, no `03-decisions.md` | Resume Phase 2 |
| Impact mapped, coverage not measured | Resume Phase 3 |
| Coverage above threshold, no `02-tasks.md` | Resume Phase 4 |
| Tasks present with unchecked items | Resume Phase 5 |
| All tasks checked, no holistic review | Resume Phase 6 |
| status `done` | Refuse |

---

## Phase 0 - Bootstrap

1. Read `CLAUDE.md`, `.specs/constitution.md`, `.claude/project-config.json`, `.specs/index.md`.
2. Compute UTC date for spec ID.
3. Read coverage threshold from project-config or default to 80%.
4. Detect state. Print resume plan.

---

## Phase 1 - Spec

1. Invoke `sd-spec-architect` with:
   - `TASK = create`
   - `TEMPLATE = refactor.template.md`
   - `SPEC_ID = REF-<slug>-<YYYYMMDD>`
   - `SMELL = <$2 or 'other'>`
2. Architect fills Smell/Driver, Current state (high level), Target state, **Invariants - MUST preserve** (concrete, checkable), Out of scope.
3. Architect leaves "Impact surface" TBD - Phase 2 fills it.

### ⛔ Gate 1 - Spec approval

STOP. Display spec summary, especially Invariants and Out-of-scope. Ask:

> Approve refactor spec REF-<slug>? (yes / refine / abort)

- `yes` -> status=`approved`, append to index, proceed.
- `refine <feedback>` -> loop with architect.

---

## Phase 2 - Impact

1. Invoke `sd-code-explorer` with:
   - `TASK = impact-map`
   - `SPEC = .specs/REF-<slug>-<YYYYMMDD>/00-spec.md`
   - `OUTPUT_APPEND_TO = .specs/REF-<slug>-<YYYYMMDD>/03-decisions.md`
2. Explorer enumerates: direct callers, transitive callers (2-3 hop), test coverage scan of affected paths, DI / config grep, public API surface, risk assessment.
3. Every finding cites file:line.

No gate here - read-only.

---

## Phase 3 - Coverage gate

1. Run coverage via `commands.coverage`. Filter to files listed in "Impact surface" and "Current state - Primary file".
2. Write the measured percentages to `00-spec.md` under "Test coverage prerequisite":
   - Current measured: `<N%>`
   - Gap: `<threshold - measured>`

### ⛔ Gate 2 - Coverage threshold met

STOP. Compare measured vs threshold.

- **If measured >= threshold** -> proceed to Phase 4.
- **If measured < threshold** -> REFUSE. Display:
  > Coverage on affected files is <measured>%, below threshold <threshold>%. Refactor is blocked.
  > Options: (1) add characterization tests now (recommended), (2) lower threshold for this spec with explicit constitution exception, (3) abort.

If user picks (1), enter the characterization sub-loop:
1. Identify uncovered branches via coverage report.
2. Invoke `sd-implementer` with `TASK_TYPE = characterization-test` per uncovered area.
3. Each new test must FAIL FAST if current behavior changes - characterization tests pin the CURRENT behavior, correct or not.
4. Re-measure coverage.

### ⛔ Gate 3 - Post-test coverage check

STOP. After characterization tests are added, re-run coverage.

- Coverage now >= threshold -> proceed.
- Still below -> loop, or escalate to constitution exception with user approval.

If user picks (2) explicit exception, document the threshold reduction in `05-retro.md` with reasoning. Log as a constitution exception.

---

## Phase 4 - Plan parallel-safe tasks

1. Invoke `sd-spec-architect` with:
   - `TASK = plan`
   - `SPEC = .specs/REF-<slug>-<YYYYMMDD>/00-spec.md`
   - `IMPACT = .specs/REF-<slug>-<YYYYMMDD>/03-decisions.md`
   - `MODE = refactor`
2. Architect writes `01-plan.md` (sequencing) and `02-tasks.md`. Each task uses the canonical format PLUS refactor-specific fields:

```
### T<NN> - <title>
- Files: <list of files to touch>
- Layer: <Domain | Application | Infrastructure | Presentation>
- Step type: <foundation | behavior | wiring | polish | test>
- Test: <test file/method to create or update>
- Acceptance: <one-line criterion>
- Depends on: <T## or "none">
- Conflicts with: <T## or "none">
- Complexity: <S | M | L>
- Reversibility: <trivial | moderate | hard>
- Pattern refs: <1-3 file:line precedent citations + what to mirror, or "none">
- Parallel batch: <batch number or "solo">
```

### ⛔ Gate 4 - Plan approval

STOP. Display batch groupings. Ask:

> Approve plan with <N> batches? (yes / refine / abort)

- `yes` -> status=`in-progress`, update index, proceed.

---

## Phase 5 - Execute batched

For each batch (up to 3 tasks in parallel):

1. **Pre-batch**: run full test suite. Must be green. If red, abort batch and surface failure - the baseline must be clean.
2. For each task in the batch:
   - Invoke `sd-implementer` with:
     - `TASK_DETAILS = <task block>`
     - `SPEC_REF = .specs/REF-<slug>-<YYYYMMDD>/00-spec.md`
     - `IMPACT_REF = .specs/REF-<slug>-<YYYYMMDD>/03-decisions.md`
     - `WORKFLOW_TYPE = refactor`
     - `INVARIANTS = <invariants list from spec>`
   - Implementer's constraint set is tightest in refactor mode: NO new public API, NO new feature, ONLY restructure.
3. **Post-batch**: run full test suite via `commands.test`.

### ⛔ Gate 5 - Tests green per batch

STOP after every batch. Display test results.

- All green -> check off tasks in `02-tasks.md`, proceed to next batch.
- Any red -> REFUSE to proceed. Revert the batch or fix the regression. The point of batched-with-tests-between is to localize failures.

---

## Phase 6 - Holistic review

After all batches complete:

1. Invoke `sd-reviewer` with:
   - `TASK_TYPE = holistic`
   - `SPEC_REF = .specs/REF-<slug>-<YYYYMMDD>/00-spec.md`
   - `INVARIANTS = <invariants list>`
   - `CHANGED_FILES = <all files touched across batches>`
2. Reviewer checks:
   - Invariants preserved (each one explicitly verified).
   - No new constitution exceptions introduced.
   - No public API drift (unless spec stated otherwise).
   - No opportunistic feature additions.
   - Test coverage did not decrease (run coverage again, compare to Phase 3 number).

### ⛔ Gate 6 - Holistic review pass

STOP. Display reviewer verdict counts + invariant verification table. Ask:

> Refactor REF-<slug> ready for close-out? (yes / address findings / abort)

- `yes` -> proceed.
- Any 🔴 BLOCK -> loop to implementer with the finding.

---

## Phase 7 - Close-out

1. Append to `05-retro.md`:
   - Tasks completed (count + IDs).
   - Coverage before / after.
   - Invariants verified (table).
   - Surprises (e.g. discovered dead code, unexpected callers).
   - Constitution exceptions (should be none).
2. Set status=`done`. Update index.
3. If retro reveals follow-ups (e.g. "this refactor exposes a perf concern"), suggest spawning the relevant spec.

---

## Rules (hard constraints)

- Gate 2 (Coverage) is HARD. No code edits until threshold met OR explicit exception logged.
- Gate 5 (Tests green per batch) is HARD. A red batch is reverted or fixed - never deferred.
- Implementer in refactor mode has the tightest scope discipline. Any "improvement" beyond restructuring is rejected.
- Public API preservation is verified by reviewer (Phase 6), not assumed.
- Max 3 parallel tasks per batch. More -> tests-between granularity is too coarse.
- Each batch's tests must finish before the next batch starts. No "tests run in background while next batch starts".
