# BUG: prompt-router.ps1 drops default workflow keywords when project-config is partial

- Priority: P1
- Area: `hooks/powershell/prompt-router.ps1`
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/router-ps1-keyword-defaults`

## Problem

Bash falls back to built-in defaults PER WORKFLOW when the config omits a keyword list
(`hooks/bash/prompt-router.sh:69-71`):

```bash
list="$(printf '%s' "${config_json}" | jq -r --arg w "${workflow}" '.workflow.keywords[$w] // [] | join("\n")')"
if [[ -z "${list}" ]]; then
    list="${default_list}"
fi
```

PowerShell only uses its defaults when the config FILE is absent or unparseable
(`prompt-router.ps1:69-76` returns `$loaded` raw, no merge), and then silently skips any
workflow whose list is null (`prompt-router.ps1:99-100`):

```powershell
$list = $KeywordMap.$workflow
if ($null -eq $list) { continue }
```

Failure scenario: a project has a valid `.claude/project-config.json` that omits
`workflow.keywords` (or omits one workflow's list). On Linux the router still emits keyword
routing hints from defaults; on Windows keyword routing silently disappears for the missing
workflows.

## Fix

Match bash semantics: apply the built-in default list per workflow when the loaded config has
no list for it. Two options (pick one, keep it simple):

- In `Get-KeywordMatches`, accept the defaults map and use `$defaults.workflow.keywords.$workflow`
  when `$null -eq $list`.
- Or merge defaults into the loaded config in `Get-ProjectConfig` before returning.

The built-in default lists already exist at `prompt-router.ps1:55-61` — reuse them; do not
duplicate the word lists.

Also mirror-check the bash side for any OTHER key where PS merges defaults and bash does not
(hooks ship in pairs; parity in both directions).

## Acceptance criteria

1. Config file present but no `workflow.keywords` key: PS emits the same keyword hints as bash
   for a prompt like "fix login bug".
2. Config overrides one workflow's keywords: the override wins for that workflow, defaults
   apply to the others — identical on both platforms.
3. Hook still exits 0 for malformed config.

## Verification

```powershell
'{"prompt":"fix login bug","cwd":"C:\\temp\\sd-fixture-partial-config"}' | pwsh -File hooks/powershell/prompt-router.ps1
```

```bash
echo '{"prompt":"fix login bug","cwd":"/tmp/sd-fixture-partial-config"}' | bash hooks/bash/prompt-router.sh
./scripts/validate.sh
```

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
