# Expected `/sd:status` numbers - `fixtures/populated/events.jsonl`

Every number below was produced twice: once by the substring counts `commands/status.md` prescribes,
and once by the independent `jq` oracle in `../README.md`. They agree. A change to the command that
makes any of these move is a regression unless the fixture moved with it.

**Window**: `2026-07-20T08:00:01Z` -> `2026-07-21T12:00:00Z`
**Total lines**: 21 | **Well-formed**: 21 | **Skipped**: 0

## Events by kind

| Kind | Count |
|---|---|
| `gate` | 13 |
| `spec_transition` | 3 |
| `subagent_stop` | 5 |
| **total** | **21** |

## Gate activity

| Gate | allow | warn | block | total |
|---|---|---|---|---|
| `verify` | 1 | 0 | 1 | 2 |
| `protected` | 0 | 0 | 2 | 2 |
| `code-edit` | 1 | 3 | 5 | 9 |
| **total** | **2** | **3** | **8** | **13** |

Decision totals across **all** events that carry a `decision` (gate + spec_transition = 16):
allow 3, warn 3, block 10. The two extra `block`s and one extra `allow` are `spec_transition`
events - do not fold them into the gate table.

## Extensions on code-edit gates

| ext | count |
|---|---|
| `.cs` | 3 |
| `.ts` | 2 |
| `.ps1` | 2 |
| `.sh` | 1 |
| **total** | **8** |

**8, not 9.** One `code-edit` gate carries no `ext` key (line 7 - the hook omits it when it cannot
resolve an extension). This fixture exists specifically so a reader that assumes extensions sum to
the `code-edit` total fails here.

## Lifecycle transitions

| Spec | From -> To | Decision |
|---|---|---|
| `FEAT-status-a` | approved -> in-progress | block |
| `BUG-parser-b` | approved -> in-progress | block |
| `REF-cleanup-c` | in-progress -> done | allow |

## Per-spec event volume

| spec_id | events |
|---|---|
| `FEAT-status-a` | 8 |
| `BUG-parser-b` | 8 |
| `REF-cleanup-c` | 3 |
| `-` (no spec in scope) | 2 |

`-` is its own bucket, never ranked as a spec.

## Friction

| Signal | Result |
|---|---|
| Blocked at a gate (`event: gate`, `decision: block`) | `BUG-parser-b` 4, `-` 2, `REF-cleanup-c` 1, `FEAT-status-a` 1 |
| code-edit warns ignored | `FEAT-status-a` 3 |
| Retro pressure (`subagent_stop` with `"stale":1`) | `BUG-parser-b` 3 |
| Silent in-progress specs | none (all three appear in the log) |

`stale` is a flag. `BUG-parser-b` was **observed stale 3 times**; it does not have 3 stale retros.

## `fixtures/malformed/events.jsonl`

Same 21 well-formed lines plus three bad ones: a truncated mid-append line, a blank line, and a
non-JSON crash message.

| Number | Value |
|---|---|
| Total lines | 24 |
| Well-formed | 21 |
| **Skipped** | **3** |

**Every other number in this document must be identical to the populated run.** If a count moves,
the skip logic is dropping good lines. If `skipped` reads 0, the skip logic is not running at all -
both are failures, not passes.

`jq -s 'length'` **aborts** on this file (`parse error ... at line 6`). That is the point: a reader
built on `jq` loses the entire report to one interrupted write. The command counts by substring
precisely so a bad line costs one line, not the report.

## `fixtures/empty/events.jsonl`

Zero bytes. Expected state `ST004` - `Metrics log exists at <path> but is empty (0 bytes).`
Not an error, and not an empty table.
