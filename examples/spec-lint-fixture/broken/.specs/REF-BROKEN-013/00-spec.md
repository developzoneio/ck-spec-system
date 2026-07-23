---
id: REF-BROKEN-013
type: refactor
smell: extract-class
status: done
created: 2026-07-12
linked_specs: []
---

# Split InvoiceHandler

<!-- SEEDED: SL041 - the retro log jumps from `approved` straight to an entry that opens at
     `in-progress`, so the chain is not contiguous: approved -> in-progress was never logged.

     Everything else about this spec is deliberately correct, because SL041 is the rule most
     easily masked by its neighbours. Both logged edges ARE legal edges, so SL040 must stay
     silent. The last entry ends at `done`, which matches frontmatter, so SL042 must stay silent.
     A retro exists, so SL043 must stay silent. The gap is visible only by checking each entry's
     `<old>` against the previous entry's `<new>` - which is exactly the check SL041 names, and
     exactly the check a linter is likeliest to skip. -->
<!-- 01-plan.md and 02-tasks.md are present because a refactor at `done` requires them (SL020),
     and every phase-deferred token is filled because none may remain at `done` (SL012). -->

## Smell / Driver

InvoiceHandler.cs has grown to 430 lines mixing invoice creation, tax calculation and PDF
rendering. Testing the tax path in isolation is impossible without constructing a renderer.

**Smell category**: extract-class

## Current state

- **Primary file**: src/Billing/InvoiceHandler.cs (430 lines)
- **Structure**: single class, 6 public methods, 14 private helpers
- **Test coverage**: currently 84%
- **Used by**: `src/Api/InvoiceController.cs:22`, `src/Jobs/MonthlyBillingJob.cs:57`

## Target state

- **Shape**: split into InvoiceCreationService, TaxCalculationService and InvoiceRenderer
- **Files affected**: src/Billing/InvoiceCreationService.cs (new),
  src/Billing/TaxCalculationService.cs (new), src/Billing/InvoiceRenderer.cs (new)
- **Public API**: preserved
- **Test approach**: each new service unit-tested in isolation

### Public API changes (if any)

- None - this is a behavior-preserving refactor.

## Invariants - MUST preserve

- [x] POST /api/invoices returns the same status codes and response shape for every case in
      tests/contract/invoice.cases.json
- [x] All existing tests pass without modification

## Impact surface

**Status**: Filled by Phase 2 impact mapping.

- Direct callers: `src/Api/InvoiceController.cs:22`, `src/Jobs/MonthlyBillingJob.cs:57`
- DI registrations: `src/Startup/BillingModule.cs:18`
- Test files: `tests/Billing/InvoiceHandlerTests.cs:1`

## Test coverage prerequisite

- **Threshold**: >= 80% line coverage on files in "Current state"
- **Current measured**: 84% measured on src/Billing/InvoiceHandler.cs
- **Gap**: none
- **Plan to close gap** (if any): none required

## Out of scope

- Renaming public DTOs.
- Any performance work.

## Constitution check

- **§1.1 Layer rules**: all three services stay in the billing layer.
- **§1.2 Pattern rules**: reinforces one-responsibility-per-service.
- **§6 Forbidden patterns**: none introduced.
- **Result**: compliant
