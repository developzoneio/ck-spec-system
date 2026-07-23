# Tasks - FEAT-example

### T01 - Add the Feed value type

- **Files**: src/Feed.cs
- **Layer**: Domain
- **Step type**: foundation
- **Test**: tests/FeedTests.cs
- **Acceptance**: `Feed` constructs from a valid source and rejects an empty one.
- **Covers**: SC-1
- **Depends on**: none
- **Conflicts with**: none
- **Estimated complexity**: S
- **Reversibility**: trivial
- **Pattern refs**: src/Odds.cs:12 - mirror the value-type validation shape.

### T02 - Wire the feed handler onto the stream

- **Files**: src/FeedHandler.cs
- **Layer**: Application
- **Step type**: behavior
- **Test**: tests/FeedHandlerTests.cs
- **Acceptance**: handler consumes the feed stream and emits one event per streamed item.
- **Covers**: SC-2
- **Depends on**: T01
- **Conflicts with**: none
- **Estimated complexity**: M
- **Reversibility**: moderate
- **Pattern refs**: src/OddsHandler.cs:20 - mirror the stream-consumption loop.
- **Revised-by**: R1

### T03 - Emit the feed event onto the envelope

- **Files**: src/FeedEvent.cs
- **Layer**: Application
- **Step type**: behavior
- **Test**: tests/FeedEventTests.cs
- **Acceptance**: each consumed item emits one envelope-wrapped event.
- **Covers**: SC-3
- **Depends on**: T02
- **Conflicts with**: none
- **Estimated complexity**: M
- **Reversibility**: moderate
- **Pattern refs**: src/OddsEvent.cs:8 - reuse the envelope type.
- **Revised-by**: R3
