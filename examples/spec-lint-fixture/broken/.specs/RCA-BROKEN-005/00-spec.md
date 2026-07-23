---
id: RCA-BROKEN-005
type: rca
status: draft
severity: P1
incident_started: 2026-07-05 02:10 UTC
incident_resolved: 2026-07-05 03:40 UTC
created: 2026-07-05
linked_specs: []
---

# RCA: Report API 500s on 2026-07-05

<!-- SEEDED: SL031 - this folder has no row in index.md, so the spec is invisible to
     /sd:spec list and /sd:spec stats. -->
<!-- SEEDED (passive): this spec is the target of FEAT-BROKEN-004's one-sided depends-on link.
     The missing inverse (`blocks: FEAT-BROKEN-004`) is what raises SL051 there. -->

## Timeline (UTC)

| Time (UTC) | Event | Source |
|---|---|---|
| 02:10 | Error rate on /api/report jumps to 22% | Datadog alert |
| 03:40 | Rollback completes, error rate normal | Deploy log |

## Symptoms

Report API returned 500 for roughly 22% of requests.

## Affected scope

All tenants using the reporting dashboard.

## Recent changes

| Time | Change | Author | Reason |
|---|---|---|---|
| 01:55 | Deploy v2.4.7 | ci | scheduled release |

## Hypothesis tree

**Status**: TBD - filled by Phase 2 enumeration.

<<PHASE-2: hypothesis tree with rankings and verification plans>>

### Verification results (Phase 3)

- <<PHASE-3: H1>>: <<PHASE-3: CONFIRMED|REJECTED|INCONCLUSIVE>> - <<PHASE-3: evidence>>
- <<PHASE-3: H2>>: <<PHASE-3: status>> - <<PHASE-3: evidence>>

## Root cause

**Status**: TBD - filled when Gate 3 (Root cause confirmed) passes.

<<PHASE-3: root cause statement>>
