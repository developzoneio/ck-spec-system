---
id: BUG-BROKEN-999
type: bug
severity: P2
status: draft
jira: none
created: 2026-07-01
linked_specs: []
---

# Cart total ignores discount

<!-- SEEDED: SL003 - `id` says BUG-BROKEN-999, the folder is BUG-BROKEN-001. -->
<!-- SEEDED: SL030 - index.md row says `approved`, this frontmatter says `draft`. -->

## Symptom

Applying a percentage discount leaves the cart total unchanged.

## Expected

The cart total reflects the discount.

## Reproduction

1. Add an item, apply a 10% discount code.
2. Observe the total is unchanged.

## Affected

- **Users / scope**: all tenants
- **Workaround available**: no

## Root cause

<!-- The phase-deferred tokens below are load-bearing, not filler. At `draft` a spec must carry
     at least as many PHASE-N tokens as its template, so a stub that simply omits these sections
     raises SL011 - a finding this fixture does not list. Keep them until the spec reaches a
     phase that fills them. -->

**Status**: TBD - filled by Phase 3 investigation.

<<PHASE-3: root cause statement with file:line citations>>

**Why this is root cause, not a symptom**: <<PHASE-3: explanation>>

## Fix approach

**Status**: TBD - filled after root cause confirmed.

- <<PHASE-3: change 1, with target file>>
- <<PHASE-3: change 2, with target file>>
