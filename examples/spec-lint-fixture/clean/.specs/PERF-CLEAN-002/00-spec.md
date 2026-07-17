---
id: PERF-CLEAN-002
type: perf
status: approved
target_metric: latency-p95
created: 2026-07-02
linked_specs: []
---

# Cut p95 latency on GET /api/search

## Target

| Field | Value |
|---|---|
| **Metric** | p95 latency on GET /api/search |
| **Current observed** | <<PHASE-2: measured baseline - do NOT pre-fill from memory>> |
| **Goal (SLA)** | p95 < 200ms under 50 RPS load |
| **Environment** | staging, single-instance, 2 vCPU / 4 GB RAM |
| **Load profile** | 50 RPS sustained, 100 concurrent users |
| **Workload type** | read-heavy |

**Why this target**: Search latency directly impacts conversion; drop-off climbs sharply past 1s.

## Measurement methodology

k6 script at tests/perf/search.js, 3 warm-up rounds, 5 minute run, 3 reps, warm cache.

## Constraints

- Result ordering must not change.

## Out of scope

- Database server upgrade or sharding - infra concerns.

## Hypothesis tree

<!-- TBD - filled by Phase 3 (Hotspot identification) and Phase 4 (Deep dive). -->

**Status**: TBD - filled by Phase 3 hotspot analysis.

<<PHASE-3: hypothesis tree>>

## Results log

| # | Date | Change | p50 | p95 | p99 | req/s | CPU | Memory | Decision |
|---|---|---|---|---|---|---|---|---|---|
| - | - | - | - | - | - | - | - | - | - |

## Trade-offs accepted

<!-- TBD - filled in Phase 6 Close-out. -->

**Status**: TBD - filled at close-out.

- <<PHASE-6: trade-off 1>>

## Constitution check

- **Result**: compliant
