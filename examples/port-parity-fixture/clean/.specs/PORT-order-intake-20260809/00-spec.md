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

This is the SW-40 `port-parity` fixture's `clean/` half: a host that fully satisfies every row of
its own fidelity tables, so a parity review over it must return `_No findings._` with every
manifest member present and every deviation correctly justified. `scope: pattern` and
`source_repo/source_commit: none` because there is no real donor repository behind this fixture -
the "donor" is the frozen snapshot under `04-artifacts/source/`, invented for this fixture and
treated exactly as a real one would be for review purposes.

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

| Donor path | Host path | Kind | Reason |
|---|---|---|---|
| `orders/order-intake.txt` | `src/orders/order-intake.txt` | mirror | - |
| `orders/order-notify.txt` | `src/orders/order-notify.txt` | mirror | - |

## Member manifest

| Donor path | Member | Ordinal | Host path | Status | Deviation ID |
|---|---|---|---|---|---|
| `orders/order-intake.txt` | `CreateOrder` | 1 | `src/orders/order-intake.txt` | deviated | D01 |
| `orders/order-intake.txt` | `ValidateTotals` | 2 | `src/orders/order-intake.txt` | deviated | D02 |
| `orders/order-intake.txt` | `ArchiveDraft` | 3 | `src/orders/order-intake.txt` | ported | - |
| `orders/order-notify.txt` | `NotifyDispatch` | 1 | `src/orders/order-notify.txt` | ported | - |
| `orders/order-notify.txt` | `NotifyFailure` | 2 | `src/orders/order-notify.txt` | deviated | D03 |

## Deviation table

| ID | Donor form | Host form | Group | Citation |
|---|---|---|---|---|
| D01 | identifier `ledger` | identifier `orderLedger` | 1 | `ledger` (conflicts with an existing host symbol of the same name) |
| D02 | member name `ValidateTotals` | member name `CheckTotals`, step order and log text unchanged | 3 | `CLAUDE.md:8` (host convention: validation members named `Check<Noun>`) |
| D03 | member name `NotifyFailure` | member name `HandleFailure`, step order and log text unchanged | 3 | `CLAUDE.md:9` (host convention: failure-handling members named `Handle<Noun>`) |

## Spawned specs

None.

## Success criteria

- [x] AC-1: Every host hunk in this port is either a structural mirror of its member-manifest row,
  or is covered by a deviation-table row whose citation satisfies its group and whose `Host form`
  accounts for the whole hunk. No `unjustified`, `missing`, `extra`, or `overreached` hunk remains
  (see sd-port-fidelity). Evidence: `04-artifacts/parity/INDEX.md` + both `.diff` files - every
  hunk maps to D01, D02, or D03 and no hunk exceeds its row.
- [x] AC-2: Member completeness is 5/5 - every manifest row has a host counterpart. Evidence: both
  host files under `src/orders/`.
- [x] AC-3: Path conformance holds - every file under `src/orders/` is a `Host path` in the path
  mapping table above. Evidence: exactly two files, both mapped.

## Out of scope

Semantic equivalence checking of the ported logic - this fixture is about diff-based fidelity
adjudication only, not behavior pinning.

## Open questions

None.

## Constitution check

- **§1.1 Layer rules**: n/a - flat procedure-card host, no layers.
- **Risk of violation**: none.
