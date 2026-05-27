# Usage guide

Command-by-command reference for ck-spec-system. For the why and how it fits together, see [`architecture.md`](architecture.md). For a fully-worked example, see [`walkthrough.md`](walkthrough.md).

---

## First-time project setup

```
cd <your-project>
claude
> /init                # Standard Claude Code init (writes a basic CLAUDE.md)
> /ck:setup            # ck-spec-system scaffold
```

`/init` is optional but recommended. It creates a baseline `CLAUDE.md` that `/ck:setup` can parse for stack hints.

`/ck:setup` is interactive and asks **at most 3 questions**:

1. Ticket system (JIRA / GitHub / Linear / none).
2. Ticket pattern (regex like `^[A-Z]+-[0-9]+$`).
3. Shell (PowerShell / bash / both).

It generates:

```
<repo>/
├── CLAUDE.md                            (overwrites with backup if present)
├── .specs/
│   ├── constitution.md                  (with <<placeholder>> tokens to fill)
│   ├── index.md                         (empty registry)
│   ├── _explorations/                   (scratchpad for /ck:explore saves)
│   ├── _reviews/                        (scratchpad for /ck:review saves)
│   └── _adr/                            (architecture decision records)
└── .claude/
    ├── project-config.json
    └── settings.json
```

After running, **open `CLAUDE.md` and `.specs/constitution.md` in your editor** and fill the placeholders. `/ck:setup` does not infer your conventions; you declare them.

---

## Workflow commands

### `/ck:feature <ID-or-slug>`

Spec-driven feature workflow.

| Phase | Subagent / Actor | Gate |
|---|---|---|
| 0 - Bootstrap | main thread | - |
| 1 - Spec | `ck:spec-architect` | ⛔ Gate 1 (spec approval) |
| 2 - Impact | `ck:code-explorer` | - |
| 3 - Plan + tasks | `ck:spec-architect` | ⛔ Gate 2 (plan approval) |
| 4 - Execute | `ck:implementer` per task + main thread self-check | - |
| 5 - Integration + batch review | main thread + `ck:reviewer` (holistic, once) | ⛔ Gate 3 (integration + review) |
| 6 - Close-out | main thread | - |

**Spec ID**: `FEAT-<arg>`. State machine on re-invocation: detected state -> resume at next phase.

Example:
```
/ck:feature INV-2501
```
With JIRA enabled and ticket pattern matching `INV-2501`, the architect fetches the ticket and includes it in the spec context.

### `/ck:bug <ID-or-slug>`

Root-cause-first bug fix. **Refuses to fix without reproduction confirmed AND root cause documented.**

| Phase | Subagent / Actor | Gate |
|---|---|---|
| 0 - Bootstrap | main thread | - |
| 1 - Capture symptoms | `ck:spec-architect` | ⛔ Gate 1 |
| 2 - Reproduce | main thread (interactive) | ⛔ Gate 2 (HARD - no override) |
| 3 - Investigate | `ck:debugger` (enumerate + verify) | ⛔ Gate 3 (root cause confirmed) |
| 4 - Write failing test FIRST | main thread | ⛔ Gate 4 (test fails as expected) |
| 5 - Minimal fix | `ck:implementer` | - |
| 6 - Regression + review | `ck:reviewer` (bug-fix-final) | ⛔ Gate 5 |
| 7 - Close-out | main thread | - |

**Spec ID**: `BUG-<arg>`.

Example:
```
/ck:bug 1247
```

### `/ck:rca <slug>`

Incident analysis. **No code is changed in this workflow.** Output IS the spec.

| Phase | Subagent / Actor | Gate |
|---|---|---|
| 0 - Bootstrap | main thread | - |
| 1 - Gather signals | main thread (interactive) | ⛔ Gate 1 (evidence gathered) |
| 2 - Hypothesis enumeration | `ck:debugger` (enumerate, incident mode) | ⛔ Gate 2 |
| 3 - Verify loop | `ck:debugger` (verify) | ⛔ Gate 3 (root cause confirmed) |
| 4 - Isolate + document | main thread | - |
| 5 - Follow-up actions | main thread | - |

**Spec ID**: `RCA-<slug>-<YYYYMMDD>`.

Fixes spawn separate `BUG-*`, `REF-*`, or `PERF-*` specs (reserved IDs listed under "Spawned specs" in the RCA).

Example:
```
/ck:rca payment-outage-jan8
```

### `/ck:refactor <slug> [smell-type]`

Coverage-gated refactor. **Refuses to touch code if coverage on affected files is below threshold (default 80%).**

| Phase | Subagent / Actor | Gate |
|---|---|---|
| 0 - Bootstrap | main thread | - |
| 1 - Spec | `ck:spec-architect` | ⛔ Gate 1 |
| 2 - Impact | `ck:code-explorer` | - |
| 3 - Coverage | main thread (runs `commands.coverage`) | ⛔ Gate 2 (threshold) + ⛔ Gate 3 (post-tests) |
| 4 - Plan parallel-safe tasks | `ck:spec-architect` | ⛔ Gate 4 |
| 5 - Execute batched (max 3 parallel) | `ck:implementer` per task | ⛔ Gate 5 (per-batch tests green) |
| 6 - Holistic review | `ck:reviewer` (holistic) | ⛔ Gate 6 |
| 7 - Close-out | main thread | - |

**Spec ID**: `REF-<slug>-<YYYYMMDD>`.

Example:
```
/ck:refactor extract-pricing-service extract-class
```

### `/ck:perf <endpoint-or-slug>`

Baseline-first optimization. **Refuses to optimize without a measured baseline.**

| Phase | Subagent / Actor | Gate |
|---|---|---|
| 0 - Bootstrap | main thread | - |
| 1 - Define target | `ck:spec-architect` | ⛔ Gate 1 |
| 2 - Baseline measurement | main thread | ⛔ Gate 2 (HARD) |
| 3 - Identify hotspot | `ck:debugger` (hotspot-analysis A) | ⛔ Gate 3 |
| 4 - Per-hotspot loop | `ck:debugger` (sub B) + `ck:implementer` + re-measure | ⛔ Gates 4-6 (hypothesis / correctness / keep-or-revert) |
| 5 - Regression check | main thread | ⛔ Gate 7 |
| 6 - Final review + close | `ck:reviewer` (perf-final) | ⛔ Gate 8 |

**Spec ID**: `PERF-<slug>-<YYYYMMDD>`.

Example:
```
/ck:perf search-endpoint-latency
```

---

## Utility commands

### `/ck:spec <subcommand>`

Spec registry. **No code is changed. No subagent is invoked.**

| Subcommand | Args | Use |
|---|---|---|
| `list` | `[type] [status]` | Filtered list of specs |
| `show` | `<ID>` | Frontmatter + section summary + task completion |
| `status` | `<ID> <new-state>` | Validated lifecycle transition (logs to retro) |
| `link` | `<ID-A> <relation> <ID-B>` | Cross-reference (depends-on, related-to, spawned-by, ...) |
| `archive` | `<ID>` | Move from `done` to `archived` |
| `revive` | `<ID> [reason]` | Move from `archived` to `in-progress` |
| `search` | `<term>` | Full-text grep across spec bodies |
| `validate` | `[ID or --all]` | Verify frontmatter + structure + index consistency |
| `stats` | - | Counts + aging report |
| `help` | - | Print subcommand list |

Examples:
```
/ck:spec list bug in-progress
/ck:spec show FEAT-INV-2501
/ck:spec status BUG-1247 done
/ck:spec link FEAT-INV-2501 depends-on REF-extract-pricing-20260112
/ck:spec search "low-stock"
/ck:spec stats
```

### `/ck:explore <target-or-query>`

Read-only code navigation. Single `ck:code-explorer` invocation. No spec created.

The command parses your query for intent:
- "where is X" / "define X" -> definition mode.
- "who calls X" / "callers of X" -> callers mode.
- "trace X" -> call-graph trace.
- "what depends on X" / "impact of changing X" -> impact map.
- "show all X" / pattern -> grep pattern search.
- "structure of X" -> directory + symbols overview.

Output includes `file:line` citations for every finding. Offers to save to `.specs/_explorations/<slug>-<timestamp>.md`.

Examples:
```
/ck:explore where is PaymentHandler defined
/ck:explore who calls UserService.GetById
/ck:explore impact of changing StockReservation
/ck:explore show all places that use Redis
```

### `/ck:review [path | "recent" | "spec <ID>"]`

Standalone compliance review. Constitution required - aborts if missing.

Four modes:

- `<path>` - review a file or directory.
- `recent` or `recent <N>h` - files modified in the last N hours (default 4).
- `spec <ID>` - changed files associated with a spec.
- *(no args)* - interactive prompt to pick a mode.

Output: severity-tagged findings 🔴 BLOCK / 🟠 WARN / 🟡 SUGGEST / 🟢 PASS, each citing `file:line` and a constitution `§N.M`.

Examples:
```
/ck:review src/Application/Payment
/ck:review recent 4h
/ck:review spec BUG-1247
```

### `/ck:setup`

Already covered above. Re-runnable. Detects state (fresh / post-init / partial / complete) and only fills gaps. Backs up any file before overwriting.

---

## Common patterns

### Picking the right workflow

| You have | Use |
|---|---|
| "Add a new endpoint / behavior / capability" | `/ck:feature` |
| "Something is broken; need to investigate then fix" | `/ck:bug` |
| "Production incident; need a post-mortem with no code change" | `/ck:rca` |
| "This file / module is too tangled; need to restructure" | `/ck:refactor` |
| "X is too slow; need to optimize with measurements" | `/ck:perf` |
| "I just want to navigate the code" | `/ck:explore` |
| "Review this change for compliance" | `/ck:review` |
| "Manage / browse the spec registry" | `/ck:spec` |

### Resuming a workflow

Workflow commands are **resumable**. Re-running `/ck:feature INV-2501` after closing your terminal mid-execution detects the current state of `.specs/FEAT-INV-2501/` and jumps to the next phase. The state machine is documented at the top of each command file.

The main heuristic: workflow checks for the presence and contents of `00-spec.md`, `01-plan.md`, `02-tasks.md` (with task completion ratio), and `05-retro.md` to determine where you are.

### Linking specs

When an RCA spawns fixes, link them so the registry knows:

```
/ck:rca payment-outage-jan8         # produces RCA-payment-outage-jan8-20260108
# ...RCA filled in, spawned specs listed...
/ck:bug 1310                        # produces BUG-1310
/ck:spec link BUG-1310 spawned-by RCA-payment-outage-jan8-20260108
```

Now `/ck:spec show BUG-1310` reveals the parent RCA.

### When a workflow can't make progress

If you hit a hard gate that the system refuses to override (e.g. bug reproduction unavailable, perf baseline cannot be measured), the workflow surfaces options:

1. **Gather more evidence** - logs, telemetry, observability changes.
2. **Accept the gate with explicit constitution exception** - logged to retro.
3. **Abort** - the spec stays at its current state for later resumption.

The system surfaces; the human decides. The gates exist precisely so the decision is conscious.

---

## Hook behavior examples

Hooks emit output inline during a session. Examples:

**prompt-router** on `"fix bug INV-2501 in stock service"`:

```
<context-router>
Routing hints from ck-spec-system (UserPromptSubmit hook):

Workflow keyword matches:
  - /ck:bug  (matched: bug, fix)

Ticket IDs detected: INV-2501
Matching spec folders under .specs/:
  - FEAT-INV-2501

Specs currently in-progress (from .specs/index.md):
  - FEAT-INV-2501
</context-router>
```

**spec-gate** when editing `src/Stock.cs` with no in-progress spec, `mode: warn`:

```
[WARN] spec-gate: editing code file 'src/Stock.cs' but no in-progress spec is recorded in .specs/index.md. Run /ck:feature, /ck:bug, /ck:refactor, or /ck:perf first to create a spec, or set hooks.specGate.mode='off' in .claude/project-config.json to disable.
```

**spec-gate** in `mode: block`:

```json
{"decision":"block","reason":"spec-gate: editing code file 'src/Stock.cs' but no in-progress spec..."}
```

**subagent-retro** after a subagent run, retro file is 90 minutes stale:

```
<retro-reminder>
Retro files appear stale or missing for the following in-progress specs:
  - FEAT-INV-2501: 05-retro.md last touched 90 min ago (threshold 30 min)

Consider appending: decisions made, surprises encountered, follow-ups identified.
</retro-reminder>
```

---

## Hook configuration

`.claude/project-config.json` contains the `hooks` section:

```json
{
  "hooks": {
    "userPromptRouter": {
      "enabled": true
    },
    "specGate": {
      "enabled": true,
      "mode": "warn"
    },
    "subagentRetro": {
      "enabled": true,
      "retroStaleMinutes": 30,
      "debounceMinutes": 10
    }
  }
}
```

**Common adjustments:**

- Tightening: change `specGate.mode` from `"warn"` to `"block"` once your team is used to the workflow.
- Loosening: set `enabled: false` on any hook during noisy debug sessions. Don't forget to flip back.
- Pace tuning: `retroStaleMinutes` and `debounceMinutes` control how often the retro reminder fires. Set both higher for long-form work; lower for tight iteration cycles.

`paths.protected` controls which files trigger an unconditional `decision=block`:

```json
{
  "paths": {
    "protected": [
      ".specs/constitution.md",
      ".specs/index.md",
      "LICENSE"
    ]
  }
}
```

Add anything you never want edited via Claude Code's tool. Migration scripts, sealed configs, generated files, etc.