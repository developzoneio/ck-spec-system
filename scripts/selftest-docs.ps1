#requires -Version 5.1
<#
.SYNOPSIS
    Negative self-test for validate.ps1 Check 7 (docs consistency), Windows.

.DESCRIPTION
    Mirror of scripts/selftest-docs.sh.

    Check 7 only earns its place in CI if it FAILS when the docs lie. A check that
    silently degrades into a no-op still reports success, so this test corrupts a
    throwaway copy of the repo in several ways and asserts the validator catches each:

      1. Clean copy                 -> passes.
      2. A wrong published number   -> fails, naming the number and the truth.
      3. A reworded claim           -> fails as vacuous (pattern matched no lines).
      4. An undeclared new claim    -> fails as undeclared.
      5. A spelled-out CAPITALISED  -> fails as undeclared.  (SW-24)
      6. A bare-noun claim          -> fails as undeclared.  (SW-24)

    Scenarios 3 and 4 are what stop the check rotting: without them someone could
    reword or add docs and quietly leave Check 7 guarding nothing. Scenarios 5 and 6
    cover the two escapes SW-24 found, both of which had let a real wrong claim sit
    in a tracked doc through many green runs. They are deliberately separate: a fix
    that only adds a lowercase word alternation passes 4 and fails 5, and a fix that
    only handles decorated nouns passes 5 and fails 6.

    Exit code 0 = the check behaves correctly; 1 = the check is broken.

    PURE ASCII. Scanned by validate.ps1 Check 1.

.EXAMPLE
    .\scripts\selftest-docs.ps1
#>

param()

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path -Parent $scriptDir

function Write-Section { param([string]$Title) Write-Host ''; Write-Host "=== $Title ===" -ForegroundColor Cyan }
function Write-Ok      { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-FailMsg { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }

$script:Failures = 0

# Working dirs are throwaway copies - the real repo is never mutated.
$SkipTop = @('.git', 'node_modules', '_bmad', '_bmad-output', 'design-artifacts', '.claude', 'dist')

$workRoot = Join-Path $env:TEMP "sd-selftest-docs-$PID"
$psExe = (Get-Process -Id $PID).Path

function New-RepoCopy {
    param([string]$Dest)
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    foreach ($entry in (Get-ChildItem -LiteralPath $repoRoot -Force)) {
        if ($SkipTop -contains $entry.Name) { continue }
        Copy-Item -LiteralPath $entry.FullName -Destination $Dest -Recurse -Force
    }
}

# The count this test corrupts is DERIVED from disk, never written down. A literal here
# would rot the moment a command is added: the pattern would stop matching, the sandbox
# copy would never be corrupted, and the scenario would report the validator as passing
# when in truth nothing was ever tested. That is exactly what happened when the 12th
# command landed against a hardcoded '11' (SW-20), and it is the same anti-pattern
# specwright.manifest.json exists to abolish.
$TrueCommands  = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'commands') -Filter '*.md' -File).Count
$WrongCommands = $TrueCommands + 1

function Edit-File {
    param([string]$Path, [string]$From, [string]$To)
    $text = Get-Content -LiteralPath $Path -Raw
    $updated = $text -replace $From, $To
    Set-Content -LiteralPath $Path -Value $updated -NoNewline
    return ($updated -ne $text)
}

# Asserts the transition, not just the destination: Edit-File reports whether the file
# actually changed. Checking only that the planted text is present is what defeated the
# original scenario-2 guard - it planted the then-current count, which by then was also
# the TRUE value already in README.md, so the check found the real line and passed
# vacuously. Returns $true when the corruption applied.
function Assert-Corruption {
    param([string]$Name, [string]$Path, [string]$From, [string]$To)

    if (Edit-File -Path $Path -From $From -To $To) {
        return $true
    }
    Write-FailMsg "$Name : fixture setup - pattern did not match, nothing was corrupted"
    $script:Failures++
    return $false
}

# Run the validator inside a copy and assert exit status + expected message.
# ExpectPass -> exit 0 required; otherwise non-zero AND $Needle in the output.
function Invoke-Case {
    param(
        [string]$Name,
        [bool]$ExpectPass,
        [string]$Needle,
        [string]$Dir
    )
    $validator = Join-Path $Dir 'scripts\validate.ps1'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $validator 2>&1 | Out-String
    $status = $LASTEXITCODE

    if ($ExpectPass) {
        if ($status -eq 0) {
            Write-Ok "$Name : validator passed as expected"
        } else {
            Write-FailMsg "$Name : expected exit 0, got $status"
            Write-Host $out
            $script:Failures++
        }
        return
    }

    if ($status -eq 0) {
        Write-FailMsg "$Name : expected non-zero exit, got 0 - THE CHECK DID NOT BITE"
        $script:Failures++
        return
    }
    if ($out.Contains($Needle)) {
        Write-Ok "$Name : failed with the right reason (exit $status)"
    } else {
        # Non-zero for the wrong reason is not a pass - it would mask a broken check.
        Write-FailMsg "$Name : exited $status but never said '$Needle'"
        Write-Host $out
        $script:Failures++
    }
}

try {
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -Recurse -Force $workRoot }

    Write-Section 'selftest: docs-consistency check (Check 7)'
    Write-Host "  Repo root: $repoRoot"
    Write-Host "  Sandbox:   $workRoot"

    # ---- Scenario 1: clean copy passes -------------------------------------

    Write-Section 'Scenario 1/6: clean copy passes'
    $clean = Join-Path $workRoot 'clean'
    New-RepoCopy -Dest $clean
    Invoke-Case -Name 'clean' -ExpectPass $true -Needle '' -Dir $clean

    # ---- Scenario 2: a wrong published number fails -------------------------

    Write-Section 'Scenario 2/6: wrong README number fails'
    $wrong = Join-Path $workRoot 'wrong-number'
    New-RepoCopy -Dest $wrong
    $planted = Assert-Corruption -Name 'wrong-number' -Path (Join-Path $wrong 'README.md') `
        -From "\*\*$TrueCommands slash commands\*\*" -To "**$WrongCommands slash commands**"
    if ($planted) {
        Invoke-Case -Name 'wrong-number' -ExpectPass $false `
            -Needle "says $WrongCommands, disk has $TrueCommands" -Dir $wrong
    }

    # ---- Scenario 3: a reworded claim fails as vacuous ----------------------

    Write-Section 'Scenario 3/6: reworded claim fails as vacuous'
    $reworded = Join-Path $workRoot 'reworded'
    New-RepoCopy -Dest $reworded
    $planted = Assert-Corruption -Name 'reworded' -Path (Join-Path $reworded 'README.md') `
        -From "\*\*$TrueCommands slash commands\*\*" -To "**$TrueCommands slash cmds**"
    if ($planted) {
        Invoke-Case -Name 'reworded' -ExpectPass $false `
            -Needle 'pattern matched no lines' -Dir $reworded
    }

    # ---- Scenario 4: an undeclared claim fails ------------------------------

    Write-Section 'Scenario 4/6: undeclared claim in a new doc fails'
    $undeclared = Join-Path $workRoot 'undeclared'
    New-RepoCopy -Dest $undeclared
    Add-Content -LiteralPath (Join-Path $undeclared 'docs\usage.md') `
        -Value "`nThe engine ships 99 reusable skills."
    Invoke-Case -Name 'undeclared' -ExpectPass $false -Needle 'undeclared inventory claim' -Dir $undeclared

    # ---- Scenario 5: a spelled-out, CAPITALISED claim fails (SW-24) ---------

    # A spelled-out number can never be validated against disk - the comparison is
    # against an integer - so the only correct outcome is rejection as undeclared.
    # Capitalised on purpose: a spelled-out count in prose is usually sentence-initial,
    # which is exactly the form a lowercase-only word alternation misses.

    Write-Section 'Scenario 5/6: spelled-out capitalised claim fails'
    $spelled = Join-Path $workRoot 'spelled-out'
    New-RepoCopy -Dest $spelled
    Add-Content -LiteralPath (Join-Path $spelled 'docs\usage.md') `
        -Value "`nSeven reusable skills ship with the engine."
    Invoke-Case -Name 'spelled-out' -ExpectPass $false -Needle 'undeclared inventory claim' -Dir $spelled

    # ---- Scenario 6: a bare-noun claim fails (SW-24) -----------------------

    # Before SW-24 the vocabulary only listed decorated forms ('slash commands',
    # 'workflow commands'), so an undecorated 'N commands' matched nothing at all.
    # That is how 'Five commands invoke no subagent' sat in docs/architecture.md unseen.

    Write-Section 'Scenario 6/6: bare-noun claim fails'
    $bareNoun = Join-Path $workRoot 'bare-noun'
    New-RepoCopy -Dest $bareNoun
    Add-Content -LiteralPath (Join-Path $bareNoun 'docs\usage.md') `
        -Value "`nThe engine ships 99 commands."
    Invoke-Case -Name 'bare-noun' -ExpectPass $false -Needle 'undeclared inventory claim' -Dir $bareNoun

    # ---- summary -----------------------------------------------------------

    Write-Section 'Summary'
    if ($script:Failures -eq 0) {
        Write-Ok 'Check 7 bites on all 6 scenarios.'
        exit 0
    } else {
        Write-FailMsg "$($script:Failures) scenario(s) behaved wrong - Check 7 is not trustworthy."
        exit 1
    }
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -Recurse -Force $workRoot -ErrorAction SilentlyContinue
    }
}
