# BUG: subagent-retro.ps1 debounce mixes UTC and local time — window off by the UTC offset

- Priority: P1
- Area: `hooks/powershell/subagent-retro.ps1`
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/retro-ps1-debounce-utc`

## Problem

`Save-State` writes UTC in round-trip format (`subagent-retro.ps1:138`):

```powershell
$obj = [pscustomobject]@{ lastReminderUtc = (Get-Date).ToUniversalTime().ToString('o') }
```

`Test-DebounceElapsed` parses it back with plain `[datetime]::Parse` (`subagent-retro.ps1:123-125`):

```powershell
$last = [datetime]::Parse($st.lastReminderUtc)
$age = (Get-Date).ToUniversalTime() - $last
return ($age.TotalMinutes -ge $DebounceMinutes)
```

`[datetime]::Parse` of a `...Z` string returns a `Kind=Local` DateTime CONVERTED to local time.
Subtracting it from a UTC now mixes the two clocks, so `$age` is wrong by the machine's UTC
offset:

- UTC+7 (Vietnam): `$age` = real age minus 7 h -> negative for ~7 hours -> reminders wrongly
  suppressed.
- UTC-5: `$age` = real age plus 5 h -> always >= debounce -> debounce never suppresses.

The bash twin is correct (epoch seconds throughout, `hooks/bash/subagent-retro.sh:164,172`).

## Fix

Parse as UTC explicitly. Either:

```powershell
$last = [datetimeoffset]::Parse($st.lastReminderUtc).UtcDateTime
```

or

```powershell
$last = [datetime]::Parse($st.lastReminderUtc, [cultureinfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::AdjustToUniversal)
```

Must remain valid on PowerShell 5.1 and pure ASCII. Keep the `catch { return $true }`
defensive fallback.

## Acceptance criteria

1. Write a state file, immediately re-run the debounce check: it returns `$false`
   (suppressed) regardless of machine timezone.
2. With `lastReminderUtc` older than the debounce window, it returns `$true`.
3. Malformed/missing state file still returns `$true` and the hook exits 0.

## Verification

```powershell
# Unit-style check in a pwsh session after dot-sourcing or inline-copying the two functions:
#   Save-State -StatePath $p; Test-DebounceElapsed -StatePath $p -DebounceMinutes 60  # expect False
.\scripts\validate.ps1
```

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
