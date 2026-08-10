# Retro - FEAT-todo-priority

## Status log

- [2026-07-31T15:30:00Z] Status: draft -> approved. Reason: Gate 1 spec approval. Both open
  questions resolved by the user: addTodo(title, priority) confirmed positional; constitution
  §1.1/§7 "Aggregate root" example refresh (AC-9) approved in-scope (kept to the two named
  occurrences - §1.2 "Mapping" and the §7 "DTO" bullet stay as-is per the user's explicit choice).
- [2026-07-31T15:50:00Z] Status: approved -> in-progress. Reason: Gate 2 plan approval - 6 tasks
  (T01-T06), complexity M, measured under threshold on all 4 decompose criteria (tasks, layers,
  impact surface, open questions). Face A normal approval, no decompose proposal.

## Task log

- T01: pass - `InvalidPriorityError` + void-throwing `validatePriority` + private
  `ALLOWED_PRIORITIES`/`DEFAULT_PRIORITY` added to `src/domain/todo.js`, mirroring
  `InvalidTitleError`/`validateTitle`. `npm test` green, 8/8 existing tests unedited.
- T02: pass - `createTodo` gained the destructuring-defaulted, validated `priority` field per D1;
  title validation still runs before priority validation (AC-6). `npm test` green, 8/8 existing
  tests unedited (T02 adds no tests of its own).
- T03: pass - 6 new tests appended to `tests/todo.test.js` covering SC-1/2/3/5 and AC-1/2/3/6
  (allowed priorities, default-on-omitted/undefined, rejection of `'urgent'`/`'HIGH'`/`''`/`null`/
  `42`, title-before-priority ordering, direct `validatePriority` accept/reject). `npm test`: 14/14
  pass, original 8 unedited.
- T04: pass - `TodoService.addTodo(title, priority)` forwards to `createTodo` per D2 (no priority
  literal, defaulting, or validation added in Application). `npm test`: 14/14 pass, unedited.
- T05: pass - 4 new tests appended to `tests/todo-service.test.js` covering SC-1/2/3/4 and
  AC-4/5/7 (explicit priority through the service, default-to-medium, priority survives
  `completeTodo`, invalid priority stores nothing - no id-sequence assertion, per scope). `npm
  test`: 18/18 pass, original 8 (4+4) unedited.
- T06: pass - `.specs/constitution.md` §1.1 (line 23) and §7 "Aggregate root" (line 141) refreshed
  from `{ id, title, done }` to `{ id, title, done, priority }`; §1.2 "Mapping" (line 31) and §7
  "DTO" (line 143) left byte-identical, per scope. `version`/`last_reviewed`/§8 untouched. `npm
  test`: 18/18 pass (no code changed by this task).

All 6 tasks (T01-T06) complete. All 18 tests pass.

## Integration + batch review (Phase 5)

- `npm test`: 18/18 pass. `commands.lint`: n/a (no linter configured for this fixture).
- `sd-reviewer` (holistic): **0 BLOCK, 0 WARN, 5 SUGGEST, 7 PASS.**
  - S1: §7 DTO bullet (`.specs/constitution.md:143`) is now inconsistent with the refreshed
    Aggregate-root bullet (`:141`) - the spec's own "widen AC-9 by one line" escape hatch expired
    at Gate 2. Deferred to close-out for a user decision (follow-up spec, ADR, or accept as-is).
  - S2: the constitution exception (AC-9) is recorded in this spec but has no ADR of its own, so
    provenance will not outlive this spec's eventual archival. Suggested: a short ADR under
    `.specs/_adr/`.
  - S3: `validatePriority` uses `== false` where sibling code uses `!`/`!==` - likely intentional
    (a global coding-standard convention), no action needed.
  - S4: explicit-priority tests check `priority` but not the full returned shape alongside it - a
    minor test-strengthening opportunity, not a coverage gap (the single unconditional return path
    is already pinned by the default-path tests).
  - S5: close-out prerequisites (`/sd:verify`, AC checkboxes) are not yet done - correctly Phase
    6's job, not a Phase 5 finding.

## Close-out (Phase 6)

- [2026-07-31T16:20:00Z] Status: in-progress -> done. Reason: Gate 3 passed clean (0 BLOCK,
  0 WARN); `/sd:verify FEAT-todo-priority` recorded `result: pass` (0 failures, all 5 SC and 9 AC
  traced to a task and a passing test or diff inspection).

**Tasks completed**: 6/6 (T01-T06).

**Surprises encountered**: the constitution's stale `{ id, title, done }` example shape appeared
in 4 places, not the 2 the user initially named at Gate 1 (`03-decisions.md`'s impact analysis
surfaced this before planning). Resolved by asking the user explicitly whether to widen scope;
they chose to keep it to the 2 originally approved. The reviewer's S1 finding shows this decision
has a real downstream cost (§7 now internally inconsistent between its Aggregate-root and DTO
bullets) - a legitimate deferred follow-up, not a mistake.

**Deferred follow-ups** (no spec ID reserved yet):
- S1/S2: the remaining 2 stale constitution occurrences (§1.2 Mapping, §7 DTO), and an ADR to
  record the Gate 1 §6 exception so its provenance outlives this spec's eventual archival.
- S4: strengthen the two explicit-priority tests to assert the full returned shape
  (`done: false` alongside `priority`), not just the priority field.
- Sorting/filtering by priority (already recorded as out of scope in `00-spec.md`).

**Constitution exceptions taken**: one, explicitly approved at Gate 1 and recorded in `00-spec.md`'s
Constitution check section - a scoped 2-line example refresh in `.specs/constitution.md` (a
protected path), authorized by the user rather than done silently.

**Cost note**: this spec was driven through the real `sd-spec-architect` / `sd-code-explorer` /
`sd-implementer` / `sd-reviewer` subagents (one `create`, one `refine`, one `impact-map`, one
`plan`, six `sd-implementer` task invocations, one `holistic` review - 10 subagent calls total),
not hand-authored. No token/dollar cost was tracked for this run.
