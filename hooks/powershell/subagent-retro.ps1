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
            metrics = [pscustomobject]@{ enabled = $true; path = '.specs/_metrics/events.jsonl' }
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

function Test-IsRootedPath {
    param([string]$Path)
    # Mirrors spec-gate.sh's rootedness test ("${fp}" != /* && "${fp}" != ?:*),
    # evaluated on the RAW path (before backslash->slash conversion): a leading
    # '/' or a drive-letter prefix like 'C:' is rooted, anything else - a plain
    # relative path such as 'src/../.specs/constitution.md' - is not.
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    if ($Path[0] -eq '/') { return $true }
    if ($Path.Length -ge 2 -and $Path[1] -eq ':') { return $true }
    return $false
}

function ConvertTo-CollapsedPath {
    param([string]$Path)
    # Pure string-based collapse of '.' and '..' segments on a forward-slash
    # path - no filesystem access, no .NET path resolution. This mirrors
    # collapse_dot_segments in spec-gate.sh exactly, including:
    #   - a rooted path (leading '/' or a drive prefix 'C:/') clamps a '..' at
    #     its own root instead of walking above it;
    #   - an unrooted path with nothing to clamp against keeps an unresolved
    #     leading '..' rather than discarding it;
    #   - an empty segment (produced by '//' or by a TRAILING separator, e.g.
    #     ".specs/constitution.md/") is a no-op, same as a '.' segment - this
    #     is what makes a trailing separator collapse away instead of
    #     defeating the later exact-match comparison against paths.protected.
    $rootPrefix = ''
    $body = $Path
    $rooted = $false
    if ($Path.StartsWith('/')) {
        $rootPrefix = '/'
        $body = $Path.Substring(1)
        $rooted = $true
    } elseif ($Path.Length -ge 2 -and $Path[1] -eq ':') {
        $rootPrefix = $Path.Substring(0, 2) + '/'
        $body = $Path.Substring(2)
        if ($body.StartsWith('/')) { $body = $body.Substring(1) }
        $rooted = $true
    }

    $acc = ''
    foreach ($seg in $body -split '/') {
        if ($seg -eq '' -or $seg -eq '.') {
            continue
        }
        if ($seg -eq '..') {
            if ($acc -ne '') {
                $lastSlash = $acc.LastIndexOf('/')
                if ($lastSlash -ge 0) { $last = $acc.Substring($lastSlash + 1) } else { $last = $acc }
                if ($last -eq '..') {
                    # Already-stacked leading '..' (unrooted overflow) - keep stacking.
                    $acc = "$acc/.."
                } elseif ($lastSlash -ge 0) {
                    $acc = $acc.Substring(0, $lastSlash)
                } else {
                    # acc was a single segment with no slash - pop to empty.
                    $acc = ''
                }
            } elseif ($rooted) {
                # Cannot go above the root - drop it, matching the bash clamp.
            } else {
                # No root to clamp against - keep the unresolved '..'.
                $acc = '..'
            }
        } else {
            if ($acc -eq '') { $acc = $seg } else { $acc = "$acc/$seg" }
        }
    }

    return "$rootPrefix$acc"
}

function Test-MetricsPathSafe {
    param([string]$RelPath)
    # A metrics path is not an arbitrary-write primitive: reject anything
    # rooted (absolute, or a drive-letter path) or that escapes Cwd via '..'
    # rather than ever writing outside the workspace. Reuses the same
    # rootedness test and dot-segment collapse used for the gate's own path
    # safety above, so the two safety checks cannot silently diverge.
    if ([string]::IsNullOrWhiteSpace($RelPath)) { return $false }
    if (Test-IsRootedPath -Path $RelPath) { return $false }
    $collapsed = ConvertTo-CollapsedPath -Path ($RelPath.Replace('\','/'))
    if ($collapsed -eq '..' -or $collapsed.StartsWith('../')) { return $false }
    return $true
}

function Write-MetricEvent {
    param(
        [string]$Cwd,
        [object]$Config,
        [string]$SpecId,
        [string]$Phase,
        [string]$EventKind,
        [System.Collections.Specialized.OrderedDictionary]$Fields
    )
    # Fully wrapped: a metrics failure must NEVER surface as a hook error or
    # change a gate decision. Every call site invokes this AFTER the decision
    # is already computed (and, for a block, already written to stdout) -
    # never from inside the decision path itself.
    try {
        $enabled = $true
        # Type-strict: only a literal JSON boolean false disables metrics -
        # copies the verifyGate `-is [bool]` pattern above so a string
        # "false" in project-config.json leaves metrics on, matching
        # spec-gate.sh's `== false` jq comparison.
        if (($Config.hooks.metrics.enabled -is [bool]) -and (-not $Config.hooks.metrics.enabled)) {
            $enabled = $false
        }
        if (-not $enabled) { return }

        $relPath = '.specs/_metrics/events.jsonl'
        try { if ($Config.hooks.metrics.path) { $relPath = [string]$Config.hooks.metrics.path } } catch { }
        $relPath = $relPath.Replace('\','/')

        if (-not (Test-MetricsPathSafe -RelPath $relPath)) { return }

        $fullPath = Join-Path $Cwd $relPath
        $parent = Split-Path -Path $fullPath -Parent
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
        }

        # [ordered] (not a plain hashtable) so ConvertTo-Json emits keys in
        # the exact insertion order below - a plain hashtable does not
        # guarantee enumeration order, which would let the two
        # implementations drift apart on key order for the same input.
        $ordered = [ordered]@{}
        $ordered['ts']      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $ordered['spec_id'] = $SpecId
        $ordered['phase']   = $Phase
        $ordered['event']   = $EventKind
        foreach ($key in $Fields.Keys) { $ordered[$key] = $Fields[$key] }

        $line = ([pscustomobject]$ordered) | ConvertTo-Json -Compress

        # Add-Content opens and closes the file handle per call and is not
        # safe against the concurrent PreToolUse + SubagentStop appends this
        # log can see; retry briefly on a transient sharing violation instead
        # of failing loudly.
        $attempt = 0
        while ($attempt -lt 5) {
            try {
                # UTF8Encoding($false): NO byte-order-mark. [Encoding]::UTF8
                # writes a BOM preamble on the FIRST write to a new/empty
                # file, which subagent-retro.sh's plain `>>` append never
                # does - that would make the two implementations' first line
                # differ by 3 bytes for the exact same input.
                [System.IO.File]::AppendAllText($fullPath, "$line`n", (New-Object System.Text.UTF8Encoding($false)))
                break
            } catch {
                $attempt++
                if ($attempt -ge 5) { break }
                Start-Sleep -Milliseconds 20
            }
        }
    } catch { }
}

function Write-SubagentStopMetric {
    param(
        [string]$Cwd,
        [object]$Config,
        [string]$SpecId,
        [string]$Phase,
        [int]$Stale
    )
    $fields = [ordered]@{ stale = $Stale }
    Write-MetricEvent -Cwd $Cwd -Config $Config -SpecId $SpecId -Phase $Phase -EventKind 'subagent_stop' -Fields $fields
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

# Metrics: one subagent_stop event per in-progress spec, emitted regardless
# of staleness or debounce - debounce below only suppresses the user-facing
# reminder, never this measurement (SW-10). A spec not in $stale (including
# every RCA, which Get-StaleRetros always skips) reports stale=0.
$staleIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
foreach ($s in $stale) { [void]$staleIds.Add($s.Id) }
foreach ($spec in $specs) {
    $staleCount = if ($staleIds.Contains($spec.Id)) { 1 } else { 0 }
    Write-SubagentStopMetric -Cwd $cwd -Config $config -SpecId $spec.Id -Phase 'in-progress' -Stale $staleCount
}

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
