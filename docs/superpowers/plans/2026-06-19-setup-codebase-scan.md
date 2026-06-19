# `/sd:setup` Codebase Scan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/sd:setup` sample the codebase and pre-fill detected *facts* (stack, paths, commands, layers) into `CLAUDE.md` and `project-config.json`, replacing blank `<<placeholder>>`s, without adding interrogation questions or touching constitution rules.

**Architecture:** Pure prompt-engineering change. specwright has no application code - the deliverables are markdown command files plus JSON templates. The "scan" is Claude-driven bounded file sampling described in `commands/setup.md`; there is no scanner script. A new `paths.layers` field is added to the project-config template.

**Tech Stack:** Markdown (ATX headers, 100-char soft wrap), JSON template, PowerShell + bash validate scripts. No build system, no unit-test framework.

## Global Constraints

- Stack-agnostic: no hardcoded stack commands (`dotnet test`, `npm test`) or language assumptions; detected commands come only from what a project's manifest declares.
- `/sd:setup` asks at most **3** interactive questions. The scan adds a single batch *confirmation*, not a 4th question.
- Idempotent; never overwrites without a timestamped backup.
- Constitution rules (`.specs/constitution.md` `§1`-`§6`) are never auto-filled - facts only.
- Generated files have no BOM (UTF-8 only).
- `/sd:setup` writes only into the target project's CWD; never modifies the engine (`~/.claude/`).
- Markdown style: ATX headers, no trailing colons in headers, fenced blocks with language hint, 100-char soft wrap.
- Every PR adds a line under `## [Unreleased]` in `CHANGELOG.md` (Keep a Changelog / SemVer).
- Verification is `scripts/validate.{ps1,sh}` + dry-run install; there are no unit tests.

---

### Task 1: Add `paths.layers` to the project-config template

**Files:**
- Modify: `templates/project-config.template.json` (the `paths` object, lines ~47-56)

**Interfaces:**
- Produces: a `paths.layers` array of `{ "name": string, "path": string }` objects, ordered inside-out (innermost layer first), default `[]`. Task 2 reads this contract when wiring Phase 6.

- [ ] **Step 1: Add the `layers` field to the `paths` object**

In `templates/project-config.template.json`, change the `paths` block from:

```json
  "paths": {
    "src": "<<e.g. src>>",
    "tests": "<<e.g. tests>>",
    "docs": "<<e.g. docs>>",
    "protected": [
      ".specs/constitution.md",
      ".specs/index.md",
      "LICENSE"
    ]
  },
```

to:

```json
  "paths": {
    "src": "<<e.g. src>>",
    "tests": "<<e.g. tests>>",
    "docs": "<<e.g. docs>>",
    "layers": [],
    "_layers_use": "Ordered inside-out [{name, path}] (innermost first); path may be a glob. Backs constitution 1.1 dependency direction. Filled by /sd:setup scan; [] when undetectable.",
    "protected": [
      ".specs/constitution.md",
      ".specs/index.md",
      "LICENSE"
    ]
  },
```

- [ ] **Step 2: Verify the template is still valid JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('templates/project-config.template.json','utf8')); console.log('OK')"`
Expected: `OK`
(If `node` is unavailable, run `python -c "import json;json.load(open('templates/project-config.template.json'));print('OK')"`.)

- [ ] **Step 3: Verify no non-ASCII crept in**

Run: `grep -nP "[^\x00-\x7F]" templates/project-config.template.json`
Expected: no output (the `_layers_use` note must use plain ASCII - write "1.1", not a section sign).

- [ ] **Step 4: Commit**

```bash
git add templates/project-config.template.json
git commit -m "Add paths.layers field to project-config template"
```

---

### Task 2: Add the scan phase, batch gate, and wiring to `commands/setup.md`

**Files:**
- Modify: `commands/setup.md` (insert Phase 2.5 after Phase 2; extend Phase 4 step 2 and Phase 6 step 2; add a Rules bullet)
- Modify: `CHANGELOG.md` (append a bullet under `## [Unreleased]` -> `### Added`)

**Interfaces:**
- Consumes: `paths.layers` contract from Task 1 (ordered inside-out `{name, path}`, `[]` default).
- Produces: nothing downstream depends on this task in code; it is the terminal behavior change.

- [ ] **Step 1: Insert Phase 2.5 between Phase 2 and Phase 3**

After the Phase 2 block (ends at the line beginning "If `CLAUDE.md` does not exist, defaults come from filename heuristics...") and before the `## Phase 3 - Interactive questions` header, insert:

````markdown
---

## Phase 2.5 - Scan codebase (facts only)

Goal: detect project **facts** by sampling actual source, turning `<<placeholder>>`s into defaults.
This is Claude-driven sampling - there is NO scanner script. Detect facts ONLY; never infer
constitution rules.

1. Build a bounded picture of the tree:
   - Glob top-level directories and file-extension counts.
   - Skip `node_modules`, `bin`, `obj`, `.git`, `dist`, `target`, `vendor`, `.venv` and similar
     build/dependency directories.
   - Cap the directory walk at depth 3 and read at most ~15-20 representative files total.
2. Detect and record:
   - **Stack** (language / framework / db): extend the Phase 2 filename heuristics with a content peek
     at the dominant package manifest (`package.json`, `*.csproj`, `pyproject.toml`, `go.mod`,
     `Cargo.toml`, `pom.xml`, `build.gradle`).
   - **Paths**: `src`, `tests`, `docs` from the directory layout.
   - **Commands** (`build` / `test` / `lint` / `run` / `coverage`): read ONLY what the dominant
     manifest declares (e.g. `package.json` `scripts`, `Makefile` targets, csproj/pyproject targets).
     Never invent a stack command the manifest does not contain; leave unknown commands as
     `<<placeholder>>`.
   - **`paths.layers`**: an ordered inside-out array of `{ name, path }` inferred from top-level
     source folders that look like architectural layers (innermost first; `path` may be a glob).
     Use `[]` when no layered structure is detectable.
3. Log which files were sampled so the user can judge confidence.

### Gate - confirm detected facts (one batch confirmation, not a question)

Print a single table of detected facts and ask the user to confirm before writing:

```
Detected (edit any before I write, or say "go"):
  Language / framework / db : <values or "not detected">
  Paths   src / tests / docs : <values or "not detected">
  Layers (inside-out)        : <name:path, ... or "none">
  Commands build/test/lint/run/coverage : <values or "<<placeholder>>">
```

> Review these. Reply with corrections (e.g. "tests = test, drop the Infrastructure layer") or "go".

This is a confirmation of a batch, not a 4th interrogation question - the 3-question rule still holds.
Anything the user does not correct is used as-is; anything still unknown stays `<<placeholder>>`.
````

- [ ] **Step 2: Wire detected stack/commands/layers into Phase 4 (Generate CLAUDE.md)**

In `## Phase 4 - Generate CLAUDE.md`, step 2, replace the bullet:

```markdown
   - Pre-fill stack fields from Phase 2 inference; leave others as `<<placeholder>>` for the user to fill.
```

with:

```markdown
   - Pre-fill the Stack, Commands, and Architecture sections from Phase 2.5 detected facts (including
     the layer list from `paths.layers`, rendered inside-out). Leave any field not detected and not
     confirmed in the Phase 2.5 gate as `<<placeholder>>` for the user to fill.
```

- [ ] **Step 3: Wire detected facts into Phase 6 (Scaffold .claude/)**

In `## Phase 6 - Scaffold .claude/`, step 2, replace these two bullets:

```markdown
   - Set `commands.{build,test,lint,coverage,run}` from inferred or asked-on-the-spot values.
   - Set `paths.{src,tests,docs}` from inferred values.
```

with:

```markdown
   - Set `commands.{build,test,lint,coverage,run}` from Phase 2.5 detected facts; any command not
     declared by the project manifest stays `<<placeholder>>`.
   - Set `paths.{src,tests,docs}` from Phase 2.5 detected facts.
   - Set `paths.layers` from Phase 2.5 as an ordered inside-out array of `{name, path}` objects
     (innermost first); write `[]` if no layered structure was detected.
```

- [ ] **Step 4: Add a Rules bullet pinning the facts-only boundary**

In `## Rules (hard constraints)`, after the existing `**Stack-agnostic.**` bullet, add:

```markdown
- **Scan detects facts, never rules.** Phase 2.5 may pre-fill stack, paths, commands, and
  `paths.layers` only. It never writes `.specs/constitution.md` rules - those stay `<<placeholder>>`
  for the user to author explicitly.
```

- [ ] **Step 5: Add the CHANGELOG entry**

In `CHANGELOG.md`, under `## [Unreleased]` -> `### Added`, append:

```markdown
- `/sd:setup` codebase scan (Phase 2.5) - samples the project tree to pre-fill detected facts
  (stack, `paths.{src,tests,docs}`, `commands.*` from the project manifest, and a new ordered
  inside-out `paths.layers` map) into `CLAUDE.md` and `project-config.json`, with a single batch
  confirmation gate. Facts only - constitution rules are never auto-filled. Adds `paths.layers` to
  `templates/project-config.template.json`.
```

- [ ] **Step 6: Verify markdown structure and ASCII hygiene**

Run: `grep -nP "[^\x00-\x7F]" commands/setup.md CHANGELOG.md`
Expected: no output (use `->`, `[OK]`, plain digits - no arrows/em-dashes/section signs).

Run: `grep -n "Phase 2.5" commands/setup.md`
Expected: matches for the new header and the Phase 4/6 references.

- [ ] **Step 7: Verify the engine still installs cleanly (setup.md count unchanged)**

Run (PowerShell): `./scripts/validate.ps1`
Expected: all checks pass; command count still reports 10 `.md` files in `commands/sd/` (this change does not add a command).
(Unix: `bash scripts/validate.sh`.)

- [ ] **Step 8: Commit**

```bash
git add commands/setup.md CHANGELOG.md
git commit -m "Add facts-only codebase scan to /sd:setup"
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-06-19-setup-codebase-scan-design.md`):
- New Phase 2.5 scan (stack, paths, commands, layers, bounds, sampling log) -> Task 2 Step 1.
- Batch review gate (one confirmation) -> Task 2 Step 1 (Gate subsection).
- Phase 4 wiring -> Task 2 Step 2. Phase 6 wiring -> Task 2 Step 3.
- `paths.layers` template field -> Task 1.
- Facts-only / constitution-untouched -> Task 2 Step 4 (Rules bullet) + reaffirmed in Step 1.
- Constraints preserved (<=3 questions, idempotent, stack-agnostic, no BOM) -> Global Constraints + Task 2 Step 4.
- Verification (validate + dry-run, CHANGELOG entry) -> Task 1 Steps 2-3, Task 2 Steps 5-7.
- No gaps.

**Placeholder scan:** `<<placeholder>>` appears only as the literal token the engine writes into target
files (intended), never as an unfilled plan step. No TBD/TODO/"handle edge cases".

**Type consistency:** `paths.layers` is `[{name, path}]`, ordered inside-out, default `[]` - identical
wording in Task 1 (produces) and Task 2 Steps 1/3 (consumes). Command-count assertion is 10 in both the
constraint and Task 2 Step 7.
