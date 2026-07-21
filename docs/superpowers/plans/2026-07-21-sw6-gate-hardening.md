# SW-6 Gate Hardening (/sd:verify + Scenario-ID Traceability) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the spec close-out transition from a prose gate into a hook-checkable one: a new
`/sd:verify <spec-ID>` command proves criterion -> task -> test traceability and writes a
`06-verify.md` pass artifact; the spec-gate hook refuses to let an `index.md` row transition to
`done` unless that artifact records `result: pass`; scenario IDs (SC-N) and criterion IDs (AC-N)
in the feature template plus a `Covers` task field make the traceability mechanical.

**Architecture:** Three layers. (1) Contract: SC-N / AC-N ID tokens in
`templates/specs/feature.template.md`, a new `Covers` field in the atomic-task format, authoring
rules in `sd-spec-templates`, and coverage checks in `sd-reviewer`. (2) Verification: a new
pure-file-ops command `commands/verify.md` (modeled on `/sd:spec validate`) with stable `VF0xx`
rule IDs that maps AC/SC -> tasks -> tests, runs `commands.test` from project-config, and always
writes `.specs/<ID>/06-verify.md` with frontmatter `result: pass|fail`. (3) Enforcement: a new
Rule 0 in both spec-gate hooks that inspects the Edit/Write/MultiEdit payload targeting
`spec.indexFile`, detects rows newly transitioning to `done`, and blocks unless each such spec
has a passing artifact - a verified close-out is allowed through the protected-path rule; every
other direct `index.md` edit keeps today's always-block behavior.

**Tech Stack:** Markdown prompt files (commands/skills/agents/templates), PowerShell 5.1+ and
bash hook scripts, jq, bespoke golden-fixture conformance runner
(`tests/hooks/run-conformance.ps1`), `scripts/validate.ps1|.sh` doc-claims checker.

## Global Constraints

- **Pure ASCII in all `.ps1` files.** Verify with
  `grep -nP "[^\x00-\x7F]" hooks/powershell/*.ps1 install/*.ps1` - any output means REJECT.
- **Hooks ship in pairs.** Every behavior change to `hooks/powershell/spec-gate.ps1` requires the
  matching change to `hooks/bash/spec-gate.sh`. Do NOT paper over divergence - the conformance
  runner compares normalized bash vs pwsh output byte-for-byte, including reason strings.
- **Hooks are defensive.** Every failure path exits 0. Parse failures in the new rule fall
  through to the existing protected-path block (safe-restrictive), never crash.
- **Block reason strings must be byte-identical across both hook implementations.** The exact
  strings are specified in the "Normalized strings" section below - copy them verbatim.
- **Stack-agnostic.** `/sd:verify` runs tests via `commands.test` from
  `.claude/project-config.json`, never a hardcoded tool.
- **Model fields are aliases only** (`sonnet`, `haiku`, `opus`, `inherit`) - not touched here,
  but do not introduce full model IDs anywhere.
- **Style:** Markdown ATX headers, no trailing colons in headers, fenced code blocks with
  language hints, 100-char soft wrap. Bash: `#!/usr/bin/env bash`, snake_case. PowerShell:
  PascalCase functions, `$camelCase` variables.
- **Commits:** imperative mood, 50-char subject (repo style: "Add ...", "Fix ..." - no
  conventional-commit prefixes). Work on branch `feat/sw6-gate-hardening` cut from the current
  branch.
- **CHANGELOG:** one `### Added` bullet under `## [Unreleased]` tagged `(SW-6)` (Task 5).
- The `verify` command is a **utility**, not a workflow command: it does NOT join
  `workflowCommands` in `specwright.manifest.json`, and `docs/architecture.md`'s "5 workflow
  commands" stays 5.

## Normalized strings (copy verbatim - both hooks, fixtures, and docs depend on these)

- Verify artifact filename: `06-verify.md` inside `<spec.dir>/<ID>/`.
- Pass marker: a line in `06-verify.md` matching regex `^result:[[:space:]]*pass[[:space:]]*$`
  case-insensitively (frontmatter line `result: pass`).
- New config flag: `hooks.specGate.verifyGate` (boolean, default `true` when absent; only a
  literal JSON `false` disables).
- Hook block reason for an unverified done-transition (`<IDS>` = ordinal-sorted, deduped,
  `", "`-joined IDs; `<SPECDIR>` = `spec.dir` from config, default `.specs`):

  ```text
  spec-gate: index row(s) [<IDS>] -> done but no passing /sd:verify artifact. Run /sd:verify <spec-ID>; close-out is allowed only after <SPECDIR>/<ID>/06-verify.md records 'result: pass'.
  ```

- The existing protected-path reason string is unchanged:
  `spec-gate: '<rel>' is listed under paths.protected in .claude/project-config.json. Update via /sd:refactor or an ADR; never edit directly.`

## File Structure

```text
commands/verify.md                                  CREATE  the /sd:verify command
commands/feature.md                                 MODIFY  Phase 6 close-out runs /sd:verify
commands/spec.md                                    MODIFY  status prose, artifact table, SL055
commands/setup.md                                   MODIFY  command count 11 -> 12
templates/specs/feature.template.md                 MODIFY  SC-N scenario + AC-N criterion IDs
templates/project-config.template.json              MODIFY  hooks.specGate.verifyGate flag
skills/sd-spec-templates/SKILL.md                   MODIFY  SC/AC authoring rules
skills/sd-atomic-task-format/SKILL.md               MODIFY  new Covers field
agents/spec-architect.md                            MODIFY  fill Covers when authoring tasks
agents/reviewer.md                                  MODIFY  holistic scenario-coverage check
hooks/powershell/spec-gate.ps1                      MODIFY  Rule 0 verify gate
hooks/bash/spec-gate.sh                             MODIFY  Rule 0 verify gate (paired)
tests/hooks/fixtures/spec-gate/                     CREATE  6 new fixture cases
README.md, CLAUDE.md, CONTRIBUTING.md,
install/README.md, docs/architecture.md,
docs/usage.md, specwright.manifest.json             MODIFY  counts 11 -> 12, /sd:verify rows
CHANGELOG.md                                        MODIFY  [Unreleased] Added bullet (SW-6)
examples/spec-lint-fixture/clean/.specs/...         MODIFY  demonstrate SC/AC + 06-verify.md
```

---

### Task 1: Traceability contract - template, skills, agents

**Files:**
- Modify: `templates/specs/feature.template.md`
- Modify: `skills/sd-spec-templates/SKILL.md`
- Modify: `skills/sd-atomic-task-format/SKILL.md`
- Modify: `agents/spec-architect.md`
- Modify: `agents/reviewer.md`

**Interfaces:**
- Produces: scenario heading format `### SC-<n>: <name>`; criterion checkbox format
  `- [ ] AC-<n>: <criterion>`; task field `- **Covers**: <SC-/AC-ID list | none>` placed
  directly after `- **Acceptance**`. Tasks 2 (verify command), 3 (workflows) and 6 (examples)
  parse exactly these shapes.
- Consumes: nothing.

- [ ] **Step 1: Update scenario headings and success criteria in the feature template**

In `templates/specs/feature.template.md` replace the three scenario headings (lines 24, 30, 36)
and the success-criteria list (lines 46-51) so the `## What` and `## Success criteria` sections
read:

```markdown
## What

<!-- Behavior described as Given/When/Then. List ALL relevant scenarios, including failure
     modes. Scenario IDs (SC-1, SC-2, ...) are stable handles: tasks reference them in their
     `Covers` field and /sd:verify checks the coverage. Number sequentially; never reuse an ID
     after deleting a scenario. -->

### SC-1: <<happy path name>>

- **Given** <<initial state>>
- **When** <<action>>
- **Then** <<observable outcome>>

### SC-2: <<edge case name>>

- **Given** <<initial state>>
- **When** <<action>>
- **Then** <<observable outcome>>

### SC-3: <<failure mode>>

- **Given** <<initial state>>
- **When** <<action that should fail>>
- **Then** <<expected failure behavior - error type, status code, log entry, etc.>>

## Success criteria

<!-- Concrete, checkable. NOT "works well" - measurable. Criterion IDs (AC-1, AC-2, ...) are
     stable handles referenced by task `Covers` fields and checked by /sd:verify. -->

- [ ] AC-1: <<criterion 1, e.g. POST /api/notifications/subscribe returns 201 with subscription ID>>
- [ ] AC-2: <<criterion 2, e.g. Webhook fires within 5s of inventory drop below threshold>>
- [ ] AC-3: <<criterion 3, e.g. Failed webhook retries 3x with exponential backoff>>
- [ ] AC-4: <<criterion 4, e.g. p95 latency on subscribe endpoint < 100ms>>
- [ ] AC-5: Unit + integration tests cover all scenarios above
- [ ] AC-6: No new constitution exceptions
```

Leave every other section of the template untouched. The `<<...>>` author-fill tokens stay -
only the headings/prefixes around them change.

- [ ] **Step 2: Add SC/AC authoring rules to sd-spec-templates**

In `skills/sd-spec-templates/SKILL.md`, in the section covering the feature template (it lists
scenario and success-criteria rules around lines 41-42), add these rules as list items:

```markdown
- Scenario headings use stable IDs: `### SC-<n>: <name>`. IDs are sequential from SC-1 and are
  never renumbered or reused after a scenario is deleted - downstream `Covers` fields and
  `/sd:verify` reports reference them.
- Success criteria use stable IDs: `- [ ] AC-<n>: <criterion>`. Same stability rule as SC IDs.
- Every SC and AC ID must be covered by at least one task's `Covers` field in `02-tasks.md`
  before `/sd:verify` can pass (see sd-atomic-task-format).
```

- [ ] **Step 3: Add the Covers field to sd-atomic-task-format**

In `skills/sd-atomic-task-format/SKILL.md`:

1. In the canonical task block (lines 10-23), insert one line directly after
   `- **Acceptance**: <observable criterion>`:

```markdown
- **Covers**: <SC-/AC-ID list, e.g. SC-1, AC-2 | none>
```

2. Change the block heading `## Task block (9 required fields + Pattern refs)` to
   `## Task block (10 required fields + Pattern refs)` and the sentence
   `The first 9 fields are **required**, not optional.` to
   `The first 10 fields are **required**, not optional.`

3. In the `## Field rules` section add, after the `### Acceptance` subsection:

```markdown
### Covers

Comma-separated scenario (SC-<n>) and success-criterion (AC-<n>) IDs from `00-spec.md` that
this task implements or proves. `none` is allowed only for pure wiring/polish tasks that
advance no criterion directly. Every ID referenced must exist in the spec; every SC and AC in
the spec must be covered by at least one task - `/sd:verify` fails the spec otherwise. Specs
authored before this field existed (no SC/AC IDs) are handled by `/sd:verify`'s generic
checks; treat a missing field as `Covers: none` when reading legacy `02-tasks.md` files.
```

- [ ] **Step 4: Teach the spec architect to fill Covers**

In `agents/spec-architect.md`, in the task-authoring section (the part describing `02-tasks.md`
authoring, lines 63-76), add one instruction bullet:

```markdown
- Fill `Covers` on every task: list the SC-/AC-IDs from `00-spec.md` the task implements or
  proves. Before finishing, cross-check that every SC and AC ID in the spec appears in at
  least one task's `Covers` - an uncovered criterion means the task list is incomplete, not
  that the criterion is optional.
```

- [ ] **Step 5: Add the coverage check to the reviewer's holistic checklist**

In `agents/reviewer.md`, in the `holistic` task-type checklist (lines 59-66), add one item:

```markdown
- [ ] Scenario/criterion coverage: every SC-<n> and AC-<n> ID in `00-spec.md` appears in at
  least one task's `Covers` field in `02-tasks.md`, and each covering task's `Test` exists.
  Report an uncovered ID as a 🔴 BLOCK finding citing the spec line.
```

- [ ] **Step 6: Verify the shapes are consistent**

Run:

```bash
grep -n "SC-1" templates/specs/feature.template.md && \
grep -n "AC-1" templates/specs/feature.template.md && \
grep -n "Covers" skills/sd-atomic-task-format/SKILL.md agents/spec-architect.md agents/reviewer.md skills/sd-spec-templates/SKILL.md
```

Expected: at least one hit per file; the task-block line reads exactly
`- **Covers**: <SC-/AC-ID list, e.g. SC-1, AC-2 | none>`.

- [ ] **Step 7: Commit**

```bash
git add templates/specs/feature.template.md skills/sd-spec-templates/SKILL.md \
  skills/sd-atomic-task-format/SKILL.md agents/spec-architect.md agents/reviewer.md
git commit -m "Add SC/AC traceability IDs and Covers task field"
```

---

### Task 2: The /sd:verify command

**Files:**
- Create: `commands/verify.md`

**Interfaces:**
- Consumes: SC/AC/Covers shapes from Task 1; `spec.dir`, `spec.indexFile`, `commands.test` from
  `.claude/project-config.json`; skills `sd-severity-taxonomy` and `sd-evidence-citation` read
  from disk at runtime (same pattern as `/sd:spec validate`, see `commands/spec.md:283-287`).
- Produces: the artifact contract `.specs/<ID>/06-verify.md` with frontmatter `result: pass` or
  `result: fail` - Tasks 3 and 4 depend on exactly this filename and marker line.

- [ ] **Step 1: Read the conventions files**

Read `commands/spec.md` in full (frontmatter shape, Phase 0 bootstrap, the `validate`
subcommand's rule-ID table and reporting format) and `commands/release.md` (single-transaction
command shape). The new command must feel like a sibling of these two.

- [ ] **Step 2: Create commands/verify.md**

Create `commands/verify.md` with exactly this content:

````markdown
---
description: Verify criterion -> task -> test traceability for a spec and write the 06-verify.md close-out gate artifact
argument-hint: <spec-ID>
---

# /sd:verify - traceability verification gate

Pure verification command - no subagent, no code changes, no edits outside the spec's own
folder. Proves that every success criterion and scenario in `00-spec.md` is implemented by at
least one task in `02-tasks.md` and observable through at least one existing test, then runs
the project test suite and writes `<spec.dir>/<ID>/06-verify.md` recording the verdict.

The spec-gate hook blocks an `index.md` row transitioning to `done` unless this artifact
records `result: pass`. Re-run the command after fixing findings; it overwrites the artifact.

## State machine

| Condition | State | Behavior |
|---|---|---|
| Spec folder missing | not-found | STOP with VF001 |
| `02-tasks.md` missing | not-planned | STOP with VF002 |
| Otherwise | verifiable | Run all applicable checks, write artifact |

Any status may be verified (verification before `in-progress` is allowed and useful), but the
artifact only matters to the hook at the `in-progress -> done` transition.

## Phase 0 - Bootstrap (always)

1. Read `.claude/project-config.json` -> `spec.dir`, `spec.indexFile`, `commands.test`.
   Missing config -> STOP: "No project config found - run /sd:setup first."
2. Resolve `<arg>` against `<spec.dir>/`: accept a full ID (`FEAT-1042`) or unique suffix.
   Ambiguous or missing -> STOP listing candidates.
3. Read from disk (commands cannot load skills via frontmatter):
   - `~/.claude/skills/sd/sd-severity-taxonomy/SKILL.md`
   - `~/.claude/skills/sd/sd-evidence-citation/SKILL.md`

## Checks

Stable rule IDs (report every finding as `VF0xx`, severity per sd-severity-taxonomy, citing
`file:line` relative to project root). Generic rules apply to all spec types; traceability
rules apply when the corresponding section exists in `00-spec.md`.

| ID | Applies | Check | Severity |
|---|---|---|---|
| VF001 | all | Spec folder and `00-spec.md` exist | BLOCK |
| VF002 | all | `02-tasks.md` exists | BLOCK |
| VF003 | all | Spec frontmatter `id` matches the folder name | BLOCK |
| VF010 | spec has `SC-<n>:` scenario headings | Every SC ID is listed in >=1 task's `Covers` | BLOCK |
| VF011 | spec has `AC-<n>:` criteria | Every AC ID is listed in >=1 task's `Covers` | BLOCK |
| VF012 | tasks have `Covers` | Every ID referenced in a `Covers` exists in `00-spec.md` | BLOCK |
| VF013 | feature specs | `## Success criteria` checkboxes carry `AC-<n>:` prefixes | WARN |
| VF020 | all | Every task whose `Covers` != none has a `Test` field that is not `none`/empty | BLOCK |
| VF021 | all | Every file path named in a `Test` field exists (use Glob; a `Test` naming a suite/pattern instead of a path is checked by VF022 only) | BLOCK |
| VF022 | all | `commands.test` from project-config runs and exits green | BLOCK |
| VF023 | `commands.test` empty/null | Cannot run tests - report and continue | WARN |
| VF030 | all | Every `## Success criteria` checkbox in `00-spec.md` is checked (`- [x]`) | BLOCK |

Parsing shapes (exact):

- Scenario IDs: headings matching `^### SC-([0-9]+):` in `00-spec.md`.
- Criterion IDs: lines matching `^- \[[ xX]\] AC-([0-9]+):` in `00-spec.md`.
- Covers: task lines matching `^- \*\*Covers\*\*: (.+)$` in `02-tasks.md`; split on commas;
  `none` means no IDs. A task block with no `Covers` line is treated as `Covers: none`
  (legacy compatibility).
- Test files: from each `- **Test**: ...` value, extract tokens that look like relative paths
  (contain `/` or a file extension); check each with Glob.

VF022 execution: run `commands.test` via Bash from the project root. Capture the exit code.
Do not guess a test command when `commands.test` is empty - that is VF023 (stack-agnostic
rule: never hardcode `dotnet test`, `npm test`, etc.).

## Artifact

ALWAYS write `<spec.dir>/<ID>/06-verify.md` (overwrite an existing one) - on pass AND on fail:

```markdown
---
spec: <ID>
result: <pass | fail>
date: <YYYY-MM-DD>
failures: <count of BLOCK findings>
---

# Verification report - <ID>

## Traceability

| ID | Kind | Covered by | Test(s) | Status |
|---|---|---|---|---|
| SC-1 | scenario | T01, T03 | tests/... | PASS |
| AC-1 | criterion | T02 | tests/... | PASS |

## Test run

- Command: `<commands.test or "not configured (VF023)">`
- Exit code: <n or "-">

## Findings

<severity-tagged VF0xx findings with file:line citations, or "none">
```

`result: pass` if and only if there are zero BLOCK-severity findings. WARN findings (VF013,
VF023) do not fail the run but must appear under Findings.

## Output

Print to the user: the traceability table, the findings list, the artifact path, and one of:

- `[OK] <ID> verified - result: pass recorded in <spec.dir>/<ID>/06-verify.md`
- `[FAIL] <ID> verification failed (<n> BLOCK findings) - result: fail recorded. Close-out is
  blocked until /sd:verify passes.`

## Hard constraints

- Never edit any file except `<spec.dir>/<ID>/06-verify.md`.
- Never invoke a subagent.
- Never mark a criterion covered without a concrete task ID + existing test citation.
- Findings without a `file:line` citation are invalid (sd-evidence-citation).
````

- [ ] **Step 3: Sanity-check the file**

Run:

```bash
grep -c "VF0" commands/verify.md && head -5 commands/verify.md
```

Expected: >= 13 rule-ID mentions; frontmatter starts with `---` and has `description:` +
`argument-hint:` only (commands do not carry `skills:` - see `commands/spec.md:1-4`).

- [ ] **Step 4: Commit**

```bash
git add commands/verify.md
git commit -m "Add /sd:verify traceability gate command"
```

---

### Task 3: Workflow integration - feature close-out and spec registry

**Files:**
- Modify: `commands/feature.md` (Phase 6, lines 177-187)
- Modify: `commands/spec.md` (status section ~lines 78-122, artifact list ~line 71, validate
  rule table ~lines 246-273)

**Interfaces:**
- Consumes: `/sd:verify` and the `06-verify.md` / `result: pass` contract from Task 2.
- Produces: prose gates that Tasks 4's hook enforcement backs mechanically; validate rule
  `SL055` (WARN) for done-specs without a passing artifact.

- [ ] **Step 1: Insert the verify step into feature close-out**

In `commands/feature.md` Phase 6 (currently a 4-item list at lines 179-187), insert a new step
1 and renumber the rest:

```markdown
## Phase 6 - Close-out

1. Run `/sd:verify FEAT-<arg>`. It must report `result: pass`.
   - On FAIL: address the findings (uncovered criterion -> back to Phase 3 to add tasks;
     failing tests -> back to Phase 4). Re-run until it passes. Do NOT proceed on fail - the
     spec-gate hook will block step 4 without a passing `06-verify.md`.
2. Append to `.specs/FEAT-<arg>/05-retro.md`:
   - Tasks completed (count + IDs).
   - Surprises encountered.
   - Deferred follow-ups (with reserved spec IDs, if any).
   - Constitution exceptions taken (should be none).
   - Cost rough estimate if available.
3. Set frontmatter status=`done` in `00-spec.md`.
4. Update `.specs/index.md`: state -> `done`, completion date.
5. Print a 5-line summary to the user.
```

- [ ] **Step 2: Document the gated transition in the spec registry command**

In `commands/spec.md`:

1. In the status-transition section (the `in-progress -> done` row of the lifecycle, lines
   78-122), add:

```markdown
The `in-progress -> done` transition is hook-enforced: spec-gate blocks the `index.md` edit
unless `<spec.dir>/<ID>/06-verify.md` exists and records `result: pass`. Run `/sd:verify <ID>`
first. Disable only via `hooks.specGate.verifyGate: false` in project-config.
```

2. In the spec-folder artifact list (line ~71, the enumeration ending `05-retro.md`), extend it
   with `06-verify.md` and one line describing it:
   `06-verify.md - verification report written by /sd:verify; gates the done transition.`

3. In the validate rule-ID table (lines 246-273), append one row:

```markdown
| SL055 | Spec status `done` but `06-verify.md` is missing or records `result: fail` | WARN |
```

(WARN, not BLOCK: specs closed before SW-6 have no artifact and must not start failing
validation retroactively.)

- [ ] **Step 3: Verify cross-references resolve**

Run:

```bash
grep -n "sd:verify" commands/feature.md commands/spec.md && grep -n "SL055" commands/spec.md
```

Expected: feature.md Phase 6 references `/sd:verify FEAT-<arg>`; spec.md mentions the
verifyGate flag and lists SL055 exactly once in the rule table.

- [ ] **Step 4: Commit**

```bash
git add commands/feature.md commands/spec.md
git commit -m "Gate feature close-out on /sd:verify pass"
```

---

### Task 4: Spec-gate hook verify gate (paired ps1 + sh) with conformance fixtures

**Files:**
- Create: `tests/hooks/fixtures/spec-gate/block-index-done-no-verify/{input.json,expected.json,workspace/...}`
- Create: `tests/hooks/fixtures/spec-gate/allow-index-done-with-verify/{...}`
- Create: `tests/hooks/fixtures/spec-gate/block-index-done-verify-fail/{...}`
- Create: `tests/hooks/fixtures/spec-gate/block-index-nondone-edit/{...}`
- Create: `tests/hooks/fixtures/spec-gate/block-index-done-multiedit-no-verify/{...}`
- Create: `tests/hooks/fixtures/spec-gate/block-index-done-gate-disabled/{...}`
- Modify: `hooks/powershell/spec-gate.ps1`
- Modify: `hooks/bash/spec-gate.sh`
- Modify: `templates/project-config.template.json` (hooks.specGate block, lines 122-126)
- Test: `tests/hooks/run-conformance.ps1`

**Interfaces:**
- Consumes: `06-verify.md` + `result: pass` contract (Task 2); the exact block reason string
  from "Normalized strings" above.
- Produces: `hooks.specGate.verifyGate` config flag; Rule 0 behavior all later docs describe.

- [ ] **Step 1: Read the harness and one existing fixture pair**

Read `tests/hooks/run-conformance.ps1` (note `ConvertTo-SpecGateDecision`, lines 172-213, and
how `{{CWD}}` is substituted) plus the existing
`tests/hooks/fixtures/spec-gate/block-protected-path/` and `allow-in-progress-spec/` cases
(input.json + expected.json + workspace layout). New fixtures MUST mirror their exact JSON
shapes - if the shapes below differ from what you find on disk, the on-disk shape wins.

- [ ] **Step 2: Write the six new fixtures (failing first)**

Shared workspace content - each case's `workspace/.specs/index.md` (unless noted):

```markdown
# Spec index

Auto-updated by /sd:spec status transitions.

| ID | Type | Status | Created | Title |
|---|---|---|---|---|
| FEAT-001 | feature | in-progress | 2026-07-01 | Demo feature |
```

1. `block-index-done-no-verify/input.json` (no `06-verify.md` in workspace):

```json
{
  "tool_name": "Edit",
  "cwd": "{{CWD}}",
  "tool_input": {
    "file_path": "{{CWD}}/.specs/index.md",
    "old_string": "| FEAT-001 | feature | in-progress | 2026-07-01 | Demo feature |",
    "new_string": "| FEAT-001 | feature | done | 2026-07-01 | Demo feature |"
  }
}
```

`expected.json` -> block with the verify-gate reason (from Normalized strings, with
`<IDS>` = `FEAT-001`, `<SPECDIR>` = `.specs`).

2. `allow-index-done-with-verify/` - same input; workspace adds
   `workspace/.specs/FEAT-001/06-verify.md`:

```markdown
---
spec: FEAT-001
result: pass
date: 2026-07-20
failures: 0
---

# Verification report - FEAT-001
```

`expected.json` -> allow (exit 0, no decision output).

3. `block-index-done-verify-fail/` - same as case 2 but the artifact line is `result: fail`
   -> expected block with the same verify-gate reason.

4. `block-index-nondone-edit/` - input edits the index WITHOUT any done transition:

```json
{
  "tool_name": "Edit",
  "cwd": "{{CWD}}",
  "tool_input": {
    "file_path": "{{CWD}}/.specs/index.md",
    "old_string": "| FEAT-001 | feature | in-progress | 2026-07-01 | Demo feature |",
    "new_string": "| FEAT-001 | feature | in-progress | 2026-07-01 | Renamed demo feature |"
  }
}
```

`expected.json` -> block with the UNCHANGED protected-path reason for `.specs/index.md`
(regression guard: fall-through to Rule 1 must still fire).

5. `block-index-done-multiedit-no-verify/` - MultiEdit payload, no artifact:

```json
{
  "tool_name": "MultiEdit",
  "cwd": "{{CWD}}",
  "tool_input": {
    "file_path": "{{CWD}}/.specs/index.md",
    "edits": [
      {
        "old_string": "| FEAT-001 | feature | in-progress | 2026-07-01 | Demo feature |",
        "new_string": "| FEAT-001 | feature | done | 2026-07-01 | Demo feature |"
      }
    ]
  }
}
```

`expected.json` -> block with the verify-gate reason.

6. `block-index-done-gate-disabled/` - same input as case 1 PLUS a passing artifact in the
   workspace PLUS `workspace/.claude/project-config.json`. IMPORTANT: a config file replaces
   the hook's built-in defaults wholesale, so it must restate the protected list:

```json
{
  "spec": { "dir": ".specs", "indexFile": ".specs/index.md" },
  "paths": { "protected": [".specs/constitution.md", ".specs/index.md", "LICENSE"] },
  "hooks": { "specGate": { "enabled": true, "mode": "warn", "verifyGate": false } }
}
```

`expected.json` -> block with the protected-path reason (gate off = today's behavior, even
with a passing artifact).

- [ ] **Step 3: Run the conformance suite - expect the new cases to FAIL**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1`
Expected: all pre-existing cases PASS; the six new cases FAIL (hook does not implement the
rule yet). If a new *block* case fails because the reason string differs rather than because
no block was emitted, fix the fixture only if the on-disk expected.json schema was wrong.

- [ ] **Step 4: Implement Rule 0 in spec-gate.ps1**

In `hooks/powershell/spec-gate.ps1` add two functions after `Get-InProgressSpecs`
(line 262):

```powershell
function Get-DoneTransitionIds {
    param(
        [object]$HookInput,
        [string]$IndexPath
    )
    # IDs that the pending edit marks as done but that the on-disk index does
    # not yet record as done. Fragments are the tool-specific NEW content.
    $fragments = New-Object System.Collections.Generic.List[string]
    try {
        $tool = $HookInput.tool_name
        if ($tool -eq 'Edit') {
            if ($HookInput.tool_input.new_string) {
                $fragments.Add([string]$HookInput.tool_input.new_string) | Out-Null
            }
        } elseif ($tool -eq 'Write') {
            if ($HookInput.tool_input.content) {
                $fragments.Add([string]$HookInput.tool_input.content) | Out-Null
            }
        } elseif ($tool -eq 'MultiEdit') {
            foreach ($e in @($HookInput.tool_input.edits)) {
                if ($e.new_string) { $fragments.Add([string]$e.new_string) | Out-Null }
            }
        }
    } catch { }

    $alreadyDone = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $IndexPath) {
        try {
            foreach ($line in (Get-Content -LiteralPath $IndexPath -Encoding UTF8 -ErrorAction Stop)) {
                if ($line -match '\|\s*done\s*\|' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
                    [void]$alreadyDone.Add($Matches[0])
                }
            }
        } catch { }
    }

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($frag in $fragments) {
        foreach ($line in ($frag -split "`n")) {
            if ($line -match '\|\s*done\s*\|' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
                $id = $Matches[0]
                if (-not $alreadyDone.Contains($id) -and -not $result.Contains($id)) {
                    $result.Add($id) | Out-Null
                }
            }
        }
    }
    return ,$result
}

function Test-VerifyArtifactPass {
    param(
        [string]$Cwd,
        [string]$SpecDir,
        [string]$SpecId
    )
    $artifact = Join-Path $Cwd (Join-Path $SpecDir (Join-Path $SpecId '06-verify.md'))
    if (-not (Test-Path -LiteralPath $artifact)) { return $false }
    try {
        $content = Get-Content -LiteralPath $artifact -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
        return $false
    }
    return ($content -match '(?im)^result:\s*pass\s*$')
}
```

Then in the main block, insert Rule 0 AFTER `$rel` is computed (line 307) and BEFORE the
`# Rule 1: protected paths` comment (line 309):

```powershell
# Rule 0: verify gate on the spec index. A row transitioning to done requires
# a passing /sd:verify artifact; a verified close-out is allowed through the
# protected-path rule. Any other direct index edit falls through to Rule 1.
$verifyGateOn = $true
try { if ($config.hooks.specGate.verifyGate -eq $false) { $verifyGateOn = $false } } catch { }

$indexRel = '.specs/index.md'
try { if ($config.spec.indexFile) { $indexRel = ([string]$config.spec.indexFile).Replace('\','/') } } catch { }
$specDir = '.specs'
try { if ($config.spec.dir) { $specDir = [string]$config.spec.dir } } catch { }

if ($verifyGateOn -and [string]::Equals($rel, $indexRel, [System.StringComparison]::OrdinalIgnoreCase)) {
    $indexAbs = Join-Path $cwd $indexRel
    $doneIds = Get-DoneTransitionIds -HookInput $hookInput -IndexPath $indexAbs
    if ($doneIds.Count -gt 0) {
        $missing = New-Object System.Collections.Generic.List[string]
        foreach ($id in $doneIds) {
            if (-not (Test-VerifyArtifactPass -Cwd $cwd -SpecDir $specDir -SpecId $id)) {
                $missing.Add($id) | Out-Null
            }
        }
        if ($missing.Count -gt 0) {
            $ids = (@($missing) | Sort-Object) -join ', '
            Write-BlockDecision "spec-gate: index row(s) [$ids] -> done but no passing /sd:verify artifact. Run /sd:verify <spec-ID>; close-out is allowed only after $specDir/<ID>/06-verify.md records 'result: pass'."
            exit 0
        }
        # Every transitioning spec has a passing artifact - allow the close-out.
        exit 0
    }
}
```

- [ ] **Step 5: Implement the identical rule in spec-gate.sh**

In `hooks/bash/spec-gate.sh`, insert between the `emit_block` helper (ends line 206) and the
`# --- Rule 1` comment (line 208):

```bash
# --- Rule 0: verify gate on the spec index ------------------------------------
# A row transitioning to done requires a passing /sd:verify artifact; a
# verified close-out is allowed through the protected-path rule. Any other
# direct index edit falls through to Rule 1. Mirrors spec-gate.ps1 Rule 0.

verify_gate="$(printf '%s' "${config_json}" | jq -r 'if .hooks.specGate.verifyGate == false then "false" else "true" end' 2>/dev/null)"
spec_dir="$(printf '%s' "${config_json}" | jq -r '.spec.dir // ".specs"' 2>/dev/null)"

rel_lower="$(to_lower "${rel}")"
index_rel_norm="${index_rel//\\//}"
index_rel_lower="$(to_lower "${index_rel_norm}")"

if [[ "${verify_gate}" == "true" && "${rel_lower}" == "${index_rel_lower}" ]]; then
    fragments=""
    case "${tool_name}" in
        Edit)      fragments="$(printf '%s' "${input}" | jq -r '.tool_input.new_string // empty' 2>/dev/null)" ;;
        Write)     fragments="$(printf '%s' "${input}" | jq -r '.tool_input.content // empty' 2>/dev/null)" ;;
        MultiEdit) fragments="$(printf '%s' "${input}" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)" ;;
    esac

    if [[ -n "${fragments}" ]]; then
        # IDs marked done in the pending edit's new content.
        pending_done="$(printf '%s' "${fragments}" \
            | grep -E '\|[[:space:]]*done[[:space:]]*\|' 2>/dev/null \
            | grep -o -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' 2>/dev/null \
            | tr -d '\r' | LC_ALL=C sort -u)"
        # IDs the on-disk index already records as done (not a transition).
        already_done=""
        if [[ -f "${index_path}" ]]; then
            already_done="$(grep -E '\|[[:space:]]*done[[:space:]]*\|' "${index_path}" 2>/dev/null \
                | grep -o -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' 2>/dev/null \
                | tr -d '\r' | LC_ALL=C sort -u)"
        fi

        transition_ids=""
        while IFS= read -r id; do
            [[ -z "${id}" ]] && continue
            if [[ -n "${already_done}" ]] && printf '%s\n' "${already_done}" | grep -qx "${id}"; then
                continue
            fi
            transition_ids="${transition_ids}${id}"$'\n'
        done <<< "${pending_done}"

        if [[ -n "${transition_ids}" ]]; then
            missing=""
            while IFS= read -r id; do
                [[ -z "${id}" ]] && continue
                artifact="${cwd}/${spec_dir}/${id}/06-verify.md"
                if [[ ! -f "${artifact}" ]] \
                   || ! grep -q -i -E '^result:[[:space:]]*pass[[:space:]]*$' "${artifact}" 2>/dev/null; then
                    if [[ -z "${missing}" ]]; then
                        missing="${id}"
                    else
                        missing="${missing}, ${id}"
                    fi
                fi
            done <<< "${transition_ids}"

            if [[ -n "${missing}" ]]; then
                emit_block "spec-gate: index row(s) [${missing}] -> done but no passing /sd:verify artifact. Run /sd:verify <spec-ID>; close-out is allowed only after ${spec_dir}/<ID>/06-verify.md records 'result: pass'."
                exit 0
            fi
            # Every transitioning spec has a passing artifact - allow the close-out.
            exit 0
        fi
    fi
fi
```

NOTE: Rule 1 (line 211) already computes `rel_lower="$(to_lower "${rel}")"`. After inserting
Rule 0 (which now computes it first), the duplicate assignment in Rule 1 is harmless - leave
it, matching the minimal-diff principle. `missing` is built in `LC_ALL=C sort -u` order, which
equals the ps1 `Sort-Object` ordinal order for these all-ASCII-uppercase IDs.

- [ ] **Step 6: Add the verifyGate flag to the config template**

In `templates/project-config.template.json`, in the `hooks.specGate` object (lines 122-126),
add after `"mode"`:

```json
"verifyGate": true,
"_verifyGate_use": "true: an index.md row may transition to done only when <spec.dir>/<ID>/06-verify.md records 'result: pass' (written by /sd:verify). false: index.md stays fully protected as before SW-6."
```

Match the surrounding `_use`-style documentation-key convention exactly as found in the file.

- [ ] **Step 7: Syntax + ASCII checks**

Run:

```bash
bash -n hooks/bash/spec-gate.sh && grep -nP "[^\x00-\x7F]" hooks/powershell/*.ps1 install/*.ps1; echo "exit=$?"
```

Expected: `bash -n` silent; the grep finds nothing (exit=1 from grep means no matches - that
is the PASS condition).

- [ ] **Step 8: Run the conformance suite - expect all green**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1`
Expected: every case PASSES, including all pre-existing spec-gate cases (especially
`block-protected-path` and the traversal variants) and all six new ones. Also run
`pwsh -NoProfile -File tests/hooks/run-conformance.ps1 -SelfTest` - expected: self-test still
detects seeded divergence.

- [ ] **Step 9: Manual smoke (bash path)**

Run from a scratch dir with the fixture workspace shape (no artifact):

```bash
echo '{"tool_name":"Edit","cwd":"'$PWD'","tool_input":{"file_path":"'$PWD'/.specs/index.md","old_string":"| FEAT-001 | feature | in-progress | 2026-07-01 | Demo feature |","new_string":"| FEAT-001 | feature | done | 2026-07-01 | Demo feature |"}}' | bash hooks/bash/spec-gate.sh
```

Expected: one-line JSON with `"decision":"block"` and the verify-gate reason naming FEAT-001.

- [ ] **Step 10: Commit**

```bash
git add hooks/powershell/spec-gate.ps1 hooks/bash/spec-gate.sh \
  templates/project-config.template.json tests/hooks/fixtures/spec-gate/
git commit -m "Enforce /sd:verify pass on index done transition"
```

---

### Task 5: Documentation, counts, and CHANGELOG

**Files:**
- Modify: `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `install/README.md`,
  `docs/architecture.md`, `docs/usage.md`, `commands/setup.md`, `specwright.manifest.json`,
  `CHANGELOG.md`

**Interfaces:**
- Consumes: the command list now containing `verify.md` (12 commands).
- Produces: docs consistent with `scripts/validate` Check 7 (docClaims).

- [ ] **Step 1: Update every count and command list from 11 to 12**

Exact known locations (verify each with grep before editing; line numbers may have drifted):

- `README.md:4` - tagline word "Eleven" -> "Twelve".
- `README.md:29` - `**11 slash commands**` -> `**12 slash commands**`; append `/sd:verify` to
  the name list.
- `README.md:~100` - command table: add row
  `| /sd:verify | Verify criterion -> task -> test traceability; writes the close-out gate artifact | (none) |`
  matching the existing table's column set.
- `CLAUDE.md:21` - `# expect 11 .md files` -> `# expect 12 .md files`.
- `CLAUDE.md:47` - `11 slash commands` -> `12 slash commands`; add `/sd:verify` to the
  parenthesized list.
- `CONTRIBUTING.md:44` - `commands/  # 11 slash commands` -> 12.
- `install/README.md:7`, `:49` (count + name list), `:84`, `:92` - 11 -> 12; add `/sd:verify`.
- `docs/architecture.md:13` - `11 workflow definitions` -> 12; `:116-122` routing tree - add
  `/sd:verify -> (none - pure file-ops)`; `:325` - `lists all 11 commands` -> 12. Leave the
  "5 workflow commands" statement at `:70` at 5.
- `commands/setup.md:325` - `(11 workflow commands)` -> `(12 workflow commands)` (or the
  file's current phrasing with 12; keep the docClaims phrase shape).
- `specwright.manifest.json` docClaims entries (~lines 123-170): wherever a claim phrase or
  expected value embeds `11` for the command count, update to `12`. Do not touch
  `workflowCommands` (stays the 5 pipeline commands).

- [ ] **Step 2: Add the usage docs section**

In `docs/usage.md`, following the `### /sd:release` / `### /sd:adr` precedent (lines ~234,
~265), add:

```markdown
### /sd:verify

Proves criterion -> task -> test traceability for one spec and writes
`.specs/<ID>/06-verify.md` with `result: pass|fail`. The spec-gate hook blocks the spec's
`index.md` row from transitioning to `done` without a passing artifact
(`hooks.specGate.verifyGate`, default on).

    /sd:verify FEAT-1042

Run it at close-out (Phase 6 of /sd:feature runs it for you) or any time earlier as a
progress check. A FAIL lists VF0xx findings with file:line citations.
```

Also add a row to the "When to use" table (~line 306):
`| Prove a spec is really done (criteria covered, tests pass) | /sd:verify |`

- [ ] **Step 3: CHANGELOG entry**

Under `## [Unreleased]` / `### Added` in `CHANGELOG.md`, add as the first bullet:

```markdown
- `/sd:verify <spec-ID>` traceability gate: SC-/AC-IDs in the feature template, a `Covers`
  task field, a `06-verify.md` pass artifact, and spec-gate hook enforcement that blocks an
  `index.md` row transitioning to `done` without a passing artifact
  (`hooks.specGate.verifyGate`). (SW-6)
```

- [ ] **Step 4: Run the docs validator**

Run: `pwsh -NoProfile -File scripts/validate.ps1`
Expected: PASS, including Check 7 (doc claims vs manifest). If any claim fails, the failure
message names the file and phrase - fix that spot, do not weaken the check.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md CONTRIBUTING.md install/README.md docs/architecture.md \
  docs/usage.md commands/setup.md specwright.manifest.json CHANGELOG.md
git commit -m "Document /sd:verify and bump command count to 12"
```

---

### Task 6: Example fixture refresh

**Files:**
- Modify: `examples/spec-lint-fixture/clean/.specs/FEAT-CLEAN-001/00-spec.md`
- Modify: `examples/spec-lint-fixture/clean/.specs/FEAT-CLEAN-001/02-tasks.md` (if present)
- Create: `examples/spec-lint-fixture/clean/.specs/FEAT-CLEAN-001/06-verify.md`

**Interfaces:**
- Consumes: SC/AC/Covers shapes (Task 1), artifact format (Task 2).
- Produces: a canonical filled example of the new traceability shapes.

- [ ] **Step 1: Add IDs to the clean fixture spec**

In `examples/spec-lint-fixture/clean/.specs/FEAT-CLEAN-001/00-spec.md`, rename each
`### Scenario <n>: <name>` heading to `### SC-<n>: <name>` and prefix each success-criteria
checkbox with `AC-<n>: ` (sequential from 1), preserving all existing text and checked-state.

- [ ] **Step 2: Add Covers lines to the fixture tasks**

If the fixture has a `02-tasks.md`: add a `- **Covers**: ...` line after each task's
`- **Acceptance**:` line, distributing the SC/AC IDs so every ID is covered by at least one
task. If the fixture has no `02-tasks.md`, skip this step and note it in the commit body.

- [ ] **Step 3: Add a passing verify artifact**

Create `examples/spec-lint-fixture/clean/.specs/FEAT-CLEAN-001/06-verify.md` using the Task 2
artifact format with `result: pass`, `failures: 0`, a traceability table consistent with the
IDs from steps 1-2, and Findings `none`. Use `date: 2026-07-21`.

- [ ] **Step 4: Check the fixture is still "clean"**

Read `examples/spec-lint-fixture/README.md` and confirm the clean fixture's promises still
hold (the linter there is prompt-driven, run by hand - the check here is consistency: IDs
sequential, every ID covered, artifact result matches). Confirm broken fixtures were NOT
touched. Then run `pwsh -NoProfile -File scripts/validate.ps1` again - expected PASS
(manifest excludes broken fixtures from doc scans; the clean fixture must not trip anything).

- [ ] **Step 5: Commit**

```bash
git add examples/spec-lint-fixture/clean/
git commit -m "Show SC/AC traceability in clean example fixture"
```

---

## Verification (whole feature)

1. `pwsh -NoProfile -File tests/hooks/run-conformance.ps1` - all fixtures green on both hook
   implementations; `-SelfTest` still detects seeded divergence.
2. `pwsh -NoProfile -File scripts/validate.ps1` - all checks pass (doc claims now say 12).
3. `bash -n hooks/bash/spec-gate.sh` silent;
   `grep -nP "[^\x00-\x7F]" hooks/powershell/*.ps1 install/*.ps1` finds nothing.
4. Sandbox install round-trip:
   `.\install\install.ps1 -BasePath C:\temp\sd-test` then
   `Get-ChildItem C:\temp\sd-test\commands\sd\` - expect **12** .md files including
   `verify.md`; `.\install\uninstall.ps1 -BasePath C:\temp\sd-test -Force`; remove the dir.
5. Jira SW-6 acceptance walk-through: in a scratch project, author a feature spec with an AC
   that no task covers -> `/sd:verify` reports VF011 FAIL and writes `result: fail`; the
   spec-gate hook (echo-pipe smoke as in Task 4 Step 9) blocks the `done` edit; add the
   covering task + passing artifact -> hook allows the edit.
6. CHANGELOG has the `(SW-6)` bullet under `[Unreleased]`.
