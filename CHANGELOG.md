# Changelog

All notable changes to **specwright** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `ROADMAP.md` - published roadmap of near-term, planned, and exploratory work, linked from
  `README.md` (new `## Roadmap` section + Documentation entry). Migrated the forward-looking items
  out of the non-standard `### Planned` subsection that sat under the `1.2.0` changelog entry into
  this dedicated file.
- `/sd:setup` codebase scan (Phase 2.5) - samples the project tree to pre-fill detected facts
  (stack, `paths.{src,tests,docs}`, `commands.*` from the project manifest, and a new ordered
  inside-out `paths.layers` map) into `CLAUDE.md` and `project-config.json`, with a single batch
  confirmation gate. Facts only - constitution rules are never auto-filled. Adds `paths.layers` to
  `templates/project-config.template.json`.
- `/sd:adr` command (11th) + `sd-docs-writer` agent (6th) - drafts a numbered, MADR-style Architecture
  Decision Record under `.specs/_adr/` from a spec's `03-decisions.md` (or an ad-hoc decision), behind one
  hard approval gate. The agent (model `sonnet`, tools Read/Write/Glob/Grep, skill `sd-evidence-citation`)
  writes only the ADR file and never invents decisions; the command owns numbering and supersession links.
  Bumps command count 10 -> 11 and agent count 5 -> 6 across docs and the validators.

### Fixed
- `/sd:setup` now migrates `.claude/*` drift instead of exiting blind on a `complete` project. A
  new Phase 1.5 (drift check & migrate) runs whenever `.claude/project-config.json` or
  `.claude/settings.json` exists (states `complete` and `partial`) and rule-based-compares them
  against the loaded templates - catching renamed engine paths (`hooks/ck` -> `hooks/sd`), the
  `$schema` URL, `/ck:*` // `ck:*` names in `_use` docs, newly-introduced fields
  (`ticket.snapshot`, `paths.layers`), pinned model IDs (`claude-sonnet-4-6` -> `sonnet`), and
  stale `settings.local.json` permission paths. Every change is previewed in one batch gate
  (silence is not approval) and each file is backed up `.bak.<timestamp>` before a targeted,
  value-preserving patch. Fixes scaffolded projects whose three hooks silently pointed at the
  non-existent `~/.claude/hooks/ck/` directory after the `ck` -> `specwright` rename.
- `/sd:setup` Phase 7 (and Phase 1.5) now verify every hook `command` path in
  `.claude/settings.json` resolves to a file on disk, warning loudly when a hook is not firing.
- `hooks/powershell/subagent-retro.ps1`, `prompt-router.ps1`, and `spec-gate.ps1` no longer assign
  parsed hook JSON to `$input` - PowerShell's reserved automatic pipeline variable. Assigning to it
  threw a non-terminating `ParameterBindingException` on every real (piped/redirected) stdin
  invocation, leaving it unbound and causing every PowerShell hook to exit silently before reading
  any input. Renamed to `$hookInput` in all three files.
- `hooks/bash/spec-gate.sh` in-progress detection now requires `in-progress` and a spec ID on the
  SAME line, matching `spec-gate.ps1` and `prompt-router.sh`'s existing same-line semantics. The
  previous two independent file-wide `grep`s let an `in-progress` legend/header line combine with a
  spec ID on an unrelated `done` row, so bash allowed a code edit that PowerShell would warn/block
  on the identical `.specs/index.md`.

---

## [1.3.0] - 2026-06-18

Release-tooling and CI hardening. Adds the `/sd:release` command (10th), a single-command repo invariant
validator with a Windows + Ubuntu CI matrix, an uninstaller, and a batch of command/agent refinements.

### Added
- `/sd:release` command (10th command) - generates release notes from completed specs: collects
  every spec in `done` status (feature / bug / refactor / perf; RCA excluded), groups them into
  Keep-a-Changelog sections (FEAT -> Added, BUG -> Fixed, REF/PERF -> Changed) under an inferred
  SemVer heading (any feature -> minor bump, else patch; major never auto-inferred), then
  transitions each `done -> archived`. One hard gate previews the notes and the archive plan
  before any write; `--dry-run` stops before writing. Pure file ops, no subagent (mirrors
  `/sd:spec`). Gives the `done` (merged, unshipped) vs `archived` (shipped) states a concrete
  meaning.
- `scripts/validate.ps1` + `scripts/validate.sh` - one command that runs every documented engine
  invariant: pure-ASCII scan of `*.ps1`, `bash -n` on `*.sh`, hook-pair parity, agent `model:`
  alias-only check, install-target file counts (real install to a temp base), and a non-empty
  `[Unreleased]` CHANGELOG gate. Exit 1 on any failure.
- `.github/workflows/ci.yml` - runs `validate` on push/PR across a Windows + Ubuntu matrix, plus an
  install -> uninstall round-trip per the `CLAUDE.md` sandbox recipe.
- `install/uninstall.ps1` + `install/uninstall.sh` - removes the five `<base>/<area>/sd/`
  directories with dry-run preview, confirmation prompt (`-Force`/`--force` to skip), and
  per-project cleanup reminders (`.claude/settings.json` hook wiring, `.claude/.hookstate/`).

### Changed
- `scripts/validate.{ps1,sh}` Check 6 now treats an empty `[Unreleased]` section as passing when the
  section immediately below it is a dated `[x.y.z] - <date>` release heading (the freshly cut version),
  so a clean post-release CHANGELOG no longer fails CI. A non-release-state empty `[Unreleased]` still
  fails, preserving the "every PR adds a changelog line" invariant.
- `/sd:perf` Gate 6 now structurally refuses a no-measurable-gain "keep" instead of merely warning about
  it in prose. The gate branches on the noise check: a measurable improvement still offers `keep` /
  `revert`, but a within-noise result defaults to `revert` and allows `keep` only as an explicit logged
  constitution exception (decision `kept (exception)` + a reason recorded to `05-retro.md`). With no
  reason supplied, the change is reverted.
- `docs/architecture.md` gains two reference sections: a "Command -> agent routing" tree showing the
  subagent fan-out per command (and the three file-ops commands that invoke none), and an "Artifact
  ownership" table mapping each `.specs/<ID>/` file to its producing phase/agent and downstream readers.
  Consolidates routing/ownership that previously lived only in scattered command files.
- `/sd:setup` Q1 and the `sd-spec-architect` ticket protocol now state explicitly that automatic
  ticket-context fetch is JIRA-only: GitHub Issues and Linear are still recorded as the project
  tracker (for prompt-hook ID recognition), but their ticket content is not auto-fetched - paste it
  into the prompt instead. The ticket snapshot protocol is documented as JIRA-specific. Closes the
  silent degradation where non-JIRA projects got no ticket fetch and no explanation.

### Fixed
- `/sd:spec status` now spells out the illegal-transition refusal instead of the vague "REFUSED with
  explanation": it prints the current state, the requested state, the valid next state(s) from the
  state machine, and the shortest legal path to the requested state when reachable (e.g. `draft -> done`
  is rejected with the hint `draft -> approved -> in-progress -> done`). No file is mutated on refusal.
- `/sd:bug` Phase 3 no longer assumes a confirmed root cause always arrives. The investigation loop
  previously said "Continue until one is CONFIRMED" with no exit, so a bug whose every hypothesis is
  rejected/inconclusive had no defined stopping point. Added Gate 3a (hypothesis tree exhausted): the
  loop now terminates on a CONFIRMED hypothesis OR an exhausted tree, and the exhausted case STOPs and
  asks the user to re-enumerate (with new evidence), add observability, or abort as "root cause not
  found" - never guessing a fix from an unconfirmed tree.
- `install/install.sh` marked executable (mode `100755`, matching `uninstall.sh`); it was `100644`,
  so the documented `./install/install.sh` invocation failed with "Permission denied" on a fresh
  Linux checkout. Surfaced by the new CI round-trip.
- `install/README.md`: total file count corrected (21 -> 32), `skills/sd/` added to the layout
  tree, install table, and manual uninstall commands (skills were missed since 1.1.0), and the
  `-Prefix`/`--prefix` option documented.

---

## [1.2.0] - 2026-06-12

Pattern conformance release. Introduces `sd-pattern-discipline` (the 6th skill), wires it into spec-architect/implementer/reviewer, adds the `Pattern refs` task field, and closes the gap where impact analysis never reached implementation.

### Added
- `sd-pattern-discipline` skill (6th skill) - pattern discovery and adherence rules: precedent
  sampling, `Pattern refs` authoring (spec-architect), following (implementer), and conformance
  review (reviewer). Fixes implementations that ignored the target codebase's structure.
- `Pattern refs` task field in `sd-atomic-task-format` - 1-3 `file:line` precedent citations the
  implementer reads before writing. Required for tasks creating a new file or public symbol;
  absent field is treated as `none` (backward compatible with existing `.specs/` folders).
- `sd-code-explorer` impact-map output gains a "Precedents & conventions" section: nearest
  similar implementations, observed naming/layout conventions, and reusable existing utilities.
- Ticket snapshot protocol in `sd-spec-architect`: fetched JIRA tickets are now persisted to
  `.specs/<ID>/04-artifacts/ticket/` together with related tickets (1 hop, capped) and linked
  Confluence pages (capped). Configurable via `ticket.snapshot` in project-config (enabled by
  default, absent means enabled); fetch failures never block spec creation.
- `CLAUDE.md` added to the specwright repo itself (was previously missing).

### Changed
- `/sd:feature`, `/sd:bug`, `/sd:refactor`, `/sd:perf` now pass `IMPACT_REF` (`03-decisions.md`)
  to `sd-implementer`, closing the gap where impact analysis never reached implementation.
- `sd-spec-architect`, `sd-implementer`, `sd-reviewer` wired to the `sd-pattern-discipline`
  skill; implementer's convention discipline expanded to cover new files, new-symbol naming, and
  reuse-before-write for helpers.
- `sd-spec-architect` Atlassian tool allowlist: added `getJiraIssueRemoteIssueLinks` and
  `getConfluencePage` (snapshot collection).

### Fixed
- `sd-spec-architect` tool allowlist referenced `mcp__atlassian__searchJiraIssues`, which is not
  a real Atlassian MCP tool name - corrected to `mcp__atlassian__searchJiraIssuesUsingJql`.
  Slug-based ticket search could never have resolved before.

> Forward-looking items that previously lived here moved to [`ROADMAP.md`](ROADMAP.md).

---

## [1.1.0] - 2026-06-03

Architecture refresh. Adds an Agent Skills layer and upgrades the `spec-gate` hook to the CLI's new permission-decision schema (forward-compatible, no break for older CLIs).

### Added

#### Skills (5, new `skills/sd/` layer)
A skill is a markdown rule pack referenced by agents from their YAML frontmatter (`skills: [...]`). Skills de-duplicate rules shared across multiple agents, keep agent prompts smaller, and make the rules auditable in one place.

- `sd-severity-taxonomy` - Severity rules (BLOCK / WARN / SUGGEST / PASS) and the mandatory review output format. Applied by `sd-reviewer`.
- `sd-hypothesis-tree` - Enumerate / verify protocol with the 5 mental models, `(L × I) / C` score formula, and the proximate-vs-root "why" ladder. Applied by `sd-debugger`.
- `sd-atomic-task-format` - The 9-field atomic task block plus canonical enums (`Step type`, `Complexity`, `Reversibility`). Applied by `sd-spec-architect` (authoring) and `sd-implementer` (consuming).
- `sd-evidence-citation` - `file:line` citation discipline, snippet length rules, evidence taxonomy, grouping. Applied by `sd-code-explorer`, `sd-debugger`, `sd-reviewer`.
- `sd-spec-templates` - Per-template authoring rules (feature / bug / refactor / perf / rca). Applied by `sd-spec-architect`.

#### Agent frontmatter
- All 5 agents now declare a `skills: [...]` list in frontmatter.
- All 5 agents now declare a `color:` field for terminal rendering.
- Agent body sizes reduced where content moved into a referenced skill.

#### Installers
- `install/install.ps1` and `install/install.sh` now install `skills/<prefix>/` alongside `commands/<prefix>/`, `agents/<prefix>/`, `hooks/<prefix>/`, `templates/<prefix>/`.

### Changed

#### Hooks - dual-format block output
Both `spec-gate.ps1` and `spec-gate.sh` now emit a single JSON object that carries **both** the new and legacy schemas. The CLI reads whichever it understands:

```json
{
  "decision": "block",
  "reason": "...",
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "..."
  }
}
```

This is forward-compatible with CLI builds that read `hookSpecificOutput.permissionDecision` and backward-compatible with builds that read the top-level `decision` field. No version probing needed.

#### Documentation
- `README.md` - Added Skills section and updated Layer 1 diagram to include `skills/sd/`.
- `docs/architecture.md` - Added "Agent skills" section explaining the rule-pack pattern; added the dual-format block-output schema to the `spec-gate` description.

---

## [1.0.0] - 2026-01-15

Initial public release.

### Added

#### Slash commands (9, all under `sd:` namespace)
- `/sd:feature` - Spec-driven feature workflow with 4 hard gates (spec, plan, review, integration).
- `/sd:bug` - Root-cause-first bug fix workflow with 5 hard gates (symptom, reproduction, root cause, failing test, regression).
- `/sd:rca` - Incident root-cause analysis (output IS the spec; no code change).
- `/sd:refactor` - Coverage-gated refactor workflow with 6 hard gates (spec, coverage threshold, post-test, plan, per-batch tests, holistic review).
- `/sd:perf` - Baseline-first performance workflow with 8 hard gates (target, baseline, hotspot, hypothesis, correctness, keep/revert, regression, final review).
- `/sd:spec` - Spec registry management (list / show / status / link / archive / revive / search / validate / stats / help).
- `/sd:explore` - Read-only code exploration via the `sd-code-explorer` agent.
- `/sd:review` - Standalone constitution-compliance review on a path, recent edits, or a spec.
- `/sd:setup` - Idempotent project scaffold (CLAUDE.md + .claude/ + .specs/ + project-config.json).

#### Subagents (5, cost-aware model assignment)
- `sd-spec-architect` (sonnet) - Creates and refines specs / plans / tasks.
- `sd-code-explorer` (haiku) - Read-only code navigation with citation discipline.
- `sd-debugger` (sonnet) - Hypothesis-tree investigation with sequential-thinking.
- `sd-implementer` (haiku) - Executes ONE atomic task with scope discipline.
- `sd-reviewer` (sonnet) - Severity-tagged compliance review (BLOCK / WARN / SUGGEST / PASS).

All agents use **portable model aliases** (`sonnet`, `haiku`) - they auto-update with the latest Anthropic models and are not pinned to specific versions.

#### Hooks (3, cross-platform)
- `prompt-router` (UserPromptSubmit) - Keyword routing and spec-context injection.
- `spec-gate` (PreToolUse on Edit / Write / MultiEdit) - Guard rail blocking code edits when no in-progress spec is registered.
- `subagent-retro` (SubagentStop) - Reminder to update stale retros after subagent runs.

Each hook ships in two flavours:
- `hooks/powershell/*.ps1` - PowerShell 5.1+ (pure ASCII, Windows-1252 safe).
- `hooks/bash/*.sh` - Bash 4+ with `jq` (graceful fallback if `jq` missing).

#### Templates (9)
**Setup templates (4):**
- `CLAUDE.template.md` - Thin orchestrator pointing at `.specs/`.
- `constitution.template.md` - YAML frontmatter + 8 governance sections.
- `project-config.template.json` - Machine-readable config (paths, commands, models, MCP, hook modes).
- `settings.template.json` - Claude Code hook wiring (PowerShell variant by default).

**Spec templates (5):**
- `feature.template.md`
- `bug.template.md` (root-cause and fix fields intentionally empty until Phase 3).
- `refactor.template.md`
- `perf.template.md` (baseline and results log intentionally empty until measured).
- `rca.template.md`

#### Installer
- Cross-platform: `install/install.ps1` (Windows) and `install/install.sh` (Unix/macOS).
- Content-hash (SHA256) comparison to skip identical files.
- Timestamped backups (`*.bak.<yyyyMMdd-HHmmss>`) before overwrites.
- `--dry-run`, `--force`, and `--base-path` options.
- Interactive y/N/all prompt on existing files.

#### Documentation
- `README.md` - GitHub landing page.
- `docs/architecture.md` - 3-layer architecture, lifecycle, cost model.
- `docs/usage.md` - Command-by-command reference.
- `docs/walkthrough.md` - End-to-end fictional project demo.
- `docs/troubleshooting.md` - Common issues and fixes.
- `install/README.md` - Install guide.
- `CONTRIBUTING.md` - PR process and dev guidelines.

### Design properties
- **Stack-agnostic** - Agents read `CLAUDE.md` and `constitution.md` at runtime; no hardcoded language, framework, or layer assumptions.
- **Hard gates** - Workflows refuse to proceed without explicit user approval at named checkpoints.
- **Spec as durable memory** - Every workflow produces searchable artifacts under `.specs/<ID>/`.
- **Cost-aware models** - Heavy reasoning (spec, debug, review) on sonnet; mechanical execution and read-only exploration on haiku.

### Known compatibility
- Claude Code CLI: tested with the released version current at January 2026.
- Operating systems: Windows 11 + PowerShell 5.1 / 7.x, macOS 13+, Ubuntu 22.04+.
- Optional MCP servers: Atlassian, Context7, sequential-thinking, GitNexus, MSSQL, Playwright, Tavily.

[Unreleased]: https://github.com/developzoneio/specwright/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/developzoneio/specwright/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/developzoneio/specwright/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/developzoneio/specwright/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/developzoneio/specwright/releases/tag/v1.0.0
