# Contributing to specwright

Thanks for considering a contribution. This document covers the PR process,
per-file-type guidelines, and how to test changes locally.

---

## Quick links

- [Project goals and non-goals](#project-goals-and-non-goals)
- [Repo layout](#repo-layout)
- [The manifest](#the-manifest)
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
specwright/
  commands/         # 11 slash commands (markdown with frontmatter)
  agents/           # 6 subagent definitions (markdown with frontmatter)
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

## The manifest

`specwright.manifest.json` is the canonical inventory contract. Check 7 of
`scripts/validate.{ps1,sh}` reads it and fails the build when a number published in the docs
disagrees with what is actually on disk. A discipline tool that misdescribes itself has no
standing to lecture anyone about specs.

The manifest **stores no counts**. It declares where assets live (`areas`, each with a `glob` or
an explicit `files` list) and where the docs make claims about them (`docClaims`); the numbers are
derived from disk at runtime. That is deliberate - a manifest holding hardcoded counts would be a
third place to update on every change and would reintroduce exactly the drift it exists to prevent.

What this means in practice:

- **Adding a command, agent, skill, or template**: add the file. Nothing else. The count follows.
- **Publishing a number in the docs**: add a `docClaims` entry - `file`, a `pattern` with exactly
  one capture group around the number, and the `equals` quantity it must match. A number with no
  entry fails the build as an *undeclared claim*, so this is not optional.
- **Rewording a sentence that carries a number**: update its `pattern` too. A pattern that matches
  nothing fails as a *vacuous claim* rather than passing quietly - otherwise a reword would turn
  the check into a no-op that still reports green.
- **Writing intentionally historical docs** (superseded counts as a past-state record): put the
  path in `historicalExclusions`. `docs/history/`, `docs/superpowers/` and `CHANGELOG.md` are
  already excluded. Never "fix" their numbers to match today's disk state.

Two constraints on `pattern`: it must be valid in **both** POSIX ERE (bash `[[ =~ ]]`) and .NET
(PowerShell), so use `[0-9]` rather than `\d` and avoid lookarounds; and it is matched
**case-sensitively** on both platforms.

`scripts/selftest-docs.{ps1,sh}` proves Check 7 still bites, by corrupting a throwaway copy of the
repo and asserting the validator catches it. CI runs it on all three OSes.

Check 7 needs `jq` on Unix and **fails loudly without it**. This is the opposite of the hook rule
below (hooks exit `0` silently when `jq` is missing so they never block a user on their own bugs) -
a validator that skipped itself for a missing tool would turn CI green while checking nothing.

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

4. **Run the validator** before opening the PR: `scripts/validate.ps1` (Windows) or
   `scripts/validate.sh` (Unix) runs every engine-invariant check at once (ASCII, hook-pair parity,
   model aliases, install-target counts, changelog gate, docs consistency). CI runs the same on
   Windows + Ubuntu. See also the [Local install test](#local-install-test) for a manual install
   smoke test, and [The manifest](#the-manifest) for what Check 7 enforces.

5. **Update the changelog.** Add a line under `## [Unreleased]` in `CHANGELOG.md`.

6. **Open the PR** with:
   - A short description.
   - Screenshots or terminal output if behaviour changes.
   - A note on whether docs were updated.

---

## Per-file-type guidelines

### Commands (`commands/*.md`)

A command is a markdown file with YAML frontmatter that Claude Code reads when the user types `/sd:<name>`.

**Required structure:**
```markdown
---
description: One-line summary shown in /help
argument-hint: <ID or slug>
---

# /sd:<name>

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
- Subagent invocation uses the `sd-` prefix, never bare names.
- No stack-specific commands inside (no `dotnet test`, `npm test`, etc.). Reference the `commands.test` field from `project-config.json`.

### Agents (`agents/*.md`)

A subagent is a markdown file with YAML frontmatter consumed by the `Task` tool.

**Required frontmatter:**
```yaml
---
name: sd-<role>
color: <color>   # e.g. cyan, orange, purple, green, blue - used for display only
description: One-line summary used by routing.
model: sonnet   # MUST be an alias: sonnet | haiku | opus | inherit
tools: Read, Grep, Glob, ...   # MINIMAL allowlist
skills:
  - sd-<shared-rule-pack>   # any skill this agent's body references; see Skills below
---
```

**Critical:**
- `model:` MUST be an alias. Full IDs like `claude-sonnet-4-7` are not portable and may not even exist. The alias `sonnet` auto-resolves to the latest Sonnet.
- `tools:` should be the minimum set the agent needs. Read-only agents do not get `Write`. Implementer does not get `WebSearch`.
- `skills:` must list every skill the agent body references (`**skill-name**` in prose). A rule used by multiple agents lives in one `SKILL.md`, never copy-pasted into agent bodies.
- Agent must read `CLAUDE.md` and `constitution.md` at runtime. No hardcoded stack assumptions (no `cs`, `csproj`, `dotnet`, etc. literal references unless they come from project config).
- Every finding cites `file:line`. No prose without citations.

### Hooks

Hooks come in pairs. If you change `hooks/powershell/foo.ps1`, you also update `hooks/bash/foo.sh`. The repo CI runs `scripts/validate.{ps1,sh}`, which refuses PRs where the pair drifts (along with the other engine-invariant checks).

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

Templates are filled by `/sd:setup` and by agents.

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
.\install\install.ps1 -BasePath C:\temp\sd-test

# 3. Verify
Get-ChildItem C:\temp\sd-test\commands\sd\
Get-ChildItem C:\temp\sd-test\agents\sd\
Get-ChildItem C:\temp\sd-test\hooks\sd\
Get-ChildItem C:\temp\sd-test\templates\sd\

# 4. Cleanup
Remove-Item -Recurse -Force C:\temp\sd-test
```

**Unix/macOS (bash):**
```bash
# 1. Dry-run
./install/install.sh --dry-run

# 2. Real install to a sandbox base path
./install/install.sh --base-path /tmp/sd-test

# 3. Verify
ls /tmp/sd-test/commands/sd/
ls /tmp/sd-test/agents/sd/
ls /tmp/sd-test/hooks/sd/
ls /tmp/sd-test/templates/sd/

# Verify hook executable bits
test -x /tmp/sd-test/hooks/sd/prompt-router.sh && echo "OK"

# 4. Cleanup
rm -rf /tmp/sd-test
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
