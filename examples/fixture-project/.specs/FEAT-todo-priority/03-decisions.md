# Impact analysis - FEAT-todo-priority

(Produced by `sd-code-explorer`, `TASK = impact-map`, against `examples/fixture-project/`. All
paths below are relative to `examples/fixture-project/`.)

GitNexus is disabled (`mcp.gitnexus.enabled: false` at `.claude/project-config.json:103-106`), so
this is a grep/Read-only analysis. No dynamic-dispatch call sites were observed in this fixture -
all calls are static ES-module imports - so the call graph below is exhaustive at this depth.

## Direct callers (1-hop)

- `src/application/todo-service.js:1` - `import { createTodo, completeTodo }` -> `src/domain/todo.js`
- `src/application/todo-service.js:19` - `TodoService.addTodo` calls `createTodo({ id, title })` -> `src/domain/todo.js:19`
- `src/application/todo-service.js:28` - `TodoService.completeTodo` calls `completeTodo(todo)` -> `src/domain/todo.js:25`
- `tests/todo.test.js:3` - imports `createTodo, completeTodo, validateTitle, InvalidTitleError` -> `src/domain/todo.js`
- `tests/todo.test.js:6,13,17,18,24` - direct unit calls into `src/domain/todo.js` exports
- `tests/todo-service.test.js:3` - imports `TodoService, TodoNotFoundError` -> `src/application/todo-service.js`
- `tests/todo-service.test.js:12,20,21,27,32,33` - direct calls into `TodoService.addTodo` / `.completeTodo`
- `src/demo.js:1` - imports `TodoService` -> `src/application/todo-service.js`
- `src/demo.js:6,7,10,12,13` - calls `service.addTodo`, `service.completeTodo`, `service.listTodos`

## Transitive callers (2-3 hop)

- `src/demo.js:6` -> `TodoService.addTodo` (`src/application/todo-service.js:17`) -> `createTodo` (`src/domain/todo.js:19`) -> `validateTitle` (`src/domain/todo.js:10`)
- `src/demo.js:10` -> `TodoService.completeTodo` (`src/application/todo-service.js:23`) -> `completeTodo` (`src/domain/todo.js:25`)
- `tests/todo-service.test.js:12` -> `TodoService.addTodo` -> `createTodo` -> `validateTitle`
- `tests/todo-service.test.js:20-21` -> `TodoService.completeTodo` -> `completeTodo` -> spread of stored todo

Full call graph is exhausted at this depth - the entire `.js` file set in this fixture is
`src/infrastructure/store.js`, `src/demo.js`, `src/domain/todo.js`, `src/application/todo-service.js`,
`tests/todo.test.js`, `tests/todo-service.test.js` (confirmed via glob of `**/*.js`; no other
consumer exists anywhere in the fixture).

## Test coverage scan

- `src/domain/todo.js` -> `tests/todo.test.js` (4 existing tests: `tests/todo.test.js:5,12,16,23`)
- `src/application/todo-service.js` -> `tests/todo-service.test.js` (4 existing tests:
  `tests/todo-service.test.js:10,18,25,30` - matches AC-4's claim of "four existing tests")
- `src/infrastructure/store.js` - no direct test file found (gap; out of target scope per spec
  AC-8, listed here only for completeness - store is unmodified by this spec)
- `src/demo.js` - no direct test file (`.specs/constitution.md:32` explicitly exempts it as a CLI
  demo entry point, not library code; out of target scope)

## DI / config grep

- No DI container in this fixture. Constructor injection: `TodoService` constructor takes `store`
  at `src/application/todo-service.js:13`; wired at `src/demo.js:4`
  (`new TodoService(new InMemoryStore())`) and at `tests/todo-service.test.js:7`
  (`makeService()` helper).
- Config keys referencing target scope:
  - `.claude/project-config.json:51-55` - `paths.layers` declares `domain` -> `src/domain`,
    `application` -> `src/application`, `infrastructure` -> `src/infrastructure` (backs the
    dependency-direction rule the spec cites in Constitution check).
  - `.claude/project-config.json:57-61` - `paths.protected` lists `.specs/constitution.md` -
    load-bearing for AC-9, since the spec's Constitution-check section (`00-spec.md:161-163`)
    relies on this exact list to justify the protected-path edit.

## Public API surface

- `src/domain/todo.js:1` - `export class InvalidTitleError extends Error`
- `src/domain/todo.js:10` - `export function validateTitle(title)`
- `src/domain/todo.js:19` - `export function createTodo({ id, title })` (target of AC-1/AC-2 destructuring change)
- `src/domain/todo.js:25` - `export function completeTodo(todo)` (spread-based, see Risk note below)
- `src/domain/todo.js:8` - `const MAX_TITLE_LENGTH = 200;` - module-private, not exported (precedent
  for spec's "priority vocabulary stays module-private" out-of-scope item, `00-spec.md:101-103`)
- `src/application/todo-service.js:3` - `export class TodoNotFoundError extends Error`
- `src/application/todo-service.js:10` - `export class TodoService` with public methods
  `addTodo(title)` (`:17`), `completeTodo(id)` (`:23`), `listTodos()` (`:31`)
- Consumers external to target scope (`src/domain/`, `src/application/`): `src/demo.js:1,6,7,10,12`,
  `tests/todo.test.js:3`, `tests/todo-service.test.js:3`

## Risk assessment

**Low risk, mechanically confirmable:**

- AC-5 (completing a todo preserves priority) - `completeTodo` at `src/domain/todo.js:25` is
  `{ ...todo, done: true }`, a spread that already carries through any field present on the input
  object, including a future `priority`. `TodoService.completeTodo`
  (`src/application/todo-service.js:23-29`) passes the stored object straight into `completeTodo`
  without touching its shape. Both call sites have existing tests (`tests/todo.test.js:16`,
  `tests/todo-service.test.js:18`).
- AC-8 ("store is shape-agnostic, needs no change") - `src/infrastructure/store.js:9-12` (`save`)
  and `:22-28` (`update`) key exclusively on `todo.id`; neither method reads or writes any other
  field. `get`/`list` (`:14-20`) likewise pass whole objects through untouched.

**Medium risk, requires implementation care:**

- AC-2's discriminating constraint: `createTodo({ id, title })` at `src/domain/todo.js:19` must
  default on absent-or-`undefined` priority but throw on `null`, `''`, `'HIGH'`, `42`. This
  constrains how the new parameter is destructured/defaulted at that call site; no signature is
  prescribed here.
- AC-6 (title validation must run before priority validation) - ordering constraint inside
  `createTodo` (`src/domain/todo.js:19-22`), currently a two-line body (`validateTitle(title)`
  then object construction); adding a second validation call changes execution order, which
  SC-5/AC-6 explicitly test for.

**Out of scope, noted only, no action implied:** `src/infrastructure/store.js:24` throws a bare
`new Error(...)` for "Cannot update unknown todo" - this is a pre-existing bare-`Error` throw that
constitution `§2.3`/`§6` forbid for expected failures (`.specs/constitution.md:49-50,133`). It
predates this spec, is not touched by AC-1..AC-9, and is flagged here only as an existing
condition in a file this spec's Constitution check asserts is "unmodified" (`00-spec.md:86`).

## Precedents & conventions

- Nearest similar implementations (precedent for the new `validatePriority` / `InvalidPriorityError` pair):
  - `src/domain/todo.js:1-17` - the `InvalidTitleError` class + `validateTitle` function + module-private
    `MAX_TITLE_LENGTH` constant is the direct structural precedent: one error class per failure mode,
    a validator function that throws that class, a module-private constant backing the validation rule.
  - `src/application/todo-service.js:3-8` - `TodoNotFoundError` is the second instance of the
    "one custom error class per failure mode" pattern, confirming it is a repo-wide convention and
    not a one-off in `todo.js`.
- Conventions observed (sampling is degenerate here - `src/domain/` and `src/application/` each
  contain exactly one file, so "sampling 3 siblings" reduces to reading that one file each; stated
  explicitly rather than inferred from more examples):
  - File naming: one exported concept per file, filename mirrors the export
    (`todo-service.js` -> `TodoService`) - evidence: `src/application/todo-service.js:10`.
  - Symbol naming: error classes suffixed `Error` and set `this.name` in the constructor -
    evidence: `src/domain/todo.js:1-6`, `src/application/todo-service.js:3-8`.
  - Test placement: `src/domain/todo.js` -> `tests/todo.test.js`; `src/application/todo-service.js`
    -> `tests/todo-service.test.js` - a 1:1 file mirror, matching `.specs/constitution.md:55` verbatim.
- Existing utilities relevant to spec scope:
  - `src/domain/todo.js:8` - `MAX_TITLE_LENGTH` - direct precedent for keeping the priority
    vocabulary (`'low'|'medium'|'high'`) as an unexported module-private constant, per the spec's
    own out-of-scope item (`00-spec.md:101-103`).

## Constitution line-number claims (verified, since AC-9/out-of-scope hinge on exact lines)

- `.specs/constitution.md:23` - `§1.1 Cross-layer data` bullet reads `{ id, title, done }` -
  confirmed, this is an AC-9 target.
- `.specs/constitution.md:141` - `§7 Aggregate root` bullet reads `{ id, title, done }` -
  confirmed, this is an AC-9 target.
- `.specs/constitution.md:31` - `§1.2 Mapping` bullet reads `{ id, title, done }` - confirmed,
  this is the "Out of scope" item, left untouched.
- `.specs/constitution.md:143` - `§7 DTO` bullet reads `{ id, title, done }` - confirmed, this is
  the second "Out of scope" item, left untouched.
- `.claude/project-config.json:57-61` - `paths.protected` includes `.specs/constitution.md` -
  confirmed, this is what makes AC-9 a protected-path edit requiring the Gate-1 exception the
  spec records.
