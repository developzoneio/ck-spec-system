---
version: 1.0.0
project: <<project-name>>
maintainers:
  - <<owner-name-or-team>>
last_reviewed: <<YYYY-MM-DD>>
review_cadence: quarterly
---

# Constitution

The constitution is the **single source of truth** for architectural and quality rules in this project. Subagents read this file at runtime; if a rule is not here, it is not enforced.

**Mutation protocol:** changes require a `/ck:refactor` spec or an ADR under `.specs/_adr/`. Never edit silently.

---

## §1. Architectural non-negotiables

### §1.1. Layer rules

- **Dependency direction**: <<inside-out chain, e.g. Domain -> Application -> Infrastructure -> WebServer>>. A layer NEVER depends on an outer layer.
- **Cross-layer data**: only DTOs or simple data structures. Never pass framework objects (EF entities, HttpContext, ORM rows) into inner layers.
- **Inversion**: inner layers define interfaces; outer layers implement them. Concrete dependencies are injected.
- **Forbidden cross-cuts**: <<e.g. Controllers do not call repositories directly; must go through a handler / use case>>.

### §1.2. Pattern rules

- **CQRS**: <<rule, e.g. Read and write paths separated; read uses Dapper, write uses EF Core>>.
- **Validation**: <<rule, e.g. FluentValidation at the application layer; never inside controllers>>.
- **Mapping**: <<rule, e.g. AutoMapper for DTO <-> entity; never manual property copying for >5 fields>>.
- **Logging**: <<rule, e.g. Serilog structured logging; never `Console.WriteLine` in production code>>.

---

## §2. Code conventions

### §2.1. Language style

- <<e.g. C#: nullable enabled, `var` only when type is obvious, expression-bodied members for one-liners>>
- <<e.g. TypeScript: strict mode on, `unknown` over `any`, no `enum` (use union types)>>

### §2.2. Async

- <<e.g. All I/O methods are async; suffix `Async` on method names; never block with `.Result` or `.Wait()`>>
- <<e.g. Pass `CancellationToken` through every async chain>>

### §2.3. Error handling

- <<e.g. Custom domain exceptions: `NotFoundException`, `ValidationException`, `ConflictException`>>
- <<e.g. Never catch `Exception` to swallow; always re-throw or transform with context>>
- <<e.g. Global exception middleware translates domain exceptions to HTTP status codes>>

### §2.4. Naming

- <<e.g. Interfaces prefixed `I`; abstract classes not prefixed>>
- <<e.g. Test files mirror source path under `tests/` with `.Tests` suffix>>
- <<e.g. Database tables PascalCase singular; columns PascalCase>>

---

## §3. Quality bars

| Metric | Threshold | Enforcement |
|---|---|---|
| Test coverage (line) | >= <<80>>% on changed lines | CI gate |
| Integration tests | Required for any change crossing layer boundaries | `/ck:reviewer` checks |
| Mutation tests | Optional, >= <<60>>% if used | Manual |
| Build warnings | Zero `CS####` warnings as errors | csproj `TreatWarningsAsErrors` |
| API response time | p95 < <<200>>ms for read endpoints | Synthetic test in CI |

**Refactor prerequisite**: refactor is blocked if coverage on affected files is below <<80>>%. Write characterization tests first.

**Performance prerequisite**: optimization is blocked without a measured baseline checked into `.specs/PERF-*/04-artifacts/`.

---

## §4. Tech stack declared

- **Language and runtime**: <<e.g. C# 12 / .NET 8>>
- **Web framework**: <<e.g. ASP.NET Core 8>>
- **ORM**: <<e.g. EF Core 8 (write) / Dapper (read)>>
- **Database**: <<e.g. SQL Server 2022>>
- **Cache**: <<e.g. Redis 7>>
- **Messaging**: <<e.g. RabbitMQ 3.x / none>>
- **Frontend**: <<e.g. React 18 + TypeScript 5 + Vite>>
- **Container**: <<e.g. Docker 24 / docker-compose>>
- **Observability**: <<e.g. Serilog -> Seq + OpenTelemetry>>
- **CI/CD**: <<e.g. GitHub Actions>>

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
- **Hardcoded secrets** - use the configured secret store.
- **`dynamic` (C#) / `any` (TS)** - outside justified boundaries; document the exception inline.
- **Catch-and-swallow** - `catch { }` or `catch (Exception) { _logger.Log... }` without re-throw is forbidden.
- **Direct DB calls from controllers** - must go through application layer.
- **Opportunistic refactor inside a feature/bug spec** - separate spec; one concern per workflow.

---

## §7. Glossary

- **Aggregate root**: <<definition in this codebase>>
- **Handler**: <<definition, e.g. MediatR `IRequestHandler<TRequest, TResponse>` implementing one use case>>
- **DTO**: data transfer object; serializable, no behavior, used at layer boundaries.
- **Hot path**: endpoint or method with measured throughput > <<N>> req/s OR latency-sensitive.
- **Characterization test**: test capturing **current** behavior (correct or not) before a refactor.

---

## §8. Changelog

| Version | Date | Change | Spec |
|---|---|---|---|
| 1.0.0 | <<YYYY-MM-DD>> | Initial constitution | - |
