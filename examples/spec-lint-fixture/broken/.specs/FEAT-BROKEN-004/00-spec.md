---
id: FEAT-BROKEN-004
type: feature
status: draft
jira: none
created: 2026-07-04
linked_specs:
  - related-to: FEAT-NOPE-999
  - depends-on: RCA-BROKEN-005
---

# Add CSV export

<!-- SEEDED: SL050 - `related-to: FEAT-NOPE-999` points at a spec that does not exist. -->
<!-- SEEDED: SL051 - `depends-on: RCA-BROKEN-005` has no inverse: RCA-BROKEN-005 carries
     `linked_specs: []`, so the link is one-sided. -->
<!-- SEEDED: SL033 - this ID appears on two rows of index.md. -->

## Why

Operators want the report data in a spreadsheet.

## What

### Scenario 1: Export current report

- **Given** an operator viewing a report
- **When** they click Export CSV
- **Then** a CSV of the current rows downloads

## Success criteria

- [ ] Export returns a CSV matching the on-screen rows

## Out of scope

- Scheduled exports.

## Open questions

- None.

## Constitution check

- **Result**: compliant
