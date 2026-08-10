---
id: BUG-CLEAN-003
type: bug
severity: P1
status: done
jira: none
created: 2026-07-01
linked_specs:
  - blocks: FEAT-CLEAN-001
---

# Stock deduction double-counts on retry

## Symptom

A retried deduction request subtracts stock twice.

**First reported**: 2026-07-01 by ops
**Frequency**: intermittent (~3%)
**Environment**: prod

## Expected

A retried request is idempotent and deducts once.

## Reproduction

1. POST /api/stock/deduct with idempotency key K.
2. Force a timeout, then replay the same request with key K.
3. Observe stock reduced by 2x the requested quantity.

## Affected

- **Users / scope**: all tenants
- **First introduced**: v2.3.0
- **Workaround available**: no

## Root cause

**Status**: Confirmed at Gate 3.

The idempotency key is checked after the deduction is written, not before, so a replay inside the
write window applies twice (`src/Stock/StockDeductionService.cs:118`).

**Why this is root cause, not a symptom**: the double-write disappears when the key check is
moved ahead of the write, verified by the failing test added in Phase 4.

## Fix approach

**Status**: Confirmed after root cause.

- Move the idempotency check ahead of the write in `src/Stock/StockDeductionService.cs`.
- The check could move into a guard clause for readability - deferred to a separate spec, since
  that is a pure structural cleanup and not part of this fix.

**Scope discipline check**:
- [x] Fix touches only files implicated by root cause
- [x] No "while I'm here" cleanups

## Regression test checklist

- [x] Failing test added that reproduces the bug (Phase 4 Gate 4)
- [x] Failing test now passes with fix applied

## Spawned specs

| Reserved ID | Type | Title | Owner |
|---|---|---|---|
| REF-CLEAN-004 | refactor | Move the idempotency check into a guard clause | ops |

<!-- The clean half of the SL090 pair. `BUG-CLEAN-003` is `done` and its "Fix approach" section
     names a follow-up ("deferred to a separate spec"), but the follow-up has a reserved ID here,
     so SL090 stays silent. `REF-CLEAN-004` has no folder and no index row on purpose: a reserved
     ID is a placeholder, not a registry entry, and must NOT raise SL032 (ghost row - there is no
     row) or SL050 (dangling link - it is not in `linked_specs`). A linter that reports either has
     confused the two. -->
