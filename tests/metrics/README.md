# `/sd:status` verification corpus

Fixtures and an independent oracle for `commands/status.md` (SW-16).

## What this is - and what it is not

`commands/status.md` is a **markdown prompt file**. There is no binary, no function, no exit code.
**CI cannot execute it**, so nothing in this folder is wired into `scripts/validate.*` or
`scripts/smoke-hooks.*`. This is a **manual verification corpus**: fixtures with known-correct
answers, plus a `jq` oracle that re-derives every answer independently of the counting method the
command prescribes.

Stating that boundary is deliberate. A folder named `tests/` that quietly proves nothing is worse
than no folder at all.

## Layout

```
fixtures/populated/events.jsonl   21 well-formed lines, all 3 event kinds, all 3 gate kinds
fixtures/malformed/events.jsonl   the same 21 plus 3 bad lines (truncated / blank / non-JSON)
fixtures/empty/events.jsonl       0 bytes
expected/populated.md             every number the command must produce
```

Line endings are pinned to LF in `.gitattributes`. The log is documented as LF-terminated and the
counts are byte-sensitive; a CRLF checkout on Windows would make the same fixture disagree with
itself across platforms.

## Procedure

1. In a scratch directory, create `.claude/project-config.json` and `.specs/_metrics/`, and copy one
   fixture to `.specs/_metrics/events.jsonl`.
2. Run `/sd:status`.
3. Compare the output against `expected/populated.md`.
4. Re-derive the numbers with the oracle below and confirm all three agree.

Scenarios to run, and what each proves:

| Fixture / setup | Proves |
|---|---|
| `populated/` | Counts are correct and reconcile against `jq` |
| `malformed/` | A bad line is skipped **and counted**; every other number is unchanged |
| `empty/` | `ST004` - labelled empty, not an error, not a blank table |
| No `.specs/_metrics/` directory | `ST003` - "no metrics recorded yet" |
| `hooks.metrics.enabled: false` | `ST002` - disabled is reported as disabled |
| No `.claude/project-config.json` | `ST001` - STOP pointing at `/sd:setup` |

## The `jq` oracle

`jq` is **not** a runtime dependency of `/sd:status` - see D1 in the plan. It is used here only as an
independent second opinion, computed a different way than the command computes it.

```bash
cd tests/metrics/fixtures

jq -s 'length' populated/events.jsonl                                   # 21
jq -r '.event'  populated/events.jsonl | sort | uniq -c                 # 13 / 3 / 5
jq -r 'select(.event=="gate")|.gate' populated/events.jsonl | sort | uniq -c
jq -r 'select(has("decision"))|.decision' populated/events.jsonl | sort | uniq -c
jq -r 'select(has("ext"))|.ext'  populated/events.jsonl | sort | uniq -c   # sums to 8, not 9
jq -r '.spec_id' populated/events.jsonl | sort | uniq -c | sort -rn
jq -s '[.[]|select(.event=="subagent_stop" and .stale==1)]|length' populated/events.jsonl   # 3
jq -r 'select(.event=="gate" and .decision=="block")|.spec_id' populated/events.jsonl | sort | uniq -c | sort -rn
```

Run the same queries against `malformed/` and **`jq` aborts**:

```
jq: parse error: Invalid string: control characters from U+0000 through U+001F
    must be escaped at line 6, column 2
```

That failure is a required result, not an inconvenience. It demonstrates why the command counts by
substring instead: a `jq`-based reader loses the whole report to a single interrupted write, which
the ticket explicitly forbids. Use `grep -cF` for the malformed run and confirm every count matches
the populated run with `skipped: 3`.

## Negative case (required)

Green is a claim. Before accepting a passing run, break it on purpose:

- Delete a good line from `malformed/` and confirm a count **moves**. If nothing moves, the counts
  are not being read from the fixture at all.
- Point the command at `empty/` and confirm it says so in words. A report that renders empty tables
  reads as "no friction" and is a defect (`ST004`).
