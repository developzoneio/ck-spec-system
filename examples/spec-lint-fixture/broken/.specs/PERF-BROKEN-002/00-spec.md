---
id: PERF-BROKEN-002
type: perf
status: approved
target_metric: latency-p95
created: 2026-07-02
linked_specs: []
---

# Cut p95 latency on GET /api/report

<!-- SEEDED: SL011 - the PHASE-2 baseline token is gone, replaced by a number, while status is
     still `approved`. Phase 2 has not run, so this value was written from memory. This is the
     case the old rule could not see: the previous "no author-fill token at >= approved" rule
     would have PASSED this spec and FAILED the correct one in ../clean/. -->

## Target

| Field | Value |
|---|---|
| **Metric** | p95 latency on GET /api/report |
| **Current observed** | ~1.4s (roughly, from memory of last quarter) |
| **Goal (SLA)** | p95 < 300ms under 20 RPS load |
| **Environment** | staging, single-instance, 2 vCPU / 4 GB RAM |
| **Load profile** | 20 RPS sustained, 40 concurrent users |
| **Workload type** | read-heavy |

**Why this target**: Report latency blocks the morning ops review.

## Measurement methodology

k6 script at tests/perf/report.js, 3 warm-up rounds, 5 minute run, 3 reps, warm cache.

## Constraints

- Report contents must not change.

## Out of scope

- Database server upgrade or sharding - infra concerns.

## Hypothesis tree

**Status**: TBD - filled by Phase 3 hotspot analysis.

<<PHASE-3: hypothesis tree>>

## Results log

| # | Date | Change | p50 | p95 | p99 | req/s | CPU | Memory | Decision |
|---|---|---|---|---|---|---|---|---|---|
| - | - | - | - | - | - | - | - | - | - |

## Trade-offs accepted

**Status**: TBD - filled at close-out.

- <<PHASE-6: trade-off 1>>

## Constitution check

- **Result**: compliant
