---
id: FEAT-BROKEN-011
type: feature
status: reviewing
jira: none
created: 2026-07-10
linked_specs: []
---

# Add saved search filters

<!-- SEEDED: SL005 - `reviewing` is not in `spec.lifecycle`, which project-config defines as
     draft / approved / in-progress / done / archived. -->
<!-- SEEDED: SL043 - status is not `draft` and there is no 05-retro.md.

     SL043 is unavoidable here, not a second accident. An illegal status cannot have a legal
     retro log: every logged edge must come from the state machine, and no edge in that machine
     ends at `reviewing`. Writing a retro to silence SL043 would raise SL040 instead. So this
     spec is the fixture's one deliberate two-finding seed, and a linter that reports only one
     of the pair has a gap. -->
<!-- This spec is fully filled - it carries no placeholder token of either form - so that
     whatever a linter decides `reviewing` means for placeholder discipline, no placeholder
     finding can fire here. Note that this comment deliberately spells out no token syntax:
     a fixture that names a token inside a comment plants a decoy for any linter that scans
     line-wise rather than parsing, and this tree must produce its listed findings and no others. -->

## Why

Analysts re-enter the same four filter combinations every morning. Saving a filter set removes
roughly 10 minutes of repeated clicking per analyst per day.

## What

### Scenario 1: Save a filter set

- **Given** an analyst has applied filters to the search view
- **When** they choose "Save this search" and name it
- **Then** the named filter set appears in their sidebar

### Scenario 2: Name collides with an existing saved search

- **Given** a saved search named "Overdue" already exists
- **When** the analyst saves another search with the same name
- **Then** the save is rejected with a message naming the conflict

### Scenario 3: Saved search references a deleted field

- **Given** a saved search filters on a field that was since removed
- **When** the analyst opens it
- **Then** the search loads with that clause dropped and a warning shown

## Success criteria

- [ ] POST /api/searches returns 201 with the saved search ID
- [ ] Duplicate names within one account return 409
- [ ] A saved search referencing a removed field loads without error
- [ ] Unit + integration tests cover all scenarios above

## Out of scope

- Sharing saved searches between accounts.
- Scheduled email digests built on a saved search.

## Open questions

- None outstanding.

## Constitution check

- **§1.1 Layer rules**: persistence stays behind the repository interface.
- **§2.3 Error handling**: reuses `DuplicateSavedSearchException`.
- **§3 Quality bars**: 80% line coverage on new files, integration test per scenario.
- **Risk of violation**: none
