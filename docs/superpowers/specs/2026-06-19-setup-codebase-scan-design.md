# Design: `/sd:setup` codebase scan (facts only)

Date: 2026-06-19
Roadmap item: ROADMAP.md "Planned" - `/sd:setup` codebase scan
Status: approved (brainstorming)

## Problem

Today `/sd:setup` leaves most of `CLAUDE.md` and `project-config.json` as `<<placeholder>>`
tokens. Phase 2 only parses an *existing* `CLAUDE.md` and applies filename heuristics; it never
samples actual source. First-run setup is therefore a blank template the user must fill by hand.

## Goal

Turn first-run setup from blank-template into detected-defaults - **facts only** - without adding
interrogation questions and without touching the opinionated constitution rules.

## Non-goals

- Inferring constitution rules (`§1`-`§6`) from sampled code. Rules stay human-authored; auto-detecting
  them risks codifying accidental/inconsistent patterns as enforced law.
- A deterministic scanner script. The scan is Claude-driven sampling inside `commands/setup.md`, so it
  stays stack-agnostic and needs no cross-platform ps1/sh pair.

## Design

### New Phase 2.5 - "Scan codebase (facts only)" in `commands/setup.md`

Inserted after the existing CLAUDE.md-parse phase (Phase 2) and before the Phase 3 questions.
Claude-driven, bounded sampling:

- **Stack** (language / framework / db): extend today's filename heuristics with content peeks at the
  dominant package manifest.
- **Paths**: detect `src`, `tests`, `docs` from the directory layout.
- **Commands** (`build` / `test` / `lint` / `run` / `coverage`): read whatever the dominant manifest
  declares (e.g. `package.json` scripts, `Makefile` targets, `*.csproj` / `pyproject.toml`). Never
  hardcoded stack commands - only what the manifest actually contains.
- **`paths.layers`**: ordered inside-out array of `{name, path}` inferred from top-level source folders
  that look like architectural layers (inner first). Empty array `[]` when undetectable. `path` may be
  a glob.

**Bounds** (keep it cheap and fast):
- Sample at most ~15-20 representative files.
- Cap directory-walk depth.
- Skip `node_modules`, `bin`, `obj`, `.git`, `dist`, `target`, vendor directories.
- Log which files were sampled.

### Batch review gate (one confirmation, not a 4th question)

After the scan, print a single detected-facts table (stack, paths, layers, commands) and ask:
"edit any of these before I write? (list corrections or say go)". This is one confirmation of a batch,
not a per-field interrogation - the `<=3 questions` adoption rule is preserved. The user can override
every value.

### Wiring into existing phases

- **Phase 4 (Generate CLAUDE.md)**: detected facts pre-fill the Stack, Commands, and Architecture/layers
  sections. Undetected fields stay `<<placeholder>>`.
- **Phase 6 (Scaffold .claude/)**: detected facts pre-fill `commands.*`, `paths.*`, and the new
  `paths.layers`. Undetected fields stay `<<placeholder>>`.
- **Constitution untouched**: facts only; `.specs/constitution.md` rules remain `<<placeholder>>`.

### Template change

`templates/project-config.template.json`: add `paths.layers: []` with a `_use` note describing the
ordered inside-out `{name, path}` contract and that it backs constitution §1.1 dependency direction.

## Constraints preserved

- `<=3` interactive questions (the scan adds a confirmation, not a question).
- Idempotent; never overwrites without a timestamped backup.
- Stack-agnostic; no hardcoded stack commands or language assumptions.
- Generated files have no BOM (UTF-8 only).
- Never modifies the engine (`~/.claude/`).

## Verification

This repo has no unit-test framework; "testing" is validate scripts + dry-run installs.

- `scripts/validate.ps1` / `scripts/validate.sh` pass (ASCII scan, model-alias-only, hook-pair parity,
  install-target counts).
- Dry-run install + install -> uninstall round-trip in a sandbox.
- Manual `/sd:setup` against a sample repo: confirm detected facts land in the generated files and
  undetected fields remain `<<placeholder>>`.
- `CHANGELOG.md` gains an `[Unreleased]` entry.

## Out of scope / follow-ups

- Architecture-doc generation from accumulated specs (separate roadmap item).
- Feeding `paths.layers` into spec-gate / impact analysis (future consumer; this change only produces it).
