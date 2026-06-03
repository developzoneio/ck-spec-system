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
   - Status of each phase artifact: which of `00-spec.md`, `01-plan.md`, `02-tasks.md`, `03-decisions.md`, `04-artifacts/`, `05-retro.md` exist.
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

3. Illegal transitions REFUSED with explanation. E.g. `draft -> done` is rejected.
4. On valid transition:
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
1. Verify both spec folders exist.
2. Validate relation is in the allow-list.
3. Update both specs:
   - In `00-spec.md` "Linked specs" section of ID-A: add line `<relation>: <ID-B>`.
   - In ID-B add the inverse: `<inverse-relation>: <ID-A>`.
4. Inverse map:

| Relation | Inverse |
|---|---|
| `depends-on` | `blocks` (other side has `blocked-by`) |
| `spawns` | `spawned-by` |
| `supersedes` | `superseded-by` |
| `related-to` | `related-to` (symmetric) |
| `duplicate-of` | `duplicate-of` (symmetric) |

5. Append a log line to both retros.

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
1. For each target spec:
   - Frontmatter present and parseable.
   - Required fields per type: `id`, `type`, `status`, `created`. Bugs need `severity`. RCAs need `incident_started`.
   - `id` field matches the folder name.
   - `type` matches the prefix.
   - `status` is in `spec.lifecycle` from project-config.
   - Expected files present per status:
     - status >= `approved` -> `00-spec.md` must NOT have "<<placeholder>>" tokens remaining.
     - status >= `in-progress` -> `01-plan.md` and `02-tasks.md` exist (except RCA).
     - status == `done` -> `05-retro.md` exists with at least one entry.
   - Index row matches frontmatter status.
2. Output: one line per spec with PASS / FAIL and the first failure reason.

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
