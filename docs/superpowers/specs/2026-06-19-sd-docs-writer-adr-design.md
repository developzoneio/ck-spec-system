# Design: `sd-docs-writer` agent + `/sd:adr` command

Date: 2026-06-19
Roadmap item: ROADMAP.md "Planned" - `sd-docs-writer` agent
Status: approved (brainstorming)

## Problem

Durable architectural decisions captured in spec artifacts (`03-decisions.md`) never get promoted into
human-facing Architecture Decision Records. The constitution's mutation protocol already points to ADRs
under `.specs/_adr/`, and `/sd:setup` already scaffolds that directory, but nothing authors ADRs and no
agent or command targets them.

## Goal

Promote durable spec decisions into numbered ADRs under `.specs/_adr/`, via a new read-mostly agent
driven by a new command.

## Non-goals

- Generating or updating human-facing architecture docs (e.g. `docs/architecture.md`) - separate, fuzzier
  roadmap item; high risk of clobbering hand-written prose.
- Drafting constitution amendments. The agent never edits `.specs/constitution.md`.
- A new spec template. ADRs are not specs; they live in `.specs/_adr/` with their own MADR-style format.

## Design

### New agent: `agents/docs-writer.md` (installs as `sd-docs-writer`)

- **Frontmatter:** `name: sd-docs-writer`, `color`, `model: sonnet` (ADR drafting is prose synthesis,
  matching the architect/reviewer tier), minimal `tools: [Read, Write, Glob, Grep]`, and
  `skills: [sd-evidence-citation]` (ADRs must cite the spec/file that drove the decision).
- **Role:** read a spec's decision artifacts (primarily `03-decisions.md`, plus spec context) and draft
  ONE ADR. Never edits the constitution, never auto-fixes code, never invents decisions not present in
  the source.

### New command: `commands/adr.md` (`/sd:adr`)

- **Argument:** `<spec-ID>` (e.g. `FEAT-012`) OR a free-text decision title for ad-hoc ADRs with no spec.
- **Phase 0 - bootstrap:** read `CLAUDE.md`, `.specs/constitution.md`, `.claude/project-config.json`,
  `.specs/index.md` (same as every command).
- **Phase 1 - resolve source:** locate the spec folder and read `03-decisions.md` (and spec context). For
  free-text mode, take the decision from the argument + a short interactive prompt.
- **Phase 2 - number + draft:** scan `.specs/_adr/` for the highest existing `NNNN-` prefix, assign the
  next zero-padded number, derive a kebab slug from the decision title, and invoke `sd-docs-writer` to
  draft `.specs/_adr/NNNN-<slug>.md`.
- **ADR format (MADR-style):** `Status` (proposed / accepted / superseded), `Context`, `Decision`,
  `Consequences`, plus a back-link to the source spec ID. Supersession: a new ADR may mark an older one
  `superseded by NNNN`, with a reciprocal link recorded on the old ADR.
- **HARD gate:** print the drafted ADR and require explicit approval before writing to disk (engine gate
  discipline; silence is not approval).
- **Idempotent:** if an ADR for the same decision already exists, offer update-in-place vs new-number
  rather than clobbering.

### Wiring (the "everywhere" surface)

Command count 10 -> 11 and agent count 5 -> 6 in:

- `CLAUDE.md` (repo) - command list, agent list, and the install-target table.
- `commands/setup.md` - Phase 7 report block ("10 workflow commands", "5 specialist agents").
- `templates/CLAUDE.template.md` - the Workflows table gains a `/sd:adr` row.
- `README.md` - command/agent counts and any command table.
- `docs/architecture.md` - the command -> agent routing tree gains `/sd:adr -> sd-docs-writer`.
- `scripts/validate.ps1` + `scripts/validate.sh` - install-target count assertions (`commands/sd` 11,
  `agents/sd` 6).

No `templates/specs/` addition (ADRs are not specs).

## Verification

- `scripts/validate.{ps1,sh}` pass with updated counts (11 commands, 6 agents); ASCII scan, hook-pair
  parity, model-alias-only all still green.
- Dry-run install + install -> uninstall round-trip in a sandbox; confirm `commands/sd/adr.md` and
  `agents/sd/docs-writer.md` land and are removed cleanly.
- Manual `/sd:adr <spec-ID>` run against a sample `.specs/<ID>/03-decisions.md`: confirm a numbered ADR
  is drafted, the HARD gate fires before writing, and the file lands in `.specs/_adr/`.
- `CHANGELOG.md` gains an `[Unreleased]` entry.

## Out of scope / follow-ups

- Architecture-doc generation from accumulated specs.
- A close-gate offer ("draft an ADR from this spec?") inside feature/bug/refactor/perf workflows - a
  follow-up once the dedicated command proves out.
