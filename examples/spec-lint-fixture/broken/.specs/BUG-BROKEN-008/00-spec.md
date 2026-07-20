---
id: BUG-BROKEN-008
type: bug
severity: P3
status: draft
jira: none
created: 2026-07-07
linked_specs:
  - blocked-by: BUG-BROKEN-001
  - related-to: FEAT-BROKEN-004
  - related-to: FEAT-BROKEN-004
  - duplicate-of: BUG-BROKEN-008
---

# Session expires early

<!-- SEEDED: SL053 - `blocked-by` is an input alias that /sd:spec link normalizes to
     `depends-on`. Finding it stored means the field was hand-edited. -->
<!-- SEEDED: SL054 - `related-to: FEAT-BROKEN-004` appears twice. -->
<!-- SEEDED: SL052 - `duplicate-of: BUG-BROKEN-008` is a self-link. -->
<!-- SEEDED: SL051 - none of these links have an inverse on the target side. -->

## Symptom

Sessions end after ~5 minutes instead of the configured 30.

## Expected

Sessions last 30 minutes.

## Reproduction

1. Log in, idle for 6 minutes.
2. Observe forced re-authentication.

## Affected

- **Users / scope**: all tenants
- **Workaround available**: yes - re-login

## Root cause

<!-- The phase-deferred tokens below are load-bearing, not filler. At `draft` a spec must carry
     at least as many PHASE-N tokens as its template, so a stub that simply omits these sections
     raises SL011 - a finding this fixture does not list. This spec seeds link rules only. -->

**Status**: TBD - filled by Phase 3 investigation.

<<PHASE-3: root cause statement with file:line citations>>

**Why this is root cause, not a symptom**: <<PHASE-3: explanation>>

## Fix approach

**Status**: TBD - filled after root cause confirmed.

- <<PHASE-3: change 1, with target file>>
- <<PHASE-3: change 2, with target file>>
