#Requires -Version 5.1
<#
.SYNOPSIS
    specwright: lesson aggregator (Windows / PowerShell).

.DESCRIPTION
    Mirror of scripts/aggregate-lessons.sh - both must emit byte-identical
    output for the same corpus. SW-18, under epic SW-7.

    Reads every <SpecDir>/*/05-retro.md, extracts well-formed lesson lines (the
    grammar in skills/sd-retro-lessons/SKILL.md), dedupes them, and renders
    <SpecDir>/_lessons/lessons.md.

    -Check writes nothing and exits 1 if the rendered output differs from what
    is already on disk. That is how idempotence is asserted in CI.

    TWO DESIGN DECISIONS worth knowing before editing:

      1. The RETROS are append-only; lessons.md is a DERIVED file, fully
         regenerated on every run. SW-18 originally called lessons.md itself
         append-only, but dedupe-with-a-count requires rewriting the line, so
         append-only and idempotent are mutually exclusive. Regenerating makes
         idempotence a property of the design rather than something to defend.

      2. Abstraction is NOT done here. Turning a retro note into an
         identifier-free rule is judgement work and belongs to the
         sd-retro-lessons skill, which writes tagged lines into 05-retro.md.
         This script only collects, dedupes and orders - no judgement, so the
         output is reproducible.

    PARITY: every comparison and sort in this file is ORDINAL. PowerShell's
    default string handling is culture-aware and case-insensitive - Sort-Object,
    hashtable keys and -eq would all silently diverge from the bash twin's
    LC_ALL=C byte ordering. Output is written as UTF-8 without BOM and with LF
    line endings, because Set-Content would emit CRLF and break the byte
    comparison on Windows.

    PURE ASCII. Scanned by validate.ps1 Check 1.

.EXAMPLE
    .\scripts\aggregate-lessons.ps1
    .\scripts\aggregate-lessons.ps1 -SpecDir tests\lessons\fixtures\corpus -Out out.md -Check
#>

[CmdletBinding()]
param(
    [string] $SpecDir = '.specs',
    [string] $Out     = '',
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enum order, NOT alphabetical - this array defines the section order in the
# rendered file, and it is duplicated in aggregate-lessons.sh and the enum
# table in skills/sd-retro-lessons/SKILL.md. All three must agree.
$TAGS = @(
    'sibling-repo-assumption', 'missed-context', 'baseline-attribution',
    'tooling-surprise', 'gate-friction', 'config-drift',
    'test-fragility', 'test-gap', 'precedent-conflict', 'scope-discipline'
)

$SEVERITIES = @('high', 'medium', 'low')
$SCOPES     = @('feature', 'bug', 'refactor', 'perf', 'rca', 'all')

$LESSON_RE = '^- \[([a-z-]+)\] ([a-z]+)/([a-z]+): (.+)$'
$COUNT_RE  = '^(.*) \([0-9]+\)$'

function Write-Section { param([string]$Title) Write-Host ''; Write-Host "=== $Title ===" -ForegroundColor Cyan }
function Write-Ok      { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-FailMsg { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }

if ([string]::IsNullOrEmpty($Out)) {
    $Out = Join-Path (Join-Path $SpecDir '_lessons') 'lessons.md'
}

function Get-OrdinalIndex {
    param([string] $Needle, [string[]] $Haystack)

    for ($i = 0; $i -lt $Haystack.Count; $i++) {
        if ([string]::CompareOrdinal($Haystack[$i], $Needle) -eq 0) { return $i }
    }
    return -1
}

# Dedupe identity. Case and spacing differences are not different lessons, and
# a trailing period is punctuation, not meaning.
function Get-NormalizedRule {
    param([string] $Rule)

    $r = $Rule.ToLowerInvariant()
    $r = [regex]::Replace($r, '\s+', ' ')
    $r = $r.Trim()
    if ($r.EndsWith('.')) { $r = $r.Substring(0, $r.Length - 1) }
    return $r
}

Write-Section 'specwright aggregate-lessons'
Write-Host "  Spec dir: $SpecDir"
Write-Host "  Output:   $Out"

if (-not (Test-Path -LiteralPath $SpecDir -PathType Container)) {
    Write-FailMsg "spec dir not found: $SpecDir"
    exit 1
}

# ---- collect ----------------------------------------------------------------

# Ordinal comparer: the default hashtable is case-insensitive, which would merge
# two lessons the bash twin keeps apart.
$groups = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)

$retroCount = 0
$skipped    = 0

# Sorted so the traversal itself is deterministic. Nothing downstream depends on
# file order (the sort below is total), but a stable walk keeps the skipped
# counter reproducible too.
$retros = @(Get-ChildItem -LiteralPath $SpecDir -Directory |
    ForEach-Object { Join-Path $_.FullName '05-retro.md' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })

$retros = @($retros | Sort-Object -Property { $_ } -CaseSensitive)

foreach ($retro in $retros) {
    $retroCount++

    foreach ($line in (Get-Content -LiteralPath $retro)) {
        if (-not $line.StartsWith('- [')) { continue }

        # Auto-generated transition lines written by /sd:spec status and
        # /sd:release open with "- [" too (they carry a timestamp in the
        # brackets) but never match the lesson grammar, so they fall out here
        # rather than needing a rule of their own.
        if ($line -cnotmatch $LESSON_RE) {
            $skipped++
            continue
        }

        $tag      = $Matches[1]
        $severity = $Matches[2]
        $scope    = $Matches[3]
        $rule     = $Matches[4]
        if ($rule -cmatch $COUNT_RE) { $rule = $Matches[1] }

        $tagIdx   = Get-OrdinalIndex -Needle $tag      -Haystack $TAGS
        $sevIdx   = Get-OrdinalIndex -Needle $severity -Haystack $SEVERITIES
        $scopeIdx = Get-OrdinalIndex -Needle $scope    -Haystack $SCOPES
        if ($tagIdx -lt 0 -or $sevIdx -lt 0 -or $scopeIdx -lt 0) {
            $skipped++
            continue
        }

        $norm = Get-NormalizedRule -Rule $rule
        $key  = "$tagIdx" + [char]0x1f + "$scopeIdx" + [char]0x1f + $norm

        if ($groups.ContainsKey($key)) {
            $g = $groups[$key]
            # Severity and surviving wording are resolved INDEPENDENTLY. Tying
            # them together means the sloppier phrasing wins whenever it happens
            # to carry the lower severity.
            #   severity -> least severe seen (largest rank): never promote.
            #   wording  -> byte-smallest seen: stable, and ASCII puts a proper
            #               capitalised sentence ahead of a lowercase one.
            if ($sevIdx -gt $g.SevIdx) { $g.SevIdx = $sevIdx }
            if ([string]::CompareOrdinal($rule, $g.Rule) -lt 0) { $g.Rule = $rule }
            $g.Count++
        }
        else {
            $groups[$key] = [pscustomobject]@{
                TagIdx   = $tagIdx
                ScopeIdx = $scopeIdx
                SevIdx   = $sevIdx
                Rule     = $rule
                Tag      = $tag
                Count    = 1
            }
        }
    }
}

# ---- order ------------------------------------------------------------------
#
# Sort-Object is culture-aware; an explicit ordinal comparison is the only way
# to match the bash twin's LC_ALL=C sort. This is the whole parity risk of the
# story, so it is done by hand rather than delegated.

$ordered = New-Object 'System.Collections.Generic.List[object]'
foreach ($g in $groups.Values) { [void]$ordered.Add($g) }

$comparison = [System.Comparison[object]] {
    param($a, $b)
    if ($a.TagIdx -ne $b.TagIdx) { return $a.TagIdx - $b.TagIdx }
    if ($a.SevIdx -ne $b.SevIdx) { return $a.SevIdx - $b.SevIdx }
    return [string]::CompareOrdinal($a.Rule, $b.Rule)
}
$ordered.Sort($comparison)

# ---- render -----------------------------------------------------------------

$lines = New-Object 'System.Collections.Generic.List[string]'
[void]$lines.Add('# Lessons')
[void]$lines.Add('')
[void]$lines.Add('GENERATED FILE - do not edit by hand. Regenerate with')
[void]$lines.Add('`scripts/aggregate-lessons.sh`; edits are lost on the next run.')
[void]$lines.Add('')
[void]$lines.Add('Every rule below is written to be free of identifiers - no paths, file names,')
[void]$lines.Add('line numbers, class or variable names - so this file can be shared outside the')
[void]$lines.Add('organisation as-is. That contract is enforced by `scripts/validate-lessons.*`')
[void]$lines.Add('and is the reason a lesson reads as a general rule rather than a bug report.')
[void]$lines.Add('')
[void]$lines.Add('A trailing count is the number of retros a lesson was drawn from. Frequency')
[void]$lines.Add('never raises severity.')

$currentTag = ''
foreach ($g in $ordered) {
    if ([string]::CompareOrdinal($g.Tag, $currentTag) -ne 0) {
        [void]$lines.Add('')
        [void]$lines.Add('## ' + $g.Tag)
        [void]$lines.Add('')
        $currentTag = $g.Tag
    }
    $severity = $SEVERITIES[$g.SevIdx]
    $scope    = $SCOPES[$g.ScopeIdx]
    $text     = '- [' + $g.Tag + '] ' + $severity + '/' + $scope + ': ' + $g.Rule
    if ($g.Count -gt 1) { $text = $text + ' (' + $g.Count + ')' }
    [void]$lines.Add($text)
}

# LF, not CRLF, and a trailing newline - Set-Content would emit CRLF on Windows
# and the byte comparison against the bash twin would fail.
$rendered = ($lines -join "`n") + "`n"

# ---- write or check ---------------------------------------------------------

$lessonCount = $ordered.Count

if ($Check) {
    $existing = $null
    if (Test-Path -LiteralPath $Out -PathType Leaf) {
        $existing = [System.IO.File]::ReadAllText($Out)
    }
    if ($null -ne $existing -and [string]::CompareOrdinal($existing, $rendered) -eq 0) {
        Write-Ok "$lessonCount lesson(s) from $retroCount retro(s); $Out is current"
        exit 0
    }
    Write-FailMsg "$Out is out of date - run without -Check to regenerate"
    if ($null -eq $existing) { Write-Host '         (file does not exist)' }
    exit 1
}

$outDir = Split-Path -Parent $Out
if (-not [string]::IsNullOrEmpty($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($Out, $rendered, $utf8NoBom)

Write-Ok "$lessonCount lesson(s) from $retroCount retro(s) -> $Out"
if ($skipped -gt 0) {
    Write-Host "         $skipped non-lesson line(s) skipped (transition logs, unknown tag/severity/scope)"
}
exit 0
