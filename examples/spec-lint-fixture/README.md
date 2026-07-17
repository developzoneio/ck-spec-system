# Spec-lint fixture

Two `.specs/` trees for exercising `/sd:spec validate`, backing the SW-4 acceptance criterion:
*a seeded broken spec surfaces each violation at the right severity; a clean tree returns
all-PASS.*

| Tree | Expectation |
|---|---|
| [`clean/`](clean/) | Every spec PASSes. `_No findings._` under all four severity sections. |
| [`broken/`](broken/) | Every finding in the table below, at the stated severity, and nothing else. |

Rule IDs (`SL0xx`) are defined in the rule table in `commands/spec.md`, under `## validate`.

---

## How to run it

`/sd:spec validate` is a **prompt**, not executable code, so no script can run it and CI cannot
gate on it. Read that limitation before trusting a green build: see "What this does not do" below.

```
cd examples/spec-lint-fixture/clean     # then, in a Claude Code session rooted here:
/sd:spec validate --all                 # expect: every spec PASS, no findings

cd ../broken
/sd:spec validate --all                 # expect: exactly the findings in the table below
```

The fixture ships its own `.claude/project-config.json` so `validate` can resolve `spec.dir` and
`spec.lifecycle` without a full `/sd:setup`. Placeholder checks read the type's template from
`~/.claude/templates/sd/specs/`, so the engine must be installed for `SL010` / `SL011` / `SL012`
to be exercised; without it those checks raise `SL013` instead.

---

## Why `clean/` is the interesting half

`clean/PERF-CLEAN-002` is at `approved` with its `<<PHASE-2: ...>>` baseline token **unfilled**,
and it must PASS. Under the pre-SW-4 rule ("status >= `approved` -> no `<<placeholder>>` tokens
remaining") this correct spec FAILED, while `broken/PERF-BROKEN-002` — the same spec with a
baseline invented from memory — PASSED. The two perf specs are a matched pair: any change that
makes one behave like the other has reintroduced the bug SW-4 seam 1 fixed.

---

## Expected findings in `broken/`

Each `00-spec.md` carries `<!-- SEEDED: ... -->` comments naming its own violations, so a finding
can be traced to an intentional seed rather than an accident.

| Spec | Rule | Severity | Seeded violation |
|---|---|---|---|
| `BUG-BROKEN-001` | `SL003` | BLOCK | `id: BUG-BROKEN-999` in a folder named `BUG-BROKEN-001` |
| `BUG-BROKEN-001` | `SL030` | BLOCK | Index row says `approved`, frontmatter says `draft` |
| `PERF-BROKEN-002` | `SL011` | BLOCK | `PHASE-2` baseline filled from memory at `approved` |
| `REF-BROKEN-003` | `SL002` | BLOCK | Required field `smell` missing |
| `REF-BROKEN-003` | `SL020` | BLOCK | `in-progress` refactor with no `01-plan.md` / `02-tasks.md` |
| `REF-BROKEN-003` | `SL042` | BLOCK | Frontmatter `in-progress`; retro log ends at `approved` |
| `FEAT-BROKEN-004` | `SL050` | BLOCK | `related-to: FEAT-NOPE-999` resolves to nothing |
| `FEAT-BROKEN-004` | `SL051` | BLOCK | `depends-on: RCA-BROKEN-005` has no inverse |
| `FEAT-BROKEN-004` | `SL033` | BLOCK | Listed on two index rows |
| `RCA-BROKEN-005` | `SL031` | BLOCK | Folder exists, no index row (orphan) |
| `FEAT-BROKEN-007` | `SL006` | BLOCK | `linked_specs: none` is a scalar, not a list |
| `FEAT-BROKEN-007` | `SL010` | BLOCK | Author-fill `<<...>>` tokens survive at `approved` |
| `BUG-BROKEN-008` | `SL051` | BLOCK | Three links, none with an inverse |
| `BUG-BROKEN-008` | `SL052` | BLOCK | `duplicate-of: BUG-BROKEN-008` is a self-link |
| `BUG-BROKEN-008` | `SL053` | WARN | `blocked-by` stored - an alias `link` normalizes away |
| `BUG-BROKEN-008` | `SL054` | WARN | `related-to: FEAT-BROKEN-004` listed twice |
| `REF-BROKEN-009` | `SL040` | BLOCK | Retro logs `draft -> done`, not an edge in the machine |
| `REF-BROKEN-009` | `SL020` | BLOCK | `done` refactor with no `01-plan.md` / `02-tasks.md` |
| `REF-BROKEN-009` | `SL012` | WARN | `PHASE-2` / `PHASE-3` tokens unfilled at `done` |
| _(tree-wide)_ | `SL032` | BLOCK | `BUG-GHOST-006` row in `index.md` has no folder |

---

## What this does not do

**It is not automated.** `/sd:spec validate` is a prompt executed by a model, so `scripts/`
cannot run it the way `selftest-docs.{ps1,sh}` runs Check 7 of `scripts/validate.{ps1,sh}`.
Automating it in CI would mean reimplementing the linter as an executable script — a second copy
of the rules, which is precisely the drift that SW-1 and SW-3 exist to prevent. Until that
trade-off is decided, this fixture makes the acceptance criterion **reproducible**, not
**enforced**.

**Rule coverage is partial: 18 of the 26 rules are seeded.** Not seeded, and why:

| Rule | Why not seeded |
|---|---|
| `SL001` | Unparseable frontmatter would break the fixture for every other reader/tool. |
| `SL004` | `type` vs prefix mismatch - cheap to add, simply not written yet. |
| `SL005` | Illegal `status` value - cheap to add, simply not written yet. |
| `SL013` | Needs an unreadable template, i.e. a broken engine install - not reproducible from a checked-in tree. |
| `SL021` | `done` with an empty retro - cheap to add, simply not written yet. |
| `SL041` | Non-contiguous transition chain - cheap to add, simply not written yet. |
| `SL043` | Non-`draft` status with no retro at all - cheap to add, simply not written yet. |
| `SL044` | `archived -> in-progress` with an empty reason - needs an archived spec; not written yet. |

A linter run over `broken/` that reports a rule from this second table has found a real bug in the
fixture, not in the spec tree.
