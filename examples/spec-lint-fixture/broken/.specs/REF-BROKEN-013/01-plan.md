# Plan: REF-BROKEN-013

Present so that the `done` status does not also raise SL020. The content is not what this
fixture exercises - only its existence is.

## Approach

Extract the tax and rendering concerns out of InvoiceHandler one at a time, keeping the public
entry point delegating, so each step is independently revertible.

## Sequence

1. Extract TaxCalculationService, leave InvoiceHandler delegating to it.
2. Extract InvoiceRenderer, same shape.
3. Rename the remainder to InvoiceCreationService and update DI registration.
