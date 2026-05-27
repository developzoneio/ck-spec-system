# Contributing to ck-spec-system

Thanks for considering a contribution. This document covers the PR process,
per-file-type guidelines, and how to test changes locally.

---

## Quick links

- [Project goals and non-goals](#project-goals-and-non-goals)
- [Repo layout](#repo-layout)
- [PR process](#pr-process)
- [Per-file-type guidelines](#per-file-type-guidelines)
  - [Commands (`commands/*.md`)](#commands-commandsmd)
  - [Agents (`agents/*.md`)](#agents-agentsmd)
  - [Hooks (`hooks/powershell/*.ps1` and `hooks/bash/*.sh`)](#hooks)
  - [Templates (`templates/**`)](#templates-templates)
- [Local install test](#local-install-test)
- [Hook test snippets](#hook-test-snippets)
- [Style conventions](#style-conventions)

---

## Project goals and non-goals

**Goals**
- Spec-driven workflows on top of Claude Code: every non-trivial change starts with a spec.
- Stack-agnostic: works for .NET, Node, Python, Go, Rust, etc. No language assumptions in agents.
- Cross-platform: PowerShell (Windows) and bash (Unix/macOS) parity.
- Cost-aware: heavy reasoning on `sonnet`, mechanical work on `haiku`.

**Non-goals**
- Not an IDE plugin or VSCode extension. Lives in `~/.claude/`.
- Not a replacement for `git` workflow tooling.
- Not a code formatter or linter wrapper.

---

## Repo layout

```
ck-spec-system/
  commands/         # 9 slash commands (markdown with frontmatter)
  agents/           # 5 subagent definitions (markdown with frontmatter)
  hooks/
    powershell/     # 3 PowerShell hooks
    bash/           # 3 bash hooks (parity with PowerShell)
  templates/        # 4 setup templates
    specs/          # 5 spec templates
  install/          # install.ps1 + install.sh + install/README.md
  docs/             # architecture, usage, walkthrough, troubleshooting
  examples/         # demo references
```

---

## PR process

1. **Open an issue first** for anything larger than a typo or a small docs fix. State:
   - What problem the change solves.
   - Which files are affected.
   - Whether it is a breaking change.

2. **Branch from `main`** with a descriptive name:
   - `feat/<slug>` for new commands / agents / hooks.
   - `fix/<slug>` for bug fixes.
   - `docs/<slug>` for docs-only changes.
   - `refactor/<slug>` for internal restructuring.

3. **Keep PRs focused.** One workflow, one agent, one hook per PR. A 1500-line "improve everything" PR will be asked to split.

4. **Run local install + a smoke test** (see [Local install test](#local-install-test)) before opening the PR.

5. **Update the changelog.** Add a line under `## [Unreleased]` in `CHANGELOG.md`.

6. **Open the PR** with:
   - A short description.
   - Screenshots or terminal output if behaviour changes.
   - A note on whether docs were updated.

---

## Per-file-type guidelines

### Commands (`commands/*.md`)

A command is a markdown file with YAML frontmatter that Claude Code reads when the user types `/ck:<name>`.

**Required structure:**
```markdown
---
description: One-line summary shown in /help
argument-hint: <ID or slug>
---

# /ck:<name>

## Phase 0 - Bootstrap
- Read CLAUDE.md
- Read .specs/constitution.md
- Read .claude/project-config.json
- Detect state (resumable?)

## Phase 1 - <name>
... (with hard gates marked as Gate N)

## Rules
- Hard constraints that cannot be bypassed.
```

**Conventions:**
- Phase 0 always bootstraps; do not skip.
- Hard gates use the explicit marker `Gate N` and prose "STOP. Wait for explicit user approval."
- State machine documented at top of file (what happens on re-invocation).
- Subagent invocation uses the `ck:` prefix, never bare names.
- No stack-specific commands inside (no `dotnet test`, `npm test`, etc.). Reference the `commands.test` field from `project-config.json`.

### Agents (`agents/*.md`)

A subagent is a markdown file with YAML frontmatter consumed by the `Task` tool.

**Required frontmatter:**
```yaml
---
name: ck:<role>
description: One-line summary used by routing.
model: sonnet   # MUST be an alias: sonnet | haiku | opus | inherit
tools: Read, Grep, Glob, ...   # MINIMAL allowlist
---
```

**Critical:**
- `model:` MUST be an alias. Full IDs like `claude-sonnet-4-7` are not portable and may not even exist. The alias `sonnet` auto-resolves to the latest Sonnet.
- `tools:` should be the minimum set the agent needs. Read-only agents do not get `Write`. Implementer does not get `WebSearch`.
- Agent must read `CLAUDE.md` and `constitution.md` at runtime. No hardcoded stack assumptions (no `cs`, `csproj`, `dotnet`, etc. literal references unless they come from project config).
- Every finding cites `file:line`. No prose without citations.

### Hooks

Hooks come in pairs. If you change `hooks/powershell/foo.ps1`, you also update `hooks/bash/foo.sh`. The repo CI (when configured) will refuse PRs where the pair drifts.

**PowerShell (`*.ps1`) - critical encoding rule:**

PowerShell 5.1 reads UTF-8 without BOM as Windows-1252. The em-dash `-` (U+2014) is byte sequence `E2 80 94`; PowerShell sees the final byte `0x94` as a curly closing quote, and your string terminates in the middle of nowhere. Result: cascading parse errors like `Missing closing '}'`.

**Pure ASCII only in `*.ps1` files.** Substitute as follows:

| Forbidden | Use instead |
|---|---|
| `-` (em-dash U+2014) | `-` (ASCII hyphen-minus) |
| `->` (right arrow) | `->` |
| `>` (triangular bullet) | `>` |
| `OK:` | `OK:` or `[OK]` |
| `WARN:` | `WARN:` or `[WARN]` |
| `X` | `X` or `[FAIL]` |
| `i` | `i` or `[INFO]` |

Verify before committing:
```bash
grep -nP "[^\x00-\x7F]" hooks/powershell/*.ps1 install/install.ps1
# Empty output = OK. Any output = REJECT, fix it.
```

**Bash (`*.sh`):**
- Shebang: `#!/usr/bin/env bash`
- Use `jq` for JSON; if `jq` is missing, exit `0` silently (do not block the user).
- Use `stat -c %Y` (Linux) AND `stat -f %m` (macOS) - detect and branch.
- Set `chmod +x` on commit (or rely on the installer to do it).
- Test with `bash -n hooks/bash/foo.sh` to catch syntax errors before runtime.

### Templates (`templates/**`)

Templates are filled by `/ck:setup` and by agents.

- Use `<<placeholder>>` syntax for fields the user fills manually.
- Keep templates short and scannable. A `CLAUDE.md` template that ends up being 600 lines defeats the purpose.
- Spec templates leave the cross-phase fields explicitly **empty** with a comment like `<!-- Filled by Phase 3 - do not pre-fill -->`. This is intentional: workflows enforce sequencing through empty fields.

---

## Local install test

Before opening any PR that touches install, hooks, commands, or agents:

**Windows (PowerShell):**
```powershell
# 1. From the repo root, dry-run first
.\install\install.ps1 -DryRun

# 2. Real install to a sandbox base path
.\install\install.ps1 -BasePath C:\temp\ck-test

# 3. Verify
Get-ChildItem C:\temp\ck-test\commands\ck\
Get-ChildItem C:\temp\ck-test\agents\ck\
Get-ChildItem C:\temp\ck-test\hooks\ck\
Get-ChildItem C:\temp\ck-test\templates\ck\

# 4. Cleanup
Remove-Item -Recurse -Force C:\temp\ck-test
```

**Unix/macOS (bash):**
```bash
# 1. Dry-run
./install/install.sh --dry-run

# 2. Real install to a sandbox base path
./install/install.sh --base-path /tmp/ck-test

# 3. Verify
ls /tmp/ck-test/commands/ck/
ls /tmp/ck-test/agents/ck/
ls /tmp/ck-test/hooks/ck/
ls /tmp/ck-test/templates/ck/

# Verify hook executable bits
test -x /tmp/ck-test/hooks/ck/prompt-router.sh && echo "OK"

# 4. Cleanup
rm -rf /tmp/ck-test
```

---

## Hook test snippets

Hooks read JSON from stdin. You can simulate Claude Code locally:

**prompt-router (UserPromptSubmit):**
```bash
echo '{"prompt":"fix bug INV-2501 in stock service","cwd":"/path/to/repo"}' \
  | bash hooks/bash/prompt-router.sh
```
```powershell
'{"prompt":"fix bug INV-2501 in stock service","cwd":"C:\\path\\to\\repo"}' `
  | powershell -File hooks\powershell\prompt-router.ps1
```

**spec-gate (PreToolUse):**
```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.cs"},"cwd":"/path/to/repo"}' \
  | bash hooks/bash/spec-gate.sh
```

**subagent-retro (SubagentStop):**
```bash
echo '{"cwd":"/path/to/repo","session_id":"test-session-001"}' \
  | bash hooks/bash/subagent-retro.sh
```

Expected behaviour: every hook exits `0` and either prints a `<context-router>` / `<retro-reminder>` block to stdout, prints a warning to stderr, or stays silent.

---

## Style conventions

- **Markdown:** ATX headers (`#`, `##`), no trailing colons in headers, fenced code blocks with language hint, 100-char soft wrap.
- **PowerShell:** PascalCase function names, `$camelCase` variables, explicit `param()` block, pure ASCII.
- **Bash:** lowercase function names, `snake_case` variables, `set -euo pipefail` at top of non-trivial scripts.
- **YAML frontmatter:** keys in lowercase-with-hyphens (`argument-hint`), values unquoted unless they contain special chars.
- **Commit messages:** imperative mood, 50-char subject, optional body wrapped at 72.

---

Thanks for contributing. If anything in this doc is unclear, open an issue and we'll improve it.
