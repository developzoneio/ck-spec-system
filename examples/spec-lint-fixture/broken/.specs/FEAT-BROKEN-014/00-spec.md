---
id: FEAT-BROKEN-014
type: feature
status: in-progress
jira: none
created: 2026-07-13
linked_specs: []
---

# Add bulk tag assignment

<!-- SEEDED: SL044 - the retro log records `archived -> in-progress` with an empty reason. That
     edge exists only via `/sd:spec revive`, which requires a reason; an empty one means the log
     line was hand-written, so the record of why this spec came back from the archive is lost.

     SL044 is the fixture's only WARN in the transition family, and that is the point: the chain
     is contiguous, every edge including this one is legal, and the last entry matches
     frontmatter. Nothing here makes the registry untruthful - `list` and `stats` still read
     correctly - so BLOCK would be wrong. The defect is a missing justification on a legal edge,
     which is recoverable by amending the log. A linter that reports this at BLOCK has misread
     the severity rationale in the rule table. -->
<!-- 01-plan.md and 02-tasks.md are present because a feature at `in-progress` requires them
     (SL020), and no author-fill tokens remain because `in-progress` is past `approved` (SL010). -->

## Why

Support agents re-tag roughly 200 tickets a week one at a time. Bulk assignment removes an
estimated 3 hours of manual work per agent per week.

## What

### Scenario 1: Tag a selection

- **Given** an agent has selected 40 tickets
- **When** they apply the tag "escalated"
- **Then** all 40 tickets carry the tag and one audit entry records the batch

### Scenario 2: Partial permission

- **Given** the selection includes tickets the agent cannot edit
- **When** they apply a tag
- **Then** the editable tickets are tagged and the response names the skipped ones

### Scenario 3: Tag does not exist

- **Given** the supplied tag name matches no existing tag
- **When** the agent applies it
- **Then** the request is rejected with 404 and nothing is tagged

## Success criteria

- [ ] POST /api/tickets/bulk-tag returns 200 with per-ticket results
- [ ] A partially-permitted batch tags what it can and reports the rest
- [ ] An unknown tag name returns 404 and applies nothing
- [ ] Unit + integration tests cover all scenarios above

## Out of scope

- Bulk tag removal - separate spec.
- Tag creation from within the bulk flow.

## Open questions

- None outstanding.

## Constitution check

- **§1.1 Layer rules**: batching stays in the application layer.
- **§2.3 Error handling**: reuses `TagNotFoundException`.
- **§3 Quality bars**: 80% line coverage, one integration test per scenario.
- **Risk of violation**: none
