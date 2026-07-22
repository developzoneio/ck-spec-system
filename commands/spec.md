---
description: Spec registry management. Pure file ops on .specs/ - no subagent invocation, no code changes.
argument-hint: <subcommand> [args...]
---

# /sd:spec

Dispatcher for spec registry operations. **No code is changed. No subagent is invoked.** All operations are file-system reads on `.specs/` with controlled writes to `.specs/index.md` and the target spec's frontmatter / `05-retro.md`.

**Usage**: `/sd:spec <subcommand> [args...]`

If `<subcommand>` is omitted or not recognized, run the `help` subcommand.

---

## Subcommands

| Subcommand | Args | Purpose |
|---|---|---|
| `list` | `[type] [status]` | List specs filtered by type and/or status |
| `show` | `<ID>` | Display one spec's frontmatter + section summary |
| `status` | `<ID> <new-state>` | Transition lifecycle state (with validation) |
| `link` | `<ID-A> <relation> <ID-B>` | Record cross-reference |
| `archive` | `<ID>` | Move from `done` to `archived` |
| `revive` | `<ID> [reason]` | Move from `archived` back to `in-progress` |
| `search` | `<term>` | Full-text search across spec bodies |
| `validate` | `[ID or --all]` | Validate frontmatter + structure |
| `stats` | - | Counts by type / status; aging report |
| `help` | - | This list |

---

## Phase 0 - Bootstrap (always)

1. Read `.claude/project-config.json` for `spec.dir`, `spec.indexFile`, `spec.prefixes`, `spec.lifecycle`.
2. Verify `.specs/index.md` exists. If not, prompt: "No spec index found. Run `/sd:setup` first."
3. Dispatch to the requested subcommand.

---

## list

Args:
- `[type]` (optional): one of `feature`, `bug`, `refactor`, `perf`, `rca`. Filters by type prefix.
- `[status]` (optional): one of the lifecycle states. Filters by current state in index.

Behavior:
1. Parse `.specs/index.md` rows.
2. Apply filters.
3. Output a markdown table: ID | Type | Status | Created | Title.

Example:
```
/sd:spec list bug in-progress
/sd:spec list feature
/sd:spec list -- in-progress    (status only, double-dash signals positional skip)
```

---

## show

Args:
- `<ID>` (required): full spec ID, e.g. `FEAT-INV-2501`.

Behavior:
1. Resolve folder `.specs/<ID>/`.
2. Read `00-spec.md`. Display:
   - Frontmatter (id, type, status, created, jira/severity if present).
   - First H2 (title or "Why").
   - Status of each phase artifact: which of `00-spec.md`, `01-plan.md`, `02-tasks.md`, `03-decisions.md`, `04-artifacts/`, `05-retro.md`, `06-verify.md` (written by `/sd:verify`; gates the `done` transition) exist.
3. If `02-tasks.md` exists, show task completion count `N/M`.
4. Print folder URL: `file://<absolute path>`.

---

## status

Args:
- `<ID>` (required).
- `<new-state>` (required): one of `draft`, `approved`, `in-progress`, `done`, `archived`.

Behavior:
1. Read current status from `.specs/<ID>/00-spec.md` frontmatter.
2. Validate transition against the state machine:

```
draft -> approved
approved -> in-progress
in-progress -> done
done -> archived
archived -> in-progress (only via 'revive', with reason)
```

The `in-progress -> done` transition of a feature (FEAT) spec is hook-enforced: spec-gate
blocks the `index.md` edit unless `<spec.dir>/<ID>/06-verify.md` exists and records
`result: pass`. Run `/sd:verify <ID>` first. Disable only via `hooks.specGate.verifyGate: false`
in project-config. Other spec types (bug, refactor, perf, rca) close out as before - the hook
does not gate their `index.md` row.

3. Illegal transitions are REFUSED. Do NOT mutate any file. Print a refusal that names the current
   state, the requested state, the valid next state(s) for the current state (from the machine above),
   and - when the requested state is reachable - the shortest legal path to it:

```
Refused: cannot move <ID> from '<current>' to '<requested>'.
Valid next state(s) from '<current>': <list, or 'none (terminal)'>.
To reach '<requested>', follow: <current> -> ... -> <requested>.   (omit this line if unreachable)
```

   Example - `status SPEC-123 done` while `SPEC-123` is `draft`:

```
Refused: cannot move SPEC-123 from 'draft' to 'done'.
Valid next state(s) from 'draft': approved.
To reach 'done', follow: draft -> approved -> in-progress -> done.
```
4. On valid transition:
   - If this is an `in-progress -> done` transition of a feature (FEAT) spec: BEFORE mutating
     any file, check `<spec.dir>/<ID>/06-verify.md` exists and records `result: pass`. If not,
     REFUSE the transition with no file mutated:

```
Refused: <ID> cannot move from 'in-progress' to 'done' - no passing /sd:verify artifact.
Run /sd:verify <ID> first; close-out is allowed only after <spec.dir>/<ID>/06-verify.md records
'result: pass'.
```

     This check exists because the frontmatter, index, and retro log are mutated one file at a
     time below; without it, a spec-gate block on the `index.md` edit alone would strand the
     frontmatter already updated to `done` while the index still says `in-progress` - an
     `SL030` disagreement. Checking first keeps the transition atomic: either nothing moves, or
     all three files do.
   - Update frontmatter `status:` field in `00-spec.md`.
   - Update the row in `.specs/index.md`.
   - Append a log entry to `.specs/<ID>/05-retro.md`:

```
- [<UTC ISO timestamp>] Status: <old> -> <new>. Reason: <reason from args or 'manual transition'>.
```

If `05-retro.md` does not yet exist, create it with a header and the entry.

---

## link

Args:
- `<ID-A>` (required).
- `<relation>` (required): one of `depends-on`, `related-to`, `spawned-by`, `spawns`, `blocks`, `blocked-by`, `duplicate-of`, `supersedes`, `superseded-by`.
- `<ID-B>` (required).

Behavior:
1. Verify both spec folders exist. A link to a non-existent ID is REFUSED - do not create a
   dangling entry.
2. Validate relation is in the allow-list, then normalize it (see below).
3. Refuse a self-link (`ID-A` == `ID-B`).
4. If the link already exists on either side, do nothing and say so - `link` is idempotent.
5. Update the `linked_specs` frontmatter list on both specs:
   - On ID-A: add `- <canonical-relation>: <ID-B>`.
   - On ID-B: add `- <inverse-relation>: <ID-A>`.
6. Append a log line to both retros.

### Relation vocabulary

`blocked-by` is an **input alias**, not a stored relation: "A is blocked-by B" and "A depends-on B"
assert the same edge, so storing both would let one spec carry two spellings of one fact and make
symmetry unverifiable. `link` normalizes `blocked-by` to `depends-on` and reports the rewrite.
The other eight inputs are already canonical and are stored as given.

| Input | Stored as | Inverse written on the other side |
|---|---|---|
| `depends-on` | `depends-on` | `blocks` |
| `blocked-by` | `depends-on` (alias) | `blocks` |
| `blocks` | `blocks` | `depends-on` |
| `spawns` | `spawns` | `spawned-by` |
| `spawned-by` | `spawned-by` | `spawns` |
| `supersedes` | `supersedes` | `superseded-by` |
| `superseded-by` | `superseded-by` | `supersedes` |
| `related-to` | `related-to` | `related-to` (symmetric) |
| `duplicate-of` | `duplicate-of` | `duplicate-of` (symmetric) |

The map is total and closed: every stored relation has exactly one inverse, and that inverse is
itself a stored relation. This is what makes the link-symmetry check in `validate` decidable.

### linked_specs format

A YAML list of single-key maps in `00-spec.md` frontmatter. Empty is `[]`.

```yaml
linked_specs:
  - depends-on: FEAT-INV-2501
  - related-to: BUG-1247
```

---

## archive

Args:
- `<ID>` (required).

Behavior:
1. Verify current status is `done`.
2. Run `status <ID> archived`.
3. Print confirmation.

If current status is not `done`, REFUSE: "Only `done` specs can be archived. Current status: <X>."

---

## revive

Args:
- `<ID>` (required).
- `[reason]` (optional, recommended): why the archived spec is being revived.

Behavior:
1. Verify current status is `archived`.
2. Run `status <ID> in-progress` with the provided reason.
3. Common use case: `done` work needs follow-up after being archived. If user is doing fundamentally new work, suggest creating a new spec instead.

---

## search

Args:
- `<term>` (required): plain text. No regex.

Behavior:
1. Recursive grep across `.specs/**/*.md` (excluding `_archived/` if conventionally placed there).
2. Output: `<spec ID>: <file>:<line>: <matching line trimmed>`.
3. Group by spec ID. Limit to 50 results; tell user to refine if hit.

---

## validate

Args:
- `<ID>` (optional, default `--all`).

Behavior:
1. Per-spec checks. For each target spec:
   - Frontmatter present and parseable.
   - Required fields present, per type (see "Required frontmatter fields" below).
   - `id` field matches the folder name.
   - `type` matches the prefix.
   - `status` is in `spec.lifecycle` from project-config.
   - Placeholder discipline (see "Placeholder tokens" below).
   - Expected files present per status:
     - status >= `in-progress` -> `01-plan.md` and `02-tasks.md` exist (feature and refactor
       only; bug, perf, and rca do not produce plan/tasks artifacts).
     - status == `done` -> `05-retro.md` exists with at least one entry.
   - Index row matches frontmatter status.
   - Transition history is legal (see "Transition replay" below).
   - Links resolve and are symmetric (see "Link integrity" below).
   - Task-block content, when `02-tasks.md` exists (see "Task-block checks" below). This is the
     only check that reads inside an artifact rather than around it.
2. Tree-wide checks (run once, only when the target is `--all`):
   - Index <-> folder symmetry (see below).
3. Report every finding using the severity taxonomy (see "Output" below). Do not stop at the
   first failure - a spec with three problems reports three findings.

### Rule table

Every finding cites one of these IDs. The ID is the finding's anchor - the taxonomy forbids a
BLOCK or WARN without one. IDs are stable: renumbering them breaks anyone who has pinned a rule.

| ID | Rule | Severity |
|---|---|---|
| `SL001` | Frontmatter missing or unparseable | 🔴 BLOCK |
| `SL002` | Required field missing for type | 🔴 BLOCK |
| `SL003` | `id` does not match folder name | 🔴 BLOCK |
| `SL004` | `type` does not match ID prefix | 🔴 BLOCK |
| `SL005` | `status` not in `spec.lifecycle` | 🔴 BLOCK |
| `SL006` | `linked_specs` missing, or present but not a list | 🔴 BLOCK |
| `SL010` | Author-fill `<<...>>` token remains at status >= `approved` | 🔴 BLOCK |
| `SL011` | Phase-deferred `<<PHASE-N: ...>>` token pre-filled at `draft` / `approved` | 🔴 BLOCK |
| `SL012` | Phase-deferred token still unfilled at `done` | 🟠 WARN |
| `SL013` | Type template unreadable - placeholder checks could not run | 🟠 WARN |
| `SL020` | Required artifact missing for status | 🔴 BLOCK |
| `SL021` | Status `done` but `05-retro.md` has no entry | 🔴 BLOCK |
| `SL030` | Index row status disagrees with frontmatter status | 🔴 BLOCK |
| `SL031` | Orphan folder - spec exists but has no index row | 🔴 BLOCK |
| `SL032` | Ghost row - index row whose folder does not exist | 🔴 BLOCK |
| `SL033` | Duplicate index rows for one ID | 🔴 BLOCK |
| `SL040` | Illegal transition edge in the retro log | 🔴 BLOCK |
| `SL041` | Transition chain not contiguous | 🔴 BLOCK |
| `SL042` | Last logged transition disagrees with frontmatter status | 🔴 BLOCK |
| `SL043` | Status is not `draft` but there is no retro log | 🔴 BLOCK |
| `SL044` | `archived -> in-progress` logged with an empty reason | 🟠 WARN |
| `SL050` | Link target does not resolve to an existing spec | 🔴 BLOCK |
| `SL051` | One-sided link - inverse entry missing on the target | 🔴 BLOCK |
| `SL052` | Self-link | 🔴 BLOCK |
| `SL053` | Stored relation is `blocked-by` - an input alias, so the field was hand-edited | 🟠 WARN |
| `SL054` | Duplicate entry in `linked_specs` | 🟠 WARN |
| `SL055` | Spec status `done` but `06-verify.md` is missing or records `result: fail` | 🟠 WARN |
| `SL060` | Task block in `02-tasks.md` has no `Pattern refs` field | 🟠 WARN |

`SL061`-`SL069` are **reserved** for further task-block content rules. Claim from this band rather
than extending another one - `SL05x` is link integrity and has nothing to do with task content.

Severity rationale: BLOCK is for a registry that **lies** (its own contents contradict each other,
so `list` / `stats` / downstream agents read something untrue) or evidence that was **fabricated**
(`SL011` - a measured field filled from memory). WARN is for a real problem that leaves the
registry still truthful and is recoverable by re-running a command. There is no SUGGEST rule
today; the section is still printed, per the taxonomy.

`SL060` is WARN by that same test: a task with no `Pattern refs` leaves the registry truthful and
is fixed by re-planning the spec. It is deliberately **not** BLOCK - in the only corpus measured,
every task authored after the field shipped already carried it (22 of 22), while the two specs
without it predate the field entirely. Blocking would fail old specs for a rule they could not
have followed, and would gain nothing on new ones.

### Task-block checks

Run only when `02-tasks.md` exists. Parse it per the **Field label grammar** in the
`sd-atomic-task-format` skill - label matching is case-insensitive, `**` around the label is
optional, and the colon may sit inside or outside the emphasis. All three forms occur in live
specs; a reader that accepts only the canonical `- **Label**:` form reports false `SL060`s against
correctly authored tasks, which is worse than not running the check at all.

A field's value runs to the next field label, not to the next newline - `Acceptance` and
`Pattern refs` are routinely multi-line with nested bullets.

Report one `SL060` per offending task block, citing the task heading (e.g. `02-tasks.md` `T01`).
A block that writes `Pattern refs: none` is **compliant** - the explicit `none` is the assertion
the rule is asking for. Only an absent field is a finding.

### Output

Read `~/.claude/skills/sd/sd-severity-taxonomy/SKILL.md` and
`~/.claude/skills/sd/sd-evidence-citation/SKILL.md` before emitting the report, and follow them.
This command has no `skills:` frontmatter - only agents load skills that way, and `validate`
invokes no subagent - so the rules are read at runtime instead. If either file is unreadable, say
so and fall back to plain PASS / FAIL lines rather than inventing a format.

Structure: the taxonomy's mandated output, plus a per-spec summary table above it.

```markdown
# Spec lint: <N> spec(s) under `.specs/`

**Verdict**: <N> 🔴 BLOCK, <N> 🟠 WARN, <N> 🟡 SUGGEST, <N> 🟢 PASS across <N> specs.

| Spec | Status | Result |
|---|---|---|
| `FEAT-INV-2501` | in-progress | PASS |
| `BUG-1247` | done | 2 findings (1 BLOCK, 1 WARN) |

## 🔴 BLOCK

### B1: `id` does not match folder name
- **File:line**: `.specs/BUG-1247/00-spec.md:2`
- **Rule**: `SL003`
- **Finding**: Frontmatter declares `id: BUG-1246` but the folder is `BUG-1247`. `show` and
  `link` resolve by folder, `list` renders the frontmatter - so the two disagree about what
  this spec is called.
- **Suggested direction**: Decide which ID is real, then fix the other side and the index row.
```

Citation rules for this command, applying `sd-evidence-citation`:

- Every finding cites `file:line`, relative to the project root.
- A finding about something **absent** (a missing artifact, a missing inverse link) has no line
  of its own. Cite the line that **creates the obligation** - e.g. for `SL020`, the `status:`
  line whose value requires the artifact - and name the absent path in the finding text. Never
  cite a bare directory: the skill rejects it, and the obligation line is the better evidence.
- Tree-wide findings (`SL031` / `SL032` / `SL033`) cite `.specs/index.md:<row>` where a row
  exists, and `.specs/<ID>/00-spec.md:1` for an orphan folder that has no row to point at.
- A clean tree prints the summary table with every spec `PASS`, and `_No findings._` under each
  of the four severity sections. Do not omit the empty sections.

### Index <-> folder symmetry

Only meaningful for `--all`; a single-ID run cannot see orphans. Compare the set of spec folders
under `spec.dir` against the set of rows in `spec.indexFile`:

- **Orphan folder**: a spec folder with no index row. The spec is invisible to `list` / `stats`.
- **Ghost row**: an index row whose folder does not exist. Points at nothing.
- **Duplicate row**: the same ID on more than one index row.

Directories whose name starts with `_` are engine-reserved (`_explorations/`, `_reviews/`,
`_adr/`, `_archived/`) and are NOT specs - skip them. Skip `index.md` and `constitution.md` too.

### Transition replay

`05-retro.md` is the append-only status log written by `status` / `link`. Replay it against the
state machine in the `status` section above:

- Parse every `- [<ts>] Status: <old> -> <new>.` line, in file order.
- Each `<old> -> <new>` must be a legal edge. `archived -> in-progress` is legal only when the
  entry's reason is non-empty (that edge exists only via `revive`).
- The chain must be contiguous: each entry's `<old>` equals the previous entry's `<new>`.
- The last entry's `<new>` must equal the current frontmatter `status`. A mismatch means a
  status was hand-edited, bypassing `status` - which is exactly what the log exists to catch.
- A spec with no retro and status `draft` is fine (nothing has transitioned yet). Any other
  status with no retro is a failure.

Replay reads only committed history - it cannot see a transition that was never logged. A
hand-edit that updated frontmatter, index, *and* forged a matching log line is out of scope.

### Link integrity

For every entry in a spec's `linked_specs`:

- The relation is a **stored** relation from the `link` vocabulary. A stored `blocked-by` is a
  failure: it is an input alias that `link` normalizes away, so its presence means the field was
  hand-edited.
- The target ID resolves to an existing spec folder (no dangling links).
- The inverse entry exists on the target, pointing back (no one-sided links). Symmetric relations
  (`related-to`, `duplicate-of`) require the same relation back.
- No self-link, no duplicate entries.

### Required frontmatter fields

Presence is what is checked, not value - a field may legitimately hold a `<<placeholder>>` at
`draft`. The "Placeholder tokens" rules below govern when a value must be real.

Every type additionally requires `linked_specs` (a YAML list; `[]` when the spec stands alone).

| Type | Required fields (beyond `linked_specs`) |
|---|---|
| `feature` | `id`, `type`, `status`, `jira`, `created` |
| `bug` | `id`, `type`, `severity`, `status`, `jira`, `created` |
| `refactor` | `id`, `type`, `smell`, `status`, `created` |
| `perf` | `id`, `type`, `status`, `target_metric`, `created` |
| `rca` | `id`, `type`, `status`, `severity`, `incident_started`, `incident_resolved`, `created` |

`jira` is required to be present but may hold `none`. `incident_resolved` may hold a placeholder
while an incident is still open - an RCA for an unresolved incident cannot pass `approved`.
`linked_specs` must be present and a list; `[]` is the valid empty form, a bare `none` is not.

### Placeholder tokens

Two token forms with opposite rules. Both live in `00-spec.md`.

| Form | Meaning | Filled by |
|---|---|---|
| `<<description>>` | Author-fill. Written when the spec is drafted. | The spec author |
| `<<PHASE-N: description>>` | Phase-deferred. MUST NOT be pre-filled - the workflow's Phase N fills it from measured evidence. | Phase N of the owning workflow |

The reference set of phase-deferred tokens for a type is the `<<PHASE-N: ...>>` tokens in
`~/.claude/templates/sd/specs/<type>.template.md`. If that template is unreadable, raise `SL013`
and skip only the placeholder checks for that spec - never silently pass them.

Rules:
- status >= `approved` -> no author-fill `<<...>>` token remains. Phase-deferred tokens are
  exempt and are NOT a failure.
- status in {`draft`, `approved`} -> for each phase `N`, the spec MUST carry at least as many
  `<<PHASE-N: ...>>` tokens as the template does. A filled-in phase-deferred field at these
  states is a failure: it means the value was written from memory rather than measured. This is
  the check that makes the cross-phase discipline enforceable rather than advisory.

  Match on the `<<PHASE-N:` prefix and count per phase - do NOT require the description text to
  match the template verbatim. Filling a field deletes its token, which the count catches;
  trimming an example out of a token's description is not pre-filling and must not fail.
- status == `in-progress` -> no assertion either way. The lifecycle records status, not which
  phase is current, so a phase-deferred token may legitimately be filled or unfilled. This is a
  known blind spot, not an oversight: narrowing it would mean tracking phase in frontmatter.
- status == `done` -> no `<<PHASE-N: ...>>` token remains.

---

## stats

Args: none.

Behavior:
1. Parse `.specs/index.md`.
2. Output:
   - Counts by type (FEAT / BUG / REF / PERF / RCA).
   - Counts by status.
   - "Aging" report: specs in `in-progress` for more than 7 days (configurable), specs in `draft` for more than 14 days.
   - Top 5 oldest `in-progress` specs.

---

## help

Behavior: print the subcommand table above with one-line examples.

---

## Rules (hard constraints)

- This command NEVER invokes a subagent.
- This command NEVER edits files outside `.specs/`. (Specifically: never touches code, never touches `.claude/`, never touches the constitution.)
- Lifecycle transitions follow the validated state machine. Illegal transitions are refused.
- Every state change is logged to `05-retro.md` with timestamp and reason. The log is append-only - never edit prior entries.
- The `revive` subcommand exists for `done` -> follow-up cases. New work uses a new spec.
- `search` is plain text; for regex needs, use `grep` directly.
