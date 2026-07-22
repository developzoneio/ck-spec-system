# specwright

> **Spec-driven development workflows for Claude Code.**
> Twelve slash commands, six specialized subagents, three guard-rail hooks, nine templates, seven reusable skills - all under the `sd:` namespace, stack-agnostic, cross-platform, and ready to drop into any project.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blue)](https://docs.claude.com/en/docs/claude-code)
[![Cross-platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](#compatibility-matrix)

---

## Why spec-driven?

Most AI coding assistants are great at producing diff-shaped output. They are less great at remembering **why** a change was made, **what** invariants must hold, or **whether** the fix even addressed the right cause. `specwright` enforces a thin layer of discipline:

- Every non-trivial change starts with a written spec.
- Workflows have **hard gates** - they refuse to proceed without explicit approval.
- Every artifact lands in `.specs/<ID>/` as durable, searchable memory.
- Heavy reasoning (spec, debug, review) uses `sonnet`; mechanical work (read-only nav, single-task execution) uses `haiku`. Cost stays sane.

The system is **stack-agnostic**. Agents read `CLAUDE.md` and `constitution.md` at runtime; there are no hardcoded language or framework assumptions.

---

## Features

| Capability | What you get |
|---|---|
| **12 slash commands** | `/sd:feature`, `/sd:bug`, `/sd:rca`, `/sd:refactor`, `/sd:perf`, `/sd:spec`, `/sd:explore`, `/sd:review`, `/sd:setup`, `/sd:release`, `/sd:adr`, `/sd:verify` |
| **6 specialized subagents** | `sd-spec-architect`, `sd-code-explorer`, `sd-debugger`, `sd-implementer`, `sd-reviewer`, `sd-docs-writer` |
| **3 cross-platform hooks** | `prompt-router`, `spec-gate`, `subagent-retro` (PowerShell + bash) |
| **9 templates** | 4 setup templates + 5 spec templates (feature / bug / refactor / perf / rca) |
| **7 reusable skills** | `sd-severity-taxonomy`, `sd-hypothesis-tree`, `sd-atomic-task-format`, `sd-evidence-citation`, `sd-spec-templates`, `sd-pattern-discipline`, `sd-retro-lessons` |
| **Cross-platform installer** | `install.ps1` for Windows, `install.sh` for macOS/Linux. Content-hash dedup, timestamped backups, dry-run mode |
| **MCP-friendly** | Tooled out of the box for Atlassian, Context7, sequential-thinking, GitNexus, your project's database MCP, Playwright, Tavily |
| **Stack-agnostic** | Works for .NET, Node, Python, Go, Rust, anything with a `CLAUDE.md` |
| **Cost-aware** | Sonnet for reasoning, Haiku for execution. Typical feature run ~$2-3 |

---

## Quick install

**Windows (PowerShell 5.1+):**
```powershell
git clone https://github.com/developzoneio/specwright.git
cd specwright
.\install\install.ps1 -DryRun   # preview
.\install\install.ps1           # install to $env:USERPROFILE\.claude
```

**macOS / Linux (bash 4+):**
```bash
git clone https://github.com/developzoneio/specwright.git
cd specwright
./install/install.sh --dry-run   # preview
./install/install.sh             # install to ~/.claude
```

Then in a real project:
```
cd <your-project>
claude
> /sd:setup
```

That's it. `/sd:setup` will scaffold `CLAUDE.md`, `.specs/`, and `.claude/project-config.json` interactively.

See [`install/README.md`](install/README.md) for advanced options.

### Uninstall

```powershell
.\install\uninstall.ps1 -DryRun   # preview
.\install\uninstall.ps1           # remove the five sd/ engine directories
```

```bash
./install/uninstall.sh --dry-run   # preview
./install/uninstall.sh             # remove the five sd/ engine directories
```

Per-project artifacts (`.specs/`, `.claude/`, project `CLAUDE.md`) remain untouched; see
[`install/README.md`](install/README.md#uninstall) for details.

---

## Commands

| Command | Type | Hard gates | Purpose |
|---|---|---|---|
| `/sd:feature <ID-or-slug>` | Workflow | 3 | Spec-driven feature: spec -> impact -> plan -> execute -> batch review -> close |
| `/sd:bug <ID-or-slug>` | Workflow | 5 | Root-cause-first fix: capture -> reproduce -> investigate -> failing test -> minimal fix -> regression |
| `/sd:rca <slug>` | Workflow | 3 | Incident analysis. **Output is the spec - no code change.** |
| `/sd:refactor <slug>` | Workflow | 6 | Coverage-gated restructure: requires >=80% coverage before touching code |
| `/sd:perf <slug>` | Workflow | 8 | Baseline-first optimization: measure -> hypothesize -> apply -> remeasure -> keep or revert |
| `/sd:spec <subcommand>` | Utility | - | Spec registry: list, show, status, link, archive, revive, search, validate, stats |
| `/sd:explore <target-or-query>` | Utility | - | Read-only code navigation, single subagent call, optional save |
| `/sd:review [path / "recent" / "spec ID"]` | Utility | - | Standalone constitution-compliance review with severity tags |
| `/sd:setup` | Utility | 2 | Idempotent project scaffold (interactive) |
| `/sd:release [version]` | Utility | 1 | Release notes from `done` specs -> Keep-a-Changelog sections, then archive them |
| `/sd:adr <spec-ID \| "decision title">` | Utility | 1 | Author an ADR from a spec's decisions under `.specs/_adr/` |
| `/sd:verify <spec-ID>` | Utility | - | Verify criterion -> task -> test traceability; writes the close-out gate artifact |

---

## Agents

| Agent | Model | Tools (minimal allowlist) | Role |
|---|---|---|---|
| `sd-spec-architect` | sonnet | Read, Write, Edit, Grep, Glob, Atlassian MCP, Context7 MCP | Create / refine specs, plans, and tasks. Constitution-aware. |
| `sd-code-explorer` | haiku | Read, Grep, Glob, GitNexus MCP | Read-only navigation. Every finding cites `file:line`. |
| `sd-debugger` | sonnet | Read, Grep, Glob, Bash, sequential-thinking, GitNexus, Tavily, Context7 | Hypothesis-tree investigation. Distinguishes proximate vs root cause. |
| `sd-implementer` | haiku | Read, Write, Edit, MultiEdit, Grep, Glob, Bash, Context7 | Executes ONE atomic task. Scope-disciplined, no opportunism. |
| `sd-reviewer` | sonnet | Read, Grep, Glob, sequential-thinking, GitNexus | Severity-tagged review: BLOCK / WARN / SUGGEST / PASS. |
| `sd-docs-writer` | sonnet | Read, Write, Glob, Grep | Authors one MADR-style ADR from a spec's decisions. Writes only the ADR file. |

All models use **portable aliases** (`sonnet`, `haiku`) so they auto-update.

---

## Skills

Skills are shared markdown rules that agents reference via frontmatter. They live in `~/.claude/skills/sd/` (one folder per skill, each with a `SKILL.md`). Pulling rules out of agent bodies and into skills keeps agent prompts smaller and lets multiple agents share the same canonical rule without copy-paste drift.

| Skill | Used by | Purpose |
|---|---|---|
| `sd-severity-taxonomy` | `sd-reviewer` | BLOCK / WARN / SUGGEST / PASS severity rules and the mandatory review output format. |
| `sd-hypothesis-tree` | `sd-debugger` | Enumerate-and-verify protocol with the 5 mental models, score formula, and proximate-vs-root "why" ladder. |
| `sd-atomic-task-format` | `sd-spec-architect`, `sd-implementer` | The atomic task block (11 required fields, including `Pattern refs`), canonical enums (`Step type`, `Complexity`, `Reversibility`), and atomicity rules. |
| `sd-evidence-citation` | `sd-code-explorer`, `sd-debugger`, `sd-reviewer`, `sd-docs-writer` | Citation discipline — every finding cites `file:line`. Snippet length, grouping, and what counts as evidence. |
| `sd-spec-templates` | `sd-spec-architect` | Per-template authoring rules (feature / bug / refactor / perf / rca), including which cross-phase fields to leave empty. |
| `sd-pattern-discipline` | `sd-spec-architect`, `sd-implementer`, `sd-reviewer` | Pattern discovery and adherence — new code mirrors cited precedents (`Pattern refs`); existing utilities are reused, not duplicated. |

Agents declare the skills they apply via a `skills:` list in their frontmatter, e.g.:

```yaml
---
name: sd-reviewer
skills:
  - sd-severity-taxonomy
  - sd-evidence-citation
---
```

---

## Spec-driven structure

Every project that adopts `specwright` ends up with:

```
<your-repo>/
  CLAUDE.md                     # Thin orchestrator (points to .specs/)
  .claude/
    project-config.json         # Machine-readable config (paths, models, MCP, hooks)
    settings.json               # Claude Code hook wiring
  .specs/
    constitution.md             # Architectural rules + conventions + quality bars
    index.md                    # Registry of all specs with lifecycle states
    _explorations/              # Scratchpad for /sd:explore saves
    _reviews/                   # Scratchpad for /sd:review saves
    _adr/                       # Architecture decision records from /sd:adr
    FEAT-INV-2501/              # One folder per spec
      00-spec.md                # Why / What / Success criteria / Constitution check
      01-plan.md                # Implementation plan
      02-tasks.md               # Atomic tasks with Files / Layer / Acceptance
      03-decisions.md           # Impact analysis from sd-code-explorer
      04-artifacts/             # Evidence: logs, queries, traces, screenshots, ticket snapshots
      05-retro.md               # Post-execution retro
    BUG-1247/
      ...
    REF-extract-pricing-20260112/
      ...
    PERF-search-endpoint-20260114/
      ...
    RCA-payment-outage-20260108/
      ...
```

A spec is not "documentation you write afterwards". It is the **input contract** to every subagent invocation.

---

## Architecture highlights

```
+--------------------------------------------------------------+
|  User scope  (~/.claude/)            installed once          |
|    commands/sd/   agents/sd/   hooks/sd/                     |
|    templates/sd/  skills/sd/                                 |
+--------------------------------------------------------------+
                            |
                            v
+--------------------------------------------------------------+
|  Project scope  (<repo>/)            per-project context     |
|    CLAUDE.md   .claude/   .specs/                            |
+--------------------------------------------------------------+
                            |
                            v
+--------------------------------------------------------------+
|  Runtime  (Claude Code session)                              |
|    main thread <-> subagents <-> hooks                       |
+--------------------------------------------------------------+
```

- **3 layers** - generic engine (user scope), per-project context (project scope), live conversation (runtime). The engine never changes per project; context comes from `CLAUDE.md` + `constitution.md` + `project-config.json`.
- **Hard gates** - workflows refuse to proceed without explicit approval at named checkpoints (spec approval, reproduction confirmed, baseline measured, plan approval, review pass, etc.).
- **Cost-aware models** - `sonnet` for reasoning agents (architect, debugger, reviewer); `haiku` for execution agents (implementer, explorer). Override per-task when needed.
- **Stack-agnostic** - the same `/sd:feature` workflow runs on .NET, Node, Python, Go, or Rust. Agents read project context at runtime.

Full architecture: [`docs/architecture.md`](docs/architecture.md).

---

## MCP integrations

`specwright` is designed around the MCP servers most useful for spec-driven work. None are required; agents fall back gracefully.

| MCP server | Used by | Purpose |
|---|---|---|
| **Atlassian** | `sd-spec-architect`, commands | Fetch JIRA ticket context for `<ID>` arguments; snapshot ticket + related tickets + linked Confluence pages to `04-artifacts/ticket/` |
| **Context7** | `sd-spec-architect`, `sd-implementer`, `sd-debugger` | Pull current library docs (no stale training-data examples) |
| **sequential-thinking** | `sd-debugger`, `sd-reviewer` | Structured hypothesis enumeration and verification |
| **GitNexus** | `sd-code-explorer`, `sd-debugger`, `sd-reviewer` | Fast symbol search, callers, call graph |
| **Database** (project-provided, e.g. `mssql`, `postgres`) | `sd-debugger` (SELECT/EXPLAIN only) | Inspect schema and query plans during investigation |
| **Playwright** | optional | E2E reproduction for `/sd:bug` |
| **Tavily** | `sd-debugger` | Web search for error signatures / library issues |

Configure per project in `.claude/project-config.json` under the `mcp` section.

---

## Compatibility matrix

| Component | Tested on | Notes |
|---|---|---|
| Claude Code CLI | Latest as of Jan 2026 | Hook contract: `UserPromptSubmit`, `PreToolUse`, `SubagentStop` |
| Windows 11 | PowerShell 5.1 and 7.x | PS 5.1 reads UTF-8 as CP1252 - hooks are pure ASCII |
| macOS 13+ | bash 4+ via Homebrew | `stat -f %m` syntax supported |
| Ubuntu 22.04+ | bash 5 | `stat -c %Y` syntax supported |
| jq | 1.6+ | Optional. Bash hooks exit 0 if missing. |
| .NET stack | ASP.NET Core 8 | Stack-agnostic - .NET is just one example |
| Node stack | Node 20+ / TS 5+ | Same `/sd:feature` workflow |
| Python stack | 3.11+ / FastAPI / Django | Same `/sd:feature` workflow |

---

## Documentation

- [`docs/architecture.md`](docs/architecture.md) - 3-layer design, lifecycle, cost model
- [`docs/usage.md`](docs/usage.md) - Command-by-command reference with examples
- [`docs/walkthrough.md`](docs/walkthrough.md) - End-to-end fictional project demo
- [`docs/troubleshooting.md`](docs/troubleshooting.md) - Common issues and fixes
- [`install/README.md`](install/README.md) - Install guide and options
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - PR process and dev guidelines
- [`CHANGELOG.md`](CHANGELOG.md) - Release notes
- [`ROADMAP.md`](ROADMAP.md) - Planned and exploratory work

---

## Roadmap

Forward-looking work lives in [`ROADMAP.md`](ROADMAP.md). Highlights:

- **Near-term** - GitHub Issue auto-fetch (`gh issue view`) to match the existing JIRA snapshot path.
- **Planned** - nothing queued right now.
- **Exploratory** - local-only, opt-in usage analytics.

Shipped work is in [`CHANGELOG.md`](CHANGELOG.md).

---

## License

MIT. See [`LICENSE`](LICENSE).

---

## Acknowledgements

Inspired by the spec-driven discipline of long-running software teams, and by the [BMAD method](https://github.com/) for structuring AI-assisted workflows. Built on top of [Claude Code](https://docs.claude.com/en/docs/claude-code) by Anthropic.
