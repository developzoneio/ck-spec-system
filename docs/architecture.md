# Architecture

specwright is a thin layer on top of Claude Code that enforces spec-driven development workflows. This document explains the moving parts and why each one exists.

---

## Three-layer architecture

```
+--------------------------------------------------------------------+
|  Layer 1 - USER scope  (~/.claude/, installed once)                |
|                                                                    |
|    commands/sd/    12 workflow definitions                         |
|    agents/sd/      6 subagent prompt files                         |
|    hooks/sd/       3 cross-platform hook scripts                   |
|    templates/sd/   4 setup + 5 spec templates                      |
|    skills/sd/      6 reusable rule packs (referenced by agents)    |
|                                                                    |
|  Generic engine. Never changes per project. Updated by re-running  |
|  the installer.                                                    |
+--------------------------------------------------------------------+
                              |
                              | reads at runtime
                              v
+--------------------------------------------------------------------+
|  Layer 2 - PROJECT scope  (<repo>/, per project)                   |
|                                                                    |
|    CLAUDE.md                  Thin orchestrator                    |
|    .specs/constitution.md     Project rules + conventions          |
|    .specs/index.md            Spec registry                        |
|    .specs/<ID>/...            Per-spec folder                      |
|    .claude/project-config.json   Paths, commands, models, MCP      |
|    .claude/settings.json         Hook wiring                       |
|                                                                    |
|  Per-project context. Tells the engine WHAT the project is.        |
+--------------------------------------------------------------------+
                              |
                              | invoked during
                              v
+--------------------------------------------------------------------+
|  Layer 3 - RUNTIME  (Claude Code session)                          |
|                                                                    |
|    main thread  <-->  subagents  <-->  hooks                       |
|         ^                                                          |
|         |                                                          |
|         +-- writes to .specs/<ID>/ as workflow progresses          |
|                                                                    |
|  Live conversation. Reads layer 1 + layer 2; writes to layer 2.    |
+--------------------------------------------------------------------+
```

The split exists so the **engine is generic** (one install handles every project) while **per-project context** lives in version control alongside the code it governs. When a teammate clones a repo, the constitution + spec history travels with the code; they only need to install the engine once.

---

## Commands as workflow definitions

Each command is a markdown file with YAML frontmatter and a phased plan. The plan is read by Claude Code's main thread; it is not executable code. Phases follow a pattern:

```
Phase 0 - Bootstrap         (always: read CLAUDE.md + constitution + config)
Phase 1 - <first concern>   [Gate 1]
Phase 2 - <second concern>  [Gate 2]
...
Phase N - Close-out
```

A **gate** is a checkpoint where the workflow refuses to proceed without explicit user approval. Silence is not approval. Skipping a gate requires logging a constitution exception to the spec's retro.

The 5 workflow commands have these gate counts:

| Workflow | Gates | Why |
|---|---|---|
| `/sd:feature` | 3 | spec, plan, per-task review, integration |
| `/sd:bug` | 5 | symptom, reproduction (HARD), root cause, failing test, regression |
| `/sd:rca` | 3 | evidence, hypotheses, root cause |
| `/sd:refactor` | 6 | spec, coverage, post-test, plan, per-batch tests, holistic review |
| `/sd:perf` | 8 | target, baseline (HARD), hotspot, hypothesis, correctness, keep/revert, regression, final review |

Gates marked HARD (e.g. bug reproduction, perf baseline) have no override path. The point is to force discipline at the moments when shortcuts are most tempting.

---

## Agents as specialized subagents

Each subagent has a focused role, a minimal tool allowlist, and a model assignment chosen for cost-effectiveness.

| Agent | Model | Tool surface | Role |
|---|---|---|---|
| `sd-spec-architect` | sonnet | Read/Write/Edit + Grep/Glob + Atlassian + Context7 | Authors specs, plans, tasks. Constitution-aware. |
| `sd-code-explorer` | haiku | Read/Grep/Glob + GitNexus | Read-only navigation. Every finding cites `file:line`. |
| `sd-debugger` | sonnet | Read/Grep/Glob/Bash + sequential-thinking + GitNexus + Tavily + Context7 | Hypothesis-tree investigation. Distinguishes proximate vs root cause. |
| `sd-implementer` | haiku | Read/Write/Edit/MultiEdit/Grep/Glob/Bash + Context7 | Executes ONE atomic task with scope discipline. |
| `sd-reviewer` | sonnet | Read/Grep/Glob + sequential-thinking + GitNexus | Severity-tagged review (🔴 BLOCK / 🟠 WARN / 🟡 SUGGEST / 🟢 PASS). Cannot write. |
| `sd-docs-writer` | sonnet | Read/Write/Glob/Grep + sd-evidence-citation | Authors one MADR-style ADR from a spec's decisions. Writes only the ADR file. |

**Tool allowlists are minimal by design.** The reviewer cannot fix code because it has no write tools. The explorer cannot suggest fixes for the same reason. This is enforced by the engine, not by prose discipline alone.

**Models use portable aliases** (`sonnet`, `haiku`) so they auto-update with the latest Anthropic model. Full model IDs would pin agents to a specific version and require code changes when the model is superseded.

---

## Command -> agent routing

Commands do not do the work themselves - they orchestrate subagents through phased gates. This is the
fan-out each command performs (left to right = invocation order; `(xN)` = once per atomic task / hotspot):

```
/sd:feature   -> spec-architect -> code-explorer -> spec-architect -> implementer (xN) -> reviewer
/sd:bug       -> spec-architect -> debugger (enumerate / verify) -> implementer -> reviewer
/sd:refactor  -> spec-architect -> code-explorer -> implementer (coverage) -> spec-architect -> implementer (xN) -> reviewer
/sd:perf      -> spec-architect -> debugger (hotspot / verify) -> implementer (xN) -> reviewer
/sd:rca       -> spec-architect -> debugger (enumerate / verify)        [no code change - output IS the spec]
/sd:explore   -> code-explorer
/sd:review    -> reviewer
/sd:adr       -> docs-writer
/sd:spec      -> (none - pure file ops on .specs/)
/sd:setup     -> (none - scaffolds CLAUDE.md / .specs/ / .claude/)
/sd:release   -> (none - pure file ops; mirrors /sd:spec)
/sd:verify    -> (none - pure file ops; traceability check + gate artifact)
```

Four commands invoke no subagent at all (`/sd:spec`, `/sd:setup`, `/sd:release`, `/sd:verify`) -
they are deterministic file operations the main thread performs directly. The rest share one
backbone: the architect frames the spec, an investigator (explorer or debugger) gathers evidence,
the implementer makes the change one atomic task at a time, and the reviewer gates the result. The
reviewer has no write tools, so the loop cannot auto-fix - findings always route back through a
fresh implementer call.

---

## Agent skills

Skills are markdown rule packs that agents reference from their frontmatter. They live in `~/.claude/skills/sd/<skill-name>/SKILL.md`. The rule body is loaded into the agent's context at runtime alongside the agent prompt itself.

The split exists for three reasons:

1. **De-duplication.** `sd-evidence-citation` is used by `sd-code-explorer`, `sd-debugger`, `sd-reviewer`, and `sd-docs-writer`. Without skills, the same `file:line` citation rule would be copy-pasted into four agent files and drift over time. With skills, it lives in one place.
2. **Smaller agent bodies.** The reviewer prompt no longer carries the full severity taxonomy inline; it points at `sd-severity-taxonomy`. Body size goes down; lookup discipline stays the same.
3. **Auditability.** A reader can open one `SKILL.md` and see exactly what rules every agent follows for that concern — without grepping across 6 agent files.

| Skill | Used by | Purpose |
|---|---|---|
| `sd-severity-taxonomy` | `sd-reviewer` | Severity levels + per-severity rules + mandatory output markdown. |
| `sd-hypothesis-tree` | `sd-debugger` | Enumerate / verify protocol, the 5 mental models, score formula `(L × I) / C`, proximate-vs-root ladder. |
| `sd-atomic-task-format` | `sd-spec-architect`, `sd-implementer` | The task block (9 required fields + `Pattern refs`) + canonical enums (`Step type`, `Complexity`, `Reversibility`). |
| `sd-evidence-citation` | `sd-code-explorer`, `sd-debugger`, `sd-reviewer`, `sd-docs-writer` | `file:line` discipline, snippet length, evidence taxonomy, grouping. |
| `sd-spec-templates` | `sd-spec-architect` | Per-template authoring rules; which cross-phase fields to leave empty. |
| `sd-pattern-discipline` | `sd-spec-architect`, `sd-implementer`, `sd-reviewer` | Pattern discovery and adherence: precedent sampling, `Pattern refs` authoring/following, conformance review. |

Agents declare the skills they apply via a `skills:` list in YAML frontmatter:

```yaml
---
name: sd-debugger
model: sonnet
skills:
  - sd-hypothesis-tree
  - sd-evidence-citation
---
```

A skill is **not** an agent. It cannot be invoked directly, has no tools of its own, and produces no output on its own. It is a context block the agent inherits.

---

## Hooks as context injection, guardrails, and recording

Three hooks ship in cross-platform pairs (PowerShell + bash). Each plays one of three roles:
`prompt-router` injects context, `spec-gate` guards edits (and records), `subagent-retro`
reminds about stale retros (and records).

### `prompt-router` (`UserPromptSubmit`)

Runs on every user prompt. Reads the prompt and the project config, then emits a `<context-router>` block when it detects:
- Workflow keywords (`bug`, `feature`, `refactor`, `perf`, `rca`).
- Ticket IDs matching the configured pattern.
- Specs currently in-progress (from `.specs/index.md`).

The block is injected into the prompt as additional context, so Claude knows there's an active spec or a likely workflow without the user having to remind it.

### `spec-gate` (`PreToolUse`, Edit / Write / MultiEdit)

Runs before any code-editing tool. Decides:
- Editing a path in `paths.protected`? -> block (constitution, index, license).
- Editing an allow-listed path (.specs/, .claude/, tests/, *.md, *.json, etc.)? -> allow.
- Editing a code file (cs/ts/py/rs/go/etc.) with no in-progress spec? -> block or warn (configurable).

This catches the common failure mode where the user (or Claude) jumps straight to editing code without creating a spec first.

Alongside guarding, `spec-gate` also **records**: every gate decision (verify / protected /
code-edit) and every `.specs/index.md` lifecycle transition it observes is appended as one JSON
line to `.specs/_metrics/events.jsonl`. Recording is purely observational - it never alters a
gate decision, only measures it after the fact. See the event log section below for the schema.

**Block output schema (dual-format).** When `spec-gate` denies a tool call, it emits a single JSON object that carries **both** the new and the legacy schema fields so it works across Claude Code CLI versions:

```json
{
  "decision": "block",
  "reason": "spec-gate: editing code file 'src/foo.cs' but no in-progress spec is recorded ...",
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "spec-gate: editing code file 'src/foo.cs' but no in-progress spec is recorded ..."
  }
}
```

- New schema (`hookSpecificOutput.permissionDecision = "deny"`) is read by recent CLI builds.
- Legacy schema (`decision = "block"`) is read by older CLI builds.
- Both are harmless to the other reader. No version probing required.

### `subagent-retro` (`SubagentStop`)

Runs after every subagent invocation. If any in-progress spec has a `05-retro.md` older than `retroStaleMinutes`, emits a `<retro-reminder>` block. Debounced per session via `.claude/.hookstate/`.

`subagent-retro` also **records**: it appends one `subagent_stop` event per in-progress spec to
`.specs/_metrics/events.jsonl`, carrying the same stale/missing-retro count the reminder is based
on. Recording happens regardless of debounce - debounce only suppresses the user-facing reminder,
not the measurement.

### Event log (`.specs/_metrics/events.jsonl`)

`spec-gate` and `subagent-retro` are the two hooks that record. Each appends one JSON object per
line (append-only, UTF-8, LF-terminated) to `.specs/_metrics/events.jsonl`, in a fixed key order so
the PowerShell and bash implementations produce byte-comparable lines:

| Field | Present | Values |
|---|---|---|
| `ts` | always | `yyyy-MM-ddTHH:mm:ssZ` - whole-second UTC, the same format used by the `subagent-retro` debounce state file |
| `spec_id` | always | `FEAT-x` / `BUG-x` / ... , or `-` when no spec is in scope |
| `phase` | always | lifecycle status of `spec_id` (`draft` / `approved` / `in-progress` / `done`), or `-` |
| `event` | always | `gate` \| `spec_transition` \| `subagent_stop` |
| `gate` | when `event` is `gate` | `verify` \| `protected` \| `code-edit` |
| `decision` | when `event` is `gate` or `spec_transition` | `allow` \| `block` \| `warn` - on a transition, whether the index edit was ultimately allowed through. Most direct index edits are blocked by `paths.protected`, so `block` is the common case; a verified `done` close-out is the path that yields `allow`. |
| `from` | when `event` is `spec_transition` | previous lifecycle status, or `-` if not derivable |
| `ext` | when `gate` is `code-edit` | lowercased file extension, e.g. `.ps1` - never a path |
| `stale` | when `event` is `subagent_stop` | count of stale/missing retros observed for that spec |

Example lines:

```json
{"ts":"2026-07-21T09:14:02Z","spec_id":"FEAT-spec-metrics","phase":"in-progress","event":"spec_transition","from":"approved","decision":"block"}
{"ts":"2026-07-21T09:31:44Z","spec_id":"FEAT-spec-metrics","phase":"in-progress","event":"gate","gate":"code-edit","decision":"warn","ext":".ps1"}
{"ts":"2026-07-21T09:40:55Z","spec_id":"FEAT-spec-metrics","phase":"in-progress","event":"subagent_stop","stale":1}
```

The log is metadata-only by design: no file paths, no code content, no commit messages - only spec
IDs, lifecycle phases, decisions, and file extensions. Controlled by `hooks.metrics` in
`.claude/project-config.json` (`enabled`, default `true`; `path`, default
`.specs/_metrics/events.jsonl`). Set `hooks.metrics.enabled` to `false` to stop writing entirely.
There is no rotation in v1 - the file grows unbounded (documented as a known limitation; see
`docs/troubleshooting.md`).

Hooks are **defensive**: any failure path exits `0` silently. They never block the user on their own bugs.

---

## Spec artifacts as durable memory

Every workflow writes to a structured folder under `.specs/<ID>/`:

```
.specs/FEAT-INV-2501/
├── 00-spec.md        Why / What / Success criteria / Constitution check
├── 01-plan.md        Phased implementation plan
├── 02-tasks.md       Atomic tasks (9 required fields + Pattern refs)
├── 03-decisions.md   Impact analysis from sd-code-explorer + debugger output
├── 04-artifacts/     Evidence: logs, queries, traces, baselines, ticket snapshots
└── 05-retro.md       Append-only log: status transitions, surprises, follow-ups
```

This is not documentation written after the fact. It is the **input contract** every subagent reads. The implementer reads `02-tasks.md` to know what to edit. The reviewer reads `00-spec.md` to know what acceptance criteria to verify. Future engineers (and future Claude sessions) read all of it to understand why the code is shaped this way.

### Artifact ownership

Each file has one producing phase / agent and a defined set of downstream readers. The folder is
append-only memory, not scratch space:

| Artifact | Produced by | When | Read by |
|---|---|---|---|
| `00-spec.md` | `sd-spec-architect` (create); later sections filled in place by the workflow | Phase 1, then incrementally | every later phase + reviewer |
| `01-plan.md` | `sd-spec-architect` (plan) | feature / refactor plan phase | `sd-implementer` |
| `02-tasks.md` | `sd-spec-architect` (plan) | feature / refactor plan phase | `sd-implementer` |
| `03-decisions.md` | `sd-code-explorer` (impact) + `sd-debugger` (hypotheses / verdicts); append-only | impact + investigation phases | `sd-implementer`, `sd-reviewer` |
| `04-artifacts/` | any agent (logs, baselines, repro evidence, ticket snapshots) | throughout | any agent + future sessions |
| `05-retro.md` | main thread (status transitions); append-only | every gate transition | resume logic + future sessions |

The cross-phase fields inside `00-spec.md` are intentionally left empty at creation
(`<!-- Filled by Phase N -->`) so the workflow enforces sequencing - the architect does not pre-fill a
root cause the debugger has not yet confirmed.

---

## Spec lifecycle

```
                        +--> revive (with reason)
                        |       (only via /sd:spec revive)
                        v
draft -> approved -> in-progress -> done -> archived
                                  ^   |
                                  |   v
                                  +-- auto after N days configurable
```

| State | Meaning | Transition trigger |
|---|---|---|
| `draft` | Spec exists, not yet approved | `sd-spec-architect` creates it |
| `approved` | Reviewed; ready to plan | User explicit approval at Gate 1 |
| `in-progress` | Execution underway | Auto on plan approval (Gate 2) |
| `done` | Closed; retro written; CI green; awaiting release | User explicit approval at close-out |
| `archived` | Shipped in a release, or no active work | Auto after N days, `/sd:spec archive`, or `/sd:release` |

All transitions are logged to `05-retro.md` with timestamp + reason. Illegal transitions are refused by `/sd:spec status`.

---

## Cost-aware model assignment

Heavy reasoning (architecture, investigation, holistic review) uses `sonnet`. Mechanical work (read-only navigation, single atomic-task execution) uses `haiku`. The result is roughly:

| Workflow run | Typical cost | Sonnet calls | Haiku calls |
|---|---|---|---|
| `/sd:feature` (6 atomic tasks) | ~$2.00 - $3.00 | architect (spec + plan) + reviewer per task | explorer + implementer per task |
| `/sd:bug` (with investigation) | ~$1.00 - $2.00 | architect + debugger + reviewer | implementer |
| `/sd:rca` (no code) | ~$0.50 - $1.50 | architect + debugger (enum + verify) | (none) |
| `/sd:refactor` (3 batches) | ~$1.50 - $3.50 | architect + reviewer holistic | explorer + implementer per task |
| `/sd:perf` (3 hypotheses tried) | ~$2.00 - $4.00 | debugger (hotspot A + B per attempt) + reviewer | implementer |
| `/sd:explore` (single call) | ~$0.05 - $0.20 | (none) | explorer |
| `/sd:review` (standalone, 20 files) | ~$0.30 - $0.80 | reviewer | (none) |

These are rough ballparks. Actual cost depends on file sizes, MCP usage, and conversation length. The point is that workflow design - not aggressive prompting alone - keeps cost predictable.

---

## MCP integration

specwright is built around a small set of MCP servers most useful for spec-driven work. None are required; agents fall back gracefully.

### Recommended user scope (`~/.claude.json`)

| Server | Purpose | Used by |
|---|---|---|
| `context7` | Up-to-date library docs (avoids stale training-data examples) | spec-architect, implementer, debugger |
| `sequential-thinking` | Structured multi-step reasoning | debugger, reviewer |
| `tavily` | Web search for error signatures and library issues | debugger |
| `playwright` (optional) | E2E reproduction for `/sd:bug` | main thread |

### Recommended project scope (per-project `.mcp.json` or `project-config.json` flags)

| Server | Purpose | Used by |
|---|---|---|
| `atlassian` | Fetch JIRA tickets for `<ID>` arguments + snapshot ticket / related tickets / linked Confluence pages | spec-architect, commands |
| `gitnexus` | Fast symbol search, callers, call graph | code-explorer, debugger, reviewer |
| `database` (project-provided, e.g. `mssql`, `postgres`; SELECT/EXPLAIN only) | Inspect schema and query plans | debugger |

The split exists because user-scope servers are generic (any project benefits from `context7`), while project-scope servers carry project-specific connection strings or credentials.

---

## Why the `sd:` prefix

Every command, agent, and (conceptually) namespaced asset uses the `sd:` prefix:

- `/sd:feature` instead of `/feature`.
- `sd-spec-architect` instead of `spec-architect`.

The prefix exists for three reasons:

1. **Collision avoidance.** A project may have its own `/feature` or `/review` slash command. `sd:` carves out a namespace.
2. **Discoverability.** Typing `/sd:` in Claude Code lists all 12 commands. The namespace is its own table of contents.
3. **Removability.** Uninstalling the engine removes everything under `sd/` subfolders, leaving the rest of `~/.claude/` intact.

---

## Stack-agnosticism in practice

The engine assumes nothing about your stack. Agents read `CLAUDE.md` and `.specs/constitution.md` at runtime; the implementer uses `commands.test` from project-config rather than hardcoding `dotnet test` or `npm test`.

Concrete example: the same `/sd:feature` workflow runs identically on...

**.NET project:**
```
commands.test = "dotnet test --no-build"
commands.lint = "dotnet format --verify-no-changes"
paths.src = "src"
constitution.§1.1 layers = Domain -> Application -> Infrastructure -> WebServer
```

**Node project:**
```
commands.test = "pnpm test"
commands.lint = "pnpm lint"
paths.src = "src"
constitution.§1.1 layers = entities -> use-cases -> adapters -> frameworks
```

The implementer agent reads `CLAUDE.md`, sees the test command, runs it. It sees the layer declaration in the constitution, respects it. The agent's prompt file (`agents/implementer.md`) contains zero hardcoded language names.

When this discipline slips - e.g. an agent writing `dotnet test` because that's what it saw last - it's a bug. File an issue.

---

## When NOT to use specwright

The system is overhead. The overhead pays off when:

- The project will live more than a few weeks.
- More than one engineer (including future-you) needs to understand prior decisions.
- Bugs reoccurring without root-cause documentation has been a real cost.
- Refactors landing without coverage gates has caused regressions.

The overhead does NOT pay off when:

- You're prototyping or doing throwaway work. Use `/sd:explore` if you want navigation, but skip the workflows.
- The project is tiny and read by only you. Plain Claude Code is faster.
- You don't intend to enforce gates. The system is built around discipline; without that intent, the gates feel like friction with no benefit.

Adopt it where it earns its keep. Skip it where it doesn't.
