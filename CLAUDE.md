# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

specwright is a spec-driven development toolkit **for** Claude Code — there is no application code, build system, or test framework. The deliverables are markdown prompt files (commands, agents, skills, templates) plus PowerShell/bash hook scripts and a cross-platform installer. "Testing" means dry-run installs and piping JSON into hooks.

This repo is **Layer 1 (the engine)** of a three-layer architecture: the installer copies it into `~/.claude/<type>/sd/` (user scope, installed once). Layer 2 is per-project context (`CLAUDE.md`, `.specs/constitution.md`, `.specs/index.md`, `.claude/project-config.json` in each target repo). Layer 3 is the live Claude Code session. The engine must stay generic — all project specifics are read at runtime from Layer 2.

Note: `templates/CLAUDE.template.md` is the template `/sd:setup` scaffolds into *target* projects. It is not this file.

## Commands

```powershell
# Preview install plan (no files written)
.\install\install.ps1 -DryRun

# Sandbox install test (run before any PR touching install/hooks/commands/agents)
.\install\install.ps1 -BasePath C:\temp\sd-test
Get-ChildItem C:\temp\sd-test\commands\sd\          # expect 9 .md files
Remove-Item -Recurse -Force C:\temp\sd-test         # cleanup
```

Unix equivalents: `./install/install.sh --dry-run`, `--base-path /tmp/sd-test`, `--force`.

```bash
# Hook smoke test — hooks read JSON from stdin; every hook must exit 0
echo '{"prompt":"fix bug INV-2501","cwd":"/path/to/repo"}' | bash hooks/bash/prompt-router.sh
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.cs"},"cwd":"/path/to/repo"}' | bash hooks/bash/spec-gate.sh

# Bash syntax check
bash -n hooks/bash/spec-gate.sh

# ASCII check for PowerShell files — any output means REJECT
grep -nP "[^\x00-\x7F]" hooks/powershell/*.ps1 install/install.ps1
```

Every PR adds a line under `## [Unreleased]` in `CHANGELOG.md` (Keep a Changelog / SemVer).

## Repo structure → install targets

| Source | Installs to | Contents |
|---|---|---|
| `commands/` | `~/.claude/commands/sd/` | 9 slash commands (`/sd:feature`, `/sd:bug`, `/sd:rca`, `/sd:refactor`, `/sd:perf`, `/sd:spec`, `/sd:explore`, `/sd:review`, `/sd:setup`) |
| `agents/` | `~/.claude/agents/sd/` | 5 subagents (`sd-spec-architect`, `sd-code-explorer`, `sd-debugger`, `sd-implementer`, `sd-reviewer`) |
| `hooks/powershell/` + `hooks/bash/` | `~/.claude/hooks/sd/` | 3 hooks × 2 platforms (`prompt-router`, `spec-gate`, `subagent-retro`) |
| `templates/` | `~/.claude/templates/sd/` | 4 setup templates + 5 spec templates in `specs/` |
| `skills/` | `~/.claude/skills/sd/` | 6 rule packs, one folder per skill with `SKILL.md` |

Source filenames are unprefixed (`agents/reviewer.md`); the `sd-`/`sd:` namespace comes from frontmatter `name:` and the `sd/` install subfolder. The namespace exists for collision avoidance and clean uninstall — never use bare names when assets reference each other.

## How the pieces interlock

- **Commands** are phased workflow definitions with **hard gates** — checkpoints that STOP and wait for explicit user approval (silence ≠ approval). Phase 0 always bootstraps (read CLAUDE.md, constitution, project-config, index); a state machine at the top of each file defines resume behavior on re-invocation. Gates marked HARD (bug reproduction, perf baseline) have no override path.
- **Agents** declare frontmatter: `name`, `description`, `color`, `model`, minimal `tools` allowlist, and a `skills:` list. Tool allowlists enforce roles structurally — the reviewer has no write tools, so it *cannot* auto-fix. Heavy reasoning agents (architect, debugger, reviewer) use `sonnet`; mechanical agents (explorer, implementer) use `haiku`.
- **Skills** are shared rule packs loaded into agent context via frontmatter reference. A rule used by multiple agents (e.g. `sd-evidence-citation`, used by 3) lives in one `SKILL.md`, never copy-pasted into agent bodies.
- **Hooks** inject context (`prompt-router` on UserPromptSubmit, `subagent-retro` on SubagentStop) or guard edits (`spec-gate` on PreToolUse blocks code edits with no in-progress spec). `spec-gate` denials emit a dual-format JSON object carrying both the new schema (`hookSpecificOutput.permissionDecision: "deny"`) and the legacy schema (`decision: "block"`) for CLI version compatibility.
- **Spec artifacts** (`.specs/<ID>/00-spec.md` … `05-retro.md`) are the input contract between agents, not after-the-fact docs. Spec templates intentionally leave cross-phase fields empty with `<!-- Filled by Phase N -->` comments — workflows enforce sequencing through those empty fields. Do not pre-fill them.

## Hard rules when editing

1. **Hooks ship in pairs.** Changing `hooks/powershell/foo.ps1` requires the matching change in `hooks/bash/foo.sh`. Hooks are defensive: every failure path exits `0` silently — they never block the user on their own bugs.
2. **Pure ASCII in all `.ps1` files** (and `install.ps1`). PowerShell 5.1 reads UTF-8-without-BOM as Windows-1252, so an em-dash or arrow character causes cascading parse errors. Use `-`, `->`, `[OK]`, `[WARN]`, `[FAIL]`. Verify with the grep above.
3. **Model fields are aliases only** (`sonnet`, `haiku`, `opus`, `inherit`) — never full model IDs.
4. **Stack-agnostic, no exceptions.** Commands and agents must not contain hardcoded stack commands (`dotnet test`, `npm test`) or language assumptions; reference `commands.test` etc. from `project-config.json`. An agent that hardcodes a stack is a bug.
5. **Minimal tool allowlists.** Read-only agents never get `Write`; add a tool only if the role requires it.
6. **Templates** use `<<placeholder>>` for user-filled fields and stay short.

## Style

- Markdown: ATX headers, no trailing colons in headers, fenced code blocks with language hint, 100-char soft wrap.
- PowerShell: PascalCase functions, `$camelCase` variables, explicit `param()` block.
- Bash: `#!/usr/bin/env bash`, `set -euo pipefail`, snake_case; use `jq` but exit 0 silently if missing; branch `stat -c %Y` (Linux) vs `stat -f %m` (macOS).
- YAML frontmatter keys: lowercase-with-hyphens (`argument-hint`).
- Commits: imperative mood, 50-char subject. Branches: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `refactor/<slug>`.
