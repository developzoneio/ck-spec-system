# Changelog

All notable changes to **specwright** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `scripts/validate.ps1` + `scripts/validate.sh` - one command that runs every documented engine
  invariant: pure-ASCII scan of `*.ps1`, `bash -n` on `*.sh`, hook-pair parity, agent `model:`
  alias-only check, install-target file counts (real install to a temp base), and a non-empty
  `[Unreleased]` CHANGELOG gate. Exit 1 on any failure.
- `.github/workflows/ci.yml` - runs `validate` on push/PR across a Windows + Ubuntu matrix, plus an
  install -> uninstall round-trip per the `CLAUDE.md` sandbox recipe.
- `install/uninstall.ps1` + `install/uninstall.sh` - removes the five `<base>/<area>/sd/`
  directories with dry-run preview, confirmation prompt (`-Force`/`--force` to skip), and
  per-project cleanup reminders (`.claude/settings.json` hook wiring, `.claude/.hookstate/`).

### Fixed
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

### Planned
- `/sd:setup` codebase scan: pre-fill constitution §1.1/§2.4 and CLAUDE.md conventions from
  sampled source files instead of leaving `<<placeholder>>`s; optional `paths.layers` map in
  project-config.
- Optional `/sd:release` workflow for release-note generation from closed specs.
- Optional `sd-docs-writer` agent for ADR generation.
- Telemetry-free usage analytics (opt-in, local only).

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

[Unreleased]: https://github.com/developzoneio/specwright/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/developzoneio/specwright/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/developzoneio/specwright/releases/tag/v1.0.0
