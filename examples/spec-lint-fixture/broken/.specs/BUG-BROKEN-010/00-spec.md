---
id: BUG-BROKEN-010
type: feature
severity: P2
status: draft
jira: none
created: 2026-07-09
linked_specs: []
---

# Timestamps render in server timezone

<!-- SEEDED: SL004 - the folder prefix is `BUG`, which project-config maps to type `bug`, but
     frontmatter declares `type: feature`. The two disagree about what kind of spec this is, so
     `list` groups it as a feature while the workflow commands resolve it as a bug. -->

<!-- This spec deliberately carries BOTH the bug-required `severity` field and the
     feature-required `jira` field, and it carries all four of the bug template's phase-3
     tokens. That is not redundancy: the linter must report SL004 alone here. If it resolved the
     type from the prefix instead of frontmatter, a missing field or a missing phase token would
     raise a second finding and mask which rule actually fired. -->

## Symptom

Audit rows show timestamps in the server's local timezone rather than the viewer's.

**First reported**: 2026-07-09 by support
**Frequency**: every request
**Environment**: prod

## Expected

Timestamps render in the viewer's timezone.

## Reproduction

1. Set the account timezone to something other than UTC.
2. Open the audit log.
3. Observe timestamps offset by the server's UTC delta.

## Affected

- **Users / scope**: all tenants outside UTC
- **First introduced**: before known history
- **Workaround available**: no

## Root cause

**Status**: TBD - filled by Phase 3 investigation.

<<PHASE-3: root cause statement with file:line citations>>

**Why this is root cause, not a symptom**: <<PHASE-3: explanation>>

## Fix approach

**Status**: TBD - filled after root cause confirmed.

- <<PHASE-3: change 1, with target file>>
- <<PHASE-3: change 2, with target file>>

## Regression test checklist

- [ ] Failing test added that reproduces the bug (Phase 4 Gate 4)
- [ ] Failing test now passes with fix applied
