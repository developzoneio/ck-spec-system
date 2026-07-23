# Plan: FEAT-BROKEN-014

Present so that the `in-progress` status does not also raise SL020. The content is not what this
fixture exercises - only its existence is.

## Approach

Add a batch endpoint that resolves the tag once, then applies it per ticket inside a single
transaction, collecting per-ticket outcomes rather than failing the whole batch.

## Sequence

1. Add the bulk-tag request/response contract.
2. Resolve and validate the tag before iterating.
3. Apply per ticket, collecting permission skips.
4. Write one audit entry per batch.
