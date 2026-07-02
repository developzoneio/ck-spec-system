---
description: Spec-driven feature workflow. Spec -> impact -> plan -> execute -> batch review -> close. 3 hard gates.
argument-hint: <JIRA-ID or slug>
---

# /sd:feature

Drives a feature from a one-line ask to closed-out, reviewed, tested code with searchable spec artifacts under `.specs/FEAT-<arg>/`.

**Argument**: `$ARGUMENTS` -> spec ID = `FEAT-<arg>` (e.g. `FEAT-INV-2501`, `FEAT-low-stock-webhook`).

---

## State machine (resume behavior)

On re-invocation with the same `<arg>`, detect the current state of `.specs/FEAT-<arg>/` and jump to the next phase. Never restart a phase that already passed its gate.

| Condition | State | Action |
|---|---|---|
| No `.specs/FEAT-<arg>/` dir | `not-found` | Start Phase 1 |
| `00-spec.md` exists, status=`draft` | `draft` | Present spec for Gate 1 |
| status=`approved`, no `02-tasks.md` | `approved` | Start Phase 3 |
| `02-tasks.md` exists, unchecked tasks remain | `in-progress` | Resume Phase 4 at next unchecked task |
| All tasks checked, no integration pass | `tasks-complete` | Start Phase 5 |
| status=`done` | `done` | Print summary, exit |
| status=`archived` | `archived` | Print archived notice, exit |

---

## Phase 0 - Bootstrap (always runs)

1. Read `CLAUDE.md` at project root.
2. Read `.specs/constitution.md`.
3. Read `.claude/project-config.json` (for `commands.*`, `spec.*`, `ticket.*`, `workflow.*`).
4. Read `.specs/index.md` for existing spec states.
5. Determine state from table above.

---

## Phase 1 - Spec

1. If `ticket.system == "jira"` and `<arg>` matches `ticket.pattern`, fetch ticket via `mcp__atlassian__getJiraIssue`. If MCP unavailable, ask user for a paste or proceed with slug.
2. Invoke `sd-spec-architect` with:
   - `TASK = create`
   - `TEMPLATE = feature.template.md`
   - `TICKET_CONTEXT = <fetched or pasted>`
   - `SPEC_ID = FEAT-<arg>`
3. Spec-architect produces `.specs/FEAT-<arg>/00-spec.md` with: Why (business value), What (Given/When/Then), Success criteria, Out of scope, Open questions, Constitution check, Linked specs.
4. If a ticket was fetched, spec-architect also snapshots it (ticket content + related tickets + linked Confluence pages, per its Ticket snapshot protocol) to `.specs/FEAT-<arg>/04-artifacts/ticket/`.
5. Register in `.specs/index.md` with status=`draft`.

### ⛔ Gate 1 - Spec approval

STOP. Present the spec to the user. Ask:

> Approve spec FEAT-<arg>? (yes / refine <feedback> / abort)

- `yes` -> set status=`approved`, proceed.
- `refine` -> invoke `sd-spec-architect` with `TASK = refine`, `SPEC = .specs/FEAT-<arg>/00-spec.md`, `FEEDBACK = <user feedback>`. Loop.
- `abort` -> set status=`archived`, exit.

---

## Phase 2 - Impact analysis

1. Invoke `sd-code-explorer` with:
   - `TASK = impact-map`
   - `SPEC = .specs/FEAT-<arg>/00-spec.md`
   - `OUTPUT_APPEND_TO = .specs/FEAT-<arg>/03-decisions.md`
2. Explorer produces: direct callers (1-hop), transitive (2-3 hop), test coverage scan, DI/config grep, public API surface, risk assessment.
3. All findings cite `file:line`.

No gate here - impact analysis is informational. User reviews it in Phase 3.

---

## Phase 3 - Plan + tasks

1. Invoke `sd-spec-architect` with:
   - `TASK = plan`
   - `SPEC = .specs/FEAT-<arg>/00-spec.md`
   - `IMPACT = .specs/FEAT-<arg>/03-decisions.md`
2. Spec-architect produces:
   - `.specs/FEAT-<arg>/01-plan.md` (approach, alternatives considered, rationale).
   - `.specs/FEAT-<arg>/02-tasks.md` with atomic tasks, each having:

```
### T<NN> - <title>
- Files: <list of files to touch>
- Layer: <Domain | Application | Infrastructure | Presentation>
- Step type: <foundation | behavior | wiring | polish | test>
- Test: <test file/method to create or update>
- Acceptance: <one-line criterion>
- Depends on: <T## or "none">
- Conflicts with: <T## or "none">
- Complexity: <S | M | L>
- Reversibility: <trivial | moderate | hard>
- Pattern refs: <1-3 file:line precedent citations + what to mirror, or "none">
```

3. Set status=`in-progress` in `00-spec.md` and `index.md`.

### ⛔ Gate 2 - Plan approval

STOP. Present the plan and task list. Ask:

> Approve plan for FEAT-<arg>? (<N> tasks, estimated <complexity>) (yes / refine <feedback> / abort)

- `yes` -> proceed.
- `refine` -> invoke `sd-spec-architect` with `TASK = refine`, `SPEC = .specs/FEAT-<arg>/00-spec.md`, `FEEDBACK = <user feedback>`. Loop.
- `abort` -> set status=`archived`, exit.

---

## Phase 4 - Execute (no per-task reviewer)

Process tasks from `02-tasks.md` in dependency order.

For each unchecked task:

1. **Pre-flight**: re-read `00-spec.md`, the specific task block, and the constitution sections cited under the spec's "Constitution check".
2. **Invoke `sd-implementer`** with:
   - `TASK_DETAILS = <full task block>`
   - `SPEC_REF = .specs/FEAT-<arg>/00-spec.md`
   - `IMPACT_REF = .specs/FEAT-<arg>/03-decisions.md`
   - `WORKFLOW_TYPE = feature`
3. Implementer edits only files in `Files`. Writes a test if `Test` references a non-existent test file.
4. **Run the task's test** in isolation via `commands.test` from project-config (scoped to the new test if possible).
5. **Self-check** (main thread, NO reviewer subagent):
   - Did implementer stay within `Files` list? If not -> revert, re-invoke.
   - Does the test pass? If not -> re-invoke implementer with failure output.
   - Any obvious constitution violation visible from the diff? If yes -> re-invoke with feedback.
6. **Check off** the task in `02-tasks.md`.
7. Log a one-line summary to `.specs/FEAT-<arg>/05-retro.md`: `T<NN>: <status> - <note>`.

> **Why no per-task reviewer?** Each reviewer invocation spawns a sonnet-class subagent that reloads the full context (CLAUDE.md + constitution + spec + changed files). For N tasks, that is N expensive calls. The main thread self-check catches scope violations and test failures. Constitution compliance and cross-task issues are caught more efficiently by the batch review in Phase 5.

Move to next task. Repeat until all tasks checked.

---

## Phase 5 - Integration + batch review

### 5a. Integration tests

1. Run the full test suite via `commands.test` from project-config.
2. Run lint via `commands.lint`.
3. If either fails, diagnose inline. If the fix is trivial (import, typo), apply directly. If non-trivial, route back through Phase 4 as a new task (append to `02-tasks.md`, spec the diagnosis under `03-decisions.md`).

### 5b. Batch review (single reviewer invocation for ALL changes)

Invoke `sd-reviewer` with:
   - `TASK_TYPE = holistic`
   - `CHANGED_FILES = <all files changed across all tasks in Phase 4>`
   - `SPEC_REF = .specs/FEAT-<arg>/00-spec.md`
   - `PLAN_REF = .specs/FEAT-<arg>/01-plan.md`

Reviewer checks ALL changes in one pass:
- Constitution compliance across the full changeset.
- Cross-task consistency (naming, patterns, DI wiring) and conformance to each task's `Pattern refs`.
- Scope creep detection (files not in any task's `Files` list).
- Test coverage adequacy.
- Public API surface changes.

### ⛔ Gate 3 - Integration + review pass

STOP. Display:
- Test + lint summary.
- Reviewer verdict counts (BLOCK / WARN / SUGGEST / PASS).

Ask:

> All clean for FEAT-<arg>? (yes / address findings / abort)

Treat findings:
- Any 🔴 BLOCK -> route back to implementer with finding as feedback. Re-run batch review after fix.
- Any 🟠 WARN -> ask user: address now or log to `05-retro.md` as follow-up?
- 🟡 SUGGEST and 🟢 PASS -> log to retro, proceed.

---

## Phase 6 - Close-out

1. Append to `.specs/FEAT-<arg>/05-retro.md`:
   - Tasks completed (count + IDs).
   - Surprises encountered.
   - Deferred follow-ups (with reserved spec IDs, if any).
   - Constitution exceptions taken (should be none).
   - Cost rough estimate if available.
2. Set frontmatter status=`done` in `00-spec.md`.
3. Update `.specs/index.md`: state -> `done`, completion date.
4. Print a 5-line summary to the user.

---

## Rules (hard constraints)

- Phase 0 always runs. No exceptions, even on resume.
- Gates 1-3 are HARD. The workflow refuses to proceed without explicit approval.
- Implementer touches only files declared in the task's `Files` list. Any scope creep -> stop, surface to main thread, log to retro.
- Reviewer is invoked ONCE in Phase 5b for the entire changeset (not per-task). This is a deliberate cost optimization.
- BLOCK findings from the batch review must be addressed before close-out.
- No new constitution exception introduced silently. If one is needed, spawn an ADR spec.
- If `ticket.system == "jira"` and `<arg>` looks like a JIRA ID, the ticket is fetched in Phase 1. If MCP is unavailable, ask user for paste or proceed with slug.
- All files under `.specs/FEAT-<arg>/` are written in UTF-8 with no BOM.