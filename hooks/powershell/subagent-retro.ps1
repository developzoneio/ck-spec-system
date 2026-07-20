#requires -Version 5.1
<#
.SYNOPSIS
    specwright: SubagentStop hook - subagent-retro.

.DESCRIPTION
    Reads Claude Code hook JSON from stdin. After a subagent finishes:
      1. Loads .claude/project-config.json (or defaults).
      2. Parses .specs/index.md for in-progress specs (skips RCAs - those
         do not require a retro file since the spec itself is the deliverable).
      3. For each in-progress spec, checks the mtime of <spec>/05-retro.md
         against retroStaleMinutes.
      4. Debounces per session by tracking the last reminder time in
         .claude/.hookstate/subagent-retro-<sessionId>.json.
      5. If any stale retros exist AND debounce window has elapsed, emits a
         <retro-reminder> block to stdout.
      6. Cleans up state files older than 24 hours.

.NOTES
    PURE ASCII ONLY. See prompt-router.ps1 for the rationale.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Read-StdinJson {
    try {
        $raw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-ProjectConfig {
    param([string]$Cwd)

    $defaults = [pscustomobject]@{
        spec  = [pscustomobject]@{
            dir       = '.specs'
            indexFile = '.specs/index.md'
        }
        hooks = [pscustomobject]@{
            subagentRetro = [pscustomobject]@{
                enabled           = $true
                retroStaleMinutes = 30
                debounceMinutes   = 10
            }
        }
    }

    $cfgPath = Join-Path $Cwd '.claude/project-config.json'
    if (-not (Test-Path -LiteralPath $cfgPath)) { return $defaults }
    # -ErrorAction Stop is required: the script-wide SilentlyContinue preference
    # would otherwise make a malformed config a NON-terminating error, so the
    # catch never fires and the function returns $null instead of the defaults.
    try {
        $loaded = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $loaded) { return $defaults }
        return $loaded
    } catch {
        return $defaults
    }
}

function Get-IndexSpecs {
    param([string]$IndexPath)
    # Returns array of objects: @{Id, Type, Status}
    $result = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $IndexPath)) { return $result }
    try {
        $lines = Get-Content -LiteralPath $IndexPath -Encoding UTF8 -ErrorAction Stop
    } catch {
        return $result
    }
    foreach ($line in $lines) {
        if ($line -match 'in-progress' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
            $id = $Matches[0]
            $type = ($id -split '-')[0]
            $obj = [pscustomobject]@{
                Id     = $id
                Type   = $type
                Status = 'in-progress'
            }
            $result.Add($obj) | Out-Null
        }
    }
    return $result
}

function Get-StaleRetros {
    param(
        [string]$SpecDir,
        $Specs,
        [int]$StaleMinutes
    )
    $stale = New-Object System.Collections.Generic.List[object]
    $now = Get-Date
    foreach ($spec in $Specs) {
        if ($spec.Type -eq 'RCA') { continue }  # RCAs are their own deliverable
        $retroPath = Join-Path $SpecDir (Join-Path $spec.Id '05-retro.md')
        if (-not (Test-Path -LiteralPath $retroPath)) {
            $stale.Add([pscustomobject]@{ Id = $spec.Id; Reason = 'missing'; AgeMinutes = -1 }) | Out-Null
            continue
        }
        try {
            $mtime = (Get-Item -LiteralPath $retroPath).LastWriteTime
            $ageMin = [int]([Math]::Round(($now - $mtime).TotalMinutes))
            if ($ageMin -ge $StaleMinutes) {
                $stale.Add([pscustomobject]@{ Id = $spec.Id; Reason = 'stale'; AgeMinutes = $ageMin }) | Out-Null
            }
        } catch { }
    }
    return $stale
}

function Test-DebounceElapsed {
    param(
        [string]$StatePath,
        [int]$DebounceMinutes
    )
    if (-not (Test-Path -LiteralPath $StatePath)) { return $true }
    try {
        $st = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        # PowerShell 7's ConvertFrom-Json auto-converts an ISO-8601 "...Z" string to a
        # [datetime] with Kind=Utc; PowerShell 5.1 leaves it as a plain string. Re-Parse-ing
        # an already-converted [datetime] stringifies it with the local culture (dropping the
        # UTC marker), so [datetimeoffset]::Parse silently re-interprets it as local time -
        # skewing $age by the machine's UTC offset. Only Parse when it is still a string.
        if ($st.lastReminderUtc -is [datetime]) {
            $last = $st.lastReminderUtc.ToUniversalTime()
        } else {
            $last = [datetimeoffset]::Parse([string]$st.lastReminderUtc).UtcDateTime
        }
        $age = (Get-Date).ToUniversalTime() - $last
        return ($age.TotalMinutes -ge $DebounceMinutes)
    } catch {
        return $true
    }
}

function Save-State {
    param([string]$StatePath)
    try {
        # -Path, not -LiteralPath: some PowerShell builds reject -LiteralPath combined
        # with -Parent as an unresolvable parameter set. -Parent does no filesystem
        # globbing (only -Resolve would), so -Path is exactly as safe here.
        $dir = Split-Path -Path $StatePath -Parent
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        # State-file shape is an ON-DISK CONTRACT shared with subagent-retro.sh:
        # a session can write it under one implementation and read it under the
        # other, so the single key and the whole-second UTC format must stay
        # identical in both. 'o' was writing 7 fractional digits that only the
        # bash side ever had to cope with.
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $obj = [pscustomobject]@{ lastReminderUtc = $stamp }
        $obj | ConvertTo-Json -Compress | Set-Content -LiteralPath $StatePath -Encoding UTF8
    } catch { }
}

function Remove-StaleStateFiles {
    param([string]$StateDir)
    if (-not (Test-Path -LiteralPath $StateDir)) { return }
    $cutoff = (Get-Date).AddHours(-24)
    try {
        $files = Get-ChildItem -LiteralPath $StateDir -File -Filter 'subagent-retro-*.json' -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            if ($f.LastWriteTime -lt $cutoff) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch { }
}

# ---- main ----

$hookInput = Read-StdinJson
if ($null -eq $hookInput) { exit 0 }

$cwd = $hookInput.cwd
if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $cwd)) { exit 0 }

$sessionId = $hookInput.session_id
if ([string]::IsNullOrWhiteSpace($sessionId)) { $sessionId = 'no-session' }

$config = Get-ProjectConfig -Cwd $cwd
try {
    if ($null -ne $config.hooks -and $null -ne $config.hooks.subagentRetro -and -not $config.hooks.subagentRetro.enabled) {
        exit 0
    }
} catch { }

$staleMinutes    = 30
$debounceMinutes = 10
try { if ($config.hooks.subagentRetro.retroStaleMinutes) { $staleMinutes = [int]$config.hooks.subagentRetro.retroStaleMinutes } } catch { }
try { if ($config.hooks.subagentRetro.debounceMinutes)   { $debounceMinutes = [int]$config.hooks.subagentRetro.debounceMinutes } } catch { }

$specDir   = if ($config.spec.dir)       { Join-Path $cwd $config.spec.dir }       else { Join-Path $cwd '.specs' }
$indexFile = if ($config.spec.indexFile) { Join-Path $cwd $config.spec.indexFile } else { Join-Path $cwd '.specs/index.md' }
$stateDir  = Join-Path $cwd '.claude/.hookstate'
$safeId    = ($sessionId -replace '[^A-Za-z0-9_\-]','_')
$statePath = Join-Path $stateDir ("subagent-retro-$safeId.json")

Remove-StaleStateFiles -StateDir $stateDir

$specs = Get-IndexSpecs -IndexPath $indexFile
if ($specs.Count -eq 0) { exit 0 }

$stale = Get-StaleRetros -SpecDir $specDir -Specs $specs -StaleMinutes $staleMinutes
if ($stale.Count -eq 0) { exit 0 }

if (-not (Test-DebounceElapsed -StatePath $statePath -DebounceMinutes $debounceMinutes)) { exit 0 }

# Emit reminder
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('<retro-reminder>') | Out-Null
$lines.Add('Retro files appear stale or missing for the following in-progress specs:') | Out-Null
foreach ($s in $stale) {
    if ($s.Reason -eq 'missing') {
        $lines.Add("  - $($s.Id): 05-retro.md missing") | Out-Null
    } else {
        $lines.Add("  - $($s.Id): 05-retro.md last touched $($s.AgeMinutes) min ago (threshold $staleMinutes min)") | Out-Null
    }
}
$lines.Add('') | Out-Null
$lines.Add('Consider appending: decisions made, surprises encountered, follow-ups identified.') | Out-Null
$lines.Add('</retro-reminder>') | Out-Null

[Console]::Out.WriteLine($lines -join "`n")
Save-State -StatePath $statePath
exit 0
