#Requires -Version 5.1
<#
.SYNOPSIS
    Cross-file contract linter for the specwright ENGINE PRODUCT (Windows / PowerShell).

.DESCRIPTION
    Twin of scripts/contract-lint.sh. Both read specwright.manifest.json's
    `contractLint` subtree and MUST report the same rule ids, in the same order,
    for the same tree. Check 8 of scripts/validate.{ps1,sh} runs this as a child
    process; tests/contract-lint/run-selftest.ps1 runs both and diffs them.

    Where validate's Check 7 guards INVENTORY (how many files exist), this guards
    the RELATIONSHIPS between them: which agent a command invokes, which skill an
    agent loads, how many hard gates a workflow declares.

    Wave 1 rule bands (the manifest's rules[] is the authoritative registry):
      CL0xx  reference resolution
      CL3xx  gate integrity
      CL9xx  suppression hygiene

    Output is TSV on stdout, one finding per line, and nothing else:
      <RULE><TAB><SEVERITY><TAB><FILE><TAB><LINE><TAB><MESSAGE>
    Paths are root-relative with forward slashes. Sort order is ordinal on file,
    then numeric line, then rule id, then message. The human-readable summary
    goes to stderr and is never parsed or compared.

    Exit codes:
      0  no BLOCK findings
      1  at least one BLOCK finding
      2  cannot run (bad -Root, missing manifest, registry parity mismatch)

    Exit 2 is separate on purpose: a validator that cannot distinguish "clean"
    from "crashed" is worthless.

    THIS FILE MUST STAY PURE ASCII. Check 1 of validate scans every *.ps1
    recursively, so this script self-polices. The gate marker is a non-ASCII
    character and is NEVER encoded here - see Get-GateClassification.

.PARAMETER Root
    Tree to lint. Defaults to the repo this script lives in. The manifest is read
    from <Root>/specwright.manifest.json, which is what lets a fixture tree
    configure itself.

.PARAMETER Rule
    Comma-separated rule ids; filters the EMITTED findings only. Every rule still
    runs, so CL902 (suppresses nothing) stays truthful.

.PARAMETER Quiet
    Suppress the stderr summary line.
#>

[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$Rule = '',
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- constants --------------------------------------------------------------
#
# Every pattern below must behave identically in .NET and POSIX ERE (the twin).
# Use [0-9] not \d, [ \t] not \s, no lookarounds. All matching goes through
# [regex]::Match / [regex]::Matches - NEVER the -match operator, which is
# case-insensitive and would silently diverge from bash's case-sensitive grep.

$RE_FENCE     = '^[ \t]*```'
$RE_HEADING   = '^(#{2,3}) (.+)$'
$RE_SDREF     = 'sd-[a-z0-9]+(-[a-z0-9]+)*'
$RE_CMDREF    = '/sd:[a-z][a-z0-9-]*'
$RE_TPLPATH   = 'templates/[A-Za-z0-9_./-]+'
# The leading boundary alternative is load-bearing: without it the pattern also
# matches '07-cqrs-read-path.md' inside the ADR filename '0007-cqrs-read-path.md'
# (agents/docs-writer.md), which is not a spec artifact at all.
$RE_ARTIFACT  = '(^|[^0-9A-Za-z_.-])[0-9][0-9]-[a-z0-9-]+\.md'
$RE_SUPPRESS  = '<!--[ \t]*contract-lint:[ \t]*allow[ \t]+CL[0-9][0-9][0-9]'
$RE_SUPPARTS  = 'allow[ \t]+(CL[0-9][0-9][0-9])(.*)$'
# An option set: a slash-separated parenthetical carrying no nested parens.
$RE_OPTPAREN  = '\(([^()/]+/)+[^()]+\)'
$RE_BULLET    = '^-[ \t]'
$RE_BULLETTOK = '^-[ \t]+`([^`]+)`'
$RE_SUBHEAD   = '^#{1,6}[ \t]'
$RE_PHASE     = '^Phase[ \t]+[0-9]+[ \t]+-[ \t]+(.*)$'
$RE_GATE_NUM  = '^ ([0-9]+)([ \t].*)?$'
$RE_GATE_SUB  = '^ ([0-9]+[a-z])([ \t].*)?$'
$RE_GATE_REPL = '^ (Re-plan)([^A-Za-z0-9].*)?$'
$RE_GATE_UNN  = '^ ?[-([]'
$RE_SKILLSKEY = '^skills:[ \t]*$'
$RE_SKILLITEM = '^[ \t]+-[ \t]+(.+)$'
# Written as an ASCII escape sequence, never as the literal character: this file
# must survive Check 1's pure-ASCII scan. bash peels the same run as BYTES under
# LC_ALL=C while .NET peels it as UTF-16 chars - three bytes there, one char
# here, and both land on the identical ASCII remainder. Nothing downstream ever
# reports a column offset, so the difference is unobservable.
$RE_NONASCII  = '^[\u0080-\uFFFF]+'

function Write-Err([string]$Message) {
    [Console]::Error.WriteLine($Message)
}

function New-OrdinalSet {
    New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
}

# ---- argument handling ------------------------------------------------------

if ([string]::IsNullOrEmpty($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Err "contract-lint: -Root is not a directory: '$Root'"
    exit 2
}
$Root = (Resolve-Path -LiteralPath $Root).ProviderPath.TrimEnd('\', '/')

$manifestPath = Join-Path $Root 'specwright.manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Err "contract-lint: manifest not found: $manifestPath"
    exit 2
}

try {
    $manifestText = [System.Text.Encoding]::UTF8.GetString(
        [System.IO.File]::ReadAllBytes($manifestPath))
    $manifest = $manifestText | ConvertFrom-Json
} catch {
    Write-Err "contract-lint: cannot parse $manifestPath - $($_.Exception.Message)"
    exit 2
}

if (-not $manifest.PSObject.Properties.Name.Contains('contractLint')) {
    Write-Err "contract-lint: manifest has no contractLint subtree"
    exit 2
}
$cl = $manifest.contractLint

$ruleFilter = New-OrdinalSet
if (-not [string]::IsNullOrEmpty($Rule)) {
    foreach ($r in $Rule.Split(',')) {
        $t = $r.Trim()
        if ($t.Length -gt 0) { [void]$ruleFilter.Add($t) }
    }
}

# ---- Phase A: index ---------------------------------------------------------

$nsSegment = 'sd'
if ($cl.PSObject.Properties.Name.Contains('installNamespaceSegment') -and
    -not [string]::IsNullOrEmpty($cl.installNamespaceSegment)) {
    $nsSegment = [string]$cl.installNamespaceSegment
}

$ruleIds = New-OrdinalSet
$ruleSeverity = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
foreach ($r in $cl.rules) {
    [void]$ruleIds.Add([string]$r.id)
    $ruleSeverity[[string]$r.id] = [string]$r.severity
}

# Every rule this implementation dispatches, in registry order. The parity guard
# below asserts this equals the manifest registry, so a wave-2 rule cannot land
# in the manifest, the docs or the fixtures without landing here too.
$dispatchIds = @(
    'CL001', 'CL002', 'CL003', 'CL004', 'CL005', 'CL006', 'CL007', 'CL008',
    'CL300', 'CL301', 'CL302', 'CL303', 'CL304', 'CL305',
    'CL900', 'CL901', 'CL902'
)
$dispatchSet = New-OrdinalSet
foreach ($d in $dispatchIds) { [void]$dispatchSet.Add($d) }

$parityBad = $false
foreach ($d in $dispatchIds) {
    if (-not $ruleIds.Contains($d)) {
        Write-Err "contract-lint: dispatched rule '$d' is absent from manifest contractLint.rules"
        $parityBad = $true
    }
}
foreach ($r in $cl.rules) {
    if (-not $dispatchSet.Contains([string]$r.id)) {
        Write-Err "contract-lint: manifest rule '$($r.id)' is not dispatched by this implementation"
        $parityBad = $true
    }
}
if ($parityBad) {
    Write-Err "contract-lint: registry parity guard failed"
    exit 2
}

$specArtifacts = New-OrdinalSet
if ($cl.PSObject.Properties.Name.Contains('specArtifacts')) {
    foreach ($a in $cl.specArtifacts) { [void]$specArtifacts.Add([string]$a) }
}

$skillConsumers = New-OrdinalSet
if ($cl.PSObject.Properties.Name.Contains('skillConsumers') -and $null -ne $cl.skillConsumers) {
    foreach ($p in $cl.skillConsumers.PSObject.Properties) { [void]$skillConsumers.Add($p.Name) }
}

$overrideTokens = New-OrdinalSet
if ($cl.PSObject.Properties.Name.Contains('overrideOptionTokens')) {
    foreach ($t in $cl.overrideOptionTokens) { [void]$overrideTokens.Add([string]$t) }
}

# Declared gate contracts. Ordinal dictionaries throughout - NEVER an @{} literal,
# whose keys are case-insensitive and would silently diverge from bash's `case`.
$gateHard = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([StringComparer]::Ordinal)
$gateCond = New-Object 'System.Collections.Generic.Dictionary[string,string[]]' ([StringComparer]::Ordinal)
$gateFiles = New-OrdinalSet
if ($cl.PSObject.Properties.Name.Contains('gates') -and $null -ne $cl.gates) {
    foreach ($p in $cl.gates.PSObject.Properties) {
        $gf = $p.Name
        if (-not (Test-Path -LiteralPath (Join-Path $Root $gf) -PathType Leaf)) {
            Write-Err "contract-lint: contractLint.gates names a file that does not exist: $gf"
            exit 2
        }
        $gateHard[$gf] = [int]$p.Value.hard
        $conds = @()
        if ($null -ne $p.Value.conditional) { $conds = @($p.Value.conditional | ForEach-Object { [string]$_ }) }
        $gateCond[$gf] = $conds
        [void]$gateFiles.Add($gf)
    }
}

# Scan files: every scanScope glob, deduplicated, ordinal-sorted for a stable
# report order the twin reproduces exactly.
$scanSet = New-OrdinalSet
foreach ($glob in $cl.scanScope) {
    $pattern = Join-Path $Root ([string]$glob).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $found = @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
    foreach ($f in $found) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
        [void]$scanSet.Add($rel)
    }
}
$scanFiles = New-Object 'System.Collections.Generic.List[string]'
foreach ($s in $scanSet) { [void]$scanFiles.Add($s) }
$scanFiles.Sort([StringComparer]::Ordinal)

if ($scanFiles.Count -eq 0) {
    Write-Err "contract-lint: contractLint.scanScope matched no files under $Root"
    exit 2
}

# ---- per-file line + fence cache -------------------------------------------
#
# One disk pass. Rules read these caches; none re-walks the tree.

$fileLines = New-Object 'System.Collections.Generic.Dictionary[string,string[]]' ([StringComparer]::Ordinal)
$fileFence = New-Object 'System.Collections.Generic.Dictionary[string,bool[]]' ([StringComparer]::Ordinal)

function Read-FileLines([string]$Rel) {
    if ($fileLines.ContainsKey($Rel)) { return }
    $abs = Join-Path $Root $Rel.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    # Read raw bytes and decode UTF-8 explicitly. Get-Content's default encoding
    # on PS 5.1 mangles the non-ASCII gate marker into codepage mojibake, and
    # .gitattributes does NOT pin *.md to LF, so on a Windows checkout every
    # file here is CRLF on disk. One read fixes both.
    $text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($abs))
    $raw = $text.Split([char]10)
    # A trailing newline yields one empty final element in .NET but no final
    # line in bash's read loop. Drop it so line counts match the twin.
    $n = $raw.Length
    if ($n -gt 0 -and $raw[$n - 1].Length -eq 0) { $n = $n - 1 }
    $lines = New-Object 'string[]' $n
    for ($i = 0; $i -lt $n; $i++) { $lines[$i] = $raw[$i].TrimEnd([char]13) }
    $fence = New-Object 'bool[]' $n
    $inFence = $false
    for ($i = 0; $i -lt $n; $i++) {
        if ([regex]::IsMatch($lines[$i], $RE_FENCE)) {
            $fence[$i] = $true
            $inFence = -not $inFence
        } else {
            $fence[$i] = $inFence
        }
    }
    $fileLines[$Rel] = $lines
    $fileFence[$Rel] = $fence
}

foreach ($rel in $scanFiles) { Read-FileLines $rel }

# ---- disk-derived inventory -------------------------------------------------
#
# Agents, skills and commands come from disk, never from the manifest - they are
# inventory, and the manifest's charter says inventory is derived.

$agentNames = New-OrdinalSet
$agentFileOf = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
$agentOrder = New-Object 'System.Collections.Generic.List[string]'
$agentDir = Join-Path $Root 'agents'
if (Test-Path -LiteralPath $agentDir -PathType Container) {
    $agentPaths = @(Get-ChildItem -Path (Join-Path $agentDir '*.md') -File -ErrorAction SilentlyContinue |
        Sort-Object -Property Name)
    foreach ($p in $agentPaths) {
        $rel = 'agents/' + $p.Name
        Read-FileLines $rel
        $name = ''
        $lines = $fileLines[$rel]
        $limit = [Math]::Min(20, $lines.Length)
        for ($i = 0; $i -lt $limit; $i++) {
            $m = [regex]::Match($lines[$i], '^name:[ \t]*(.+)$')
            if ($m.Success) { $name = $m.Groups[1].Value.Trim(); break }
        }
        if ($name.Length -eq 0) { continue }
        [void]$agentNames.Add($name)
        $agentFileOf[$name] = $rel
        [void]$agentOrder.Add($name)
    }
}

$skillNames = New-OrdinalSet
$skillFileOf = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
$skillOrder = New-Object 'System.Collections.Generic.List[string]'
$skillsDir = Join-Path $Root 'skills'
if (Test-Path -LiteralPath $skillsDir -PathType Container) {
    $skillPaths = @(Get-ChildItem -Path (Join-Path $skillsDir '*') -Directory -ErrorAction SilentlyContinue |
        Sort-Object -Property Name)
    foreach ($d in $skillPaths) {
        $sm = Join-Path $d.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $sm -PathType Leaf)) { continue }
        [void]$skillNames.Add($d.Name)
        $skillFileOf[$d.Name] = 'skills/' + $d.Name + '/SKILL.md'
        [void]$skillOrder.Add($d.Name)
    }
}

$commandNames = New-OrdinalSet
$commandsDir = Join-Path $Root 'commands'
if (Test-Path -LiteralPath $commandsDir -PathType Container) {
    foreach ($p in @(Get-ChildItem -Path (Join-Path $commandsDir '*.md') -File -ErrorAction SilentlyContinue)) {
        [void]$commandNames.Add([System.IO.Path]::GetFileNameWithoutExtension($p.Name))
    }
}

# ---- finding + suppression stores ------------------------------------------

$findings = New-Object 'System.Collections.Generic.List[object]'

function Add-Finding([string]$RuleId, [string]$File, [int]$Line, [string]$Message) {
    # Sanitised at the source, not at print time: a tab or CR inside a message
    # silently corrupts the consumer's tab-delimited read.
    $clean = $Message.Replace([string][char]9, '').Replace([string][char]13, '')
    [void]$findings.Add([PSCustomObject]@{
        Rule = $RuleId; File = $File; Line = $Line; Message = $clean
    })
}

$suppressions = New-Object 'System.Collections.Generic.List[object]'

# ---- reference index --------------------------------------------------------
#
# A flat (kind, target, file, line) table. EVERY CL0xx rule reads this table and
# none of them re-walks the disk, so a wave-2 rule means adding one kind to one
# extractor rather than a second traversal.

$refs = New-Object 'System.Collections.Generic.List[object]'
$refPatterns = @(
    @{ Kind = 'sdref';        Pattern = $RE_SDREF },
    @{ Kind = 'commandRef';   Pattern = $RE_CMDREF },
    @{ Kind = 'templatePath'; Pattern = $RE_TPLPATH },
    @{ Kind = 'specArtifact'; Pattern = $RE_ARTIFACT }
)

foreach ($rel in $scanFiles) {
    $lines = $fileLines[$rel]
    $fence = $fileFence[$rel]
    foreach ($rp in $refPatterns) {
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($fence[$i]) { continue }
            foreach ($m in [regex]::Matches($lines[$i], $rp.Pattern)) {
                $tok = $m.Value
                if ($rp.Kind -eq 'specArtifact') {
                    # Drop the boundary character the pattern had to consume.
                    if ($tok.Length -gt 0 -and -not ($tok[0] -ge '0' -and $tok[0] -le '9')) {
                        $tok = $tok.Substring(1)
                    }
                }
                [void]$refs.Add([PSCustomObject]@{
                    Kind = $rp.Kind; Target = $tok; File = $rel; Line = ($i + 1)
                })
            }
        }
    }
}

# ---- agent `skills:` frontmatter index -------------------------------------

$agentSkillRefs = New-Object 'System.Collections.Generic.List[object]'
foreach ($name in $agentOrder) {
    $rel = $agentFileOf[$name]
    $lines = $fileLines[$rel]
    $inFm = $false
    $inSkills = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -ceq '---') {
            if (-not $inFm) { $inFm = $true; continue } else { break }
        }
        if (-not $inFm) { continue }
        if ([regex]::IsMatch($line, $RE_SKILLSKEY)) { $inSkills = $true; continue }
        if ($inSkills) {
            $m = [regex]::Match($line, $RE_SKILLITEM)
            if ($m.Success) {
                [void]$agentSkillRefs.Add([PSCustomObject]@{
                    File = $rel; Line = ($i + 1); Skill = $m.Groups[1].Value.Trim()
                })
                continue
            }
            $inSkills = $false
        }
    }
}

# ---- gate index -------------------------------------------------------------
#
# A gate BLOCK is [heading line, next heading of any level or EOF). That window
# is the whole reason CL300 does not fire on the ~20 literal STOPs in Phase 0
# bootstrap error paths - they all sit under a '## Phase 0' heading, never
# inside a gate block.

function Get-GateClassification([string]$Title) {
    # Peel the leading non-ASCII marker run, then an optional 'Phase N - '
    # prefix, and report whether the remainder names a gate.
    $t = [regex]::Replace($Title, $RE_NONASCII, '')
    while ($t.Length -gt 0 -and $t[0] -eq ' ') { $t = $t.Substring(1) }
    $mp = [regex]::Match($t, $RE_PHASE)
    if ($mp.Success) { $t = $mp.Groups[1].Value }
    if (-not $t.StartsWith('Gate', [System.StringComparison]::Ordinal)) { return $null }
    $rest = $t.Substring(4)

    $m = [regex]::Match($rest, $RE_GATE_NUM)
    if ($m.Success) { return @{ Kind = 'hard'; Label = $m.Groups[1].Value } }
    $m = [regex]::Match($rest, $RE_GATE_SUB)
    if ($m.Success) { return @{ Kind = 'conditional'; Label = $m.Groups[1].Value } }
    $m = [regex]::Match($rest, $RE_GATE_REPL)
    if ($m.Success) { return @{ Kind = 'conditional'; Label = 'Re-plan' } }
    if ([regex]::IsMatch($rest, $RE_GATE_UNN)) { return @{ Kind = 'hard'; Label = '' } }
    # Anything else is not a gate. This single branch is the entire
    # false-positive defence and it needs no exclusion list: 'Gate' followed by a
    # lowercase word ('## Gate activity' in commands/status.md) is never a gate.
    return $null
}

$gates = New-Object 'System.Collections.Generic.List[object]'
foreach ($rel in $scanFiles) {
    $lines = $fileLines[$rel]
    $fence = $fileFence[$rel]
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($fence[$i]) { continue }
        $mh = [regex]::Match($lines[$i], $RE_HEADING)
        if (-not $mh.Success) { continue }
        $cls = Get-GateClassification $mh.Groups[2].Value
        if ($null -eq $cls) { continue }
        $end = $lines.Length
        for ($j = $i + 1; $j -lt $lines.Length; $j++) {
            if ((-not $fence[$j]) -and [regex]::IsMatch($lines[$j], $RE_SUBHEAD)) { $end = $j; break }
        }
        $isHard = ($lines[$i].Contains('(HARD)') -or $lines[$i].Contains('[HARD]'))
        [void]$gates.Add([PSCustomObject]@{
            File = $rel; Line = ($i + 1); Kind = $cls.Kind; Label = $cls.Label
            HardMarked = $isHard; BlockEnd = $end
        })
    }
}

# ---- suppression index ------------------------------------------------------
#
# Indexed ONLY inside scanScope and ONLY outside fenced code blocks, so
# docs/contract-lint.md and CONTRIBUTING.md can show the syntax without minting
# a phantom suppression that then trips CL902.

foreach ($rel in $scanFiles) {
    $lines = $fileLines[$rel]
    $fence = $fileFence[$rel]
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($fence[$i]) { continue }
        if (-not [regex]::IsMatch($lines[$i], $RE_SUPPRESS)) { continue }
        $m = [regex]::Match($lines[$i], $RE_SUPPARTS)
        if (-not $m.Success) { continue }
        $sRule = $m.Groups[1].Value
        $reason = $m.Groups[2].Value
        $cut = $reason.IndexOf('-->', [System.StringComparison]::Ordinal)
        if ($cut -ge 0) { $reason = $reason.Substring(0, $cut) }
        # Measure the payload with separators removed, mirroring `tr -d ' \t-'`.
        $bare = $reason.Replace(' ', '').Replace([string][char]9, '').Replace('-', '')
        $bad = $false
        if (-not $ruleIds.Contains($sRule)) {
            $bad = $true
            Add-Finding 'CL901' $rel ($i + 1) "suppression names unknown rule '$sRule'"
        } elseif ($bare.Length -lt 10) {
            Add-Finding 'CL900' $rel ($i + 1) "suppression for $sRule carries no usable reason"
        }
        [void]$suppressions.Add([PSCustomObject]@{
            File = $rel; Line = ($i + 1); Rule = $sRule; Used = $false; Bad = $bad
        })
    }
}

# ---- Phase B: rules ---------------------------------------------------------
#
# Each rule reads the index and calls Add-Finding. SEVERITY IS NEVER PASSED BY A
# RULE - it is looked up from the manifest at emit time, so a BLOCK/WARN
# divergence between the twins is structurally impossible.

# CL002 owns the lines of an agent's `skills:` frontmatter list. Without this
# set, both CL001 and CL002 would fire on the same missing skill - one problem
# reported twice, the same "one error, not two" doctrine that exempts a
# CL901-flagged suppression from CL902.
$skillEntryLines = New-OrdinalSet
foreach ($a in $agentSkillRefs) { [void]$skillEntryLines.Add($a.File + ':' + $a.Line) }

# CL001 / CL003
foreach ($r in $refs) {
    if ($r.Kind -cne 'sdref') { continue }
    if ($agentNames.Contains($r.Target)) { continue }
    if ($skillNames.Contains($r.Target)) { continue }
    if ($skillEntryLines.Contains($r.File + ':' + $r.Line)) { continue }
    $txt = $fileLines[$r.File][$r.Line - 1].ToLowerInvariant()
    if ($txt.Contains('skill')) {
        Add-Finding 'CL003' $r.File $r.Line "unresolved skill reference '$($r.Target)'"
    } else {
        Add-Finding 'CL001' $r.File $r.Line "unresolved sd- reference '$($r.Target)'"
    }
}

# CL002
foreach ($a in $agentSkillRefs) {
    $sm = Join-Path (Join-Path (Join-Path $Root 'skills') $a.Skill) 'SKILL.md'
    if (Test-Path -LiteralPath $sm -PathType Leaf) { continue }
    Add-Finding 'CL002' $a.File $a.Line "skills: entry '$($a.Skill)' has no skills/$($a.Skill)/SKILL.md"
}

# CL004
foreach ($s in $skillOrder) {
    if ($skillConsumers.Contains($s)) { continue }
    $self = $skillFileOf[$s]
    $referenced = $false
    foreach ($r in $refs) {
        if ($r.Kind -cne 'sdref') { continue }
        if ($r.Target -cne $s) { continue }
        if ($r.File -ceq $self) { continue }
        $referenced = $true; break
    }
    if (-not $referenced) {
        foreach ($a in $agentSkillRefs) {
            if ($a.Skill -ceq $s) { $referenced = $true; break }
        }
    }
    if (-not $referenced) {
        Add-Finding 'CL004' $self 1 "skill '$s' is referenced by nothing in scan scope"
    }
}

# CL005
$nsPrefix = 'templates/' + $nsSegment + '/'
foreach ($r in $refs) {
    if ($r.Kind -cne 'templatePath') { continue }
    $p = $r.Target
    # templates/<ns>/... is the INSTALL target (~/.claude/templates/sd/), not a
    # repo path. Fold the namespace segment away before testing disk.
    if ($p.StartsWith($nsPrefix, [System.StringComparison]::Ordinal)) {
        $p = 'templates/' + $p.Substring($nsPrefix.Length)
    } elseif ($p -ceq ('templates/' + $nsSegment)) {
        $p = 'templates'
    }
    if ($p.EndsWith('.', [System.StringComparison]::Ordinal)) { $p = $p.Substring(0, $p.Length - 1) }
    if ($p.EndsWith('/', [System.StringComparison]::Ordinal)) { $p = $p.Substring(0, $p.Length - 1) }
    $abs = Join-Path $Root $p.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $abs) { continue }
    Add-Finding 'CL005' $r.File $r.Line "templates path does not exist: '$($r.Target)'"
}

# CL006
foreach ($r in $refs) {
    if ($r.Kind -cne 'commandRef') { continue }
    $name = $r.Target.Substring(4)
    if ($commandNames.Contains($name)) { continue }
    Add-Finding 'CL006' $r.File $r.Line "no command file for '$($r.Target)'"
}

# CL007
foreach ($a in $agentOrder) {
    $seen = $false
    foreach ($r in $refs) {
        if ($r.Kind -cne 'sdref') { continue }
        if ($r.Target -cne $a) { continue }
        if ($r.File.StartsWith('commands/', [System.StringComparison]::Ordinal)) { $seen = $true; break }
    }
    if (-not $seen) {
        Add-Finding 'CL007' $agentFileOf[$a] 1 "agent '$a' is invoked by no command"
    }
}

# CL008
foreach ($r in $refs) {
    if ($r.Kind -cne 'specArtifact') { continue }
    if ($specArtifacts.Contains($r.Target)) { continue }
    Add-Finding 'CL008' $r.File $r.Line "unknown spec artifact filename '$($r.Target)'"
}

# The seven steps below are a CONTRACT with contract-lint.sh's normalize_option.
# Both must produce byte-identical tokens or CL305 diverges between the twins.
#   1. truncate at the first backtick        5. drop every ` and " character
#   2. trim spaces/tabs                      6. lowercase A-Z only
#   3. truncate at the first " - "           7. trim spaces/tabs again
#   4. truncate at the first " <"
function Get-NormalizedOption([string]$Raw) {
    $trimChars = [char[]]@([char]32, [char]9)
    $s = $Raw
    $i = $s.IndexOf('`', [System.StringComparison]::Ordinal)
    if ($i -ge 0) { $s = $s.Substring(0, $i) }
    $s = $s.Trim($trimChars)
    $i = $s.IndexOf(' - ', [System.StringComparison]::Ordinal)
    if ($i -ge 0) { $s = $s.Substring(0, $i) }
    $i = $s.IndexOf(' <', [System.StringComparison]::Ordinal)
    if ($i -ge 0) { $s = $s.Substring(0, $i) }
    $s = $s.Replace('`', '').Replace('"', '').ToLowerInvariant()
    return $s.Trim($trimChars)
}

function Get-GateOptions([string]$Rel, [int]$StartLine, [int]$BlockEnd) {
    $lines = $fileLines[$Rel]
    $tokens = New-Object 'System.Collections.Generic.List[object]'
    $hasSet = $false
    $bullets = 0
    for ($i = $StartLine - 1; $i -lt $BlockEnd; $i++) {
        $line = $lines[$i]
        $mp = [regex]::Match($line, $RE_OPTPAREN)
        if ($mp.Success) {
            $hasSet = $true
            $inner = $mp.Value
            $inner = $inner.Substring(1, $inner.Length - 2)
            foreach ($piece in $inner.Split([char]47)) {
                $tok = Get-NormalizedOption $piece
                if ($tok.Length -gt 0) {
                    [void]$tokens.Add([PSCustomObject]@{ Line = ($i + 1); Token = $tok })
                }
            }
        }
        if ([regex]::IsMatch($line, $RE_BULLET)) {
            $bullets = $bullets + 1
            $mb = [regex]::Match($line, $RE_BULLETTOK)
            if ($mb.Success) {
                $tok = Get-NormalizedOption $mb.Groups[1].Value
                if ($tok.Length -gt 0) {
                    [void]$tokens.Add([PSCustomObject]@{ Line = ($i + 1); Token = $tok })
                }
            }
        }
    }
    if ($bullets -ge 2) { $hasSet = $true }
    return @{ HasSet = $hasSet; Tokens = $tokens }
}

# CL300 / CL301 / CL305
foreach ($g in $gates) {
    $lines = $fileLines[$g.File]
    $hasStop = $false
    for ($i = $g.Line - 1; $i -lt $g.BlockEnd; $i++) {
        if ($lines[$i].Contains('STOP')) { $hasStop = $true; break }
    }
    if (-not $hasStop) {
        Add-Finding 'CL300' $g.File $g.Line 'gate block contains no literal STOP'
    }
    $opts = Get-GateOptions $g.File $g.Line $g.BlockEnd
    if (-not $opts.HasSet) {
        Add-Finding 'CL301' $g.File $g.Line 'gate block offers no option set'
    }
    if ($g.HardMarked) {
        foreach ($t in $opts.Tokens) {
            if ($overrideTokens.Contains($t.Token)) {
                Add-Finding 'CL305' $g.File $t.Line "HARD gate offers override option '$($t.Token)'"
            }
        }
    }
}

# CL302 / CL303 / CL304
foreach ($rel in $scanFiles) {
    $count = 0
    $labels = New-Object 'System.Collections.Generic.List[int]'
    foreach ($g in $gates) {
        if ($g.File -cne $rel) { continue }
        if ($g.Kind -cne 'hard') { continue }
        $count = $count + 1
        if ($g.Label.Length -gt 0) { [void]$labels.Add([int]$g.Label) }
    }

    $declHard = 0
    $declCond = @()
    if ($gateFiles.Contains($rel)) {
        $declHard = $gateHard[$rel]
        $declCond = $gateCond[$rel]
    }
    if ($count -ne $declHard) {
        Add-Finding 'CL302' $rel 1 "hard gate count is $count on disk, manifest declares $declHard"
    }

    # CL303 is SET-based, never file order: commands/bug.md authors
    # '### Gate 3a' before '### Gate 3' and must still pass.
    if ($labels.Count -gt 0) {
        $sorted = @($labels | Sort-Object)
        $bad = $false
        $seen = New-OrdinalSet
        foreach ($v in $sorted) {
            if (-not $seen.Add([string]$v)) { $bad = $true }
        }
        $want = 1
        foreach ($v in $sorted) {
            if ($v -ne $want) { $bad = $true; break }
            $want = $want + 1
        }
        if ($bad) {
            Add-Finding 'CL303' $rel 1 "hard gate numbering is not 1..$($labels.Count) without duplicates"
        }
    }

    # CL304 - symmetric set difference, both directions BLOCK. The
    # declared-but-absent half is the anti-rot direction.
    $onDisk = New-OrdinalSet
    $declSet = New-OrdinalSet
    foreach ($c in $declCond) { [void]$declSet.Add($c) }
    foreach ($g in $gates) {
        if ($g.File -cne $rel) { continue }
        if ($g.Kind -cne 'conditional') { continue }
        [void]$onDisk.Add($g.Label)
        if (-not $declSet.Contains($g.Label)) {
            Add-Finding 'CL304' $rel $g.Line "conditional gate '$($g.Label)' is not declared in the manifest"
        }
    }
    foreach ($c in $declCond) {
        if (-not $onDisk.Contains($c)) {
            Add-Finding 'CL304' $rel 1 "manifest declares conditional gate '$c' but it is absent from disk"
        }
    }
}

# ---- Phase C: suppressions, sort, emit -------------------------------------
#
# A suppression can never suppress CL900, CL901 or CL902 - otherwise
# '<!-- contract-lint: allow CL900 -->' would be a self-authorizing loophole.
# That exclusion is hardcoded, never manifest-driven.

$kept = New-Object 'System.Collections.Generic.List[object]'
foreach ($f in $findings) {
    $hit = $false
    if ($f.Rule -cne 'CL900' -and $f.Rule -cne 'CL901' -and $f.Rule -cne 'CL902') {
        foreach ($s in $suppressions) {
            if ($s.Bad) { continue }
            if ($s.File -cne $f.File) { continue }
            if ($s.Rule -cne $f.Rule) { continue }
            if ($s.Line -eq $f.Line -or $s.Line -eq ($f.Line - 1)) {
                $s.Used = $true
                $hit = $true
                break
            }
        }
    }
    if (-not $hit) { [void]$kept.Add($f) }
}
$findings = $kept

# CL902 runs LAST, over the used flags. A CL901-flagged suppression is exempt -
# one error per broken suppression, never two.
foreach ($s in $suppressions) {
    if ($s.Bad) { continue }
    if ($s.Used) { continue }
    Add-Finding 'CL902' $s.File $s.Line "suppression for $($s.Rule) suppressed nothing"
}

$blocks = 0
$warns = 0
$rows = New-Object 'System.Collections.Generic.List[string]'
foreach ($f in $findings) {
    if ($ruleFilter.Count -gt 0 -and -not $ruleFilter.Contains($f.Rule)) { continue }
    $sev = 'BLOCK'
    if ($ruleSeverity.ContainsKey($f.Rule)) { $sev = $ruleSeverity[$f.Rule] }
    if ($sev -ceq 'BLOCK') { $blocks = $blocks + 1 } else { $warns = $warns + 1 }
    # Sort key: file, then zero-padded line so lexical order IS numeric order,
    # then rule id, then message. The twin builds the identical key and sorts it
    # byte-wise, which is what makes the two outputs comparable line for line.
    $key = '{0}{1}{2:D9}{1}{3}{1}{4}' -f $f.File, [char]1, $f.Line, $f.Rule, $f.Message
    $row = '{0}{1}{2}{1}{3}{1}{4}{1}{5}' -f $f.Rule, [char]9, $sev, $f.File, $f.Line, $f.Message
    [void]$rows.Add(($key + [char]9 + $row))
}
$rows.Sort([StringComparer]::Ordinal)

foreach ($r in $rows) {
    # Write-Output, never [Console]::Out.WriteLine: the latter writes straight to
    # the console handle and silently bypasses PowerShell's '>' redirection, so
    # the parity capture in run-selftest.ps1 would collect an empty file while
    # the findings scrolled past on screen.
    $tab = $r.IndexOf([char]9)
    Write-Output $r.Substring($tab + 1)
}

if (-not $Quiet) {
    Write-Err "contract-lint: $blocks block, $warns warn (root: $Root)"
}

if ($blocks -gt 0) { exit 1 }
exit 0
