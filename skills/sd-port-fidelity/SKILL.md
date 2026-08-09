# sd-port-fidelity

Cross-project port fidelity policy for specwright. A port reproduces a donor implementation inside
a host repo; the donor's form is the specification, and every departure from it is a citable
decision rather than a preference. Authored into port specs by `sd-spec-architect` and enforced
against the changeset by `sd-reviewer`.

Read the section matching your role. The core rule and the deviation allowlist apply to everyone.

---

## The core rule

**Mirror the donor structurally. Every departure is a row in the deviation table, or it is a
defect.**

Structural mirror means the host reproduces, as far as the target permits: the donor's file
layout, member set, member order, symbol names, local variable names, step order within each
member, attribute order, and log message text. Judgement is not the mechanism here. A departure
carrying a deviation row is legal; a departure carrying none is a defect; and nobody is asked to
decide which of the two a given hunk is.

---

## Deviation allowlist

Exactly four groups force a departure. Each requires its own citation - a row citing nothing is
invalid, and the hunk it claims to cover is unjustified.

| Group | Forced by | Citation required |
|---|---|---|
| 1 | Compiler, namespace, or assembly conflict | the conflicting identifier |
| 2 | Host constitution | the constitution section, `§N.M` |
| 3 | Host precedent | `file:line` in the host |
| 4 | Behavior parity fix on an agreed donor defect | the parity criterion it satisfies |

Anything outside these four reverts to the donor form. "Cleaner", "more idiomatic to me", and "the
host does it differently somewhere" are not groups.

---

## Anti-simplification rules

These bind the implementer through the task blocks the architect writes, not by the implementer
loading this file: `sd-spec-architect` puts each applicable rule into the port task's `Acceptance`
and cites the donor `file:line` in `Pattern refs` (see **sd-atomic-task-format**).

- **No unrequested simplification.** Shorter is not better. Collapsing branches, merging members,
  or replacing a loop with a library call is a departure and needs a row.
- **No gratuitous rename.** Donor identifier names carry over even where host style would differ.
  Group 1, group 3, or nothing.
- **No reordering.** Statement order, parameter order, and member order follow the donor, even
  where another order reads better.
- **No opportunistic fix.** A donor defect is reproduced as-is and recorded for a follow-up spec.
  Fixing it inline is group 4 only when the fix was agreed at the gate before implementation began.
- **Host constitution beats donor precedent.** "It is only a copy" exempts nothing. A donor form
  that violates the host constitution is a cited group 2 deviation, never a verbatim import.

---

## Gate tables (sd-spec-architect)

A port spec carries three tables. Each has a completeness condition the gate evaluates
mechanically - it counts and matches, it never assesses whether a reason is good. A table failing
its condition is incomplete and the gate refuses it.

The spec must also carry a **fidelity acceptance criterion**: the criterion these tables are
evidence for. It is what review findings anchor to, and without it a fidelity finding has no legal
anchor (see **sd-severity-taxonomy**). A port spec missing it fails the gate.

### Path mapping table

| Column | Contents |
|---|---|
| `Donor path` | repo-relative path in the donor |
| `Host path` | repo-relative destination in the host |
| `Kind` | `mirror` / `merge` / `omit` |
| `Reason` | required when `Kind` is not `mirror`; `-` when it is |

**Complete when**: one row per file in the declared donor scope and no others; every `Host path`
unique; no empty cell; every non-`mirror` row carries a non-empty `Reason`.

### Member manifest

| Column | Contents |
|---|---|
| `Donor path` | the donor file the member comes from |
| `Member` | donor symbol name, verbatim |
| `Ordinal` | 1-based position of the member within that donor file |
| `Host path` | destination, copied from the path mapping table |
| `Status` | `ported` / `deviated` / `omitted` |
| `Deviation ID` | `D<NN>` when `Status` is not `ported`; `-` when it is |

**Complete when**: one row per member of every non-`omit` donor file; the `Ordinal` values within
each `Donor path` form `1..N` with no gap and no duplicate; each `Host path` equals the mapping row
for its `Donor path`; every non-`ported` row names a `Deviation ID` present in the deviation table.

### Deviation table

| Column | Contents |
|---|---|
| `ID` | `D<NN>`, unique, ascending |
| `Donor form` | the donor name, order, or text departed from |
| `Host form` | what the host uses instead |
| `Group` | `1`, `2`, `3`, or `4` from the allowlist |
| `Citation` | the citation that group requires, verbatim |

**Complete when**: every `ID` unique; every `Group` is one of `1` to `4`; every `Citation` is
non-empty and in the shape its group requires; every `Deviation ID` named in the member manifest
appears here exactly once; no row here is unreferenced by the manifest.

---

## Snapshot artifacts (sd-spec-architect)

Under a port spec's `04-artifacts/source/`: the bridged contract always, and under
`snapshot: contract+source`, the donor files too. `MANIFEST.md` sits at that directory's root.

### Snapshot manifest format

- **Donor**: <repo url or path>
- **Commit**: <full sha>
- **Captured**: <YYYY-MM-DD>
- **Mode**: contract | contract+source
- **Hash algorithm**: sha256, lowercase hex, over the bytes as captured

| Snapshot path | Donor path | Commit | Bytes | SHA-256 | Member ranges |
|---|---|---|---|---|---|
| `orders/order-intake` | `src/orders/order-intake` | `<sha>` | 4821 | `3f9a...` | `1: CreateOrder 12-58; 2: ValidateTotals 60-93` |

One row per captured file. `Member ranges` is `<ordinal>: <member> <firstLine>-<lastLine>`,
semicolon-separated, ordinals contiguous from 1 - the same ordinals the Member manifest table uses.

### Two snapshot rules

1. **Cite the snapshot, not the donor.** Path mapping and Member manifest rows cite `Snapshot
   path`, never a donor-repo path - donor line numbers rot the moment the donor changes; the
   snapshot is frozen. Donor paths, the commit, and line ranges live only in `MANIFEST.md`,
   addressed by `(Snapshot path, Ordinal)` - the Member manifest table carries no line-range
   column of its own.
2. **Quarantine.** The snapshot directory is evidence, never a copy source handed to an
   implementer without a Member manifest row and an allowed-deviation list scoping it.

### Immutability

At freeze, every file under `04-artifacts/source/` plus `MANIFEST.md` is appended as an
**individual literal string** to `paths.protected` in `.claude/project-config.json`. Both
`spec-gate` hooks match `paths.protected` by exact string equality, not glob - the enumeration
*is* the mechanism, not a workaround for one. The append must be idempotent. `/sd:spec` cannot
perform this step itself (it never touches `.claude/`); it is a documented manual step until the
port pipeline lands. `spec-gate` guards `Edit`/`Write` only - it does not stop a shell delete.

Per-file hashes are recorded now so a later drift check (re-hashing the donor at a newer commit)
remains possible; consuming them is out of scope for this story.

---

## Hunk classification (sd-reviewer)

Classify every hunk of the port changeset into exactly one class. The vocabulary is closed - there
is no fifth class and no "probably fine".

| Class | Condition | Verdict |
|---|---|---|
| `justified` | maps to a deviation row whose citation satisfies its group | accept |
| `unjustified` | departs from the donor form with no deviation row covering it | BLOCK |
| `missing` | a manifest member has no host counterpart and no `omitted` status | BLOCK |
| `extra` | host content with no donor counterpart and no deviation row | BLOCK |

Anchor every fidelity BLOCK to the port spec's fidelity acceptance criterion - a spec acceptance
criterion is a legal anchor for a code target under **sd-severity-taxonomy**. Cite the deviation
row, or its absence, as the supporting `file:line` per **sd-evidence-citation**. A deviation row is
evidence; it is never the anchor by itself.

---

## Anti-patterns

- **Improving the donor while porting.** The port is not the moment. Reproduce it, record it, and
  raise the follow-up.
- **A deviation row citing nothing.** "Host style" is not a citation; group 3 needs `file:line`.
- **Renaming to local taste.** Taste is not one of the four groups.
- **Reordering for readability.** Donor order is the order, attribute order included.
- **Waving a table through because it looks right.** The completeness conditions are counted, not
  judged. An incomplete table is refused without a discussion of intent.
- **Treating a donor defect as an invitation.** Record it; fix it in its own spec.
