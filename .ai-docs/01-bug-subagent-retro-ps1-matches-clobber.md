# BUG: `$Matches` clobbered in subagent-retro.ps1 — spec ID extracted as "in-progress"

- Priority: P1
- Area: `hooks/powershell/subagent-retro.ps1`
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/retro-ps1-matches-clobber`

## Problem

In PowerShell, every successful `-match` overwrites the automatic `$Matches` variable. In
`Get-InProgressSpecs` the spec-ID regex runs FIRST and the `in-progress` literal match runs
SECOND, so by the time `$Matches[0]` is read it holds the literal string `"in-progress"`, not
the spec ID.

`hooks/powershell/subagent-retro.ps1:75-77`:

```powershell
if ($line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+' -and $line -match 'in-progress') {
    $id = $Matches[0]
    $type = ($id -split '-')[0]
```

Consequences on Windows, for every in-progress row:

- `$id` = `"in-progress"`, `$type` = `"in"` — the RCA-skip check can never match.
- The hook looks for `<specDir>/in-progress/05-retro.md`, which never exists, so every
  in-progress spec is reported stale under the wrong ID.
- Total behavioral divergence from the bash twin (`hooks/bash/subagent-retro.sh:99` extracts
  the real ID via `grep -oE ... | head -n1`).

The two sister hooks already do this correctly by testing `in-progress` FIRST and the ID
SECOND: `hooks/powershell/prompt-router.ps1:167` and `hooks/powershell/spec-gate.ps1:145`.

## Fix

Swap the two `-match` clauses so the ID regex runs last (its `$Matches` is then consumed):

```powershell
if ($line -match 'in-progress' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
```

No change needed in the bash twin (it is correct), but confirm parity of the overall behavior
per the hooks-ship-in-pairs rule.

## Constraints

- Pure ASCII in `.ps1` files (CLAUDE.md rule 2).
- Hook must still exit 0 on every failure path.

## Acceptance criteria

1. With an index containing `| FEAT-123 | ... | in-progress |` and no
   `.specs/FEAT-123/05-retro.md`, the hook reminder names `FEAT-123` (not `in-progress`).
2. An in-progress `RCA-...` row is skipped (RCA has no retro requirement in this hook's logic
   only if the code says so — preserve existing intent).
3. Bash and PowerShell hooks produce equivalent output for the same fixture index.

## Verification

```powershell
# Build a throwaway fixture repo with .specs/index.md containing an in-progress FEAT row,
# then pipe the documented sample JSON into the hook and inspect output:
'{"cwd":"C:\\temp\\sd-fixture"}' | pwsh -File hooks/powershell/subagent-retro.ps1
# Compare against: echo '{"cwd":"/tmp/sd-fixture"}' | bash hooks/bash/subagent-retro.sh
.\scripts\validate.ps1
```

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
