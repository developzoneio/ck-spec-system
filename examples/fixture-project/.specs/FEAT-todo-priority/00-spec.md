---
id: FEAT-todo-priority
type: feature
status: done
jira: none
created: 2026-07-31
complexity: M  # 2 production layers (Domain + Application) plus tests and one scoped constitution example edit, ~5 files, ~6-7 tasks; Infrastructure untouched
linked_specs: []
---

# Add a validated priority field to todos

## Why

A todo today carries no urgency signal at all - `{ id, title, done }` says what to do and whether
it is finished, but not whether it matters. Every caller that needs ordering has to keep that
information outside the library (a parallel map, a naming convention like `"[URGENT] ..."`, or a
wrapper object), which defeats the point of a shared todo entity and puts the urgency data outside
the reach of the library's own validation. Carrying a validated `priority` on the entity means one
source of truth, rejected at the boundary instead of silently accepted as a typo, and it costs one
optional argument at the only place a todo is born.

## What

### SC-1: Adding a todo with an explicit priority

- **Given** a `TodoService` backed by an empty store
- **When** a caller adds a todo titled `"Buy milk"` with priority `high`
- **Then** the returned todo is `{ id, title: 'Buy milk', done: false, priority: 'high' }`, and the
  same todo - carrying `priority: 'high'` - is what `listTodos()` subsequently returns

### SC-2: Adding a todo without a priority defaults to medium

- **Given** a `TodoService` backed by an empty store
- **When** a caller adds a todo titled `"Buy milk"` and supplies no priority at all
- **Then** the returned todo has `priority: 'medium'`, and every call shape that worked before this
  change still works unchanged (no caller is forced to pass a priority)

### SC-3: Rejecting a priority outside the allowed set

- **Given** a `TodoService` backed by an empty store
- **When** a caller adds a todo with a priority that is not one of `low`, `medium`, `high` - for
  example `'urgent'`, `'HIGH'`, `''`, `null`, or `42`
- **Then** an `InvalidPriorityError` is thrown from the Domain layer, no todo is stored, and
  `listTodos()` still returns an empty list

### SC-4: Completing a todo preserves its priority

- **Given** a stored todo with `priority: 'high'` and `done: false`
- **When** the caller completes it by id
- **Then** the returned todo has `done: true` and still has `priority: 'high'`; the original object
  is left untouched, as it is today

### SC-5: An invalid title still fails first

- **Given** a `TodoService` backed by an empty store
- **When** a caller adds a todo whose title is invalid (e.g. `'   '`) *and* whose priority is also
  invalid (e.g. `'urgent'`)
- **Then** an `InvalidTitleError` is thrown - the existing error contract for a bad title is not
  changed or masked by the new validation

## Success criteria

- [x] AC-1: `createTodo({ id, title, priority })` in `src/domain/todo.js` returns
      `{ id, title, done: false, priority }` for each of `'low'`, `'medium'`, `'high'`.
      Evidence: `src/domain/todo.js:35-38`; `tests/todo.test.js:27-32` ("createTodo accepts each
      allowed priority").
- [x] AC-2: The default fires **only** on an absent or `undefined` priority - both
      `createTodo({ id, title })` and an explicit `priority: undefined` yield `priority: 'medium'`.
      Every other value outside the allowed set, including `null`, `''`, `'HIGH'`, `'urgent'` and
      `42`, throws rather than defaulting.
      Evidence: `src/domain/todo.js:35` (destructuring default, not `??`/`||`);
      `tests/todo.test.js:34-46` ("defaults priority to medium when omitted or undefined",
      "rejects a priority outside the allowed set").
- [x] AC-3: `src/domain/todo.js` exports `validatePriority` and `InvalidPriorityError` (with
      `name === 'InvalidPriorityError'`), mirroring the existing `validateTitle` /
      `InvalidTitleError` pair, and `validatePriority` has at least one direct unit test.
      Evidence: `src/domain/todo.js:8-13,29-33`; `tests/todo.test.js:52-58` (direct
      accept/reject tests).
- [x] AC-4: A todo added through `TodoService` with a priority is stored and returned carrying that
      priority; the four existing tests in `tests/todo-service.test.js` are **not edited** and still
      pass. New tests for this feature are added to that same file (§2.4: test files mirror source
      layout).
      Evidence: `src/application/todo-service.js:17-21`; `tests/todo-service.test.js:37-42`;
      reviewer P5 (line-offset reconciliation confirming the 4 existing tests are unedited,
      `05-retro.md`).
- [x] AC-5: Completing a todo returns a todo whose `priority` equals the stored todo's priority
      (`completeTodo` is not allowed to drop the field).
      Evidence: `tests/todo-service.test.js:50-56` ("completeTodo preserves the priority of a
      stored todo").
- [x] AC-6: When both title and priority are invalid, `InvalidTitleError` is thrown - title
      validation runs before priority validation.
      Evidence: `src/domain/todo.js:36-37` (validateTitle before validatePriority);
      `tests/todo.test.js:48-50` ("rejects an invalid title even when the priority is also
      invalid").
- [x] AC-7: Unit + integration tests cover all scenarios above - Domain unit tests for SC-1, SC-2,
      SC-3 and SC-5, and at least one integration test through `TodoService` (SC-1, SC-2, SC-4)
      covering the Domain/Application crossing. `npm test` passes.
      Evidence: `npm test` - 18/18 pass (8 original + 6 Domain + 4 Application), confirmed after
      every task and again in Phase 5a.
- [x] AC-8: No constitution exception beyond the single Gate-1-approved one recorded under
      Constitution check (the §6 / mutation-protocol exception that authorizes AC-9). No other rule
      is bent. `src/infrastructure/store.js` is unmodified - the store is shape-agnostic and needs
      no change to carry the new field.
      Evidence: reviewer P7 - no scope creep, `src/infrastructure/store.js` and `src/demo.js`
      untouched, changeset is exactly the 5 declared files (`05-retro.md`).
- [x] AC-9: In `.specs/constitution.md`, the example shape in §1.1 "Cross-layer data" (line 23) and
      in §7 "Aggregate root" (line 141) reads `{ id, title, done, priority }` instead of
      `{ id, title, done }`. Exactly those two literals change: no rule text is reworded, no other
      occurrence is touched, and the file's `version`, `last_reviewed` and §8 Changelog table are
      deliberately left alone (this is an example refresh, not a constitution amendment).
      Evidence: `.specs/constitution.md:23,141`; reviewer P4 (verified exact lines, `:31`/`:143`
      byte-identical, frontmatter/§8 untouched).

## Out of scope

- Changing a todo's priority after creation - no `setPriority` / update path in this iteration.
  Priority is set once, when the todo is added.
- Sorting or filtering `listTodos()` by priority. The list order stays insertion order.
- Case-insensitive input, aliases, or numeric levels (`'HIGH'`, `'urgent'`, `1`/`2`/`3`). The
  accepted set is exactly the three lowercase strings; anything else is an error, not a hint.
- Exporting the priority vocabulary as a public constant. The allowed set stays module-private,
  mirroring the private `MAX_TITLE_LENGTH` (`src/domain/todo.js:8`); tests assert against literals,
  as the existing tests already do.
- Updating `src/demo.js` to display priority. The demo keeps its current output.
- Id-sequence gaps on rejected input. `TodoService.addTodo` calls `nextId()` before validation, so a
  rejected add already consumes an id today (`InvalidTitleError` behaves the same way). Priority
  validation inherits that behavior; changing it is a separate concern per §6 (the approved §6
  exception under Constitution check covers the AC-9 example refresh only, nothing else).
- The two *other* stale `{ id, title, done }` occurrences in `.specs/constitution.md`: §1.2
  "Mapping" (line 31) and the **DTO** bullet of §7 (line 143). The Gate 1 approval named exactly two
  literals - §1.1 "Cross-layer data" and §7 "Aggregate root" (AC-9) - so these two stay as they are.
  Note that the §7 DTO bullet sits in the same section as an approved one; if the user wants it
  included, widening AC-9 by one line at Gate 2 is enough, and no other part of this spec moves.

## Open questions

None - both questions were resolved by the user at Gate 1. Kept here as a decision record:

- **Resolved (Gate 1) - how the service accepts the priority.** Positional:
  `addTodo(title, priority)`, confirming the spec's stated default. It is a single scalar, it matches
  this fixture's deliberately minimal style, and it leaves `addTodo('Buy milk')` working untouched.
  The options-object alternative (`addTodo(title, { priority })`) was considered and declined; both
  keep existing call sites valid, so this was a style/longevity call, not a compatibility one.
- **Resolved (Gate 1) - the constitution's example shapes are refreshed as part of this spec.** Not
  deferred to a separate ADR, which was the spec's original default. The refresh is now in scope and
  checkable as AC-9, and the exception that permits it is recorded under Constitution check. Its
  boundary is narrow on purpose: two example literals (§1.1 "Cross-layer data", §7 "Aggregate root"),
  no rule text, no other occurrence - see Out of scope for the two occurrences left untouched.

## Constitution check

- **§1.1 Layer rules**: respected. Validation and the entity shape change stay in Domain
  (`src/domain/todo.js`); Application (`src/application/todo-service.js`) only passes the caller's
  value through to `createTodo` and keeps receiving its store by constructor injection. Nothing new
  is imported in either direction, and Infrastructure is untouched - `save`/`get`/`list`/`update`
  are shape-agnostic. The cross-layer payload stays a plain object literal, gaining one string
  field: `{ id, title, done, priority }`.
- **§2.3 Error handling**: one new custom error class, `InvalidPriorityError` (Domain), introduced
  as a sibling of the existing `InvalidTitleError` - one class per failure mode, no bare
  `throw new Error(...)` for this expected failure, and no catch-and-swallow anywhere on the path.
  `InvalidTitleError` and `TodoNotFoundError` are reused as-is; SC-5 exists specifically to prove
  the existing title contract is not masked.
- **§3 Quality bars**: this change crosses the Domain/Application boundary, so an integration test
  through `TodoService` is **mandatory, not discretionary** (AC-7). The new exported Domain function
  `validatePriority` needs its own direct test to satisfy "every exported Domain/Application
  function has >= 1 passing test" (AC-3); the modified `createTodo`, `completeTodo` and
  `TodoService.addTodo` keep their existing tests and gain priority assertions.
- **§1.2 Pattern rules (Validation)**: `validatePriority` lives in Domain alongside `validateTitle` -
  never in Infrastructure and never inline in a test file. The Application layer performs no
  validation of its own; it forwards the value and lets Domain reject it.
- **§6 Forbidden patterns - one explicitly approved exception**: this spec carries a small, scoped
  exception to §6's "no opportunistic refactor inside a feature/bug spec" caution. At Gate 1 the user
  approved refreshing exactly the two stale example shapes - §1.1 "Cross-layer data" and §7
  "Aggregate root" - from `{ id, title, done }` to `{ id, title, done, priority }` as part of this
  spec's work (AC-9). The exception is bounded three ways, and all three matter downstream:
  - **Scope**: the literal example text only. Not a rule change, not a reworded bullet, not a
    broader constitution edit, and not a `version` / `last_reviewed` / §8 Changelog amendment.
  - **Mutation protocol** (constitution line 14: changes require a `/sd:refactor` spec or an ADR -
    "Never edit silently"): a feature spec is not on that list, so the user's express Gate 1
    approval is what authorizes this edit. It is recorded here precisely so it is not silent.
  - **Protected path**: `.specs/constitution.md` is listed in `paths.protected` in
    `project-config.json`. The same Gate 1 approval covers this specific protected-path edit; the
    Phase 4 implementer should treat AC-9 as pre-authorized rather than stalling on the guard.
- **Risk of violation**: **low**. The change is architecturally clean - Domain owns the validation,
  Application only forwards, Infrastructure is untouched. The one deviation is documentary and
  deliberate: a single narrowly-scoped example refresh in the constitution, made under express Gate 1
  authorization and recorded above, rather than an opportunistic edit. No constitution gap identified
  - the existing rules cover this change cleanly.
