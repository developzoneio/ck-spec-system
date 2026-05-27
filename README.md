# ck-spec-system

> **Spec-driven development workflows for Claude Code.**
> Nine slash commands, five specialized subagents, three guard-rail hooks, nine templates - all under the `ck:` namespace, stack-agnostic, cross-platform, and ready to drop into any project.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blue)](https://docs.claude.com/en/docs/claude-code)
[![Cross-platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](#compatibility-matrix)

---

## Why spec-driven?

Most AI coding assistants are great at producing diff-shaped output. They are less great at remembering **why** a change was made, **what** invariants must hold, or **whether** the fix even addressed the right cause. `ck-spec-system` enforces a thin layer of discipline:

- Every non-trivial change starts with a written spec.
- Workflows have **hard gates** - they refuse to proceed without explicit approval.
- Every artifact lands in `.specs/<ID>/` as durable, searchable memory.
- Heavy reasoning (spec, debug, review) uses `sonnet`; mechanical work (read-only nav, single-task execution) uses `haiku`. Cost stays sane.

The system is **stack-agnostic**. Agents read `CLAUDE.md` and `constitution.md` at runtime; there are no hardcoded language or framework assumptions.

---

## Features

| Capability | What you get |
|---|---|
| **9 slash commands** | `/ck:feature`, `/ck:bug`, `/ck:rca`, `/ck:refactor`, `/ck:perf`, `/ck:spec`, `/ck:explore`, `/ck:review`, `/ck:setup` |
| **5 specialized subagents** | `ck:spec-architect`, `ck:code-explorer`, `ck:debugger`, `ck:implementer`, `ck:reviewer` |
| **3 cross-platform hooks** | `prompt-router`, `spec-gate`, `subagent-retro` (PowerShell + bash) |
| **9 templates** | 4 setup templates + 5 spec templates (feature / bug / refactor / perf / rca) |
| **Cross-platform installer** | `install.ps1` for Windows, `install.sh` for macOS/Linux. Content-hash dedup, timestamped backups, dry-run mode |
| **MCP-friendly** | Tooled out of the box for Atlassian, Context7, sequential-thinking, GitNexus, MSSQL, Playwright, Tavily |
| **Stack-agnostic** | Works for .NET, Node, Python, Go, Rust, anything with a `CLAUDE.md` |
| **Cost-aware** | Sonnet for reasoning, Haiku for execution. Typical feature run ~$2-3 |

---

## Quick install

**Windows (PowerShell 5.1+):**
```powershell
git clone https://github.com/developzoneio/ck-spec-system.git
cd ck-spec-system
.\install\install.ps1 -DryRun   # preview
.\install\install.ps1           # install to $env:USERPROFILE\.claude
```

**macOS / Linux (bash 4+):**
```bash
git clone https://github.com/developzoneio/ck-spec-system.git
cd ck-spec-system
./install/install.sh --dry-run   # preview
./install/install.sh             # install to ~/.claude
```

Then in a real project:
```
cd <your-project>
claude
> /ck:setup
```

That's it. `/ck:setup` will scaffold `CLAUDE.md`, `.specs/`, and `.claude/project-config.json` interactively.

See [`install/README.md`](install/README.md) for advanced options.

---

## Commands

| Command | Type | Hard gates | Purpose |
|---|---|---|---|
| `/ck:feature <ID-or-slug>` | Workflow | 4 | Spec-driven feature: spec -> impact -> plan -> execute -> review -> close |
| `/ck:bug <ID-or-slug>` | Workflow | 5 | Root-cause-first fix: capture -> reproduce -> investigate -> failing test -> minimal fix -> regression |
| `/ck:rca <slug>` | Workflow | 3 | Incident analysis. **Output is the spec - no code change.** |
| `/ck:refactor <slug>` | Workflow | 6 | Coverage-gated restructure: requires >=80% coverage before touching code |
| `/ck:perf <slug>` | Workflow | 8 | Baseline-first optimization: measure -> hypothesize -> apply -> remeasure -> keep or revert |
| `/ck:spec <subcommand>` | Utility | - | Spec registry: list, show, status, link, archive, revive, search, validate, stats |
| `/ck:explore <target-or-query>` | Utility | - | Read-only code navigation, single subagent call, optional save |
| `/ck:review [path / "recent" / "spec ID"]` | Utility | - | Standalone constitution-compliance review with severity tags |
| `/ck:setup` | Utility | - | Idempotent project scaffold (interactive) |

---

## Agents

| Agent | Model | Tools (minimal allowlist) | Role |
|---|---|---|---|
| `ck:spec-architect` | sonnet | Read, Write, Edit, Grep, Glob, Atlassian MCP, Context7 MCP | Create / refine specs, plans, and tasks. Constitution-aware. |
| `ck:code-explorer` | haiku | Read, Grep, Glob, GitNexus MCP | Read-only navigation. Every finding cites `file:line`. |
| `ck:debugger` | sonnet | Read, Grep, Glob, Bash, sequential-thinking, GitNexus, MSSQL (SELECT only), Tavily, Context7 | Hypothesis-tree investigation. Distinguishes proximate vs root cause. |
| `ck:implementer` | haiku | Read, Write, Edit, MultiEdit, Grep, Glob, Bash, Context7 | Executes ONE atomic task. Scope-disciplined, no opportunism. |
| `ck:reviewer` | sonnet | Read, Grep, Glob, sequential-thinking, GitNexus | Severity-tagged review: BLOCK / WARN / SUGGEST / PASS. |

All models use **portable aliases** (`sonnet`, `haiku`) so they auto-update.

---

## Spec-driven structure

Every project that adopts `ck-spec-system` ends up with:

```
<your-repo>/
  CLAUDE.md                     # Thin orchestrator (points to .specs/)
  .claude/
    project-config.json         # Machine-readable config (paths, models, MCP, hooks)
    settings.json               # Claude Code hook wiring
  .specs/
    constitution.md             # Architectural rules + conventions + quality bars
    index.md                    # Registry of all specs with lifecycle states
    FEAT-INV-2501/              # One folder per spec
      00-spec.md                # Why / What / Success criteria / Constitution check
      01-plan.md                # Implementation plan
      02-tasks.md               # Atomic tasks with Files / Layer / Acceptance
      03-decisions.md           # Impact analysis from ck:code-explorer
      04-artifacts/             # Evidence: logs, queries, traces, screenshots
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
|    commands/ck/   agents/ck/   hooks/ck/   templates/ck/     |
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
- **Stack-agnostic** - the same `/ck:feature` workflow runs on .NET, Node, Python, Go, or Rust. Agents read project context at runtime.

Full architecture: [`docs/architecture.md`](docs/architecture.md).

---

## MCP integrations

`ck-spec-system` is designed around the MCP servers most useful for spec-driven work. None are required; agents fall back gracefully.

| MCP server | Used by | Purpose |
|---|---|---|
| **Atlassian** | `ck:spec-architect`, commands | Fetch JIRA ticket context for `<ID>` arguments |
| **Context7** | `ck:spec-architect`, `ck:implementer`, `ck:debugger` | Pull current library docs (no stale training-data examples) |
| **sequential-thinking** | `ck:debugger`, `ck:reviewer` | Structured hypothesis enumeration and verification |
| **GitNexus** | `ck:code-explorer`, `ck:debugger`, `ck:reviewer` | Fast symbol search, callers, call graph |
| **MSSQL** | `ck:debugger` (SELECT/EXPLAIN only) | Inspect schema and query plans during investigation |
| **Playwright** | optional | E2E reproduction for `/ck:bug` |
| **Tavily** | `ck:debugger` | Web search for error signatures / library issues |

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
| Node stack | Node 20+ / TS 5+ | Same `/ck:feature` workflow |
| Python stack | 3.11+ / FastAPI / Django | Same `/ck:feature` workflow |

---

## Documentation

- [`docs/architecture.md`](docs/architecture.md) - 3-layer design, lifecycle, cost model
- [`docs/usage.md`](docs/usage.md) - Command-by-command reference with examples
- [`docs/walkthrough.md`](docs/walkthrough.md) - End-to-end fictional project demo
- [`docs/troubleshooting.md`](docs/troubleshooting.md) - Common issues and fixes
- [`install/README.md`](install/README.md) - Install guide and options
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - PR process and dev guidelines
- [`CHANGELOG.md`](CHANGELOG.md) - Release notes

---

## License

MIT. See [`LICENSE`](LICENSE).

---

## Acknowledgements

Inspired by the spec-driven discipline of long-running software teams, and by the [BMAD method](https://github.com/) for structuring AI-assisted workflows. Built on top of [Claude Code](https://docs.claude.com/en/docs/claude-code) by Anthropic.
