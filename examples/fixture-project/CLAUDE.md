# fixture-project

> Thin orchestrator. Heavy context lives in `.specs/constitution.md` and `.specs/index.md`.
> This file should stay short (~50 lines). If it grows, move detail into the constitution.

## Read on demand

- `.specs/constitution.md` - architectural rules, conventions, quality bars (read for any non-trivial change).
- `.specs/index.md` - active spec registry with lifecycle states (read at start of every workflow).
- `.claude/project-config.json` - machine-readable paths, commands, models, MCP servers.

## Workflows (spec-driven)

| Command | Use when |
|---|---|
| `/sd:feature <ID-or-slug>` | New behavior or non-trivial change. |
| `/sd:bug <ID-or-slug>` | Defect with reproduction; root-cause-first. |
| `/sd:rca <slug>` | Incident analysis. **No code change.** Output is the spec. |
| `/sd:refactor <slug>` | Restructure without behavior change. Requires test coverage. |
| `/sd:perf <slug>` | Optimization. Requires measured baseline. |
| `/sd:spec <subcommand>` | Spec registry management (list, show, status, link, ...). |
| `/sd:explore <query>` | Read-only code navigation. |
| `/sd:review <target>` | Standalone compliance review. |
| `/sd:setup` | Idempotent project scaffold. |
| `/sd:adr <spec-ID>` | Author an ADR from a spec's decisions. |

## Stack

- **Language**: JavaScript (ES2022+), Node.js 20+
- **Framework**: none - plain library, no web/app framework
- **Database**: none - in-memory storage only
- **Container**: none

## Commands (CLI)

- **Build**: n/a - no compile step (plain JavaScript, no bundler/transpiler)
- **Test**: `npm test` (`node --test`)
- **Lint**: n/a - no linter configured
- **Run**: `npm start` (`node src/demo.js`)
- **Coverage**: `npm run coverage` (`node --test --experimental-test-coverage`)

## Architecture

- **Style**: Layered (inside-out), no framework
- **Layers**: Domain -> Application -> Infrastructure
- **Namespace / package convention**: plain ES modules, one class/concept per file, path mirrors layer (`src/<layer>/<file>.js`)

## Code conventions (apply silently)

- Domain functions are pure - no I/O, no imports from Application or Infrastructure.
- Application receives its store via constructor injection; never imports `InMemoryStore` directly outside tests/wiring (`src/demo.js`).
- Plain object shapes cross layer boundaries (e.g. `{ id, title, done }`); never a storage-specific object.
- Custom error classes for domain/application failures (e.g. `InvalidTitleError`, `TodoNotFoundError`); never a bare `throw new Error(...)` for an expected failure mode.

## Forbidden patterns

- Service locator / static singletons holding mutable state.
- `// TODO` or `// HACK` left in committed code.
- Hardcoded secrets or connection strings (n/a today - no external services - but the rule stands if one is ever added).
- Infrastructure imported directly by Domain, or by Application outside constructor injection.

## Quality bars

- **Test coverage**: every exported Domain and Application function has at least one passing test.
- **Integration test**: required for any change crossing the Domain/Application boundary (i.e. anything routed through `TodoService`).
- **Performance**: not a concern for this fixture - no hot path, no measured baseline required.

## When ambiguous

1. Constitution silent and no precedent? -> `/sd:explore` to find precedent in repo.
2. Still unclear? -> Spec it under "Open questions" and ask before implementing.
3. Two equally valid options? -> Pick the one that minimizes future churn; document the choice in `03-decisions.md`.
