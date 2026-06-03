---
id: <<BUG-XXX>>
type: bug
severity: <<P0|P1|P2|P3>>
status: draft
jira: <<TICKET-ID-or-none>>
created: <<YYYY-MM-DD>>
---

# <<Short imperative title - what is broken>>

## Symptom

<!-- What the user / operator observes. Verbatim if from a ticket. -->
<!-- Include error messages, screenshots references (under 04-artifacts/), stack traces. -->

<<paragraph or bulleted list of observed symptoms>>

**First reported**: <<date / by whom / where>>
**Frequency**: <<every request | intermittent (~N%) | one-off | escalating>>
**Environment**: <<prod | staging | dev | all>>

## Expected

<!-- What SHOULD happen. Contrast with Symptom. -->

<<one paragraph>>

## Reproduction

<!-- Deterministic steps. If non-deterministic, capture the conditions that make it more likely. -->
<!-- Gate 2 (Reproduce) requires this section to be confirmed working before Phase 3. -->

1. <<step 1, including exact inputs>>
2. <<step 2>>
3. <<step 3 - observe symptom>>

**Reproduction rate**: <<100% | ~N% | unable to reproduce locally - see 04-artifacts/ for prod logs>>
**Minimal repro available**: <<yes - tests/repro/BUG-XXX_test.cs | no, see steps above>>

## Affected

- **Components**: <<list, e.g. src/Application/Handlers/StockHandler.cs, src/Infrastructure/Cache/RedisStockCache.cs>>
- **Users / scope**: <<who is impacted, e.g. all tenants on plan tier "premium">>
- **First introduced**: <<commit SHA / version / "before known history">>
- **Workaround available**: <<yes - <description> | no>>

## Root cause

<!-- DO NOT FILL until Phase 3 (Investigate). -->
<!-- Filled by sd-debugger output after hypothesis verification. -->
<!-- Must be: a named, fixable cause. NOT a symptom restatement. -->
<!-- Format: "X happens because Y, which violates assumption Z." -->

**Status**: TBD - filled by Phase 3 investigation.

<<root cause statement with file:line citations>>

**Why this is root cause, not a symptom**: <<explanation>>

## Fix approach

<!-- DO NOT FILL until root cause is confirmed at Gate 3. -->
<!-- Filled after Phase 3, before Phase 4 (failing test). -->
<!-- Must be MINIMAL. No opportunistic refactor. -->

**Status**: TBD - filled after root cause confirmed.

- <<change 1, with target file>>
- <<change 2, with target file>>

**Scope discipline check**:
- [ ] Fix touches only files implicated by root cause
- [ ] No "while I'm here" cleanups
- [ ] No reformatting unrelated code
- [ ] If a refactor is needed, spawn a separate REF-* spec - do not bundle

## Regression test checklist

<!-- Tests that must exist after this fix. Gate 4 requires the failing test BEFORE fix is applied. -->

- [ ] Failing test added that reproduces the bug (Phase 4 Gate 4)
- [ ] Failing test now passes with fix applied
- [ ] Test placed under tests/<<path mirroring source>>
- [ ] Test name describes the bug, not the fix (e.g. `Should_NotDoubleDecrement_When_RetryAfterTransientFailure`)
- [ ] Adjacent edge cases also covered if cheap
- [ ] CI passes locally

## Constitution check

- **Applicable sections**: <<§N.M ...>>
- **Violation in current code that caused the bug**: <<yes - §N.M was bypassed | no - bug is within rules but rules are insufficient>>
- **If rules insufficient**: <<recommend constitution amendment as follow-up spec>>
