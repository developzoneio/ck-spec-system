---
id: REF-BROKEN-003
type: refactor
status: in-progress
created: 2026-07-03
linked_specs: []
---

# Split StockHandler

<!-- SEEDED: SL002 - required field `smell` is missing for a refactor spec. -->
<!-- SEEDED: SL020 - status is `in-progress`, so a refactor must have 01-plan.md and 02-tasks.md.
     Neither exists in this folder. -->
<!-- SEEDED: SL042 - frontmatter says `in-progress`; the retro log's last entry ends at
     `approved`. The status was hand-edited, bypassing /sd:spec status. -->

## Smell / Driver

StockHandler.cs has grown to 480 lines with 7 distinct concerns mixed.

**Smell category**: extract-class

## Current state

- **Primary file**: src/Stock/StockHandler.cs (480 lines)
- **Structure**: single class with 7 public methods
- **Test coverage**: currently 84%
- **Used by**: <<PHASE-2: list callers - filled by sd-code-explorer>>

## Target state

- **Shape**: Split into StockDeductionService + StockQueryService
- **Public API**: preserved

## Invariants - MUST preserve

- [ ] All existing tests pass without modification

## Impact surface

**Status**: TBD - filled by Phase 2 impact mapping.

<<PHASE-2: impact analysis with file:line citations>>

## Test coverage prerequisite

- **Threshold**: >= 80% line coverage on files in "Current state"
- **Current measured**: <<PHASE-3: N% measured on files in "Current state">>
- **Gap**: <<PHASE-3: N% below threshold, or "none">>
- **Plan to close gap** (if any): <<PHASE-3: list characterization tests to add>>

## Out of scope

- Behavior changes.
