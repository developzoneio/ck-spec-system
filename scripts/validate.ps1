#requires -Version 5.1
<#
.SYNOPSIS
    Repo invariant validator for specwright (Windows / PowerShell).

.DESCRIPTION
    Runs every documented engine invariant as a single command:
      1. Pure-ASCII scan of all *.ps1 files (this file included).
      2. bash -n syntax check on hooks/bash/*.sh, install/*.sh, scripts/*.sh.
      3. Hook-pair parity: every hooks/powershell/X.ps1 has a hooks/bash/X.sh
         and vice-versa.
      4. Model-alias-only: agent frontmatter model: in {sonnet,haiku,opus,inherit}.
      5. Install-target count: a real install to a temp base lands the expected
         file counts under each <area>/sd/ subfolder.
      6. CHANGELOG gate: the [Unreleased] section is non-empty.
      7. Plugin manifest validation: claude plugin validate passes on the repo root.

    Exit code 0 = all checks passed; 1 = at least one check failed.

    PURE ASCII. This file is scanned by check 1, so it must contain no byte
    above 0x7F (no em-dash, arrows, or box-drawing characters).

.EXAMPLE
    .\scripts\validate.ps1
#>

param()

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path -Parent $scriptDir

# ---- expected install-target counts ----------------------------------------
# One platform's hooks land per install (PowerShell hooks here), so 3 not 6.
$ExpectedCommands  = 11
$ExpectedAgents    = 6
$ExpectedSkills    = 6
$ExpectedHooks     = 3
$ExpectedTemplates = 9

$ModelAliases = @('sonnet', 'haiku', 'opus', 'inherit')

# ---- output helpers ---------------------------------------------------------

function Write-Section { param([string]$Title) Write-Host ''; Write-Host "=== $Title ===" -ForegroundColor Cyan }
function Write-Ok      { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-FailMsg { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Write-WarnMsg { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }

$script:Failures = New-Object System.Collections.Generic.List[string]
function Add-Failure { param([string]$m) $script:Failures.Add($m) }

function Get-RelPath { param([string]$Path) $Path.Substring($repoRoot.Length).TrimStart('\', '/') }

# Returns the 1-based line number of the first non-ASCII byte, or 0 if clean.
function Get-FirstNonAsciiLine {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $line = 1
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $b = $bytes[$i]
        if ($b -eq 10) { $line++ }
        if ($b -gt 127) { return $line }
    }
    return 0
}

# Locate a usable bash. On Windows the bare 'bash' on PATH is often the WSL
# launcher, which fails when no distro is installed and mistranslates Windows
# paths; prefer Git for Windows' bash, which handles C:/... paths natively.
# Returns the path to the first bash that passes a smoke test, or $null.
function Find-WorkingBash {
    $candidates = New-Object System.Collections.Generic.List[string]
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $gitRoot = Split-Path -Parent (Split-Path -Parent $git.Source)
        $candidates.Add((Join-Path $gitRoot 'bin\bash.exe'))
        $candidates.Add((Join-Path $gitRoot 'usr\bin\bash.exe'))
    }
    foreach ($pf in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs")) {
        if ($pf) {
            $candidates.Add((Join-Path $pf 'Git\bin\bash.exe'))
            $candidates.Add((Join-Path $pf 'Git\usr\bin\bash.exe'))
        }
    }
    foreach ($c in (Get-Command bash -All -ErrorAction SilentlyContinue)) {
        $candidates.Add($c.Source)
    }
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            try {
                & $c -c 'exit 0' 2>$null
                if ($LASTEXITCODE -eq 0) { return $c }
            } catch { }
        }
    }
    return $null
}

Write-Section 'specwright validate'
Write-Host "  Repo root: $repoRoot"

# ---- Check 1: pure-ASCII scan ----------------------------------------------

Write-Section 'Check 1/7: Pure-ASCII scan (*.ps1)'
$ps1Files = Get-ChildItem -Path $repoRoot -Recurse -Filter *.ps1 -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
$asciiBad = 0
foreach ($f in $ps1Files) {
    $line = Get-FirstNonAsciiLine -Path $f.FullName
    if ($line -gt 0) {
        $rel = Get-RelPath $f.FullName
        Write-FailMsg "$rel : non-ASCII byte at line $line"
        Add-Failure "ASCII: $rel (line $line)"
        $asciiBad++
    }
}
if ($asciiBad -eq 0) { Write-Ok "$($ps1Files.Count) .ps1 file(s) are pure ASCII" }

# ---- Check 2: bash -n syntax -----------------------------------------------

Write-Section 'Check 2/7: bash -n syntax (*.sh)'
$shFiles = @()
foreach ($sub in @('hooks\bash', 'install', 'scripts')) {
    $dir = Join-Path $repoRoot $sub
    if (Test-Path -LiteralPath $dir) {
        $shFiles += Get-ChildItem -Path $dir -Filter *.sh -File
    }
}
$bashExe = Find-WorkingBash
if ($null -eq $bashExe) {
    Write-WarnMsg 'No working bash found; skipping syntax check (CI runs this on Ubuntu).'
} else {
    $synBad = 0
    foreach ($f in $shFiles) {
        $p = $f.FullName -replace '\\', '/'
        $out = & $bashExe -n $p 2>&1
        if ($LASTEXITCODE -ne 0) {
            $rel = Get-RelPath $f.FullName
            Write-FailMsg "$rel : $out"
            Add-Failure "bash -n: $rel"
            $synBad++
        }
    }
    if ($synBad -eq 0) { Write-Ok "$($shFiles.Count) .sh file(s) pass bash -n" }
}

# ---- Check 3: hook-pair parity ---------------------------------------------

Write-Section 'Check 3/7: Hook-pair parity'
$psHooks = Get-ChildItem (Join-Path $repoRoot 'hooks\powershell') -Filter *.ps1 -File |
    ForEach-Object { $_.BaseName }
$shHooks = Get-ChildItem (Join-Path $repoRoot 'hooks\bash') -Filter *.sh -File |
    ForEach-Object { $_.BaseName }
$parityBad = 0
foreach ($h in $psHooks) {
    if ($shHooks -notcontains $h) {
        Write-FailMsg "hooks/powershell/$h.ps1 has no hooks/bash/$h.sh"
        Add-Failure "parity: missing bash twin for $h"
        $parityBad++
    }
}
foreach ($h in $shHooks) {
    if ($psHooks -notcontains $h) {
        Write-FailMsg "hooks/bash/$h.sh has no hooks/powershell/$h.ps1"
        Add-Failure "parity: missing PowerShell twin for $h"
        $parityBad++
    }
}
if ($parityBad -eq 0) { Write-Ok "$($psHooks.Count) hook pair(s) present on both platforms" }

# ---- Check 4: agent model aliases ------------------------------------------

Write-Section 'Check 4/7: Agent model aliases'
$agentFiles = Get-ChildItem (Join-Path $repoRoot 'agents') -Filter *.md -File
$modelBad = 0
foreach ($f in $agentFiles) {
    $rel = Get-RelPath $f.FullName
    $match = Select-String -Path $f.FullName -Pattern '^model:\s*(.+?)\s*$' | Select-Object -First 1
    if ($null -eq $match) {
        Write-FailMsg "$rel : no model: field"
        Add-Failure "model: $rel missing model field"
        $modelBad++
        continue
    }
    $val = ($match.Matches[0].Groups[1].Value -replace '\s*#.*$', '').Trim()
    if ($ModelAliases -notcontains $val) {
        Write-FailMsg "$rel : model '$val' is not an alias ($($ModelAliases -join ', '))"
        Add-Failure "model: $rel = $val"
        $modelBad++
    }
}
if ($modelBad -eq 0) { Write-Ok "$($agentFiles.Count) agent(s) use a model alias" }

# ---- Check 5: install-target counts ----------------------------------------

Write-Section 'Check 5/7: Install-target counts'
$installPs1 = Join-Path $repoRoot 'install\install.ps1'
$tmp = Join-Path $env:TEMP "sd-validate-$PID"
$psExe = (Get-Process -Id $PID).Path
try {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force $tmp }
    if ($env:OS -eq 'Windows_NT') {
        $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installPs1, '-BasePath', $tmp, '-Force')
    } else {
        $childArgs = @('-NoProfile', '-File', $installPs1, '-BasePath', $tmp, '-Force')
    }
    & $psExe @childArgs *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-FailMsg "installer exited with code $LASTEXITCODE"
        Add-Failure "install: installer exit $LASTEXITCODE"
    } else {
        $targets = @(
            [pscustomobject]@{ Name = 'commands';  Path = 'commands\sd';  Expected = $ExpectedCommands },
            [pscustomobject]@{ Name = 'agents';    Path = 'agents\sd';    Expected = $ExpectedAgents },
            [pscustomobject]@{ Name = 'skills';    Path = 'skills\sd';    Expected = $ExpectedSkills },
            [pscustomobject]@{ Name = 'hooks';     Path = 'hooks\sd';     Expected = $ExpectedHooks },
            [pscustomobject]@{ Name = 'templates'; Path = 'templates\sd'; Expected = $ExpectedTemplates }
        )
        foreach ($t in $targets) {
            $full = Join-Path $tmp $t.Path
            if (Test-Path -LiteralPath $full) {
                $cnt = (Get-ChildItem -LiteralPath $full -Recurse -File).Count
            } else {
                $cnt = 0
            }
            if ($cnt -eq $t.Expected) {
                Write-Ok "$($t.Name)/sd : $cnt file(s)"
            } else {
                Write-FailMsg "$($t.Name)/sd : expected $($t.Expected), found $cnt"
                Add-Failure "install: $($t.Name)/sd expected $($t.Expected) found $cnt"
            }
        }
    }
} finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}

# ---- Check 6: CHANGELOG [Unreleased] non-empty -----------------------------

Write-Section 'Check 6/7: CHANGELOG [Unreleased] gate'
$changelog = Join-Path $repoRoot 'CHANGELOG.md'
$lines = Get-Content -LiteralPath $changelog
$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s+\[Unreleased\]') { $start = $i; break }
}
if ($start -lt 0) {
    Write-FailMsg 'no ## [Unreleased] section found'
    Add-Failure 'changelog: no [Unreleased] header'
} else {
    $hasEntry = $false
    $nextHeader = $null
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+\[') { $nextHeader = $lines[$i]; break }
        if ($lines[$i] -match '^\s*-\s+\S') { $hasEntry = $true; break }
    }
    # An empty [Unreleased] passes only immediately after a release: the next
    # section must be a dated [x.y.z] - <date> heading (the freshly cut
    # version). Otherwise every PR must add an entry under [Unreleased].
    $justReleased = ($null -ne $nextHeader) -and ($nextHeader -match '^##\s+\[\d+\.\d+\.\d+\]\s+-\s+\S')
    if ($hasEntry) {
        Write-Ok '[Unreleased] has at least one entry'
    } elseif ($justReleased) {
        Write-Ok '[Unreleased] empty but sits directly above a dated release (just cut)'
    } else {
        Write-FailMsg '[Unreleased] section is empty (add a changelog entry)'
        Add-Failure 'changelog: [Unreleased] empty'
    }
}

# ---- Check 7: plugin manifest validation -----------------------------------

Write-Section 'Check 7/7: Plugin manifest validation'
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($null -eq $claudeCmd) {
    Write-WarnMsg 'claude CLI not found in PATH; skipping plugin validate (CI runs this step).'
} else {
    $pluginOut = & claude plugin validate $repoRoot 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok '.claude-plugin/plugin.json and marketplace.json pass claude plugin validate'
    } else {
        Write-FailMsg "claude plugin validate failed:`n$pluginOut"
        Add-Failure "plugin-validate: claude plugin validate exited $LASTEXITCODE"
    }
}

# ---- summary ---------------------------------------------------------------

Write-Section 'Summary'
if ($script:Failures.Count -eq 0) {
    Write-Host '  [OK]   All checks passed.' -ForegroundColor Green
    exit 0
} else {
    Write-Host "  [FAIL] $($script:Failures.Count) check(s) failed:" -ForegroundColor Red
    foreach ($m in $script:Failures) { Write-Host "         - $m" -ForegroundColor Red }
    exit 1
}
