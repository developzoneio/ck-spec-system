# Tasks - FEAT-todo-priority

Spec: `.specs/FEAT-todo-priority/00-spec.md` | Plan: `.specs/FEAT-todo-priority/01-plan.md`

All paths are relative to `examples/fixture-project/`. Test command: `npm test`
(`commands.test`, `.claude/project-config.json:41`). Design decisions D1-D3 referenced below live
in `01-plan.md`.

---

## Phase 1 - Foundation

### T01 - Add InvalidPriorityError and validatePriority to the Domain

- **Files**: src/domain/todo.js
- **Layer**: Domain
- **Step type**: foundation
- **Test**: tests/todo.test.js (existing 4 tests must stay green; new tests land in T03)
- **Acceptance**:
  - `src/domain/todo.js` exports `class InvalidPriorityError extends Error` whose constructor sets
    `this.name = 'InvalidPriorityError'` and builds its message from the offending value, exactly as
    `InvalidTitleError` does.
  - `src/domain/todo.js` exports `function validatePriority(priority)` that is **void-throwing**
    (D1): it returns nothing for each of `'low'`, `'medium'`, `'high'`, and throws
    `InvalidPriorityError` for every other value **including `undefined` and `null`**. It must not
    apply, return, or know about the default - `createTodo` owns that (T02).
  - Two **unexported** module-private constants are added, mirroring `MAX_TITLE_LENGTH`
    (`src/domain/todo.js:8`) in both placement and SCREAMING_SNAKE naming:
    `ALLOWED_PRIORITIES` (the set `'low'`, `'medium'`, `'high'`) and `DEFAULT_PRIORITY`
    (`'medium'`). Use those exact names - T02 references them. Neither appears in an `export`
    statement (D3).
  - `createTodo` and `completeTodo` are left unchanged in this task.
  - Observable check 1: `npm test` passes with all 8 existing tests unedited.
  - Observable check 2, run from `examples/fixture-project/`:
    `node --input-type=module -e "import { validatePriority, InvalidPriorityError } from './src/domain/todo.js'; validatePriority('high'); try { validatePriority('urgent'); } catch (e) { console.log(e.name, e instanceof InvalidPriorityError); }"`
    prints `InvalidPriorityError true` and exits 0 (the `validatePriority('high')` call must not
    throw). If this one-liner cannot run for tooling reasons (shell quoting, or Node `--eval`
    relative-specifier resolution), accept T01 on inspection instead - both symbols present in
    `export` statements, neither constant exported, `npm test` green - and do **not** spend time
    debugging the one-liner.
- **Covers**: AC-3
- **Depends on**: none
- **Conflicts with**: none
- **Estimated complexity**: S
- **Reversibility**: trivial
- **Pattern refs**:
  - `src/domain/todo.js:1-6` - `InvalidTitleError`: mirror this class shape exactly (extends `Error`,
    `super(...)` with the offending value via `JSON.stringify`, `this.name` assigned in the
    constructor). Place the new class next to it.
  - `src/domain/todo.js:8` - `MAX_TITLE_LENGTH`: mirror this as the precedent for a module-private,
    unexported constant backing a validation rule. Do not export the new constants.
  - `src/domain/todo.js:10-17` - `validateTitle`: mirror the validator contract - takes the raw
    value, throws its own error class, returns nothing. Do not return a value.


---

## Phase 2 - Behavior

### T02 - Accept, default and validate priority in createTodo

- **Files**: src/domain/todo.js
- **Layer**: Domain
- **Step type**: behavior
- **Test**: tests/todo.test.js
- **Acceptance**:
  - `createTodo({ id, title, priority })` returns `{ id, title, done: false, priority }` and returns
    the given value for each of `'low'`, `'medium'`, `'high'` (AC-1).
  - The default is applied as a **destructuring default** in the parameter list -
    `{ id, title, priority = DEFAULT_PRIORITY }` (D1). `??` and `||` are forbidden
    here: both would default `null` (and `||` would also default `''`), which AC-2 requires to
    throw. Both `createTodo({ id, title })` and `createTodo({ id, title, priority: undefined })`
    yield `priority: 'medium'`; `null`, `''`, `'HIGH'`, `'urgent'` and `42` all throw
    `InvalidPriorityError` (AC-2).
  - Call order inside the body is `validateTitle(title)` **first**, then
    `validatePriority(priority)`, so an invalid title beats an invalid priority (AC-6).
  - `completeTodo` is not modified - its spread already carries the new field
    (`03-decisions.md:76-81`).
  - `npm test` passes with all 8 existing tests unedited.
- **Covers**: SC-1, SC-2, SC-3, SC-5, AC-1, AC-2, AC-6
- **Depends on**: T01
- **Conflicts with**: none
- **Estimated complexity**: S
- **Reversibility**: trivial
- **Pattern refs**:
  - `src/domain/todo.js:19-22` - the current `createTodo`: mirror its validate-then-construct
    shape; the new validator call is appended after `validateTitle`, and the returned object keeps
    its plain-literal form with `priority` added as the last field.


### T03 - Add Domain unit tests for the priority field

- **Files**: tests/todo.test.js
- **Layer**: Tests
- **Step type**: test
- **Test**: tests/todo.test.js
- **Acceptance**:
  - Tests are **appended**; the four existing tests (`tests/todo.test.js:5,12,16,23`) are not
    edited, reordered or deleted.
  - New tests cover: `createTodo` returns the given priority for each of `'low'`, `'medium'`,
    `'high'` (SC-1/AC-1); `createTodo({ id, title })` and an explicit `priority: undefined` both
    yield `'medium'` (SC-2/AC-2); each of `'urgent'`, `'HIGH'`, `''`, `null`, `42` throws
    `InvalidPriorityError` via `assert.throws` (SC-3/AC-2); an invalid title with an
    also-invalid priority throws `InvalidTitleError` (SC-5/AC-6); and at least one **direct** call to
    `validatePriority` - one accepting case and one throwing case (AC-3).
  - `InvalidPriorityError` and `validatePriority` are added to the existing import statement at
    `tests/todo.test.js:3` rather than a second import of the same module.
  - Assertions use string literals (`'high'`), never an imported vocabulary constant - the
    vocabulary stays module-private (D3).
  - `npm test` passes; total test count increases and no existing test is reported as failing.
- **Covers**: SC-1, SC-2, SC-3, SC-5, AC-1, AC-2, AC-3, AC-6, AC-7
- **Depends on**: T02
- **Conflicts with**: none
- **Estimated complexity**: M
- **Reversibility**: trivial
- **Pattern refs**:
  - `tests/todo.test.js:5-25` - mirror the file's test style: `test('<lowercase sentence>', () => {
    ... })`, one behavior per test, `assert.equal` for values and
    `assert.throws(() => ..., ErrorClass)` for failures.
  - `tests/todo.test.js:1-3` - mirror the import header (`node:test`, `node:assert/strict`, one
    import from `../src/domain/todo.js`); extend the third line, do not add a fourth import.


---

## Phase 3 - Wiring

### T04 - Forward the priority through TodoService.addTodo

- **Files**: src/application/todo-service.js
- **Layer**: Application
- **Step type**: wiring
- **Test**: tests/todo-service.test.js
- **Acceptance**:
  - `addTodo(title, priority)` takes the priority as a **second positional parameter** (the Gate 1
    decision, `00-spec.md:119-123`) and passes it straight into
    `createTodo({ id, title, priority })`.
  - The Application layer neither defaults nor validates (D2): after this task
    `src/application/todo-service.js` contains **no priority string literal** - no `'medium'`, no
    `= 'medium'` parameter default, no membership check. When the caller omits the argument,
    `priority` is `undefined` and Domain's destructuring default produces `'medium'`.
  - `addTodo('Buy milk')` still works with one argument; the `nextId()` -> `createTodo` -> `save`
    sequence and the constructor-injected `#store` are unchanged.
  - No new import is added to this file, and no Domain error class is re-exported from it (R7).
  - `npm test` passes with the four existing tests in `tests/todo-service.test.js` unedited.
- **Covers**: SC-1, SC-2, AC-4
- **Depends on**: T02, T03
- **Conflicts with**: none
- **Estimated complexity**: S
- **Reversibility**: trivial
- **Pattern refs**:
  - `src/application/todo-service.js:17-21` - the current `addTodo`: mirror its exact three-step
    body (`nextId` -> `createTodo` -> `store.save`); only the signature and the `createTodo`
    argument object change.
  - `src/domain/todo.js:19` - the `createTodo` signature this call must satisfy after T02: pass a
    plain object literal with `priority`, never a positional third argument.


### T05 - Add integration tests through TodoService

- **Files**: tests/todo-service.test.js
- **Layer**: Tests
- **Step type**: test
- **Test**: tests/todo-service.test.js
- **Acceptance**:
  - Tests are **appended**; the four existing tests (`tests/todo-service.test.js:10,18,25,30`) are
    not edited, reordered or deleted (AC-4).
  - New tests cover the Domain/Application crossing (AC-7): `addTodo('Buy milk', 'high')` returns a
    todo with `priority: 'high'` and `listTodos()` returns that same priority (SC-1);
    `addTodo('Buy milk')` yields `priority: 'medium'` (SC-2); completing a stored `'high'` todo
    returns `done: true` with `priority: 'high'` still present (SC-4/AC-5); and
    `addTodo('Buy milk', 'urgent')` throws `InvalidPriorityError` with
    `service.listTodos().length === 0` afterwards (SC-3).
  - The rejected-add test asserts **only** that nothing was stored
    (`listTodos().length === 0`). It must **not** assert anything about the id sequence: `addTodo`
    calls `nextId()` before validation, so a rejected add already consumes an id today, and that
    behavior is explicitly out of scope (`00-spec.md:105-108`).
  - `InvalidPriorityError` is imported **directly** from `../src/domain/todo.js` in this test file -
    the same way `InMemoryStore` is already imported from Infrastructure at
    `tests/todo-service.test.js:4`. Do not re-export it from `src/application/todo-service.js` (R7).
  - New tests reuse the existing `makeService()` helper; no test constructs `new TodoService(...)`
    inline.
  - `npm test` passes (AC-7).
- **Covers**: SC-1, SC-2, SC-3, SC-4, AC-4, AC-5, AC-7
- **Depends on**: T04
- **Conflicts with**: none
- **Estimated complexity**: M
- **Reversibility**: trivial
- **Pattern refs**:
  - `tests/todo-service.test.js:6-16` - mirror the `makeService()` + arrange/act/assert shape and
    reuse the helper; do not duplicate it.
  - `tests/todo-service.test.js:25-28` - mirror this error-path test's use of
    `assert.throws(() => service...., ErrorClass)` for the rejected-priority case.
  - `tests/todo-service.test.js:3-4` - mirror the import header; add the Domain error import as a
    separate line alongside the existing Infrastructure import.


---

## Phase 4 - Polish

### T06 - Refresh the two constitution example shapes

- **Files**: .specs/constitution.md
- **Layer**: Config
- **Step type**: polish
- **Test**: none - documentation edit; verified by diff inspection, plus `npm test` unchanged
- **Acceptance**:
  - `.specs/constitution.md:23` (§1.1 "Cross-layer data") and `.specs/constitution.md:141`
    (§7 "Aggregate root") read `{ id, title, done, priority }` instead of `{ id, title, done }`
    (AC-9).
  - The edit is an **in-place literal replacement**: `git diff -- .specs/constitution.md` shows
    exactly **two** changed lines and no others. No rule text is reworded, no line is added or
    removed, and the file's `version`, `last_reviewed` and §8 Changelog table are untouched - this
    is an example refresh, not a constitution amendment.
  - `.specs/constitution.md:31` (§1.2 "Mapping") and `.specs/constitution.md:143` (§7 "DTO") are
    **byte-identical** to their pre-task state - they are explicitly out of scope
    (`00-spec.md:109-113`). In-place replacement keeps all line numbers stable, so both can be
    checked at those exact lines after the edit.
  - `git status` at this point shows exactly five modified files: `src/domain/todo.js`,
    `src/application/todo-service.js`, `tests/todo.test.js`, `tests/todo-service.test.js`,
    `.specs/constitution.md`. `src/infrastructure/store.js` and `src/demo.js` are unmodified (AC-8).
  - `npm test` still passes (this task changes no code).
  - `.specs/constitution.md` is in `paths.protected`
    (`.claude/project-config.json:57-61`); this specific edit is **pre-authorized** by the Gate 1
    exception recorded at `00-spec.md:151-163`. `hooks.specGate.mode` is `"warn"` in this fixture,
    so the guard logs and does not block - proceed, do not stall or request an override.
- **Covers**: AC-8, AC-9
- **Depends on**: T01, T02, T03, T04, T05
- **Conflicts with**: none
- **Estimated complexity**: S
- **Reversibility**: trivial
- **Pattern refs**: none

