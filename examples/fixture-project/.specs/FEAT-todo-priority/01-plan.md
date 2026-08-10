# Implementation plan - FEAT-todo-priority

Spec: `.specs/FEAT-todo-priority/00-spec.md` (status `approved`, `complexity: M`)
Impact: `.specs/FEAT-todo-priority/03-decisions.md`
Tasks: `.specs/FEAT-todo-priority/02-tasks.md`

All paths in this file and in `02-tasks.md` are relative to `examples/fixture-project/`.
Test command is `npm test` (`commands.test`, `.claude/project-config.json:41`).

---

## Approach

The feature adds one optional string field to the todo entity. The whole change is: a validator
plus its error class in Domain, one defaulted destructuring parameter on `createTodo`, one
forwarded positional parameter on `TodoService.addTodo`, tests on both sides of the
Domain/Application boundary, and a two-literal example refresh in the constitution (AC-9).

Nothing else moves. `src/infrastructure/store.js` is shape-agnostic
(`03-decisions.md:82-84`: `save`/`update` key only on `todo.id`), and `completeTodo` is
`{ ...todo, done: true }` (`src/domain/todo.js:25`), a spread that already carries any field
present on the input. `src/demo.js` is out of scope per the spec.

### Alternatives considered

- **Options object on the service** (`addTodo(title, { priority })`) - declined by the user at
  Gate 1 in favour of positional `addTodo(title, priority)`. Recorded under Open questions in
  `00-spec.md:119-123`; the plan implements the decision, it does not revisit it.
- **Defaulting inside `validatePriority`** (validator returns the effective value) - rejected. See
  Design decision D1 below; it breaks AC-3's "mirroring the existing `validateTitle` /
  `InvalidTitleError` pair", because `validateTitle` returns nothing.
- **Defaulting in the Application layer** (`addTodo(title, priority = 'medium')`) - rejected.
  Constitution §1.2 puts validation - and with it the priority vocabulary - in Domain. The
  Application layer must not know the string `'medium'`. See D2.
- **Exporting the priority vocabulary as a public constant** - out of scope per `00-spec.md:101-103`;
  the module-private `MAX_TITLE_LENGTH` (`src/domain/todo.js:8`) is the precedent for keeping it
  unexported.

---

## Design decisions

These three are the implementation-time choices the ACs actually discriminate between. They are
pinned here and restated as task acceptance criteria so the Phase 4 implementer does not re-derive
them.

### D1 - The default lives on `createTodo`, never inside `validatePriority`

`validatePriority(priority)` is **void-throwing**: it returns nothing for each of `'low'`,
`'medium'`, `'high'` and throws `InvalidPriorityError` for everything else, **including
`undefined`**. `createTodo` applies the default in its destructuring parameter list before calling
the validator.

Two ACs force this shape together:

- AC-3 requires `validatePriority` to mirror `validateTitle`, and `validateTitle`
  (`src/domain/todo.js:10-17`) returns nothing and only throws. A validator that returned an
  effective value would not mirror it.
- AC-2 requires the default to fire on absent-or-`undefined` only, and to throw on `null`, `''`,
  `'HIGH'`, `'urgent'`, `42`. A JavaScript destructuring default has exactly that semantics: it
  fires on `undefined` and on `undefined` alone.

The concrete consequence for T02: the default must be written as a destructuring default
(`{ id, title, priority = DEFAULT_PRIORITY }`). Writing `priority ?? 'medium'` or
`priority || 'medium'` inside the body would silently swallow `null` (and, for `||`, `''`) and
break AC-2. This is Risk R1.

### D2 - The Application layer forwards, it does not default and does not validate

`TodoService.addTodo(title, priority)` passes `priority` straight into
`createTodo({ id, title, priority })`. When the caller omits the argument, `priority` is `undefined`
inside `addTodo`, the value reaches `createTodo` as `undefined`, and D1's destructuring default
produces `'medium'` in Domain. That is how SC-2 is satisfied without any Application-layer knowledge
of the vocabulary (§1.2, and `00-spec.md:148-150`).

After T04, `src/application/todo-service.js` must contain no priority string literal at all.

### D3 - Vocabulary and default stay module-private in Domain

Two unexported constants in `src/domain/todo.js`, mirroring `MAX_TITLE_LENGTH`
(`src/domain/todo.js:8`): the allowed set and the default value. Tests assert against string
literals, exactly as the existing tests do (`tests/todo.test.js:6-9`).

---

## Phased overview

| Phase | Tasks | What lands |
|---|---|---|
| Foundation | T01 | `InvalidPriorityError`, `validatePriority`, the two private constants. No caller yet. |
| Behavior | T02, T03 | `createTodo` gains the defaulted, validated field; Domain unit tests prove SC-1, SC-2, SC-3, SC-5. |
| Wiring | T04, T05 | `TodoService.addTodo` forwards the value; integration tests prove the Domain/Application crossing. |
| Polish | T06 | The two constitution example literals (AC-9), and the scoped-diff check that backs AC-8. |

## Sequencing rationale

- **T01 before T02** - `createTodo` cannot call a validator that does not exist yet. Both tasks edit
  `src/domain/todo.js`; they are strictly serialized by that `Depends on` edge, so the shared file is
  never touched by two unsequenced tasks. Feature mode runs tasks sequentially and has no
  `Parallel batch` field, so no conflict edge is declared.
- **T03 after T02** - the Domain tests assert the defaulting and the ordering, which only exist once
  T02 lands. T03 is also the first point where SC-5/AC-6 (title error wins) becomes checkable.
- **T04 after T03** - the Application forward technically needs only T02's new parameter, but T03 is
  sequenced first so the Domain layer is fully green before the boundary is crossed. That is the
  cheaper failure ordering: a Domain bug found at T03 costs one file to fix, the same bug found at
  T05 costs a boundary bisect. T04 therefore declares `Depends on: T02, T03`.
- **T05 after T04** - integration tests need the new service signature.
- **T06 last** - AC-8 is a whole-changeset assertion ("no other rule bent", `store.js` unmodified),
  so its diff check is only meaningful once every code task has landed. It is also the only task on
  a protected path; keeping it last means the protected-path edit happens after all reversible work
  is proven green.

**Critical path**: T01 -> T02 -> T04 -> T05. T03 hangs off T02 and T06 off the whole set; neither is
on the critical path for a working feature, but both are required for spec completion (T03 owns
AC-3's direct-test requirement, T06 owns AC-9).

---

## Coverage map (every SC and AC has an owning task)

| Spec ID | Owning task(s) | Note |
|---|---|---|
| SC-1 | T02, T03, T04, T05 | Production change in T02 + T04, proven by T03 (unit) and T05 (integration). |
| SC-2 | T02, T03, T04, T05 | Default path, both layers. |
| SC-3 | T02, T03, T05 | T05 owns the service-level "nothing stored" half. |
| SC-4 | T05 | Test-only, no production task - see below. |
| SC-5 | T02, T03 | Domain-level ordering proof. |
| AC-1 | T02, T03 | |
| AC-2 | T02, T03 | The discriminating criterion; D1. |
| AC-3 | T01, T03 | T01 creates the pair, T03 gives `validatePriority` its direct test. |
| AC-4 | T04, T05 | T05 is append-only: the four existing tests are not edited. |
| AC-5 | T05 | Test-only, no production task - see below. |
| AC-6 | T02, T03 | |
| AC-7 | T03, T05 | Both halves of "unit + integration"; `npm test` green. |
| AC-8 | T06 | Whole-changeset diff assertion, checkable only once last. |
| AC-9 | T06 | |

**SC-4 and AC-5 have no production task, deliberately.** `completeTodo` is
`{ ...todo, done: true }` (`src/domain/todo.js:25`) and `TodoService.completeTodo` passes the stored
object straight through (`src/application/todo-service.js:23-29`), so the field already survives
completion with zero code change - confirmed as mechanically low-risk in `03-decisions.md:76-81`.
An AC proven by test alone is legitimate; an AC with no owner is not, which is why both are pinned
to T05 rather than left implicit.

---

## Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | `??`/`\|\|` used instead of a destructuring default in `createTodo`, silently defaulting `null` (and `''`) and breaking AC-2. This is the single most likely way this feature ships wrong. | D1 is restated verbatim in T02's Acceptance, and T03 asserts `null`, `''`, `'HIGH'`, `'urgent'`, `42` all throw - the `null` case fails loudly under `??`. |
| R2 | Validation order inverted, so an invalid title + invalid priority throws `InvalidPriorityError` and breaks the existing title contract (AC-6). | T02's Acceptance fixes the order (`validateTitle` first); T03 owns the SC-5 test that fails if it is inverted. |
| R3 | Defaulting or validating duplicated into `src/application/todo-service.js`, violating §1.2. | D2, plus T04's Acceptance: after the task, `todo-service.js` contains no priority string literal. |
| R4 | AC-9 edits `.specs/constitution.md`, listed in `paths.protected` (`.claude/project-config.json:57-61`). | Pre-authorized by the Gate 1 exception recorded in `00-spec.md:151-163`; the implementer treats it as approved rather than stalling. Note `hooks.specGate.mode` is `"warn"` in this fixture (`.claude/project-config.json:128`), so the guard logs to stderr and does not block - there is no override to request. |
| R5 | AC-9 scope creep onto the two out-of-scope occurrences (`.specs/constitution.md:31` §1.2 Mapping, `:143` §7 DTO), which are one line and one section away from the targets. | T06's Acceptance is a diff assertion: exactly two changed lines, and `:31`/`:143` byte-identical. In-place literal replacement keeps every other line number stable. |
| R6 | Existing tests edited to accommodate the new field, violating AC-4 and destroying the regression signal. | Both test tasks are append-only, stated in their Acceptance; the 8 existing tests (4 + 4) must pass unedited. They do: every existing assertion is field-wise, and none reads an exhaustive object shape. |
| R7 | `InvalidPriorityError` re-exported from `src/application/todo-service.js` so the integration test can import it, leaking a Domain symbol through Application. | T05 imports it directly from `../src/domain/todo.js`, exactly as `tests/todo-service.test.js:4` already imports `InMemoryStore` from Infrastructure. Stated in T05's Acceptance. |

---

## Complexity self-assessment (measured at plan time)

| Threshold | Measured | Over? |
|---|---|---|
| Tasks > 8 | 6 (T01-T06) | no |
| Production layers > 2 (distinct `Layer`, excluding `Tests`/`Config`) | 2 - Domain, Application | no |
| Impact surface > 8 files | 5 - `src/domain/todo.js`, `src/application/todo-service.js`, `tests/todo.test.js`, `tests/todo-service.test.js`, `.specs/constitution.md` | no |
| Any unresolved Open question | 0 - both resolved at Gate 1 (`00-spec.md:117-128`) | no |

**Under threshold on all four.** The create-time estimate `complexity: M` holds. Gate 2 is normal
plan approval; no decompose proposal.
