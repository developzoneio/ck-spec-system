---
id: <<PORT-slug-YYYYMMDD>>
type: port
status: draft
jira: <<TICKET-ID-or-none>>
created: <<YYYY-MM-DD>>
scope: <<endpoint|module|feature|pattern>>
source_repo: <<url-or-path-of-donor-repo, or 'none' when scope is pattern>>
source_commit: <<full-sha-of-donor-commit, or 'none' when scope is pattern>>
source_license: <<SPDX-identifier-or-'proprietary'>>
snapshot: <<contract|contract+source>>
linked_specs: []
---

<!-- `source_repo` / `source_commit` are the only cross-project traceability that exists -
     `linked_specs` cannot reference another repository. Both are mandatory (a real value, not a
     placeholder) when `scope` is not `pattern`; write `none` for a `pattern`-scope port that
     reproduces a technique rather than a specific donor snapshot. `snapshot: contract` captures
     only the bridged contract this spec describes; `contract+source` also freezes the donor files
     themselves under `04-artifacts/source/`. Leave all ten placeholder tokens above for the
     architect to fill; all must be gone before `approved`. -->


# <<Short imperative title - what is ported, from where>>

> **The donor is the specification. Every departure is a row in the deviation table, or it is a
> defect.** The three fidelity tables below (Path mapping, Member manifest, Deviation table) are
> defined and enforced by the **sd-port-fidelity** skill - read it before filling them.

## Why

<!-- One paragraph. Why the host needs this donor behavior, and why porting rather than
     reimplementing from a fresh spec. -->

<<paragraph>>

## Donor provenance

- **Donor**: <<source_repo>> @ <<source_commit>>
- **License**: <<source_license>> - <<obligation, e.g. attribution notice retained in the host header>>
- **Snapshot mode**: <<contract | contract+source>>
- **Snapshot root**: `04-artifacts/source/`
- **Manifest**: `04-artifacts/source/MANIFEST.md`
- **Frozen**: <<yes|no>> - <<N>> path(s) appended to `paths.protected` on <<YYYY-MM-DD>>

<!-- Layout: `04-artifacts/source/` always holds the bridged contract; under
     `snapshot: contract+source` it also holds the donor files. `MANIFEST.md` records, per file,
     the donor path, commit, byte hash, and the line ranges the Member manifest below addresses by
     (Snapshot path, Ordinal) - see sd-port-fidelity's "Snapshot artifacts" section for the exact
     format. Quarantine rule: the snapshot directory is evidence, never a copy source handed to an
     implementer without a Member manifest row and an allowed-deviation list scoping it. Freeze
     rule: at freeze time, every file under `04-artifacts/source/` plus `MANIFEST.md` is appended
     as an individual literal path to `paths.protected` in `.claude/project-config.json` - matching
     there is exact-string, not glob, so this is an enumeration, not a wildcard.

     Parity artifacts: the snapshot-vs-host diffs the parity review reads live under
     `04-artifacts/parity/`, are written by the main thread at the parity phase, and are NOT frozen
     - see sd-port-fidelity's "Parity artifacts" section.

     Known limitation: spec-gate's in-progress-spec detection, prompt-router's context injection,
     and subagent-retro's lesson scoping do not yet recognize the `PORT-` prefix (it is hardcoded
     in the hook scripts). This is a documented gap, not an oversight - see
     docs/troubleshooting.md. -->

## Behavioral contract

<!-- The donor's observable contract. Fill every row; write "n/a" only with a one-line reason. -->

| Facet | Donor behavior (verbatim) |
|---|---|
| Route / entry point | <<...>> |
| Input shape | <<...>> |
| Output shape | <<...>> |
| Status / result codes | <<...>> |
| Auth requirement | <<...>> |
| Side effects | <<...>> |
| Error paths | <<...>> |

## Behavioral invariants (non-obvious)

<!-- Donor behavior a reasonable re-implementation gets wrong. This is the single highest-value
     section in this spec and is mandatory even when short. Never delete it - if you genuinely
     found none, write one entry saying so and what you checked. -->

- INV-1: <<e.g. The donor trims trailing whitespace from the identifier BEFORE the uniqueness
  check, so "abc " and "abc" collide. A re-implementation that validates first and trims later
  accepts both.>>

## Path mapping table

<!-- Columns and completeness condition are defined by sd-port-fidelity: one row per file in the
     declared donor scope and no others; every Host path unique; no empty cell; every non-mirror
     row carries a non-empty Reason. Donor path values below are snapshot-relative (relative to
     04-artifacts/source/), never donor-repo paths - donor line numbers rot the moment the donor
     changes; the snapshot is frozen. -->

| Donor path | Host path | Kind | Reason |
|---|---|---|---|
| <<orders/order-intake>> | <<src/orders/order-intake>> | <<mirror>> | <<->> |

## Member manifest

<!-- Columns and completeness condition are defined by sd-port-fidelity: one row per member of
     every non-omit donor file; Ordinal values within each Donor path form 1..N with no gap or
     duplicate; each Host path equals the mapping row for its Donor path; every non-ported row
     names a Deviation ID present in the deviation table below. There is no line-range column
     here - donor line ranges live only in 04-artifacts/source/MANIFEST.md, addressed by
     (Snapshot path, Ordinal). This table must not be empty. -->

| Donor path | Member | Ordinal | Host path | Status | Deviation ID |
|---|---|---|---|---|---|
| <<orders/order-intake>> | <<CreateOrder>> | <<1>> | <<src/orders/order-intake>> | <<ported>> | <<->> |

## Deviation table

<!-- Columns and completeness condition are defined by sd-port-fidelity: every ID unique; every
     Group is 1-4; every Citation non-empty and in the shape its group requires; every Deviation ID
     named in the Member manifest above appears here exactly once; no row here is unreferenced.
     Each row should be PR-ready - copy-pasteable into the PR description as the justification for
     the hunks it covers. -->

| ID | Donor form | Host form | Group | Citation |
|---|---|---|---|---|
| <<D01>> | <<donor name/order/text>> | <<host name/order/text>> | <<1-4>> | <<citation the group requires>> |

## Spawned specs

<!-- IDs reserved (not yet implemented). One row per donor defect reproduced deliberately - per
     sd-port-fidelity: record it, fix it in its own spec. A group-4 deviation is a fix that was
     agreed at the gate before implementation began and therefore does NOT belong here. -->

| Reserved ID | Type | Title | Owner |
|---|---|---|---|
| <<BUG-XXX>> | bug | <<title>> | <<owner>> |

## Success criteria

<!-- AC-1 is fixed by sd-port-fidelity and is the anchor every fidelity finding cites - never
     renumber it; renumbering breaks review anchors. Reword it only to track a change in
     sd-port-fidelity's own vocabulary, never to soften it. AC-2+ are author-fill. -->

- [ ] AC-1: Every host hunk in this port is either a structural mirror of its member-manifest row,
  or is covered by a deviation-table row whose citation satisfies its group and whose `Host form`
  accounts for the whole hunk. No `unjustified`, `missing`, `extra`, or `overreached` hunk remains
  (see sd-port-fidelity).
- [ ] AC-2: <<criterion citing an INV-<n> or a license/attribution obligation>>

## Out of scope

<<thing 1>>

## Open questions

<<question 1>>

## Constitution check

<!-- Which constitution sections apply. Filled by sd-spec-architect. -->

- **§1.1 Layer rules**: <<how this port respects layer boundaries>>
- **Risk of violation**: <<none | low | medium - explain>>

<!-- Cross-references live in the `linked_specs` frontmatter field, not in a body section. They
     are written by `/sd:spec link <ID-A> <relation> <ID-B>`. Do not hand-edit `linked_specs`. -->
