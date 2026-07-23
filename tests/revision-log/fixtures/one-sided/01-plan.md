# Plan - FEAT-example

## Phased overview

- Foundation: T01
- Behavior: T02

## Sequencing rationale

T01 lands the type before T02 wires the behavior onto it. Critical path is T01 -> T02.

## Risks

- The upstream interface T02 assumes may differ from the sample. Mitigation: verify at implementation.

## Revisions

### R1 - 2026-07-22T09:14:00Z

- Trigger: T02 assumed `IFeed.Fetch` returns a list, but the real interface returns a stream.
- Phase: execute
- Gate: re-plan
- Affected tasks: T02
- Delta: T02 rewritten to consume the stream and assert the streamed-count acceptance instead.
- revised-from: original T02 asserted a returned `List<Item>` and mirrored the list-based handler.

<!-- SL071: this entry names `Affected tasks: T02`, but T02 in 02-tasks.md carries no
     `Revised-by: R1` marker. The revision points at a task that does not point back. -->
