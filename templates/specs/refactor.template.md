---
id: <<REF-XXX>>
type: refactor
smell: <<extract-method|extract-class|rename|inline|move|replace-conditional|reduce-coupling|other>>
status: draft
created: <<YYYY-MM-DD>>
---

# <<Short imperative title - what is being restructured>>

## Smell / Driver

<!-- WHY this refactor is needed. Name the code smell or driver explicitly. -->
<!-- Bad:  "Cleanup needed." -->
<!-- Good: "StockHandler.cs has grown to 480 lines with 7 distinct concerns mixed. Adding the next feature (BUG-1247 fix) is blocked by the inability to test the deduction path in isolation." -->

<<paragraph identifying the smell and the concrete pain it causes>>

**Smell category**: <<from frontmatter, expanded>>
**Triggering change** (optional): <<spec ID that surfaced this need, e.g. BUG-1247>>

## Current state

<!-- Describe what exists today. Use file:line citations. sd-code-explorer fills detail in 03-decisions.md. -->

- **Primary file**: <<src/path/to/file.ext>> (<<N>> lines)
- **Structure**: <<brief description of current shape, e.g. "single class with 7 public methods + 12 private helpers + 4 inline cache calls">>
- **Test coverage**: <<currently N% - filled from coverage report>>
- **Used by**: <<list callers - filled by sd-code-explorer in Phase 2>>

## Target state

<!-- Describe what it should look like after. Concrete. -->

- **Shape**: <<e.g. "Split into StockDeductionService (deduct path) + StockReservationService (reservation path) + StockQueryService (read path)">>
- **Files affected**: <<list, e.g. src/Application/Stock/StockDeductionService.cs (new), ...>>
- **Public API**: <<preserved | one change documented below>>
- **Test approach**: <<each new service unit-tested in isolation; integration tests cover the wired behavior>>

### Public API changes (if any)

<!-- If the public API changes, list each change and the justification. Otherwise: "None - this is a behavior-preserving refactor." -->

- <<change 1, e.g. None>>

## Invariants - MUST preserve

<!-- These are checked before and after. If any fails, the refactor is reverted. -->
<!-- Be CONCRETE. "Behavior preserved" is not an invariant. -->

- [ ] <<invariant 1, e.g. POST /api/stock/deduct returns same status codes and response shape for all inputs in tests/contract/stock-deduct.cases.json>>
- [ ] <<invariant 2, e.g. Database writes occur in the same order under concurrent load (verified by integration test)>>
- [ ] <<invariant 3, e.g. Cache invalidation timing unchanged (Redis TTL behavior identical)>>
- [ ] All existing tests pass without modification (no test edits except renames)
- [ ] No new public API added (this is restructure, not feature)

## Impact surface

<!-- TBD - filled by sd-code-explorer in Phase 2 (impact-map task). -->
<!-- Should list: direct callers, transitive callers, test files, DI registrations, config references. -->

**Status**: TBD - filled by Phase 2 impact mapping.

<<impact analysis with file:line citations>>

## Test coverage prerequisite

<!-- Refactor is BLOCKED if coverage on affected files is below threshold. -->
<!-- Default threshold: 80% line coverage on changed files. -->

- **Threshold**: >= <<80>>% line coverage on files in "Current state"
- **Current measured**: <<N% - filled in Phase 3>>
- **Gap**: <<N% - filled in Phase 3>>
- **Plan to close gap** (if any): <<list characterization tests to add - filled in Phase 3>>

**Gate 2 (Coverage threshold)** is HARD. If coverage is below threshold, characterization tests are written FIRST, then re-measured, then proceed.

## Out of scope

- <<e.g. Renaming public DTOs - separate spec if desired>>
- <<e.g. Updating consumer projects - they will continue to work via unchanged public API>>
- <<e.g. Performance optimization - any perf gain is incidental, not a goal>>

## Constitution check

- **§1.1 Layer rules**: <<does the refactor preserve / improve layer boundaries?>>
- **§1.2 Pattern rules**: <<which patterns are introduced or reinforced?>>
- **§6 Forbidden patterns**: <<confirm none introduced>>
- **Result**: <<compliant | introduces a new pattern requiring constitution amendment (separate spec)>>
