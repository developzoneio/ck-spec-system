# Port parity fixture

Two `.specs/` trees sharing one port spec's fidelity tables, for exercising `sd-reviewer`'s
`port-parity` mode, backing the SW-40 acceptance criteria: a seeded-broken host surfaces every
BLOCK class and both whole-artifact checks at the right severity; a clean host returns all-PASS and
a correctly justified deviation is never reported in either tree.

| Tree | Expectation |
|---|---|
| [`clean/`](clean/) | `_No findings._`. Member completeness `5/5`. Path conformance PASS. Three `justified` hunks counted in the summary, none written up. |
| [`broken/`](broken/) | Every finding in the table below, at the stated severity, and nothing else. |

Both trees carry the *same* `00-spec.md` fidelity tables (path mapping, member manifest, deviation
table) - `orders/order-intake.txt` (members `CreateOrder`, `ValidateTotals`, `ArchiveDraft`) and
`orders/order-notify.txt` (members `NotifyDispatch`, `NotifyFailure`), donor snapshot under
`04-artifacts/source/`. What differs is only the host under `src/orders/` and the parity diffs under
`04-artifacts/parity/` that were generated against it.

---

## How to run it

`sd-reviewer`'s `port-parity` mode is a prompt, not executable code, so no script can run it and CI
cannot gate on it - see "What this does not do" below. From a session rooted in one of the trees,
invoke the `sd-reviewer` subagent with:

```
TASK_TYPE = port-parity
SPEC_REF  = .specs/PORT-order-intake-20260809/00-spec.md
DIFF_REF  = .specs/PORT-order-intake-20260809/04-artifacts/parity/INDEX.md
CHANGED_FILES = src/orders/order-intake.txt, src/orders/order-notify.txt (+ src/orders/order-audit.txt in broken/)
```

`clean/` must come back `_No findings._`, member completeness `5/5`, path conformance PASS, and a
summary line counting 3 `justified` hunks (D01, D02, D03) with none of them written up individually.

`broken/` must come back with exactly the findings below and nothing else.

---

## Expected findings in `broken/`

| Case | Class or check | Severity | Seeded defect |
|---|---|---|---|
| 1 | `unjustified` | BLOCK | `CreateOrder` step 5 log text reads `"Order accepted for <reference>"`; no deviation row covers a log-text change |
| 2 | `missing` | BLOCK | `ArchiveDraft` (`orders/order-intake.txt`, ordinal 3) has no counterpart in `src/orders/order-intake.txt` |
| 3 | `overreached` | BLOCK | `D02` licenses only the rename `ValidateTotals` -> `CheckTotals`; the host hunk also swaps steps 2 and 3 |
| 4 | `overreached` | BLOCK | `D03` licenses only the rename `NotifyFailure` -> `HandleFailure`; the host hunk also swaps steps 1 and 2 |
| 5 | `extra` | BLOCK | `src/orders/order-notify.txt` gains a `NotifyEscalation` member with no donor counterpart and no deviation row |
| 6 | Member completeness | BLOCK | `4/5 members present` - `ArchiveDraft` named as the absent row |
| 7 | Path conformance | BLOCK | `src/orders/order-audit.txt` exists in `CHANGED_FILES` with no row in the path mapping table |

Case 2 and case 6 are the same underlying gap (`ArchiveDraft` is absent) reported through two
different lenses on purpose: case 2 is the hunk-level `missing` classification against the specific
manifest row's diff, case 6 is the whole-artifact member-completeness count the skill requires
regardless of which hunks were classified. A parity review that reports one but not the other has
implemented only half the gate.

### Why `D01`, `D02`, and `D03` are the interesting rows

All three deviations are correctly cited and, for `D01`, correctly and completely applied - the
host hunk does exactly what `D01` licenses and nothing more. It must **not** appear in the findings
in either tree. `D02` and `D03` are each correctly applied in `clean/` (same control) but exceeded
in `broken/` (cases 3 and 4) - the same deviation ID demonstrating both the accept path and the
`overreached` path depending on host compliance, rather than needing a fourth, unrelated deviation
just to prove the negative. A run that reports `D01`, or that reports `D02`/`D03` as `unjustified`
instead of `overreached`, has regressed the gate's precision - flagging correctly-cited work is just
as damaging to the gate's usefulness as missing a real BLOCK, since a reviewer that cries wolf on
correct deviations trains its own users to stop trusting the report.

## Why the seed markers live in the spec, not in the ported files

`<!-- SEEDED: ... -->` comments appear only in `broken/.specs/PORT-order-intake-20260809/00-spec.md`,
next to the table row each defect relates to. A comment line inside a host `.txt` file would be
itself content with no donor counterpart - i.e. it would seed an `extra` hunk the expected-findings
table above does not claim, corrupting the very diff the fixture exists to exercise.

## Why each seed gets its own diff hunk

`sd-port-fidelity` requires a diff artifact with "at least 3 lines of context" per hunk. Two nearby
changes closer than that context merge into a single hunk under standard unified-diff rules, which
would force one hunk to carry two different classifications. Every member in both donor files is
followed by an identical, unchanged `-- member boundary --` padding block precisely so each seeded
change - and the trailing `NotifyEscalation` addition - lands in its own isolated hunk. Run
`diff -u` yourself between any donor/host pair under this fixture to confirm: `clean/` produces 2
hunks in `order-intake.txt` and 1 in `order-notify.txt`; `broken/` produces 3 in each.

## What this does not do

**It is not automated.** `sd-reviewer`'s `port-parity` mode is a prompt executed by a model, so
`scripts/` cannot run it the way `selftest-docs.{ps1,sh}` runs Check 7 of `scripts/validate.{ps1,sh}`.
Automating it in CI would mean reimplementing the adjudicator as an executable script - a second
copy of the rules, the same drift `sd-port-fidelity` itself exists to prevent. Until that trade-off
is decided, this fixture makes the SW-40 acceptance criteria **reproducible**, not **enforced**.

**The parity diffs are checked in, not generated live.** The command that would generate
`04-artifacts/parity/` from a live host is the port pipeline, SW-41, not yet built - see
`docs/troubleshooting.md`. The `.diff` files here were produced by hand with `diff -u` against the
donor snapshot and are exactly what that future command's output would look like.

## Cross-fixture invariant

Both trees must also be clean under `/sd:spec validate` - the seeds here are parity defects, not
spec-lint defects, so `SL080`-`SL083` (real-looking `source_repo`/`source_commit` sentinel values,
a non-empty member manifest, every `Citation` non-empty with `Group` in 1-4, a `Reason` on every
non-`mirror` mapping row) must hold in `broken/` too. An `SL0xx` finding on this fixture is a
fixture bug, not a parity finding.
