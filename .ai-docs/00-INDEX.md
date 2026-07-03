# specwright fix backlog — 2026-07-02 audit

Each numbered document is a self-contained work item: read it, implement it, verify it, open one PR.
All findings were verified against `main` @ `4d4d290` by direct file inspection.

## How to work an item

1. Read the document fully, then re-verify its file:line evidence against the current tree
   (files may have moved since the audit).
2. Follow repo rules in `CLAUDE.md` — especially: hooks ship in bash/powershell pairs, pure ASCII
   in `.ps1` files, stack-agnostic (no hardcoded stack commands), minimal tool allowlists.
3. Every PR adds a line under `## [Unreleased]` in `CHANGELOG.md`.
4. Run `scripts/validate.ps1` (or `validate.sh`) before opening the PR; run the acceptance
   commands listed in the document.
5. Branch naming: `fix/<slug>`, `refactor/<slug>`, `docs/<slug>` per CLAUDE.md.

## Recommended order

### P1 — real bugs (fix first)

| Doc | Title | Area |
|---|---|---|
| [01](01-bug-subagent-retro-ps1-matches-clobber.md) | `$Matches` clobbered — retro hook extracts `"in-progress"` as spec ID | hooks/powershell |
| [02](02-bug-spec-gate-parity-in-progress-detection.md) | spec-gate bash vs PowerShell divergence on in-progress detection | hooks (pair) |
| [03](03-bug-feature-md-subagent-field-names.md) | feature.md passes field names the subagents don't read | commands |
| [04](04-bug-spec-validate-fails-bug-perf.md) | `/sd:spec validate` fails every correct bug/perf spec | commands |
| [05](05-bug-subagent-retro-ps1-debounce-utc.md) | Debounce mixes UTC and local time — off by UTC offset | hooks/powershell |
| [06](06-bug-prompt-router-ps1-keyword-defaults.md) | PS router drops default keywords when config is partial | hooks/powershell |

### P2 — contract and consistency

| Doc | Title | Area |
|---|---|---|
| [07](07-fix-stale-mcp-tool-names.md) | Stale MCP tool names in agents and skills | agents, skills |
| [08](08-fix-stack-agnostic-violations.md) | MSSQL / C# / TS references violate the stack-agnostic rule | agents, commands |
| [09](09-fix-code-explorer-append-contract.md) | code-explorer told to APPEND but has no write tool | agents, commands |
| [10](10-fix-lifecycle-state-jumps.md) | bug/rca/perf workflows skip lifecycle states | commands |
| [11](11-fix-phase0-missing-context-guard.md) | Workflow Phase 0 has no missing-context error path | commands |
| [12](12-refactor-dedup-agent-skill-rules.md) | Rules duplicated between agent bodies and skills | agents, skills, commands |

### P3 — docs and infrastructure

| Doc | Title | Area |
|---|---|---|
| [13](13-docs-readme-roadmap-usage-drift.md) | README/ROADMAP/usage drift after v1.3.0+ ships | docs |
| [14](14-ci-macos-and-hook-smoke-tests.md) | CI: add macOS to matrix + hook smoke tests | CI |
| [15](15-refactor-validate-dynamic-counts.md) | Derive validate counts from the source tree | scripts |
| [16](16-fix-install-sh-hardening.md) | install.sh hardening (set flags, prefix guard, quoting) | install |

Dependency notes: 01/02/05/06 are independent of each other but 14 (CI smoke tests) should land
after them so the new tests pass. 03 may be extended by a fleet-wide field-name convention
(see the follow-up section inside doc 03). 13 is one sweep PR. Multiple PRs touching
`CHANGELOG.md [Unreleased]` will conflict — merge sequentially and rebase.