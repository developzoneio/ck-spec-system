# <<project-name>>

> Thin orchestrator. Heavy context lives in `.specs/constitution.md` and `.specs/index.md`.
> This file should stay short (~50 lines). If it grows, move detail into the constitution.

## Read on demand

- `.specs/constitution.md` - architectural rules, conventions, quality bars (read for any non-trivial change).
- `.specs/index.md` - active spec registry with lifecycle states (read at start of every workflow).
- `.gemini/project-config.json` - machine-readable paths, commands, models, MCP servers.

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

- **Language**: <<language-and-version>>
- **Framework**: <<framework-and-version>>
- **Database**: <<db-and-version>>
- **Container**: <<container-runtime-and-version>>

## Commands (CLI)

- **Build**: `<<build-command>>`
- **Test**: `<<test-command>>`
- **Lint**: `<<lint-command>>`
- **Run**: `<<run-command>>`
- **Coverage**: `<<coverage-command>>`

## Architecture

- **Style**: <<architecture-style, e.g. Clean Architecture (Uncle Bob), CQRS, Hexagonal>>
- **Layers**: <<layer-list, inside-out, e.g. Domain -> Application -> Infrastructure -> WebServer>>
- **Namespace / package convention**: <<convention, e.g. <Company>.<Product>.<Layer>>>

## Code conventions (apply silently)

- <<convention-1, e.g. Async methods suffixed `Async`; never block with .Result>>
- <<convention-2, e.g. Use `== false` instead of `!` for negation>>
- <<convention-3, e.g. Custom domain exceptions, never generic `Exception`>>
- <<convention-4, e.g. DTOs cross layer boundaries; entities never leave the domain>>

## Forbidden patterns

- <<forbidden-1, e.g. Service locator / static singletons>>
- <<forbidden-2, e.g. `// TODO` left in committed code>>
- <<forbidden-3, e.g. Hardcoded connection strings or secrets>>
- <<forbidden-4, e.g. `dynamic` types outside well-justified boundaries>>

## Quality bars

- **Test coverage**: >= <<threshold, e.g. 80>>% on changed lines.
- **Integration test**: required for any change crossing layer boundaries.
- **Performance**: no change to a hot path without a measured baseline.

## When ambiguous

1. Constitution silent and no precedent? -> `/sd:explore` to find precedent in repo.
2. Still unclear? -> Spec it under "Open questions" and ask before implementing.
3. Two equally valid options? -> Pick the one that minimizes future churn; document the choice in `03-decisions.md`.
