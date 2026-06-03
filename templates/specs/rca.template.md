---
id: <<RCA-slug-YYYYMMDD>>
type: rca
status: draft
severity: <<P0|P1|P2|P3>>
incident_started: <<YYYY-MM-DD HH:MM UTC>>
incident_resolved: <<YYYY-MM-DD HH:MM UTC>>
created: <<YYYY-MM-DD>>
---

# RCA: <<short incident name, e.g. Payment outage on 2026-01-08>>

> **This spec IS the deliverable.** No code is changed in `/sd:rca`. Fixes spawn separate BUG-* / REF-* / PERF-* specs (see "Spawned specs" below).

## Timeline (UTC)

<!-- Chronological. Sub-minute granularity if available. -->
<!-- Sources: pager, monitoring, logs, chat transcripts, deployment history. -->

| Time (UTC) | Event | Source |
|---|---|---|
| <<HH:MM>> | <<event, e.g. Deploy of release v2.4.7 to prod>> | <<source, e.g. CI pipeline #4521>> |
| <<HH:MM>> | <<event, e.g. Error rate on /api/payment jumps from 0.2% to 18%>> | <<source, e.g. Datadog alert>> |
| <<HH:MM>> | <<event, e.g. PagerDuty notifies on-call>> | <<source>> |
| <<HH:MM>> | <<event, e.g. On-call begins investigation>> | <<source>> |
| <<HH:MM>> | <<event, e.g. Mitigation applied - rollback to v2.4.6>> | <<source>> |
| <<HH:MM>> | <<event, e.g. Error rate back to baseline 0.2%>> | <<source>> |
| <<HH:MM>> | <<event, e.g. Incident closed>> | <<source>> |

**Detection latency**: <<time from event to alert, e.g. 4 minutes>>
**Mitigation latency**: <<time from alert to recovery, e.g. 23 minutes>>
**Total impact window**: <<HH:MM duration>>

## Symptoms observed

<!-- What was visible at the time. Be specific. -->

- <<symptom 1, e.g. POST /api/payment returns 500 with stack trace pointing at NullReferenceException in PaymentHandler.ProcessAsync line 142>>
- <<symptom 2, e.g. Database connection pool exhausted (HikariCP max=20 reached)>>
- <<symptom 3, e.g. Downstream service /api/notification queue depth grows from 0 to 12,000>>

Artifacts: see `04-artifacts/` for logs, screenshots, query results.

## Affected scope

- **Services / endpoints**: <<list>>
- **User-facing impact**: <<e.g. ~14,000 failed checkouts; estimated revenue loss $42k>>
- **Internal impact**: <<e.g. on-call woken at 02:17; 6 engineer-hours spent>>
- **Data integrity impact**: <<e.g. None - all failures occurred BEFORE DB writes>> OR <<e.g. 47 payment rows in inconsistent state - listed in 04-artifacts/affected-rows.csv>>

## Recent changes

<!-- Anything deployed / configured in the 72 hours before the incident. -->

| When | What | By | Notes |
|---|---|---|---|
| <<YYYY-MM-DD HH:MM>> | <<change, e.g. Deploy v2.4.7 (#4521): includes refactor of PaymentHandler>> | <<author>> | <<link to PR / spec>> |
| <<YYYY-MM-DD HH:MM>> | <<change, e.g. Database connection pool config bumped 15 -> 20>> | <<author>> | <<reason>> |

## Hypothesis tree

<!-- TBD - filled by Phase 2 (sd-debugger enumerate mode). -->
<!-- 4-8 hypotheses ranked by (Likelihood × Impact) ÷ Cost-to-verify. -->

**Status**: TBD - filled by Phase 2 enumeration.

<<hypothesis tree with rankings and verification plans>>

### Verification results (Phase 3)

<!-- Each hypothesis gets: CONFIRMED / REJECTED / INCONCLUSIVE with evidence pointers. -->
<!-- Document REJECTED with FULL reasoning - this is knowledge preservation. -->

- <<H1>>: <<CONFIRMED|REJECTED|INCONCLUSIVE>> - <<evidence>>
- <<H2>>: <<status>> - <<evidence>>

## Root cause

<!-- TBD - filled by Phase 3 once a hypothesis is CONFIRMED. -->
<!-- Must be: a named, fixable cause. NOT a symptom restatement. -->

**Status**: TBD - filled when Gate 3 (Root cause confirmed) passes.

<<root cause statement>>

## Affected components

<!-- Concrete: file:line, service name, config key. -->

- <<component 1, e.g. src/Application/Payment/PaymentHandler.cs:142>>
- <<component 2, e.g. Configuration key DB__ConnectionPool__Max in appsettings.Production.json>>
- <<component 3, e.g. PR #4521 (refactor of PaymentHandler) introduced the regression>>

## Why this is root cause (not symptom)

<!-- Explain the chain. "Why" 5 times if needed. -->
<!-- Bad:  "PaymentHandler threw NRE." (symptom) -->
<!-- Good: "PaymentHandler.ProcessAsync was refactored in PR #4521 to fetch the customer eagerly. The new code path does not handle the case where the customer cache returns null (which happens when the customer was archived in the last 60s, a rare but valid state). The original code defended against this. The unit tests do not cover the archived-customer path because the test fixtures assume active customers only." -->

<<reasoning>>

## Mitigation applied

<!-- What stopped the bleeding. Not the long-term fix. -->

- **Action**: <<e.g. Rolled back to v2.4.6 via deploy pipeline #4522>>
- **Effective at**: <<UTC timestamp>>
- **Confidence**: <<high - error rate returned to baseline within 2 minutes>>
- **Reversibility**: <<can roll forward once root cause is fixed; v2.4.7 has known defect documented above>>

## Follow-up actions

### Immediate (P0 hotfix)

- [ ] <<action 1, e.g. Spawn BUG-1310: defensive null check + test for archived-customer path>>
- [ ] <<action 2>>

### Short-term (within sprint)

- [ ] <<action 1, e.g. Audit test fixtures for active-only-customer assumption>>
- [ ] <<action 2>>

### Long-term (next quarter)

- [ ] <<action 1, e.g. Establish refactor coverage gate at 80% before merge>>
- [ ] <<action 2>>

### Knowledge capture

- [ ] <<action 1, e.g. Add archived-customer scenario to integration test fixtures>>
- [ ] <<action 2, e.g. Document customer-cache nullability in §7 glossary>>

## Spawned specs

<!-- IDs reserved (not yet implemented). These are the work products that follow the RCA. -->

| Reserved ID | Type | Title | Owner |
|---|---|---|---|
| <<BUG-XXX>> | bug | <<title>> | <<owner>> |
| <<REF-XXX>> | refactor | <<title>> | <<owner>> |
| <<FEAT-XXX>> | feature | <<title - e.g. observability for cache nullability>> | <<owner>> |

## Lessons learned

<!-- 3-5 takeaways. Honest. -->

1. <<lesson 1, e.g. "Refactors of hot paths require integration test coverage, not just unit tests with happy-path fixtures.">>
2. <<lesson 2>>
3. <<lesson 3>>

**What we did well**: <<e.g. Detection latency was 4 minutes thanks to error-rate alerting>>
**What we did poorly**: <<e.g. The refactor PR was merged without an integration test covering customer lifecycle states>>
**What we got lucky on**: <<e.g. The data layer rejected inconsistent writes - no payments were charged in error>>
