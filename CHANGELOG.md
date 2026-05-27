# Changelog

All notable changes to **ck-spec-system** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Optional `/ck:release` workflow for release-note generation from closed specs.
- Optional `ck:docs-writer` agent for ADR generation.
- Telemetry-free usage analytics (opt-in, local only).

---

## [1.0.0] - 2026-01-15

Initial public release.

### Added

#### Slash commands (9, all under `ck:` namespace)
- `/ck:feature` - Spec-driven feature workflow with 4 hard gates (spec, plan, review, integration).
- `/ck:bug` - Root-cause-first bug fix workflow with 5 hard gates (symptom, reproduction, root cause, failing test, regression).
- `/ck:rca` - Incident root-cause analysis (output IS the spec; no code change).
- `/ck:refactor` - Coverage-gated refactor workflow with 6 hard gates (spec, coverage threshold, post-test, plan, per-batch tests, holistic review).
- `/ck:perf` - Baseline-first performance workflow with 8 hard gates (target, baseline, hotspot, hypothesis, correctness, keep/revert, regression, final review).
- `/ck:spec` - Spec registry management (list / show / status / link / archive / revive / search / validate / stats / help).
- `/ck:explore` - Read-only code exploration via the `ck:code-explorer` agent.
- `/ck:review` - Standalone constitution-compliance review on a path, recent edits, or a spec.
- `/ck:setup` - Idempotent project scaffold (CLAUDE.md + .claude/ + .specs/ + project-config.json).

#### Subagents (5, cost-aware model assignment)
- `ck:spec-architect` (sonnet) - Creates and refines specs / plans / tasks.
- `ck:code-explorer` (haiku) - Read-only code navigation with citation discipline.
- `ck:debugger` (sonnet) - Hypothesis-tree investigation with sequential-thinking.
- `ck:implementer` (haiku) - Executes ONE atomic task with scope discipline.
- `ck:reviewer` (sonnet) - Severity-tagged compliance review (BLOCK / WARN / SUGGEST / PASS).

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

[Unreleased]: https://github.com/developzoneio/ck-spec-system/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/developzoneio/ck-spec-system/releases/tag/v1.0.0
