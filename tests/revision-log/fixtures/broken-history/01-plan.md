# Plan - FEAT-example

## Phased overview

- Foundation: T01
- Behavior: T02, T03

## Sequencing rationale

T01 lands the type before T02 and T03 wire behavior onto it.

## Risks

- The upstream interface may differ from the sample. Mitigation: verify at implementation.

## Revisions

### R1 - 2026-07-22T09:14:00Z

- Trigger: T02 assumed `IFeed.Fetch` returns a list, but the real interface returns a stream.
- Phase: execute
- Gate: re-plan
- Affected tasks: T02
- Delta: T02 rewritten to consume the stream.
- revised-from: original T02 asserted a returned `List<Item>`.

### R3 - 2026-07-22T11:02:00Z

- Trigger: T03's event schema clashed with the existing envelope.
- Phase: review
- Gate: re-plan
- Affected tasks: T03
- Delta: T03 rewritten to reuse the envelope type.
- revised-from: original T03 defined a new event record.

<!-- SL072: numbering jumps R1 -> R3 with no R2. A contiguous append-only log has no gap;
     this one was not appended contiguously (or R2 was removed). -->
