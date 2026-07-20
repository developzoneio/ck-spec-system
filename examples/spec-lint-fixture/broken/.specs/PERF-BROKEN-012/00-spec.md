---
id: PERF-BROKEN-012
type: perf
status: done
target_metric: memory
created: 2026-07-11
linked_specs: []
---

# Cut peak memory on the nightly export job

<!-- SEEDED: SL021 - status is `done` but 05-retro.md contains only its header, so the spec
     claims a completed lifecycle with no transition ever logged.

     SL021 and SL043 are neighbours and this spec pins the boundary between them. The retro file
     EXISTS here, so SL043 ("status is not draft and there is no retro log") does not apply -
     SL021 is the rule for a log that exists but is empty. SL042 ("last logged transition
     disagrees with frontmatter") also stays silent: there is no last entry to disagree with.
     A linter that reports SL043 or SL042 on this spec has collapsed three distinct rules into
     one, and the finding it prints will point the reader at the wrong fix. -->
<!-- No placeholder token of either form remains: at `done` an author-fill token is SL010 and a
     phase-deferred token is SL012, and neither belongs in this seed. This comment spells out no
     token syntax on purpose - naming one inside a comment plants a decoy for any linter that
     scans line-wise rather than parsing. -->

## Target

| Field | Value |
|---|---|
| **Metric** | peak RSS during the nightly export job |
| **Current observed** | 3.1 GB peak RSS, median of 3 runs |
| **Goal (SLA)** | peak RSS under 1.5 GB |
| **Environment** | staging, single worker, 2 vCPU / 4 GB RAM |
| **Load profile** | full nightly export, ~2.4M rows |
| **Workload type** | read-heavy |

**Why this target**: the worker is OOM-killed roughly twice a week at the current peak, and each
kill costs a full re-run of the export.

## Measurement methodology

- **Tool**: /usr/bin/time -v plus in-process GC counters
- **Test script**: tests/perf/nightly-export.sh
- **Warm-up**: none - the job is cold by definition
- **Duration**: one full export per run
- **Repetitions**: 3 runs, median reported
- **Database state**: staging snapshot, ~2.4M rows
- **Cache state**: cold
- **Artifacts saved to**: `04-artifacts/baseline-20260711-0200.json`

## Constraints

- **Correctness**: the exported file must be byte-identical to the pre-change output.
- **Public API**: preserved
- **Resource budget**: no new dependencies
- **Behavior change**: none

## Out of scope

- Moving the export off the application worker.

## Hypothesis tree

**Status**: Confirmed at Phase 3.

1. The row set is materialized into a list before serialization
   (`src/Export/NightlyExporter.cs:64`) - expected to account for most of the peak.
2. The CSV writer buffers the entire payload before flushing
   (`src/Export/CsvWriter.cs:31`) - secondary contributor.

## Results log

| # | Date | Change | p50 | p95 | p99 | req/s | CPU | Memory | Decision |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 2026-07-11 | baseline | - | - | - | - | 61% | 3.1 GB | - |
| 1 | 2026-07-11 | stream rows instead of materializing | - | - | - | - | 63% | 1.4 GB | kept |

## Trade-offs accepted

**Status**: Filled at close-out.

- Streaming the row set means the exporter can no longer report a total row count up front, so
  the progress log now reports rows written rather than percent complete.

## Constitution check

- **§1 Layer rules**: streaming stays inside the export layer.
- **§3 Quality bars**: baseline measured at Gate 2.
- **§6 Forbidden patterns**: none introduced.
- **Result**: compliant
