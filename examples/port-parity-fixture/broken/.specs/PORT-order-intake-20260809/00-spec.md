---
id: PORT-order-intake-20260809
type: port
status: in-progress
jira: none
created: 2026-08-09
scope: pattern
source_repo: none
source_commit: none
source_license: proprietary
snapshot: contract+source
linked_specs: []
---

# Port order-intake and order-notify to order-service

> **The donor is the specification. Every departure is a row in the deviation table, or it is a
> defect.** The three fidelity tables below (Path mapping, Member manifest, Deviation table) are
> defined and enforced by the **sd-port-fidelity** skill - read it before filling them.

## Why

This is the SW-40 `port-parity` fixture's `broken/` half: the identical intended contract as
`clean/` (same three tables below), against a host that seeds exactly one defect per BLOCK class
plus both whole-artifact checks, and one correctly-justified deviation that must NOT be reported -
the regression guard for the gate's noise floor, not only for its BLOCKs. `<!-- SEEDED: ... -->`
comments below name each defect; see the fixture README for the full expected-findings table.
`scope: pattern` and `source_repo/source_commit: none` because there is no real donor repository
behind this fixture - the "donor" is the frozen snapshot under `04-artifacts/source/`.

## Donor provenance

- **Donor**: none (pattern-scope fixture - see fixture README)
- **License**: proprietary - none
- **Snapshot mode**: contract+source
- **Snapshot root**: `04-artifacts/source/`
- **Manifest**: `04-artifacts/source/MANIFEST.md`
- **Frozen**: no - fixture only, never appended to `paths.protected`

## Behavioral contract

| Facet | Donor behavior (verbatim) |
|---|---|
| Route / entry point | n/a - library-style procedure cards, no entry route |
| Input shape | a customer reference and an order total, per member |
| Output shape | a ledger entry or a notification send |
| Status / result codes | n/a - plain-text procedure cards carry no status codes |
| Auth requirement | none |
| Side effects | ledger append, archive flag, message send |
| Error paths | reference already in ledger; totals mismatch |

## Behavioral invariants (non-obvious)

- INV-1: `CreateOrder` rejects a duplicate reference BEFORE appending to the ledger, so the
  ledger-conflict check always runs ahead of any write.

## Path mapping table

<!-- SEEDED: path conformance - src/orders/order-audit.txt exists in the host with no row here and
     no deviation row. Expected: one BLOCK naming the file. -->

| Donor path | Host path | Kind | Reason |
|---|---|---|---|
| `orders/order-intake.txt` | `src/orders/order-intake.txt` | mirror | - |
| `orders/order-notify.txt` | `src/orders/order-notify.txt` | mirror | - |

## Member manifest

<!-- SEEDED: missing - ArchiveDraft (ordinal 3) has no counterpart in the host order-intake.txt.
     Expected: member completeness 4/5, one BLOCK naming Donor path orders/order-intake.txt,
     Member ArchiveDraft, Ordinal 3. -->

| Donor path | Member | Ordinal | Host path | Status | Deviation ID |
|---|---|---|---|---|---|
| `orders/order-intake.txt` | `CreateOrder` | 1 | `src/orders/order-intake.txt` | deviated | D01 |
| `orders/order-intake.txt` | `ValidateTotals` | 2 | `src/orders/order-intake.txt` | deviated | D02 |
| `orders/order-intake.txt` | `ArchiveDraft` | 3 | `src/orders/order-intake.txt` | ported | - |
| `orders/order-notify.txt` | `NotifyDispatch` | 1 | `src/orders/order-notify.txt` | ported | - |
| `orders/order-notify.txt` | `NotifyFailure` | 2 | `src/orders/order-notify.txt` | deviated | D03 |

## Deviation table

<!-- SEEDED (control, AC-6): D01 is correctly cited and the host hunk does exactly what it licenses
     - it must NOT appear in the findings. A run that reports D01 has regressed the noise floor. -->
<!-- SEEDED: unjustified - host CreateOrder step 5 log text reads "Order accepted for <reference>";
     no row here covers a log-text change. Expected: one BLOCK, no covering deviation row. -->
<!-- SEEDED: overreached - D02 licenses only the rename to CheckTotals; the host hunk also swaps
     steps 2 and 3. Expected: one BLOCK naming D02 and the reorder its Host form does not state. -->
<!-- SEEDED: overreached - D03 licenses only the rename to HandleFailure; the host hunk also swaps
     steps 1 and 2. Expected: one BLOCK naming D03 and the reorder its Host form does not state. -->
<!-- SEEDED: extra - host order-notify.txt gains a NotifyEscalation member with no donor
     counterpart and no row here. Expected: one BLOCK. -->

| ID | Donor form | Host form | Group | Citation |
|---|---|---|---|---|
| D01 | identifier `ledger` | identifier `orderLedger` | 1 | `ledger` (conflicts with an existing host symbol of the same name) |
| D02 | member name `ValidateTotals` | member name `CheckTotals`, step order and log text unchanged | 3 | `CLAUDE.md:8` (host convention: validation members named `Check<Noun>`) |
| D03 | member name `NotifyFailure` | member name `HandleFailure`, step order and log text unchanged | 3 | `CLAUDE.md:9` (host convention: failure-handling members named `Handle<Noun>`) |

## Spawned specs

None.

## Success criteria

- [ ] AC-1: Every host hunk in this port is either a structural mirror of its member-manifest row,
  or is covered by a deviation-table row whose citation satisfies its group and whose `Host form`
  accounts for the whole hunk. No `unjustified`, `missing`, `extra`, or `overreached` hunk remains
  (see sd-port-fidelity). Blocked by the five seeds above - see the fixture README's expected
  findings table.
- [ ] AC-2: Member completeness is 5/5. Currently 4/5 - `ArchiveDraft` (ordinal 3) is absent.
- [ ] AC-3: Path conformance holds. Currently fails - `src/orders/order-audit.txt` is unmapped.

## Out of scope

Semantic equivalence checking of the ported logic - this fixture is about diff-based fidelity
adjudication only, not behavior pinning.

## Open questions

None.

## Constitution check

- **§1.1 Layer rules**: n/a - flat procedure-card host, no layers.
- **Risk of violation**: none.
