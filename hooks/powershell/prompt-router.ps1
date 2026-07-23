#requires -Version 5.1
<#
.SYNOPSIS
    specwright: UserPromptSubmit hook - prompt-router.

.DESCRIPTION
    Reads Claude Code hook JSON from stdin. Extracts the user prompt and the
    project cwd. Loads .claude/project-config.json (or sane defaults if absent)
    and:
      1. Matches the prompt against workflow keywords (bug / feature / refactor
         / perf / rca) and suggests the relevant /sd:* command.
      2. Detects ticket IDs in the prompt using ticket.pattern and looks up
         matching folders under .specs/.
      3. Reads .specs/index.md and surfaces any spec currently in-progress.
      4. Emits a <context-router> block to stdout that Claude Code injects
         into the prompt as additional context.

    The hook is defensive: any failure exits 0 silently to avoid blocking the
    user. It never writes to disk.

.NOTES
    PURE ASCII ONLY. PowerShell 5.1 reads UTF-8 without BOM as Windows-1252;
    a single em-dash byte sequence will cascade into "Missing closing '}'"
    parse errors. Use ASCII hyphen-minus, "->", "[OK]", "[WARN]" etc.
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

$script:DefaultKeywords = [pscustomobject]@{
    bug      = @('bug','fix','broken','error','crash','regression','defect')
    feature  = @('feature','add','implement','new','support')
    refactor = @('refactor','restructure','clean up','extract','rename')
    perf     = @('perf','performance','slow','optimize','latency','throughput')
    rca      = @('incident','outage','rca','root cause','post-mortem','postmortem')
}

function Get-ProjectConfig {
    param([string]$Cwd)

    $defaults = [pscustomobject]@{
        spec    = [pscustomobject]@{
            dir       = '.specs'
            indexFile = '.specs/index.md'
        }
        ticket  = [pscustomobject]@{
            pattern = '^[A-Z]+-[0-9]+$'
            baseUrl = ''
        }
        workflow = [pscustomobject]@{
            keywords = $script:DefaultKeywords
        }
        hooks = [pscustomobject]@{
            userPromptRouter = [pscustomobject]@{ enabled = $true }
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

function Test-HookEnabled {
    param($Config)
    try {
        if ($null -eq $Config.hooks) { return $true }
        if ($null -eq $Config.hooks.userPromptRouter) { return $true }
        # Type-strict: only a literal JSON boolean false disables the hook.
        # [bool]$null is $false, so a userPromptRouter block with an ABSENT
        # `enabled` would silently disable the router - diverging from
        # prompt-router.sh's `== false`, which leaves it on. -is [bool] matches
        # jq (SW-22).
        $en = $Config.hooks.userPromptRouter.enabled
        if (($en -is [bool]) -and (-not $en)) { return $false }
        return $true
    } catch {
        return $true
    }
}

function Get-KeywordMatches {
    param(
        [string]$Prompt,
        $KeywordMap,
        $DefaultKeywordMap
    )
    $matches = @{}
    $lower = $Prompt.ToLowerInvariant()
    foreach ($workflow in @('bug','feature','refactor','perf','rca')) {
        $list = $null
        if ($null -ne $KeywordMap) { $list = $KeywordMap.$workflow }
        if ($null -eq $list -or @($list).Count -eq 0) {
            $list = $DefaultKeywordMap.$workflow
        }
        if ($null -eq $list) { continue }
        foreach ($kw in $list) {
            $kwLower = $kw.ToLowerInvariant()
            if ($lower.Contains($kwLower)) {
                if (-not $matches.ContainsKey($workflow)) {
                    $matches[$workflow] = New-Object System.Collections.ArrayList
                }
                [void]$matches[$workflow].Add($kw)
            }
        }
    }
    return $matches
}

function Get-TicketIds {
    param(
        [string]$Prompt,
        [string]$Pattern
    )
    $found = New-Object System.Collections.Generic.HashSet[string]
    if ([string]::IsNullOrWhiteSpace($Pattern)) { return @() }

    # Strip anchors so we can run as a substring match within the prompt.
    $body = $Pattern -replace '^\^','' -replace '\$$',''
    try {
        $rx = [regex]::new($body)
        foreach ($m in $rx.Matches($Prompt)) {
            [void]$found.Add($m.Value)
        }
    } catch {
        return @()
    }
    return @($found)
}

function Find-SpecsByTicket {
    param(
        [string]$SpecDir,
        [string[]]$TicketIds
    )
    $hits = @()
    if (-not (Test-Path -LiteralPath $SpecDir)) { return $hits }
    if (-not $TicketIds -or $TicketIds.Count -eq 0) { return $hits }

    $folders = Get-ChildItem -LiteralPath $SpecDir -Directory -ErrorAction SilentlyContinue
    foreach ($folder in $folders) {
        foreach ($tid in $TicketIds) {
            if ($folder.Name -match [regex]::Escape($tid)) {
                $hits += $folder.Name
                break
            }
        }
    }
    return $hits
}

function Get-InProgressSpecs {
    param([string]$IndexPath)
    $result = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $IndexPath)) { return $result }
    try {
        $lines = Get-Content -LiteralPath $IndexPath -Encoding UTF8 -ErrorAction Stop
    } catch {
        return $result
    }
    foreach ($line in $lines) {
        # Match a table row containing "in-progress" and an ID like FEAT-..., BUG-..., REF-...
        if ($line -match 'in-progress' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
            $result.Add($Matches[0]) | Out-Null
        }
    }
    return $result
}

# ---- main ----

$hookInput = Read-StdinJson
if ($null -eq $hookInput) { exit 0 }

$prompt = $hookInput.prompt
$cwd    = $hookInput.cwd
if ([string]::IsNullOrWhiteSpace($prompt) -or [string]::IsNullOrWhiteSpace($cwd)) { exit 0 }
if (-not (Test-Path -LiteralPath $cwd)) { exit 0 }

$config = Get-ProjectConfig -Cwd $cwd
if (-not (Test-HookEnabled -Config $config)) { exit 0 }

$specDir   = if ($config.spec.dir)       { Join-Path $cwd $config.spec.dir }       else { Join-Path $cwd '.specs' }
$indexFile = if ($config.spec.indexFile) { Join-Path $cwd $config.spec.indexFile } else { Join-Path $cwd '.specs/index.md' }
$pattern   = if ($config.ticket.pattern) { $config.ticket.pattern }                else { '^[A-Z]+-[0-9]+$' }
$kwMap     = $config.workflow.keywords

$workflowMatches = Get-KeywordMatches -Prompt $prompt -KeywordMap $kwMap -DefaultKeywordMap $script:DefaultKeywords
$ticketIds       = Get-TicketIds      -Prompt $prompt -Pattern $pattern
$ticketSpecs     = Find-SpecsByTicket -SpecDir $specDir -TicketIds $ticketIds
$inProgress      = Get-InProgressSpecs -IndexPath $indexFile

if ($workflowMatches.Count -eq 0 -and $ticketIds.Count -eq 0 -and $inProgress.Count -eq 0) {
    exit 0
}

# Build output block
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('<context-router>') | Out-Null
$lines.Add('Routing hints from specwright (UserPromptSubmit hook):') | Out-Null

if ($workflowMatches.Count -gt 0) {
    $lines.Add('') | Out-Null
    $lines.Add('Workflow keyword matches:') | Out-Null
    foreach ($key in $workflowMatches.Keys) {
        $kws = ($workflowMatches[$key] | Select-Object -Unique) -join ', '
        $lines.Add("  - /sd:$key  (matched: $kws)") | Out-Null
    }
}

if ($ticketIds.Count -gt 0) {
    $lines.Add('') | Out-Null
    $lines.Add("Ticket IDs detected: $($ticketIds -join ', ')") | Out-Null
    if ($ticketSpecs.Count -gt 0) {
        $lines.Add('Matching spec folders under .specs/:') | Out-Null
        foreach ($s in $ticketSpecs) { $lines.Add("  - $s") | Out-Null }
    } else {
        $lines.Add('No matching spec folder found. Consider /sd:feature or /sd:bug to create one.') | Out-Null
    }
}

if ($inProgress.Count -gt 0) {
    $lines.Add('') | Out-Null
    $lines.Add('Specs currently in-progress (from .specs/index.md):') | Out-Null
    foreach ($s in $inProgress) { $lines.Add("  - $s") | Out-Null }
}

$lines.Add('</context-router>') | Out-Null

[Console]::Out.WriteLine($lines -join "`n")
exit 0
