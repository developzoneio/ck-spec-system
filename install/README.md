# Installing ck-spec-system

The installer copies the engine (commands, agents, hooks, templates) into a Claude Code base directory, under the `ck/` subfolder of each engine directory:

```
<base>/
├── commands/ck/        9 slash commands
├── agents/ck/          5 subagent definitions
├── hooks/ck/           3 hook scripts (.ps1 on Windows, .sh on Unix)
└── templates/ck/       9 templates (4 setup + 5 spec)
```

Default base is `$HOME/.claude` (Unix) or `$env:USERPROFILE\.claude` (Windows).

---

## Default install

**Windows (PowerShell 5.1+):**
```powershell
.\install\install.ps1 -DryRun     # preview first (recommended)
.\install\install.ps1             # apply
```

**Unix / macOS (bash 4+):**
```bash
./install/install.sh --dry-run    # preview first (recommended)
./install/install.sh              # apply
```

---

## Options

| Option (PS / sh) | Default | Effect |
|---|---|---|
| `-DryRun` / `--dry-run` | off | Show the install plan; no files written. |
| `-Force` / `--force` | off | Overwrite differing files without prompting. Backups are still created. |
| `-BasePath <path>` / `--base-path <path>` | `~/.claude` | Install to a custom base directory (useful for sandboxed testing). |

---

## What gets installed

| Source (in repo) | Target (under `<base>/`) | Files | Notes |
|---|---|---|---|
| `commands/` | `commands/ck/` | 9 | `feature`, `bug`, `rca`, `refactor`, `perf`, `spec`, `explore`, `review`, `setup` |
| `agents/` | `agents/ck/` | 5 | `ck:spec-architect`, `ck:code-explorer`, `ck:debugger`, `ck:implementer`, `ck:reviewer` |
| `hooks/powershell/` (Windows installer) | `hooks/ck/` | 3 | `prompt-router.ps1`, `spec-gate.ps1`, `subagent-retro.ps1` |
| `hooks/bash/` (Unix installer) | `hooks/ck/` | 3 | `prompt-router.sh`, `spec-gate.sh`, `subagent-retro.sh` (chmod +x applied) |
| `templates/` | `templates/ck/` | 4 + 5 | Setup templates + `specs/` subfolder with 5 spec templates |

**Total**: 21 files per OS.

---

## Behavior on existing files

The installer is **idempotent**:

1. **Identical content** (SHA256 match) -> silently skipped. No backup, no overwrite.
2. **Different content, no `-Force`** -> interactive prompt:
   ```
   Overwrite 'foo.md' ? [y/N/a=all]
   ```
   - `y` -> back up existing as `<file>.bak.<yyyyMMdd-HHmmss>` then copy.
   - `N` (default if you press Enter) -> skip; existing file untouched.
   - `a` -> answer `y` to all remaining prompts in this run.
3. **Different content, `-Force`** -> always overwrite, but a timestamped backup is still created.

This means: running the installer twice in a row produces no churn. Upgrading produces backups you can roll back to.

---

## Verification

After install, check the target directories:

**Windows:**
```powershell
Get-ChildItem $env:USERPROFILE\.claude\commands\ck\     # expect 9 .md files
Get-ChildItem $env:USERPROFILE\.claude\agents\ck\       # expect 5 .md files
Get-ChildItem $env:USERPROFILE\.claude\hooks\ck\        # expect 3 .ps1 files
Get-ChildItem $env:USERPROFILE\.claude\templates\ck\    # expect 4 files + specs\ folder
```

**Unix:**
```bash
ls ~/.claude/commands/ck/      # 9 .md files
ls ~/.claude/agents/ck/        # 5 .md files
ls ~/.claude/hooks/ck/         # 3 .sh files (executable)
ls -l ~/.claude/hooks/ck/      # confirm +x bits set
ls ~/.claude/templates/ck/     # 4 files + specs/ folder
```

Then in a real project:
```
cd <your-project>
claude
> /ck:setup
> /ck:explore "where is the entrypoint"
```

If `/ck:explore` returns findings with `file:line` citations, the install is working.

---

## Uninstall

The installer does not ship an uninstall script (the install is just files in known directories). To remove:

**Windows:**
```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\.claude\commands\ck
Remove-Item -Recurse -Force $env:USERPROFILE\.claude\agents\ck
Remove-Item -Recurse -Force $env:USERPROFILE\.claude\hooks\ck
Remove-Item -Recurse -Force $env:USERPROFILE\.claude\templates\ck
```

**Unix:**
```bash
rm -rf ~/.claude/commands/ck \
       ~/.claude/agents/ck \
       ~/.claude/hooks/ck \
       ~/.claude/templates/ck
```

Per-project artifacts (`.specs/`, `.claude/project-config.json`, `.claude/settings.json`, `CLAUDE.md`) remain in your projects until you remove them manually.

---

## Troubleshooting basics

| Symptom | Likely cause | Fix |
|---|---|---|
| `install.ps1 cannot be loaded ... execution policy` | PS execution policy | Run: `powershell -ExecutionPolicy Bypass -File install\install.ps1` |
| `bash: ./install/install.sh: Permission denied` | Missing +x on the installer itself | `chmod +x install/install.sh` then re-run |
| `Missing required source directories` | Running from wrong directory | `cd` to the repo root (the parent of `install/`) and re-run |
| Hooks not firing in Claude Code after install | settings.json not wired in the project | Run `/ck:setup` in the project; it writes `.claude/settings.json` |
| `jq: command not found` warnings in hook output | `jq` not installed (Unix only) | Install via `brew install jq` (macOS) or `apt install jq` (Linux). Hooks exit 0 silently without it. |

Further troubleshooting in [`docs/troubleshooting.md`](../docs/troubleshooting.md).
