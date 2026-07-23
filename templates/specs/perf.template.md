---
id: <<PERF-XXX>>
type: perf
status: draft
target_metric: <<latency-p95|throughput|memory|cpu|cold-start|other>>
created: <<YYYY-MM-DD>>
linked_specs: []
---

# <<Short imperative title - what is being optimized>>

## Target

| Field | Value |
|---|---|
| **Metric** | <<e.g. p95 latency on GET /api/search>> |
| **Current observed** | <<PHASE-2: measured baseline - do NOT pre-fill from memory>> |
| **Goal (SLA)** | <<e.g. p95 < 200ms under 50 RPS load>> |
| **Environment** | <<e.g. staging, single-instance, 2 vCPU / 4 GB RAM, SQL Server 8 vCPU / 16 GB>> |
| **Load profile** | <<e.g. 50 RPS sustained, 100 concurrent users, synthetic queries from tests/perf/queries.json>> |
| **Workload type** | <<read-heavy | write-heavy | mixed | bursty>> |

**Why this target**: <<business justification, e.g. "Search latency directly impacts conversion; current p95 of 1.4s causes 22% drop-off after 1s.">>

## Measurement methodology

<!-- HOW the baseline is measured. Phase 2 Gate 2 (Baseline) requires this to be executed and results checked in. -->

- **Tool**: <<e.g. k6, BenchmarkDotNet, wrk, custom script>>
- **Test script**: <<path, e.g. tests/perf/search-load.js>>
- **Warm-up**: <<e.g. 30s ramp-up, discard first 30s of samples>>
- **Duration**: <<e.g. 5 minutes sustained>>
- **Repetitions**: <<e.g. 3 runs, median reported>>
- **Database state**: <<e.g. seeded with tests/perf/seed.sql, ~1M rows>>
- **Cache state**: <<cold | warm - and how warmth is achieved>>
- **What is captured**: p50, p95, p99 latency; req/s; CPU; memory; DB query plan if applicable
- **Artifacts saved to**: `04-artifacts/baseline-<<YYYYMMDD-HHmm>>.json` and `.txt` summary

## Constraints

<!-- Hard constraints that cannot be sacrificed for speed. -->

- **Correctness**: <<e.g. Existing functional tests must continue to pass>>
- **Public API**: <<preserved | changes documented below>>
- **Resource budget**: <<e.g. No new dependencies; memory ceiling +50MB; CPU baseline +0%>>
- **Behavior change**: <<none | documented below if optimization changes observable behavior, e.g. eventual consistency window introduced>>

## Out of scope

- <<e.g. Optimizing endpoints already meeting SLA>>
- <<e.g. Database server upgrade or sharding - infra concerns>>
- <<e.g. Frontend rendering perf - separate spec>>

## Hypothesis tree

<!-- TBD - filled by Phase 3 (Hotspot identification) and Phase 4 (Deep dive). -->
<!-- sd-debugger in hotspot-analysis mode populates this. Format: ranked hypotheses with expected impact. -->

**Status**: TBD - filled by Phase 3 hotspot analysis.

<<PHASE-3: hypothesis tree>>

## Results log

<!-- TBD - filled iteratively in Phase 4 per attempt. Each row = one optimization attempt. -->
<!-- Pre-baseline row added in Phase 2; subsequent rows added one per measured change. -->

| # | Date | Change | p50 | p95 | p99 | req/s | CPU | Memory | Decision |
|---|---|---|---|---|---|---|---|---|---|
| - | - | - | - | - | - | - | - | - | - |

**Decision values**: `kept` | `reverted` | `pending`. Reverts MUST be logged. Each row links to the commit / artifact directory.

## Trade-offs accepted

<!-- TBD - filled in Phase 6 Close-out. -->
<!-- Document everything the optimization gave up: readability, simplicity, generality, eventual consistency, etc. -->

**Status**: TBD - filled at close-out.

- <<PHASE-6: trade-off 1, e.g. "Added in-memory LRU cache (1000 entries) in the read path. Trade-off: search result freshness window extended from real-time to up to 30s. Acceptable per product owner.">>

## Constitution check

- **§1 Layer rules**: <<does optimization introduce cross-layer leakage? e.g. inlining a repo call into a controller would violate §1>>
- **§3 Quality bars**: <<perf prerequisite (baseline measured) - satisfied at Gate 2>>
- **§6 Forbidden patterns**: <<confirm no `dynamic`, no service locator, no static state introduced>>
- **Result**: <<compliant | introduces approved exception (link to ADR)>>
