# DOCS: README/ROADMAP/usage drift after the v1.3.0+ ships (/sd:adr, sd-docs-writer, setup scan)

- Priority: P3
- Area: `README.md`, `ROADMAP.md`, `docs/usage.md`, `templates/project-config.template.json`,
  `CONTRIBUTING.md`, `examples/README.md`
- Status: VERIFIED (agent-audited with quotes; docs/architecture.md was checked and is CURRENT — do not touch it)
- Suggested branch: `docs/post-1.3-drift-sweep`

## Findings — one sweep PR

1. **README.md:4** — "Ten slash commands, five specialized subagents" -> "Eleven slash
   commands, six specialized subagents" (repo has 11 commands incl. `/sd:adr`, 6 agents incl.
   `sd-docs-writer`; CLAUDE.md:47-48 and docs/architecture.md:12-17 already say 11/6).
2. **README.md:89-100** — Commands table lacks a `/sd:adr` row. Add:
   `/sd:adr <spec-ID>` | Utility | 1 | "Author an ADR from a spec's decisions" (mirror the
   wording in `commands/adr.md` frontmatter).
3. **README.md:106-112** — Agents table lacks `sd-docs-writer`. Add a row mirroring
   `docs/architecture.md:95` (sonnet; Read/Write/Glob/Grep; skill `sd-evidence-citation`).
4. **README.md:91** — `/sd:feature` hard-gate count says 4; the command says 3
   (`commands/feature.md:2`, gates merged review+integration). Change to 3.
5. **templates/project-config.template.json:69** — `workflow.gates.feature` still lists 4
   entries (`"spec-approved","plan-approved","review-pass","integration-pass"`); collapse the
   last two to match the merged Gate 3 (e.g. `"integration-review-pass"`). NOTE: grep shows no
   hook consumes `workflow.gates` — decide: fix the values AND add a `_comment`/doc note that
   the block is descriptive, or remove the block entirely. Removal touches setup templates —
   check `commands/setup.md` first.
6. **ROADMAP.md:22-28** — "`/sd:setup` codebase scan" and "`sd-docs-writer` agent" still sit
   under `## Planned` but both SHIPPED (PR #11 commit 3f3ee96, PR #12 commit 9b1a599). Remove
   them from Planned (shipped items live in CHANGELOG per ROADMAP.md:3). Keep "GitHub Issue
   auto-fetch" (near-term) and "local-only usage analytics" (exploratory) — still open.
7. **README.md:260-261** — repeats the same stale "Planned" highlights; update alongside 6.
8. **docs/usage.md** — the Utility commands section (~:159-261) documents spec, explore,
   review, setup, release but has NO `/sd:adr` entry. Add one modeled on the release entry
   (argument form, the 1 hard gate, output path `.specs/_adr/`).
9. **README.md:148-172** — the `.specs/` tree diagram omits the `_adr/`, `_explorations/`,
   `_reviews/` dirs that `/sd:setup` scaffolds (documented at usage.md:32-34). Add them.
10. **CONTRIBUTING.md:126-133** — agent frontmatter example omits `color:` and `skills:`,
    both mandated by CLAUDE.md:58 and present in every real agent. Extend the example.
11. **examples/README.md:20** — "Future additions (not in v1.0.0):" lists dirs that never
    materialized, three minor versions later. Reword without the version gate (point to
    ROADMAP or drop the promised list).

## Acceptance criteria

1. `grep -rn "Ten slash\|five specialized\|ten command" README.md docs/` returns nothing.
2. Every command in `commands/` has a row in the README Commands table and a section in
   `docs/usage.md`; every agent in `agents/` has a row in the README Agents table.
3. Gate counts in README match each command file's frontmatter.
4. ROADMAP contains no shipped item.
5. `scripts/validate.sh` passes (Check 6 needs the CHANGELOG entry).

Add a CHANGELOG `### Fixed` (docs) entry under `## [Unreleased]`.
