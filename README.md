# specwright

> **Claude Code cannot touch your code until a spec is approved.**
> 14 slash commands, 6 specialized subagents, 3 guard-rail hooks, 10 templates, 9 reusable skills - all under the `sd:` namespace, stack-agnostic, cross-platform, and ready to drop into any project.

[![Release](https://img.shields.io/github/v/release/developzoneio/specwright)](https://github.com/developzoneio/specwright/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blue)](https://docs.claude.com/en/docs/claude-code)
[![Cross-platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](#compatibility-matrix)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/developzone)

---

## What it looks like

You ask for a feature. Nothing gets written yet - the workflow drafts a spec and **stops**:

```
> /sd:feature todo-priority

Phase 1  sd-spec-architect -> .specs/FEAT-todo-priority/00-spec.md

  Why               A todo carries no urgency signal. Every caller that needs
                    ordering keeps that data outside the library, beyond the
                    reach of the library's own validation.
  Success criteria  AC-1 .. AC-9, each requiring a file:line or test citation
  Out of scope      6 items, incl. "no setPriority path in this iteration"
  Constitution      1.1  Layer rules       OK - validation stays in Domain
                    2.3  Error handling    OK - one class per failure mode
                    3    Quality bars      integration test MANDATORY
                                           (change crosses Domain/Application)
                    6    Forbidden         1 exception, scoped and recorded

  Gate 1 - Spec approval   [STOP]

  Approve spec FEAT-todo-priority? (yes / refine <feedback> / abort)
_
```

That STOP is not a suggestion. Until you answer, the `spec-gate` hook denies every
`Edit` / `Write` call at the tool layer - so the model cannot quietly start coding while
you are still reading.

After the work is done, the review gate is just as blunt:

```
  Gate 3 - Integration + review pass   [STOP]

  Tests    18/18 pass (8 original + 6 Domain + 4 Application), original 8 unedited
  Review   0 BLOCK / 0 WARN / 5 SUGGEST / 7 PASS
           S1  .specs/constitution.md:143 - DTO bullet now inconsistent
               with the refreshed Aggregate-root bullet at :141
           S2  the approved constitution exception has no ADR of its own,
               so its provenance dies when this spec is archived

  All clean for FEAT-todo-priority? (yes / address findings / abort)
_
```

Every artifact above is real and committed. Read the whole run at
[`examples/fixture-project/.specs/FEAT-todo-priority/`](examples/fixture-project/.specs/FEAT-todo-priority/) -
spec, plan, tasks, decisions, retro, verify - for an actual change to a runnable project.

---

## Why spec-driven?

Most AI coding assistants are great at producing diff-shaped output. They are less great at remembering **why** a change was made, **what** invariants must hold, or **whether** the fix even addressed the right cause. `specwright` enforces a thin layer of discipline:

- Every non-trivial change starts with a written spec.
- Workflows have **hard gates** - they refuse to proceed without explicit approval.
- Every artifact lands in `.specs/<ID>/` as durable, searchable memory.
- Heavy reasoning (spec, debug, review) uses `sonnet`; mechanical work (read-only nav, single-task execution) uses `haiku`. Cost stays sane.

The system is **stack-agnostic**. Agents read `CLAUDE.md` and `constitution.md` at runtime; there are no hardcoded language or framework assumptions.

### How this differs from prompt-level discipline

Plenty of tools ask the model nicely to plan first. Four things here are structural instead:

- **Gates halt the workflow.** Silence is not approval - the phase does not advance without an explicit answer. HARD gates (bug reproduction, perf baseline) have no override path at all.
- **The block lives outside the prompt.** `spec-gate` is a `PreToolUse` hook: with no in-progress spec, `Edit` / `Write` is denied by the CLI, not discouraged by instructions. A prompt can be argued with; a tool-level deny cannot.
- **The reviewer physically cannot auto-fix.** Its tool allowlist contains no write tools, so findings must route back through a fresh implementer call. The role separation is enforced by configuration, not by asking the model to behave.
- **Specs are inputs, not write-ups.** `00-spec.md` through `06-verify.md` are what each subagent is handed on invocation - so they cannot rot into after-the-fact documentation nobody reads.

---

## Quickstart

Goal: your first spec in under 5 minutes.

**Requirements:** the [Claude Code CLI](https://docs.claude.com/en/docs/claude-code), installed and authenticated. PowerShell 5.1+ on Windows, or bash 4+ on macOS/Linux. Node 20+ only if you want to run the bundled example.

**1. Install the engine.**

```powershell
# Windows (PowerShell 5.1+)
git clone https://github.com/developzoneio/specwright.git
cd specwright
.\install\install.ps1 -DryRun   # preview
.\install\install.ps1           # install to $env:USERPROFILE\.claude
```

```bash
# macOS / Linux (bash 4+)
git clone https://github.com/developzoneio/specwright.git
cd specwright
./install/install.sh --dry-run   # preview
./install/install.sh             # install to ~/.claude
```

**2. Scaffold a project.** In any repo:

```
cd <your-project>
claude
> /sd:setup
```

`/sd:setup` interactively generates `CLAUDE.md`, `.specs/` (constitution + index), and `.claude/project-config.json`. It is idempotent - safe to re-run.

**3. Run a real spec-driven change.**

```
> /sd:feature <slug>
```

The workflow walks spec -> impact -> plan -> execute -> review, stopping at Gate 1 for your sign-off. That STOP is your first spec.

**No project handy?** Use the bundled one - zero dependencies, Node's built-in test runner:

```bash
cd examples/fixture-project
node --test          # if this passes, your environment is ready
claude
> /sd:feature <slug>
```

---

## Features

| Capability | What you get |
|---|---|
| **14 slash commands** | `/sd:feature`, `/sd:bug`, `/sd:rca`, `/sd:refactor`, `/sd:perf`, `/sd:port`, `/sd:spec`, `/sd:explore`, `/sd:review`, `/sd:setup`, `/sd:release`, `/sd:adr`, `/sd:verify`, `/sd:status` |
| **6 specialized subagents** | `sd-spec-architect`, `sd-code-explorer`, `sd-debugger`, `sd-implementer`, `sd-reviewer`, `sd-docs-writer` |
| **3 cross-platform hooks** | `prompt-router`, `spec-gate`, `subagent-retro` (PowerShell + bash) |
| **10 templates** | 4 setup templates + 6 spec templates (feature / bug / refactor / perf / rca / port) |
| **9 reusable skills** | Shared rule packs referenced from agent frontmatter - severity taxonomy, hypothesis tree, atomic task format, evidence citation, and more |
| **Cross-platform installer** | `install.ps1` for Windows, `install.sh` for macOS/Linux. Content-hash dedup, timestamped backups, dry-run mode |
| **MCP-friendly** | Tooled out of the box for Atlassian, Context7, sequential-thinking, GitNexus, your project's database MCP, Playwright, Tavily |
| **Stack-agnostic** | Works for .NET, Node, Python, Go, Rust, anything with a `CLAUDE.md` |
| **Cost-aware** | Sonnet for reasoning, Haiku for execution. `/sd:status` reports your own per-workflow cost from the local metrics log |

---

## Commands

| Command | Type | Hard gates | Purpose |
|---|---|---|---|
| `/sd:feature <ID-or-slug>` | Workflow | 3 | Spec-driven feature: spec -> impact -> plan (complexity triage) -> execute -> batch review -> close |
| `/sd:bug <ID-or-slug>` | Workflow | 5 | Root-cause-first fix: capture -> reproduce -> investigate -> failing test -> minimal fix -> regression |
| `/sd:rca <slug>` | Workflow | 3 | Incident analysis. **Output is the spec - no code change.** |
| `/sd:refactor <slug>` | Workflow | 6 | Coverage-gated restructure: requires >=80% coverage before touching code |
| `/sd:perf <slug>` | Workflow | 8 | Baseline-first optimization: measure -> hypothesize -> apply -> remeasure -> keep or revert |
| `/sd:port <slug> --from <source> --scope <scope>` | Workflow | 6 | Fidelity-first port: bridge -> freeze -> tables -> pin -> execute -> justified-diff parity |
| `/sd:spec <subcommand>` | Utility | - | Spec registry: list, show, status, link, archive, revive, search, validate, stats |
| `/sd:explore <target-or-query>` | Utility | - | Read-only code navigation, single subagent call, optional save |
| `/sd:review [path / "recent" / "spec ID"]` | Utility | - | Standalone constitution-compliance review with severity tags |
| `/sd:setup` | Utility | 2 | Idempotent project scaffold (interactive) |
| `/sd:release [version]` | Utility | 1 | Release notes from `done` specs -> Keep-a-Changelog sections, then archive them |
| `/sd:adr <spec-ID \| "decision title">` | Utility | 1 | Author an ADR from a spec's decisions under `.specs/_adr/` |
| `/sd:verify <spec-ID>` | Utility | - | Verify criterion -> task -> test traceability; writes the close-out gate artifact |
| `/sd:status` | Utility | - | Read-only summary of the metrics log + spec registry: in progress, gate activity, friction |

Command-by-command reference with worked examples: [`docs/usage.md`](docs/usage.md).

---

## Agents and skills

Commands do not do the work themselves - they orchestrate 6 subagents, each with a focused role and a **minimal tool allowlist** that enforces that role structurally.

| Agent | Model | Role |
|---|---|---|
| `sd-spec-architect` | sonnet | Creates and refines specs, plans, and atomic tasks. Constitution-aware. |
| `sd-code-explorer` | haiku | Read-only navigation. Every finding cites `file:line`. |
| `sd-debugger` | sonnet | Hypothesis-tree investigation. Distinguishes proximate from root cause. |
| `sd-implementer` | haiku | Executes ONE atomic task. Scope-disciplined, no opportunism. |
| `sd-reviewer` | sonnet | Severity-tagged review: BLOCK / WARN / SUGGEST / PASS. **No write tools.** |
| `sd-docs-writer` | sonnet | Authors one MADR-style ADR from a spec's decisions. Writes only the ADR file. |

Models use **portable aliases** (`sonnet`, `haiku`) so they auto-update - never a pinned model ID.

Cross-cutting rules live in **9 skills**: markdown rule packs that agents load via a `skills:` list in their frontmatter, rather than copy-pasting the same rule into every agent body that needs it.

```yaml
---
name: sd-reviewer
model: sonnet
skills:
  - sd-severity-taxonomy
  - sd-evidence-citation
---
```

Full agent tool allowlists, the command -> agent routing map, and the complete skill catalogue: [`docs/architecture.md`](docs/architecture.md).

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
    PORT-order-intake-20260209/
      00-spec.md                # Donor provenance / fidelity tables / Success criteria
      04-artifacts/
        source/                 # Frozen donor snapshot - protected once frozen
          MANIFEST.md           # Per-file donor path, commit, hash, member line ranges
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
| Claude Code CLI | Latest as of Aug 2026 | Hook contract: `UserPromptSubmit`, `PreToolUse`, `SubagentStop` |
| Windows 11 | PowerShell 5.1 and 7.x | PS 5.1 reads UTF-8 as CP1252 - hooks are pure ASCII |
| macOS 13+ | bash 4+ via Homebrew | `stat -f %m` syntax supported |
| Ubuntu 22.04+ | bash 5 | `stat -c %Y` syntax supported |
| jq | 1.6+ | Optional. Bash hooks exit 0 if missing. |
| .NET stack | ASP.NET Core 8 | Stack-agnostic - .NET is just one example |
| Node stack | Node 20+ (plain JS) | Demonstrated end-to-end in [`examples/fixture-project/`](examples/fixture-project/) - real `/sd:feature` run committed, not just asserted. TS not yet exercised. |
| Python stack | 3.11+ / FastAPI / Django | Same `/sd:feature` workflow - not yet demonstrated with a committed example |

---

## Install options and uninstall

The [Quickstart](#quickstart) covers the common path. For custom install roots, selective areas, and backup behavior, see [`install/README.md`](install/README.md).

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

## Documentation

- [`docs/architecture.md`](docs/architecture.md) - 3-layer design, agent routing, skills, lifecycle, cost model
- [`docs/usage.md`](docs/usage.md) - Command-by-command reference with examples
- [`docs/walkthrough.md`](docs/walkthrough.md) - End-to-end fictional project demo (illustrative prose)
- [`docs/troubleshooting.md`](docs/troubleshooting.md) - Common issues and fixes
- [`docs/contract-lint.md`](docs/contract-lint.md) - How cross-file contracts between commands, agents, and skills are machine-checked
- [`install/README.md`](install/README.md) - Install guide and options
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - PR process and dev guidelines
- [`CHANGELOG.md`](CHANGELOG.md) - Release notes
- [`ROADMAP.md`](ROADMAP.md) - Planned and exploratory work

### Runnable examples

- [`examples/fixture-project/`](examples/fixture-project/) - End-to-end **runnable** non-.NET project with a committed worked spec (`FEAT-todo-priority`, `00-spec.md` through `06-verify.md`)
- [`examples/port-parity-fixture/`](examples/port-parity-fixture/) - Donor/host pair exercising the `/sd:port` fidelity gates
- [`examples/spec-lint-fixture/`](examples/spec-lint-fixture/) - Deliberately malformed specs that `/sd:spec validate` must catch

---

## Roadmap

Shipped work is in [`CHANGELOG.md`](CHANGELOG.md) - the latest release is
[v1.5.0](https://github.com/developzoneio/specwright/releases). Forward-looking work lives in
[`ROADMAP.md`](ROADMAP.md):

- **Near-term** - GitHub Issue auto-fetch (`gh issue view`) to match the existing JIRA snapshot path.
- **Exploratory** - local-only, opt-in usage analytics.

Have a workflow you wish existed? [Open an issue](https://github.com/developzoneio/specwright/issues/new) - the roadmap is shaped by what people actually hit.

---

## Support

Enjoying `specwright`? A coffee goes a long way toward keeping it maintained -
[buy me one on Ko-fi](https://ko-fi.com/developzone). Thank you!

A star on the repo helps others find it. Using `specwright` at work? [Open an issue](https://github.com/developzoneio/specwright/issues/new) and let us know - we'd love to list you.

---

## License

MIT. See [`LICENSE`](LICENSE).

---

## Acknowledgements

Inspired by the spec-driven discipline of long-running software teams, and by the [BMAD method](https://github.com/bmad-code-org/BMAD-METHOD) for structuring AI-assisted workflows. Built on top of [Claude Code](https://docs.claude.com/en/docs/claude-code) by Anthropic.
