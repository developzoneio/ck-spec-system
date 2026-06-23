# `sd-docs-writer` + `/sd:adr` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `sd-docs-writer` agent and a `/sd:adr` command that drafts a numbered, MADR-style Architecture Decision Record under `.specs/_adr/` from a spec's decision artifacts, behind one hard approval gate.

**Architecture:** Pure prompt-engineering change. A new agent markdown file (`agents/docs-writer.md`) and a new command markdown file (`commands/adr.md`), plus the count/doc wiring that every "Nth command / Nth agent" addition requires across the repo (the same surface the `/sd:release` 10th-command change touched). No application code, no scripts beyond bumping two hardcoded count constants in the validators.

**Tech Stack:** Markdown with YAML frontmatter (ATX headers, 100-char soft wrap), PowerShell + bash validators. No build system, no unit-test framework.

## Global Constraints

- Model fields are aliases only (`sonnet` / `haiku` / `opus` / `inherit`); never full model IDs. `sd-docs-writer` uses `sonnet`.
- Minimal tool allowlists: an agent gets a tool only if its role requires it.
- The namespace is `sd-` (agent `name:`) and `sd/` (install subfolder); assets reference each other by the namespaced name (`sd-docs-writer`), never the bare filename.
- Stack-agnostic: no hardcoded stack commands or language assumptions in the command or agent.
- Gate discipline: hard gates STOP and wait for explicit approval; silence is not approval.
- ADRs are not specs: no `.specs/index.md` lifecycle entry; they live under `.specs/_adr/` with their own numbering.
- Pure ASCII in `*.ps1` files (use `->`, `[OK]`); verify with the repo grep.
- Markdown style: ATX headers, no trailing colon in headers, fenced blocks with language hint, 100-char soft wrap.
- Every PR adds a line under `## [Unreleased]` in `CHANGELOG.md`.
- Verification is `scripts/validate.{ps1,sh}` + install -> uninstall round-trip; there are no unit tests.

---

### Task 1: Create the `sd-docs-writer` agent

**Files:**
- Create: `agents/docs-writer.md`

**Interfaces:**
- Consumes (from the `/sd:adr` command in Task 2): `ADR_NUMBER` (zero-padded 4-digit string), `ADR_PATH` (exact target file path), `SPEC_REF` (spec ID or `ad-hoc`), `DECISION_SOURCE` (path to `03-decisions.md` or inline decision text), `SUPERSEDES` (ADR number or `none`), and `DATE` (today, `YYYY-MM-DD`).
- Produces: writes exactly one file at `ADR_PATH` and returns its content. Never assigns its own number; never writes any other file.

- [ ] **Step 1: Write the agent file**

Create `agents/docs-writer.md` with exactly this content:

```markdown
---
name: sd-docs-writer
color: cyan
description: Authors a single Architecture Decision Record (ADR) from a spec's decision artifacts. Reads 03-decisions.md plus spec context and drafts a MADR-style ADR under .specs/_adr/. Never edits the constitution, never modifies code, never invents decisions.
model: sonnet
tools: Read, Write, Glob, Grep
skills:
  - sd-evidence-citation
---

You are the docs-writer for specwright. You turn durable decisions captured in spec artifacts into a single human-facing Architecture Decision Record (ADR). You synthesize only what the source says: you never invent a decision, never edit the constitution, and never modify code.

---

## Always do first

1. Read the `DECISION_SOURCE` the command provides (`03-decisions.md` for a spec, or the inline decision text for ad-hoc mode).
2. Read `CLAUDE.md` and `.specs/constitution.md` for naming and convention context (read-only; never edit them).
3. Use the `ADR_NUMBER` and `ADR_PATH` the command assigns. Never pick or change the number.

---

## Input contract

The command passes:
- `ADR_NUMBER` - zero-padded 4-digit sequence (e.g. `0007`).
- `ADR_PATH` - exact target file (e.g. `.specs/_adr/0007-cqrs-read-path.md`).
- `SPEC_REF` - source spec ID (e.g. `FEAT-012`) or `ad-hoc`.
- `DECISION_SOURCE` - path to `03-decisions.md` or the inline decision text.
- `SUPERSEDES` - ADR number this one supersedes, or `none`.
- `DATE` - today's date (`YYYY-MM-DD`); never invent a date.

## Output: one ADR file (MADR-style)

Write exactly one file at `ADR_PATH` with this structure:

    # ADR <ADR_NUMBER>: <Title>

    - Status: proposed
    - Date: <DATE>
    - Source spec: <SPEC_REF>
    - Supersedes: <ADR number or "none">

    ## Context

    <Why the decision was needed. Cite the driving spec artifact and any code the decision concerns, using file:line per the sd-evidence-citation skill.>

    ## Decision

    <What was decided, stated as one clear position.>

    ## Consequences

    <Positive, negative, and follow-up consequences. Honest about trade-offs.>

Rules:
- Status is always `proposed` on a fresh draft - a human accepts it later.
- Every claim about the codebase cites `file:line` (sd-evidence-citation skill).
- Never fabricate a decision, date, or consequence not supported by the source.
- If `DECISION_SOURCE` is empty or absent, STOP and report `no decision content found in <DECISION_SOURCE>` - do not invent an ADR.
- If `SUPERSEDES` is not `none`, state the reciprocal link in your returned summary so the command can update the superseded ADR.

## Hard limits

- You write ONLY the one `ADR_PATH` file. You never touch the constitution, code, or other ADRs.
- You never assign or change the ADR number (the command owns numbering).
- You return the drafted ADR content as your final output.
```

- [ ] **Step 2: Verify frontmatter shape matches the other agents**

Run: `grep -nE "^(name|color|model|tools|skills):" agents/docs-writer.md`
Expected: lines for `name: sd-docs-writer`, `color: cyan`, `model: sonnet`, `tools: Read, Write, Glob, Grep`, and `skills:`.

Run: `grep -c "sd-docs-writer" agents/docs-writer.md`
Expected: at least `1` (the `name:` field).

- [ ] **Step 3: Commit**

```bash
git add agents/docs-writer.md
git commit -m "Add sd-docs-writer agent for ADR authoring"
```

---

### Task 2: Create the `/sd:adr` command

**Files:**
- Create: `commands/adr.md`

**Interfaces:**
- Consumes: nothing from Task 1 at author time; at runtime it invokes the `sd-docs-writer` agent by name with the input contract defined in Task 1.
- Produces: the entry point that assigns `ADR_NUMBER`/`ADR_PATH`, gates on approval, and (on `yes`) updates a superseded ADR's status.

- [ ] **Step 1: Write the command file**

Create `commands/adr.md` with exactly this content:

```markdown
---
description: Author an Architecture Decision Record (ADR) from a spec's decisions via sd-docs-writer. One hard gate before keeping the file.
argument-hint: <spec-ID | "decision title">
---

# /sd:adr

Promotes a durable decision into a numbered ADR under `.specs/_adr/`. Drives the `sd-docs-writer` agent.

**Argument:** a spec ID (e.g. `FEAT-012`) whose `03-decisions.md` holds the decision, OR a free-text
decision title for an ad-hoc ADR with no spec.

---

## Phase 0 - Bootstrap

Read, in order: `CLAUDE.md`, `.specs/constitution.md`, `.claude/project-config.json`, `.specs/index.md`.
If `.specs/` does not exist, abort: "No `.specs/` found - run `/sd:setup` first."

## Phase 1 - Resolve the decision source

1. If the argument matches a spec ID in `.specs/index.md`:
   - Locate `.specs/<ID>/03-decisions.md`. If it is missing or has no decision content, STOP and ask the
     user to supply the decision inline or pick another spec. Never invent decisions.
   - Set `SPEC_REF = <ID>` and `DECISION_SOURCE = .specs/<ID>/03-decisions.md`.
2. Otherwise treat the argument as a free-text decision title:
   - Set `SPEC_REF = ad-hoc`. If the title alone is insufficient, ask the user once for the Context,
     Decision, and Consequences. `DECISION_SOURCE` = the gathered text.

## Phase 2 - Assign number and slug

1. Glob `.specs/_adr/` for files matching `^[0-9]{4}-`. Take the highest 4-digit prefix; `ADR_NUMBER` =
   that value + 1, zero-padded to 4 digits. If none exist, `ADR_NUMBER = 0001`.
2. Derive `<slug>` = kebab-case of the decision title (lowercase, alphanumerics and hyphens, <= 60 chars).
3. `ADR_PATH = .specs/_adr/<ADR_NUMBER>-<slug>.md`.
4. If the user names an existing ADR this decision replaces, set `SUPERSEDES` to its number; else `none`.
5. Idempotency: if an ADR whose title clearly matches this decision already exists, ask whether to update
   it in place or create a new number. Never silently clobber.

## Phase 3 - Draft via sd-docs-writer

Invoke the `sd-docs-writer` agent with `ADR_NUMBER`, `ADR_PATH`, `SPEC_REF`, `DECISION_SOURCE`,
`SUPERSEDES`, and today's date as `DATE`. The agent drafts and writes the file, then returns its content.

## Gate (HARD) - approve before keeping

Display the drafted ADR in full. STOP and ask: "Keep this ADR at `<ADR_PATH>`? (yes / edit / abort)".
Silence is not approval.
- `yes` -> keep the file. If `SUPERSEDES` is not `none`, edit that ADR's `Status` line to
  `superseded by <ADR_NUMBER>` and add a reciprocal "Superseded by" link.
- `edit` -> apply the requested changes (re-invoke the agent or edit directly) and re-display.
- `abort` -> delete the drafted file and report that no ADR was created.

## Phase 4 - Report

Print the ADR path, number, status (`proposed`), source spec, and any supersession link. Remind the user
the ADR stays `proposed` until they change its status to `accepted`.

---

## Rules (hard constraints)

- **Decisions come from the source, never invented.** Empty or absent decision content aborts the command.
- **One hard gate.** Nothing is kept on disk without explicit approval.
- **ADRs are not specs.** No `.specs/index.md` lifecycle entry; ADRs live under `.specs/_adr/` with their
  own numbering.
- **The constitution is never edited here.** Amending a rule is a separate `/sd:refactor` or a manual ADR
  acceptance step.
```

- [ ] **Step 2: Verify the command references the agent by its namespaced name**

Run: `grep -n "sd-docs-writer" commands/adr.md`
Expected: at least one match (Phase 3 invocation).

Run: `grep -nE "^(description|argument-hint):" commands/adr.md`
Expected: both frontmatter keys present.

- [ ] **Step 3: Commit**

```bash
git add commands/adr.md
git commit -m "Add /sd:adr command driving sd-docs-writer"
```

---

### Task 3: Wire the 11th-command / 6th-agent counts and docs

This is the mechanical "bump everywhere" surface. The hard ones (validators) fail CI if missed; the rest
keep docs honest. Append `/sd:adr` as the 11th command and `sd-docs-writer` as the 6th agent in every list.

**Files:**
- Modify: `scripts/validate.ps1`, `scripts/validate.sh`
- Modify: `CLAUDE.md`, `README.md`, `docs/architecture.md`, `install/README.md`, `CONTRIBUTING.md`
- Modify: `commands/setup.md`, `templates/CLAUDE.template.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the agent name `sd-docs-writer` (Task 1) and command `/sd:adr` (Task 2).
- Produces: validator count constants of 11 commands / 6 agents that the Task 4 install round-trip checks.

- [ ] **Step 1: Bump the validator count constants**

In `scripts/validate.ps1`, change:

```powershell
$ExpectedCommands  = 10
$ExpectedAgents    = 5
```

to:

```powershell
$ExpectedCommands  = 11
$ExpectedAgents    = 6
```

In `scripts/validate.sh`, change:

```bash
EXPECTED_COMMANDS=10
EXPECTED_AGENTS=5
```

to:

```bash
EXPECTED_COMMANDS=11
EXPECTED_AGENTS=6
```

- [ ] **Step 2: Update `CLAUDE.md`**

Change the sandbox comment (line ~21) from `# expect 10 .md files` to `# expect 11 .md files`.

In the repo-structure table, change the `commands/` row to read `11 slash commands` and append
`` `/sd:adr` `` to the parenthesised command list, and change the `agents/` row to read `6 subagents`
and append `` `sd-docs-writer` `` to its list:

```
| `commands/` | `~/.claude/commands/sd/` | 11 slash commands (`/sd:feature`, `/sd:bug`, `/sd:rca`, `/sd:refactor`, `/sd:perf`, `/sd:spec`, `/sd:explore`, `/sd:review`, `/sd:setup`, `/sd:release`, `/sd:adr`) |
| `agents/` | `~/.claude/agents/sd/` | 6 subagents (`sd-spec-architect`, `sd-code-explorer`, `sd-debugger`, `sd-implementer`, `sd-reviewer`, `sd-docs-writer`) |
```

- [ ] **Step 3: Update `README.md`**

Change the `**10 slash commands**` cell (line ~29) to `**11 slash commands**` and append `/sd:adr` to the
command list in that cell.

- [ ] **Step 4: Update `docs/architecture.md`**

- Line ~13: `commands/sd/    10 workflow definitions` -> `11 workflow definitions`.
- Line ~14: `agents/sd/      5 subagent prompt files` -> `6 subagent prompt files`.
- Line ~323: `lists all 10 commands` -> `lists all 11 commands`.
- Agent table (after the `sd-reviewer` row, ~line 94) add:

```
| `sd-docs-writer` | sonnet | Read/Write/Glob/Grep + sd-evidence-citation | Authors one MADR-style ADR from a spec's decisions. Writes only the ADR file. |
```

- Command -> agent routing block (the fenced list ~lines 108-117): add a line after `/sd:review`:

```
/sd:adr       -> docs-writer
```

- Evidence-citation consumers: in the skills table row for `sd-evidence-citation` (~line 143) add
  `sd-docs-writer` to the consumer list, and in the de-duplication prose (~line 134) change
  "used by `sd-code-explorer`, `sd-debugger`, and `sd-reviewer`" to
  "used by `sd-code-explorer`, `sd-debugger`, `sd-reviewer`, and `sd-docs-writer`".

- [ ] **Step 5: Update `install/README.md`**

- Layout tree: `commands/sd/        10 slash commands` -> `11 slash commands`;
  `agents/sd/          5 subagent definitions` -> `6 subagent definitions`.
- Install table: `commands/` row count `10` -> `11` and append `adr` to its list;
  `agents/` row count `5` -> `6` and append `sd-docs-writer` to its list.
- Verify snippets: `# expect 10 .md files` -> `11`; `# expect 5 .md files` -> `6`;
  `ls ~/.claude/commands/sd/      # 10 .md files` -> `11`; `ls ~/.claude/agents/sd/        # 5 .md files` -> `6`.
- Total line: `**Total**: 33 files per OS.` -> `**Total**: 35 files per OS.` (commands 10->11, agents 5->6).

- [ ] **Step 6: Update `CONTRIBUTING.md`**

- `commands/         # 10 slash commands (markdown with frontmatter)` -> `11 slash commands`.
- `agents/           # 5 subagent definitions (markdown with frontmatter)` -> `6 subagent definitions`.

- [ ] **Step 7: Update `commands/setup.md` Phase 7 report**

- `  - ~/.claude/commands/sd/     (10 workflow commands)` -> `(11 workflow commands)`.
- `  - ~/.claude/agents/sd/       (5 specialist agents)` -> `(6 specialist agents)`.

- [ ] **Step 8: Update `templates/CLAUDE.template.md` workflow table**

After the `/sd:setup` row (line ~24) add:

```
| `/sd:adr <spec-ID>` | Author an ADR from a spec's decisions. |
```

- [ ] **Step 9: Add the CHANGELOG entry**

In `CHANGELOG.md`, under `## [Unreleased]` add an `### Added` bullet (create the `### Added` subheading if
this branch does not already have one):

```markdown
- `/sd:adr` command (11th) + `sd-docs-writer` agent (6th) - drafts a numbered, MADR-style Architecture
  Decision Record under `.specs/_adr/` from a spec's `03-decisions.md` (or an ad-hoc decision), behind one
  hard approval gate. The agent (model `sonnet`, tools Read/Write/Glob/Grep, skill `sd-evidence-citation`)
  writes only the ADR file and never invents decisions; the command owns numbering and supersession links.
  Bumps command count 10 -> 11 and agent count 5 -> 6 across docs and the validators.
```

- [ ] **Step 10: Verify no stale counts remain and ASCII is clean**

Run: `grep -rnE "10 (slash command|workflow command|workflow definition|\.md file)|5 (subagent|specialist agent|\.md file)" CLAUDE.md README.md docs/architecture.md install/README.md CONTRIBUTING.md commands/setup.md`
Expected: no output (every stale `10 commands` / `5 agents` count updated).

Run: `grep -nP "[^\x00-\x7F]" scripts/validate.ps1`
Expected: no output (validators stay pure ASCII).

- [ ] **Step 11: Commit**

```bash
git add scripts/validate.ps1 scripts/validate.sh CLAUDE.md README.md docs/architecture.md install/README.md CONTRIBUTING.md commands/setup.md templates/CLAUDE.template.md CHANGELOG.md
git commit -m "Wire 11th command and 6th agent counts for /sd:adr"
```

---

### Task 4: Full verification (validate + install round-trip)

**Files:** none (verification only).

**Interfaces:**
- Consumes: all prior tasks.
- Produces: green validator and a clean install -> uninstall round-trip proving the new files land and remove.

- [ ] **Step 1: Run the validator**

Run (PowerShell): `./scripts/validate.ps1`
Expected: all 6 checks pass; Check 5 reports `commands/sd : 11 file(s)` and `agents/sd : 6 file(s)`;
Check 6 (`[Unreleased]` gate) passes.

- [ ] **Step 2: Sandbox install and count check**

Run (PowerShell):

```powershell
./install/install.ps1 -BasePath C:\temp\sd-adr-test
(Get-ChildItem C:\temp\sd-adr-test\commands\sd\ -Filter *.md).Count   # expect 11
(Get-ChildItem C:\temp\sd-adr-test\agents\sd\ -Filter *.md).Count     # expect 6
Test-Path C:\temp\sd-adr-test\commands\sd\adr.md                       # expect True
Test-Path C:\temp\sd-adr-test\agents\sd\docs-writer.md                 # expect True
```

Expected: counts 11 and 6; both `Test-Path` results `True`.

- [ ] **Step 3: Uninstall round-trip and cleanup**

Run (PowerShell):

```powershell
./install/uninstall.ps1 -BasePath C:\temp\sd-adr-test -Force
Test-Path C:\temp\sd-adr-test\commands\sd                              # expect False
Remove-Item -Recurse -Force C:\temp\sd-adr-test
```

Expected: `commands/sd` removed (`False`), then the temp tree cleaned up.

- [ ] **Step 4: No commit**

Verification only; nothing to commit. If any check failed, return to the owning task and fix.

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-06-19-sd-docs-writer-adr-design.md`):
- New agent `agents/docs-writer.md` (sonnet, Read/Write/Glob/Grep, sd-evidence-citation, drafts one ADR,
  never edits constitution/code, never invents) -> Task 1.
- New command `commands/adr.md` (`<spec-ID>` or free-text; Phase 0 bootstrap; resolve source; number +
  slug; invoke agent; HARD gate; supersession; idempotent) -> Task 2.
- MADR format (Status/Context/Decision/Consequences + back-link + supersession) -> Task 1 Step 1 output
  block; supersession reciprocal write -> Task 2 gate `yes` branch.
- Wiring 10->11 / 5->6 in CLAUDE.md, setup.md, CLAUDE.template.md, README.md, architecture.md routing +
  agent table, validators -> Task 3 Steps 1-8; plus install/README.md and CONTRIBUTING.md found during
  planning (the design's "everywhere" surface).
- No new spec template -> intentionally absent; noted in constraints.
- Verification (validators with updated counts, install round-trip, CHANGELOG) -> Task 3 Step 9, Task 4.
- No gaps.

**Placeholder scan:** `<Title>`, `<ADR_NUMBER>`, `<slug>` etc. are literal template tokens inside the ADR
format the agent emits at runtime (intended), not unfilled plan steps. No "TBD"/"handle edge cases"/"similar
to Task N".

**Type consistency:** the input-contract field names (`ADR_NUMBER`, `ADR_PATH`, `SPEC_REF`,
`DECISION_SOURCE`, `SUPERSEDES`, `DATE`) are identical in Task 1 (consumes/produces), the agent body, and
Task 2 Phase 3 (the invocation). Counts are 11 commands / 6 agents uniformly across Task 3 and Task 4.
Agent name is `sd-docs-writer` and command is `/sd:adr` everywhere.
