#Requires -Version 5.1
<#
.SYNOPSIS
    specwright: privacy validator for lesson files (Windows / PowerShell).

.DESCRIPTION
    Mirror of scripts/validate-lessons.sh - both must accept and reject exactly
    the same lines. Unlike scripts/validate.ps1 (which checks THIS repo's own
    invariants), this validator runs against a consumer repo's lessons file:
    specwright itself has no .specs/ tree, so there is nothing here to check
    except the fixtures under tests/lessons/fixtures/.

    With no argument it defaults to .specs/_lessons/lessons.md relative to the
    current directory. A missing default file is NOT an error (a repo that has
    not produced lessons yet is valid); a missing explicit argument is.

    Grammar enforced (see skills/sd-retro-lessons/SKILL.md):
        - [tag] severity/scope: Rule sentence.

    Exit 0 = every lesson line is well-formed and identifier-free;
    exit 1 = at least one violation.

.EXAMPLE
    .\scripts\validate-lessons.ps1
    .\scripts\validate-lessons.ps1 tests\lessons\fixtures\clean-lessons.md
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

$DEFAULT_REL   = '.specs/_lessons/lessons.md'
$MAX_RULE_LEN  = 120

# Kept in sync with $TAGS in validate-lessons.sh and the enum table in
# skills/sd-retro-lessons/SKILL.md. Capped at 12 by that skill; adding one
# takes a PR citing the retro that produced it.
$TAGS = @(
    'sibling-repo-assumption', 'missed-context', 'baseline-attribution',
    'tooling-surprise', 'gate-friction', 'config-drift',
    'test-fragility', 'test-gap', 'precedent-conflict', 'scope-discipline'
)

$SCOPES     = @('feature', 'bug', 'refactor', 'perf', 'rca', 'all')
$SEVERITIES = @('high', 'medium', 'low')

# Technology proper nouns that are legitimately PascalCase. Deliberately short -
# a lesson needing a word that is not here is usually less portable than its
# author thinks. Extending this list takes a PR (and the same edit in the
# bash twin).
$IDENT_ALLOWLIST = @(
    'PowerShell', 'TypeScript', 'JavaScript', 'PostgreSQL', 'MySQL', 'MongoDB',
    'SQLite', 'GitHub', 'GitLab', 'OpenAPI', 'GraphQL', 'WebSocket', 'DevOps',
    'JSONPath'
)

# Extensions that mark a filename. An explicit list rather than a generic
# dot-letters pattern, which would flag ordinary prose such as "e.g." or a
# sentence-ending period followed by a lowercase word.
$EXT_RE = '\.(md|json|jsonl|ps1|sh|bash|cs|ts|tsx|js|jsx|mjs|py|go|rb|rs|java|kt|php|yml|yaml|xml|sql|txt|csv|html|css|scss|toml|ini|cfg|lua|sln|csproj)([^a-zA-Z0-9]|$)'

# Same grammar as the bash twin's [[ =~ ]] pattern.
$LESSON_RE = '^- \[([a-z-]+)\] ([a-z]+)/([a-z]+): (.+)$'
$COUNT_RE  = '^(.*) \([0-9]+\)$'

$script:Violations  = 0
$script:LessonsSeen = 0

function Write-Section { param([string] $Text) Write-Host ''; Write-Host "=== $Text ===" -ForegroundColor Cyan }
function Write-Ok      { param([string] $Text) Write-Host "  [OK]   $Text" -ForegroundColor Green }
function Write-Fail    { param([string] $Text) Write-Host "  [FAIL] $Text" -ForegroundColor Red }

function Add-Violation {
    param([string] $File, [int] $LineNo, [string] $Message)

    Write-Fail "${File}:${LineNo} : $Message"
    $script:Violations++
}

# Splits the rule text into word tokens and tests each one whole. Done this way
# rather than with a word-boundary regex so the logic reads identically to the
# bash twin, which cannot portably use \b. All identifier tests use -cmatch:
# PowerShell's -match is case-insensitive, which would make every casing test
# here vacuously true.
function Test-Identifier {
    param([string] $File, [int] $LineNo, [string] $Text)

    $scrubbed = $Text
    foreach ($word in $IDENT_ALLOWLIST) {
        $scrubbed = $scrubbed.Replace($word, '')
    }

    foreach ($token in ($scrubbed -split '[^A-Za-z0-9_]+')) {
        if ([string]::IsNullOrEmpty($token)) {
            continue
        }
        if ($token -cmatch '^[A-Z][a-z]+[A-Z][A-Za-z0-9]*$') {
            Add-Violation $File $LineNo "PascalCase identifier '$token' in rule text"
        }
        elseif ($token -cmatch '^[a-z]+[A-Z][A-Za-z0-9]*$') {
            Add-Violation $File $LineNo "camelCase identifier '$token' in rule text"
        }
        elseif ($token -cmatch '^[a-z]+_[a-z0-9_]+$') {
            Add-Violation $File $LineNo "snake_case identifier '$token' in rule text"
        }
    }
}

function Test-RuleText {
    param([string] $File, [int] $LineNo, [string] $Text)

    if ($Text.Length -gt $MAX_RULE_LEN) {
        Add-Violation $File $LineNo ("rule is " + $Text.Length + " chars (max $MAX_RULE_LEN)")
    }
    if ($Text.Contains('`')) {
        Add-Violation $File $LineNo 'backtick in rule text - still describing code'
    }
    if ($Text.Contains('/') -or $Text.Contains('\')) {
        Add-Violation $File $LineNo 'path separator in rule text'
    }
    if ($Text -cmatch $EXT_RE) {
        Add-Violation $File $LineNo 'file extension in rule text'
    }
    if ($Text -cmatch ':[0-9]+') {
        Add-Violation $File $LineNo 'line citation in rule text'
    }
    Test-Identifier $File $LineNo $Text
}

function Test-LessonFile {
    param([string] $FullPath, [string] $Rel)

    $lineNo = 0
    foreach ($line in (Get-Content -LiteralPath $FullPath)) {
        $lineNo++

        # Only lines that open like a lesson are candidates. Prose, headers and
        # blank lines in the file are none of this validator's business.
        if (-not $line.StartsWith('- [')) {
            continue
        }
        $script:LessonsSeen++

        if ($line -cnotmatch $LESSON_RE) {
            Add-Violation $Rel $lineNo "does not match '- [tag] severity/scope: Rule sentence.'"
            continue
        }

        $tag      = $Matches[1]
        $severity = $Matches[2]
        $scope    = $Matches[3]
        $rule     = $Matches[4]

        # An aggregator-appended repeat count is metadata, not rule text.
        if ($rule -cmatch $COUNT_RE) {
            $rule = $Matches[1]
        }

        if ($TAGS -cnotcontains $tag) {
            Add-Violation $Rel $lineNo "unknown tag '$tag'"
        }
        if ($SEVERITIES -cnotcontains $severity) {
            Add-Violation $Rel $lineNo "unknown severity '$severity'"
        }
        if ($SCOPES -cnotcontains $scope) {
            Add-Violation $Rel $lineNo "unknown scope '$scope'"
        }

        Test-RuleText $Rel $lineNo $rule
    }
}

# ---- collect targets --------------------------------------------------------

$targets = @()
if ($Path -and $Path.Count -gt 0) {
    foreach ($arg in $Path) {
        if (-not (Test-Path -LiteralPath $arg -PathType Leaf)) {
            Write-Section 'specwright validate-lessons'
            Write-Fail "$arg : file not found"
            exit 1
        }
        $targets += (Resolve-Path -LiteralPath $arg).Path
    }
}
else {
    if (Test-Path -LiteralPath $DEFAULT_REL -PathType Leaf) {
        $targets += (Resolve-Path -LiteralPath $DEFAULT_REL).Path
    }
    else {
        Write-Section 'specwright validate-lessons'
        Write-Ok ("no $DEFAULT_REL in " + (Get-Location).Path + " - nothing to validate")
        exit 0
    }
}

# ---- run --------------------------------------------------------------------

Write-Section 'specwright validate-lessons'
foreach ($t in $targets) {
    $rel = $t
    if ($t.StartsWith($repoRoot)) {
        $rel = $t.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
    }
    Test-LessonFile $t $rel
}

if ($script:Violations -eq 0) {
    Write-Ok ("$script:LessonsSeen lesson line(s) across " + $targets.Count + " file(s): well-formed, no identifiers")
    exit 0
}
else {
    Write-Fail "$script:Violations violation(s) across $script:LessonsSeen lesson line(s)"
    exit 1
}
