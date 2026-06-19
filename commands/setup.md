---
description: Idempotent project scaffold. Detects state, asks 3 questions, generates CLAUDE.md + .specs/ + .claude/. Stack-agnostic.
argument-hint: (no args - interactive)
---

# /sd:setup

Scaffolds a project to use `specwright`. Safe to re-run: detects existing state and only fills gaps.

**No arguments.** Fully interactive.

---

## Phase 0 - Prerequisites check

1. Verify the following installed paths exist (i.e. the engine has been installed via the installer):
   - `~/.claude/templates/sd/`
   - `~/.claude/skills/sd/`
   - If either is missing -> abort with: "specwright install incomplete — `<missing path>` not found. Run `install/install.ps1` (Windows) or `install/install.sh` (Unix) from the specwright repo first."
2. Verify the current directory looks like a project root.
   - Heuristics: presence of `.git/`, OR a package manifest (`package.json`, `*.csproj`, `*.sln`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`).
   - If nothing found -> warn and ask: "This directory does not appear to be a project root. Continue anyway? (yes / no)".
3. Read `~/.claude/templates/sd/CLAUDE.template.md`, `constitution.template.md`, `project-config.template.json`, `settings.template.json` into memory. (Spec templates remain on disk for later.)

---

## Phase 1 - Detect existing state

Classify the project into one of four states:

| State | Detection | Action |
|---|---|---|
| `fresh` | No `CLAUDE.md`, no `.specs/`, no `.claude/` | Full scaffold |
| `post-init` | Has `CLAUDE.md` but no `.specs/` (e.g. ran `/init` only) | Backup `CLAUDE.md`, regenerate from template merging stack hints; scaffold `.specs/` and `.claude/` |
| `partial` | Has `.specs/` OR `.claude/` but not both, OR missing key files | Fill the missing pieces only; never overwrite existing |
| `complete` | Has `CLAUDE.md`, `.specs/constitution.md`, `.specs/index.md`, `.claude/project-config.json`, `.claude/settings.json` | Print "already set up - run `/sd:spec list` to view specs". Exit cleanly. |

Print the detected state and the planned changes BEFORE writing anything.

---

## Phase 2 - Parse existing CLAUDE.md (if present)

Goal: extract stack info to pre-fill answers in Phase 3.

1. Read existing `CLAUDE.md`.
2. Try to extract:
   - **Language**: from headers like "## Stack" -> "Language" or "Language:" patterns; from filenames present in root (e.g. `*.csproj` -> .NET / C#).
   - **Framework**: similar.
   - **Database**: similar.
   - **Build / Test / Lint commands**: from "## Commands" or "## Scripts" sections.
3. Store extracted values as defaults for Phase 3. Do not assume; only pre-fill if confidence is high.

If `CLAUDE.md` does not exist, defaults come from filename heuristics (`*.csproj` -> .NET; `package.json` -> Node; `pyproject.toml` -> Python; etc.).

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

---

## Phase 3 - Interactive questions

Ask **three** critical questions. Provide defaults from Phase 2 inference where possible.

### Q1: Ticket system

> What ticket system does this project use?
> 1. JIRA (default if existing CLAUDE.md mentions JIRA)
> 2. GitHub Issues
> 3. Linear
> 4. None / local only

If JIRA: ask `ticket.baseUrl` (e.g. `https://yourorg.atlassian.net/browse`).

> Heads up: automatic ticket-context fetch is **JIRA-only** today - the `sd-spec-architect` agent
> ships with Atlassian MCP tools only. GitHub Issues and Linear are still recorded as the project
> tracker (so the prompt hook recognizes their ID format), but their ticket content is **not**
> auto-fetched. For those, paste the relevant ticket details into the prompt when you start a
> workflow.

### Q2: Ticket pattern

> What ticket ID pattern should the hook recognize?
> Examples:
>   - JIRA: `^[A-Z]+-[0-9]+$` (e.g. INV-2501)
>   - GitHub: `^#[0-9]+$` (e.g. #1247)
>   - Custom: enter your own regex

Validate the pattern compiles.

### Q3: OS and shell

> Which shell will this project be developed with?
> 1. PowerShell (Windows)
> 2. Bash / Zsh (Unix / macOS)
> 3. Both (write settings.json for both; user picks one)

This determines which hook variant the generated `settings.json` references.

---

## Phase 4 - Generate CLAUDE.md

1. If existing `CLAUDE.md` is present:
   - Backup to `CLAUDE.md.bak.<YYYYMMDD-HHmmss>`.
   - Merge: take stack hints from existing into the new template; preserve user-customized sections under "## Code conventions" and "## Forbidden patterns" verbatim if they exist.
2. Generate new `CLAUDE.md` from `~/.claude/templates/sd/CLAUDE.template.md`:
   - Substitute `<<project-name>>` -> from current directory name or git remote.
   - Pre-fill the Stack, Commands, and Architecture sections from Phase 2.5 detected facts (including
     the layer list from `paths.layers`, rendered inside-out). Leave any field not detected and not
     confirmed in the Phase 2.5 gate as `<<placeholder>>` for the user to fill.
3. Display a diff summary (new vs old).

---

## Phase 5 - Scaffold .specs/

1. Create `.specs/` directory if missing.
2. Write `.specs/constitution.md` from `~/.claude/templates/sd/constitution.template.md`:
   - Substitute `<<project-name>>` and frontmatter fields.
   - Leave all rule placeholders as `<<placeholder>>` (the user must declare rules explicitly).
3. Write `.specs/index.md`:

```
# Spec index

Active specs (auto-updated by /sd:spec status transitions):

| ID | Type | Status | Created | Title |
|---|---|---|---|---|
```

4. Create empty subdirectories: `.specs/_explorations/`, `.specs/_reviews/`, `.specs/_adr/`.
5. If `.specs/constitution.md` already existed, do NOT overwrite. Print "Constitution already present - skipping. Edit manually if needed."

---

## Phase 6 - Scaffold .claude/

1. Create `.claude/` directory if missing.
2. Write `.claude/project-config.json` from `~/.claude/templates/sd/project-config.template.json`:
   - Substitute project name, owner (from git config), repo URL (from git remote).
   - Set `ticket.system`, `ticket.pattern`, `ticket.baseUrl` from Phase 3 Q1/Q2.
   - Set `commands.{build,test,lint,coverage,run}` from Phase 2.5 detected facts; any command not
     declared by the project manifest stays `<<placeholder>>`.
   - Set `paths.{src,tests,docs}` from Phase 2.5 detected facts.
   - Set `paths.layers` from Phase 2.5 as an ordered inside-out array of `{name, path}` objects
     (innermost first); write `[]` if no layered structure was detected.
   - Leave MCP servers `enabled: false` by default. Print: "MCP servers are disabled by default. Enable them by editing `.claude/project-config.json` after installing the corresponding MCP servers in `~/.claude.json`."
3. Write `.claude/settings.json` from the appropriate variant per Phase 3 Q3:
   - PowerShell -> use `settings.template.json` as-is.
   - Bash -> swap `powershell -NoProfile ...` invocations for `bash <path>.sh`.
   - Both -> write both, comment in the file noting which is active.
4. Backup any existing `.claude/settings.json` first.

---

## Phase 7 - Validate + report

1. Grep the generated `CLAUDE.md` for remaining `<<placeholder>>` tokens. List them.
2. Grep `.specs/constitution.md` for remaining `<<placeholder>>` tokens. List them.
3. Validate `.claude/project-config.json` is parseable JSON.
4. Validate `.claude/settings.json` is parseable JSON.
5. Print report:

```
Setup complete. Generated:
  - CLAUDE.md (N placeholders to fill)
  - .specs/constitution.md (N placeholders to fill)
  - .specs/index.md (empty registry)
  - .claude/project-config.json (M MCP servers disabled)
  - .claude/settings.json (hooks: prompt-router, spec-gate, subagent-retro)

Installed engine paths:
  - ~/.claude/commands/sd/     (10 workflow commands)
  - ~/.claude/agents/sd/       (5 specialist agents)
  - ~/.claude/hooks/sd/        (3 hooks)
  - ~/.claude/templates/sd/    (templates)
  - ~/.claude/skills/sd/       (6 skills: severity-taxonomy, hypothesis-tree, atomic-task-format, evidence-citation, spec-templates, pattern-discipline)

Next steps:
  1. Fill placeholders in CLAUDE.md and .specs/constitution.md (open them in your editor).
  2. Enable MCP servers you use in .claude/project-config.json under the "mcp" section.
  3. Restart Claude Code so hooks are picked up.
  4. Try: /sd:explore "where is the entrypoint" to verify the install works.
```

---

## Rules (hard constraints)

- **Idempotent.** Safe to re-run. Never overwrites without a timestamped backup.
- **Stack-agnostic.** Inference uses filename heuristics + CLAUDE.md parsing. Never hardcodes .NET / Node / Python assumptions. If inference fails, the field stays as `<<placeholder>>`.
- **Scan detects facts, never rules.** Phase 2.5 may pre-fill stack, paths, commands, and
  `paths.layers` only. It never writes `.specs/constitution.md` rules - those stay `<<placeholder>>`
  for the user to author explicitly.
- **Never asks more than 3 questions.** Other fields are inferred or left as placeholders for the user to fill in their editor. Excess prompting kills adoption.
- **Never enables MCP servers automatically.** They're opt-in; user must edit project-config.json after installing the server in `~/.claude.json`.
- **Never modifies the engine** (`~/.claude/`). The setup command writes ONLY into the current working directory.
- **Generated files have no BOM.** UTF-8 only.
- If state is `complete`, the command exits without writing. The user can manually edit any generated file at any time.
