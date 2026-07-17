---
id: REF-BROKEN-009
type: refactor
smell: inline
status: done
created: 2026-07-08
linked_specs: []
---

# Inline config reader

<!-- SEEDED: SL040 - the retro log records `draft -> done`, which is not an edge in the state
     machine. -->
<!-- SEEDED: SL020 - status is `done`, so a refactor must have 01-plan.md and 02-tasks.md. -->
<!-- SEEDED: SL012 - the PHASE-2 / PHASE-3 tokens below are still unfilled at `done`. -->

## Smell / Driver

ConfigReader is a one-line indirection used in a single place.

**Smell category**: inline

## Current state

- **Primary file**: src/Config/ConfigReader.cs (12 lines)
- **Test coverage**: currently 91%
- **Used by**: <<PHASE-2: list callers - filled by sd-code-explorer>>

## Target state

- **Shape**: inlined at the single call site
- **Public API**: preserved

## Invariants - MUST preserve

- [ ] All existing tests pass without modification

## Impact surface

<<PHASE-2: impact analysis with file:line citations>>

## Test coverage prerequisite

- **Threshold**: >= 80% line coverage on files in "Current state"
- **Current measured**: <<PHASE-3: N% measured on files in "Current state">>
- **Gap**: <<PHASE-3: N% below threshold, or "none">>
- **Plan to close gap** (if any): <<PHASE-3: list characterization tests to add>>

## Out of scope

- Behavior changes.
