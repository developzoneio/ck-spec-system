---
version: 1.0.0
project: fixture-project
maintainers:
  - specwright maintainers
last_reviewed: 2026-07-31
review_cadence: quarterly
---

# Constitution

The constitution is the **single source of truth** for architectural and quality rules in this project. Subagents read this file at runtime; if a rule is not here, it is not enforced.

**Mutation protocol:** changes require a `/sd:refactor` spec or an ADR under `.specs/_adr/`. Never edit silently.

---

## §1. Architectural non-negotiables

### §1.1. Layer rules

- **Dependency direction**: Domain -> Application -> Infrastructure. A layer NEVER depends on an outer layer (Domain never imports Application or Infrastructure; Application never imports Infrastructure directly).
- **Cross-layer data**: only plain object literals (e.g. `{ id, title, done, priority }`). Never pass a storage-specific object (a `Map` entry, a driver row) into an inner layer.
- **Inversion**: Application defines the store contract implicitly by the methods it calls (`nextId`, `save`, `get`, `list`, `update`); Infrastructure implements that contract. The concrete store is injected via the `TodoService` constructor - Application never `import`s `InMemoryStore` itself (only test/wiring code does, e.g. `src/demo.js`).
- **Forbidden cross-cuts**: no file under `src/domain/` may import from `src/application/` or `src/infrastructure/`.

### §1.2. Pattern rules

- **CQRS**: not applicable - this library has no read/write path split; it is a single small object graph.
- **Validation**: input validation (e.g. `validateTitle`) lives in Domain, never in Infrastructure or inline in a test.
- **Mapping**: not applicable - one plain-object shape (`{ id, title, done }`) is used end-to-end; no DTO/entity translation layer exists at this size.
- **Logging**: none configured. If added, structured logging only - never a bare `console.log` in library code (the one exception is `src/demo.js`, which is a CLI demo entry point, not library code).

---

## §2. Code conventions

### §2.1. Language style

- Plain modern JavaScript (ES2022+), ES modules (`"type": "module"`). No TypeScript, no build step.
- Private class fields (`#field`) for internal state (see `InMemoryStore`, `TodoService`); never a `_prefixed` convention for privacy.

### §2.2. Async

- Not applicable - every operation in this fixture is synchronous (in-memory store, no I/O). If a future change adds async I/O, every touched method becomes `async`/`await` end-to-end; no mixing of callbacks and promises.

### §2.3. Error handling

- Custom error classes per failure mode: `InvalidTitleError` (Domain), `TodoNotFoundError` (Application). Never a bare `throw new Error(...)` for an expected failure.
- Never catch-and-swallow. If a caller needs to react to a specific failure, it catches the named error class.

### §2.4. Naming

- One class or cohesive concept per file; filename mirrors the exported concept (`todo-service.js` exports `TodoService`).
- Test files mirror source layout under `tests/` (e.g. `src/domain/todo.js` -> `tests/todo.test.js`).

---

## §3. Quality bars

| Metric | Threshold | Enforcement |
|---|---|---|
| Test coverage | Every exported Domain/Application function has >= 1 passing test | `sd-reviewer` checks; `node --test --experimental-test-coverage` reports the number |
| Integration tests | Required for any change crossing the Domain/Application boundary | `sd-reviewer` checks |
| Mutation tests | Not used at this size | n/a |
| Build warnings | n/a - no build step | n/a |
| API response time | n/a - no network endpoint in this fixture | n/a |

**Refactor prerequisite**: refactor is blocked if the touched file has no passing test. Write a characterization test first.

**Performance prerequisite**: not applicable - this fixture has no measured hot path.

---

## §4. Tech stack declared

- **Language and runtime**: JavaScript (ES2022+) / Node.js 20+
- **Web framework**: none
- **ORM**: none
- **Database**: none - in-memory `Map` only
- **Cache**: none
- **Messaging**: none
- **Frontend**: none
- **Container**: none
- **Observability**: none
- **CI/CD**: none dedicated to this fixture (exercised via the parent specwright repo's own `.github/workflows/`)

Adding a stack element requires a constitution amendment (this section + glossary).

---

## §5. Workflow rules

### §5.1. Spec-driven

- Every non-trivial change starts with a spec under `.specs/<ID>/`.
- "Non-trivial" = more than one file edited OR any behavior change OR any cross-layer change.
- Typo fixes, dependency bumps without behavior change, and pure formatting are exempt.

### §5.2. Lifecycle states

```
draft -> approved -> in-progress -> done -> archived
                                  ^
                                  +-- revive (from archived) for follow-up
```

| State | Meaning | Who can transition |
|---|---|---|
| `draft` | Spec exists, not yet approved | Author |
| `approved` | Reviewed and ready to plan | User (explicit approval at Gate 1) |
| `in-progress` | Implementation underway | Auto on Phase 4 start |
| `done` | Closed; retro written; CI green | User (explicit approval at close gate) |
| `archived` | No active work | Auto after N days in `done` (configurable) |

All transitions logged to the spec's `05-retro.md` with timestamp + reason.

### §5.3. Gate discipline

- Workflows **refuse** to proceed without explicit approval at hard gates.
- "Looks fine, go ahead" is acceptable approval. Silence is not.
- A skipped gate (override) is logged to retro and constitutes a constitution exception.

---

## §6. Forbidden patterns

- **Service locator** - resolve dependencies via constructor injection only.
- **Static singletons holding state** - configuration is fine; mutable state is not.
- **`// TODO` or `// HACK` in committed code** - either fix, ticket, or spec it.
- **Hardcoded secrets** - n/a today (no external services), but the rule stands if one is ever added.
- **Type-safety escapes** - n/a, this project has no `any`/`dynamic` equivalent (plain JS, no TS).
- **Catch-and-swallow** - `catch { }` or a catch that only logs, without re-throw, is forbidden.
- **Direct store access from outside Application** - a test or demo script may construct an `InMemoryStore` directly, but production code paths always go through `TodoService`.
- **Opportunistic refactor inside a feature/bug spec** - separate spec; one concern per workflow.

---

## §7. Glossary

- **Aggregate root**: the `todo` object itself (`{ id, title, done, priority }`) - this fixture has no nested entity graph.
- **Handler**: not applicable - no command/query dispatcher; `TodoService` methods are called directly.
- **DTO**: data transfer object; serializable, no behavior, used at layer boundaries. In this fixture the plain `{ id, title, done }` object doubles as both entity and DTO given its size.
- **Hot path**: not applicable - no throughput/latency-sensitive code in this fixture.
- **Characterization test**: test capturing **current** behavior (correct or not) before a refactor.

---

## §8. Changelog

| Version | Date | Change | Spec |
|---|---|---|---|
| 1.0.0 | 2026-07-31 | Initial constitution | - |
