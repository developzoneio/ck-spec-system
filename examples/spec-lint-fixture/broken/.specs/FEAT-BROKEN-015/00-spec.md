---
id: FEAT-BROKEN-015
type: feature
status: done
jira: none
created: 2026-07-14
linked_specs: []
---

# Add saved-view sharing

<!-- SEEDED: SL090 - this spec is `done`, its "Fix approach"-equivalent section ("Constitution
     check" below) names work that was deferred, and its `## Spawned specs` table has a header and
     separator but no data row. The follow-up exists only as prose, which is exactly the failure
     mode the section was added to prevent.

     SL090 is the fixture's only SUGGEST, and that is the point: nothing here is untrue and
     nothing is broken. `list`, `stats`, and every downstream agent read this registry correctly -
     the cost is paid later, by whoever needs to find the deferred work again. A linter that
     reports this at WARN or BLOCK has misread the severity rationale in the rule table, and one
     that reports it on a `done` spec with an empty table but no deferred-work language has
     misread condition 1. -->
<!-- 01-plan.md, 02-tasks.md and 05-retro.md are present because a `done` feature requires them
     (SL020, SL021); 06-verify.md records `result: pass` so SL055 stays silent; no author-fill
     token remains because `done` is past `approved` (SL010); the feature template declares no
     `<<PHASE-N: ...>>` token, so SL012 has nothing to report. -->

## Why

Teams re-create the same filtered views by hand. Sharing a saved view removes the copying and
the drift between two people's "same" view.

## What

### SC-1: Share a view

- **Given** a user owns a saved view
- **When** they share it with a team
- **Then** every member of that team sees the view read-only

### SC-2: Revoke a share

- **Given** a view is shared with a team
- **When** the owner revokes the share
- **Then** the view disappears for the team and stays for the owner

## Success criteria

- [x] AC-1: POST /api/views/{id}/share returns 200 and the view is visible to the team
- [x] AC-2: DELETE /api/views/{id}/share removes team visibility only
- [x] AC-3: Unit + integration tests cover both scenarios

## Out of scope

- Editable shares - read-only in this iteration.

## Open questions

- None outstanding.

## Spawned specs

| Reserved ID | Type | Title | Owner |
|---|---|---|---|

## Constitution check

- **§1.1 Layer rules**: sharing stays in the application layer.
- **§2.3 Error handling**: reuses `ViewNotFoundException`.
- **§3 Quality bars**: 80% line coverage, one integration test per scenario.
- **Risk of violation**: none. The permission cache is not invalidated on revoke, so a revoked
  share stays visible for up to 60s - left as-is here, since the fix belongs in the caching layer
  and is a separate spec, not an exception taken by this one.
