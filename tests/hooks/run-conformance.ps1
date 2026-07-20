#requires -Version 7.0
<#
.SYNOPSIS
    specwright: cross-implementation hook conformance runner.

.DESCRIPTION
    For every fixture case under tests/hooks/fixtures/<hook>/<case>/:
      1. Create a fresh temp workspace PER IMPLEMENTATION and copy the
         case's workspace/ tree into it (fresh copy means hook state such
         as the subagent-retro debounce file cannot leak across runs).
      2. Apply setup.json actions (currently: backdating file mtimes).
      3. Substitute {{CWD}} in input.json with the workspace path
         (forward slashes; both implementations accept them) and pipe the
         payload into the implementation on stdin.
      4. Normalize what the hook did into a small decision object.
      5. Assert bash decision == pwsh decision == expected.json golden.

    A behavioral divergence in only one implementation fails the suite
    and prints all three decision objects for a clear diff.

    -SelfTest substitutes a stub bash spec-gate hook that always allows,
    then asserts the harness DETECTS the divergence. Proves the
    comparison would notice real drift (mirror of scripts/selftest-docs).

.NOTES
    PURE ASCII ONLY (see hooks/powershell/prompt-router.ps1 for why).
    Single cross-platform runner by design: unlike the platform-native
    scripts/ checks, conformance must run BOTH implementations in one
    process, so a bash twin of this script would itself be a drift risk.
    CI runs this under pwsh on every matrix OS.
#>

[CmdletBinding()]
param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot    = (Resolve-Path (Join-Path $scriptDir '..' '..')).Path
$fixturesDir = Join-Path $scriptDir 'fixtures'

$script:pass = 0
$script:fail = 0

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK]   $Message"
    $script:pass++
}

function Write-Bad {
    param([string]$Message)
    Write-Host "  [FAIL] $Message"
    $script:fail++
}

function Resolve-BashPath {
    # On Windows prefer Git Bash explicitly: System32 bash.exe is WSL's
    # stub and fails when no distro is installed.
    if ($IsWindows) {
        $gitBash = 'C:\Program Files\Git\bin\bash.exe'
        if (Test-Path -LiteralPath $gitBash) { return $gitBash }
    }
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    return $null
}

function New-CaseWorkspace {
    param([string]$CaseDir)

    $name = 'sd-conformance-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 12)
    $ws = Join-Path ([System.IO.Path]::GetTempPath()) $name
    New-Item -ItemType Directory -Path $ws -Force | Out-Null

    $src = Join-Path $CaseDir 'workspace'
    if (Test-Path -LiteralPath $src) {
        # -Force on Get-ChildItem: fixture trees are mostly dot-dirs
        # (.claude, .specs) which Unix wildcard copies would skip.
        Get-ChildItem -LiteralPath $src -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $ws -Recurse -Force
        }
    }

    $setupPath = Join-Path $CaseDir 'setup.json'
    if (Test-Path -LiteralPath $setupPath) {
        $setup = Get-Content -LiteralPath $setupPath -Raw | ConvertFrom-Json
        foreach ($t in @($setup.touch)) {
            if ($null -eq $t) { continue }
            $target = Join-Path $ws $t.path
            if (Test-Path -LiteralPath $target) {
                $item = Get-Item -LiteralPath $target
                $item.LastWriteTimeUtc = [System.DateTime]::UtcNow.AddMinutes(-1 * [double]$t.ageMinutes)
            }
        }
        # `write` plants a file whose CONTENT carries a timestamp - a hook state
        # file, say. The timestamp is computed at run time from a
        # {{UTCNOW-90M}} / {{UTCNOW+5M}} token rather than written literally
        # into the fixture, which would rot the moment the clock moved past it.
        foreach ($w in @($setup.write)) {
            if ($null -eq $w) { continue }
            $content = [string]$w.content
            $content = [regex]::Replace($content, '\{\{UTCNOW([+-]\d+)M\}\}', {
                param($m)
                $offset = [int]$m.Groups[1].Value
                [System.DateTime]::UtcNow.AddMinutes($offset).ToString('yyyy-MM-ddTHH:mm:ssZ')
            })
            $target = Join-Path $ws $w.path
            $dir = Split-Path -Path $target -Parent
            if (-not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            Set-Content -LiteralPath $target -Value $content -Encoding ascii -NoNewline
        }
    }

    return $ws
}

function Invoke-HookProcess {
    param(
        [string]$Exe,
        [string[]]$ProcArgs,
        [string]$Payload
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    foreach ($a in $ProcArgs) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write($Payload)
    $proc.StandardInput.Close()
    # Hook output is tiny (well under pipe buffer size), so sequential
    # reads cannot deadlock.
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{
        ExitCode = $proc.ExitCode
        Stdout   = $stdout.Replace("`r", '')
        Stderr   = $stderr.Replace("`r", '')
    }
}

function Invoke-HookImpl {
    param(
        [string]$Impl,
        [string]$HookScript,
        [string]$CaseDir
    )
    $ws = New-CaseWorkspace -CaseDir $CaseDir
    try {
        $wsForward = $ws.Replace('\', '/')
        $inputPath = Join-Path $CaseDir 'input.json'
        $payload = (Get-Content -LiteralPath $inputPath -Raw).Replace('{{CWD}}', $wsForward)
        if ($Impl -eq 'bash') {
            return Invoke-HookProcess -Exe $script:bashExe -ProcArgs @($HookScript) -Payload $payload
        }
        return Invoke-HookProcess -Exe 'pwsh' -ProcArgs @('-NoProfile', '-File', $HookScript) -Payload $payload
    } finally {
        Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---- normalizers: one per hook, each maps a raw run to a decision object ----

function ConvertTo-SpecGateDecision {
    param($Run)
    $decision = 'allow'
    $permission = $null
    $reason = $null
    $stdoutTrim = $Run.Stdout.Trim()
    if ($stdoutTrim.Length -gt 0) {
        try {
            $obj = $stdoutTrim | ConvertFrom-Json
            if ($obj.decision) { $decision = [string]$obj.decision }
            if ($obj.hookSpecificOutput -and $obj.hookSpecificOutput.permissionDecision) {
                $permission = [string]$obj.hookSpecificOutput.permissionDecision
            }
            # The human-readable reason is duplicated into both schema halves by
            # both implementations; if the two copies ever disagree the object
            # must not silently keep one of them.
            $topReason = if ($obj.reason) { [string]$obj.reason } else { $null }
            $nestedReason = if ($obj.hookSpecificOutput -and $obj.hookSpecificOutput.reason) {
                [string]$obj.hookSpecificOutput.reason
            } else { $null }
            if ($topReason -ne $nestedReason) {
                $reason = 'REASON-MISMATCH-BETWEEN-SCHEMA-HALVES'
            } else {
                $reason = $topReason
            }
        } catch {
            $decision = 'unparseable-stdout'
        }
    } elseif ($Run.Stderr.Contains('[WARN]')) {
        $decision = 'warn'
    }
    # stderr is part of the decision: the repo invariant is that a hook stays
    # SILENT unless it has something to say, so an unexpected diagnostic on
    # stderr must fail the case rather than pass unnoticed.
    return [pscustomobject][ordered]@{
        exitCode           = $Run.ExitCode
        decision           = $decision
        permissionDecision = $permission
        reason             = $reason
        stderr             = $Run.Stderr.Trim()
    }
}

function ConvertTo-PromptRouterDecision {
    param($Run)
    $workflows   = [System.Collections.Generic.List[string]]::new()
    $ticketIds   = [System.Collections.Generic.List[string]]::new()
    $specFolders = [System.Collections.Generic.List[string]]::new()
    $inProgress  = [System.Collections.Generic.List[string]]::new()
    $section = ''
    foreach ($line in ($Run.Stdout -split "`n")) {
        if ($line -match '^Workflow keyword matches:') { $section = 'workflows'; continue }
        if ($line -match '^Ticket IDs detected: (.*)$') {
            $section = 'tickets'
            foreach ($t in ($Matches[1] -split ', ')) {
                if ($t.Trim()) { $ticketIds.Add($t.Trim()) }
            }
            continue
        }
        if ($line -match '^Matching spec folders') { $section = 'folders'; continue }
        if ($line -match '^No matching spec folder') { $section = ''; continue }
        if ($line -match '^Specs currently in-progress') { $section = 'inprogress'; continue }
        if ($line -match '^\s+-\s+(.+)$') {
            $item = $Matches[1].Trim()
            switch ($section) {
                'workflows' {
                    if ($item -match '^/sd:([a-z]+)') { $workflows.Add($Matches[1]) }
                }
                'folders'    { $specFolders.Add($item) }
                'inprogress' { $inProgress.Add($item) }
            }
        }
    }
    return [pscustomobject][ordered]@{
        exitCode    = $Run.ExitCode
        emitted     = $Run.Stdout.Contains('<context-router>')
        workflows   = @($workflows | Sort-Object)
        ticketIds   = @($ticketIds | Sort-Object)
        specFolders = @($specFolders | Sort-Object)
        inProgress  = @($inProgress | Sort-Object)
        stderr      = $Run.Stderr.Trim()
    }
}

function ConvertTo-SubagentRetroDecision {
    param($Run)
    $stale = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($Run.Stdout -split "`n")) {
        # The measured age and the threshold it was compared against are part of
        # the decision - dropping them would let the two implementations disagree
        # on arithmetic (truncate vs round) while still looking identical.
        if ($line -match '^\s+-\s+([A-Za-z0-9_\-]+): 05-retro\.md missing$') {
            $stale.Add([pscustomobject][ordered]@{
                id = $Matches[1]; reason = 'missing'; ageMinutes = $null; thresholdMinutes = $null
            })
        } elseif ($line -match '^\s+-\s+([A-Za-z0-9_\-]+): 05-retro\.md last touched (\d+) min ago \(threshold (\d+) min\)$') {
            $stale.Add([pscustomobject][ordered]@{
                id = $Matches[1]; reason = 'stale'
                ageMinutes = [int]$Matches[2]; thresholdMinutes = [int]$Matches[3]
            })
        }
    }
    return [pscustomobject][ordered]@{
        exitCode = $Run.ExitCode
        emitted  = $Run.Stdout.Contains('<retro-reminder>')
        stale    = @($stale | Sort-Object -Property id)
        stderr   = $Run.Stderr.Trim()
    }
}

$hookNormalizers = @{
    'spec-gate'      = ${function:ConvertTo-SpecGateDecision}
    'prompt-router'  = ${function:ConvertTo-PromptRouterDecision}
    'subagent-retro' = ${function:ConvertTo-SubagentRetroDecision}
}

function Get-CanonicalJson {
    param($Obj)
    return ($Obj | ConvertTo-Json -Depth 5 -Compress)
}

function Invoke-ConformanceCase {
    param(
        [string]$HookName,
        [string]$CaseDir,
        [string]$BashHook,
        [string]$PwshHook
    )
    $normalizer = $hookNormalizers[$HookName]
    $bashRun = Invoke-HookImpl -Impl 'bash' -HookScript $BashHook -CaseDir $CaseDir
    $pwshRun = Invoke-HookImpl -Impl 'pwsh' -HookScript $PwshHook -CaseDir $CaseDir
    $expected = Get-Content -LiteralPath (Join-Path $CaseDir 'expected.json') -Raw | ConvertFrom-Json
    $bashJson     = Get-CanonicalJson (& $normalizer $bashRun)
    $pwshJson     = Get-CanonicalJson (& $normalizer $pwshRun)
    $expectedJson = Get-CanonicalJson $expected
    return [pscustomobject]@{
        CaseName = Split-Path -Leaf $CaseDir
        Bash     = $bashJson
        Pwsh     = $pwshJson
        Expected = $expectedJson
        Match    = ($bashJson -eq $expectedJson) -and ($pwshJson -eq $expectedJson)
    }
}

function Write-CaseDiff {
    param($Result)
    Write-Host "         expected : $($Result.Expected)"
    Write-Host "         bash     : $($Result.Bash)"
    Write-Host "         pwsh     : $($Result.Pwsh)"
}

# ---- preconditions ----------------------------------------------------------

$script:bashExe = Resolve-BashPath
if ($null -eq $script:bashExe) {
    Write-Host '[FAIL] bash not found; conformance requires both implementations.'
    exit 1
}
if ($null -eq (Get-Command jq -ErrorAction SilentlyContinue)) {
    # Without jq the bash hooks exit 0 silently, which would make every
    # bash decision look like "allow" and the comparison meaningless.
    Write-Host '[FAIL] jq not found; the bash hooks would silently no-op.'
    exit 1
}

# ---- self-test mode ---------------------------------------------------------

if ($SelfTest) {
    Write-Host '=== conformance self-test: harness must DETECT divergence ==='
    $stubName = 'sd-selftest-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8) + '.sh'
    $stub = Join-Path ([System.IO.Path]::GetTempPath()) $stubName
    "#!/usr/bin/env bash`nexit 0`n" | Set-Content -LiteralPath $stub -NoNewline -Encoding ascii
    try {
        $caseDir = Join-Path $fixturesDir 'spec-gate' 'block-code-no-spec'
        $result = Invoke-ConformanceCase -HookName 'spec-gate' -CaseDir $caseDir `
            -BashHook $stub -PwshHook (Join-Path $repoRoot 'hooks' 'powershell' 'spec-gate.ps1')
    } finally {
        Remove-Item -LiteralPath $stub -Force -ErrorAction SilentlyContinue
    }
    if ($result.Pwsh -ne $result.Expected) {
        Write-Bad 'self-test precondition: real pwsh impl no longer matches the golden'
        Write-CaseDiff $result
        exit 1
    }
    if ($result.Match) {
        Write-Bad 'self-test: harness did NOT detect an always-allow bash stub'
        Write-CaseDiff $result
        exit 1
    }
    Write-Ok 'self-test: divergence in one implementation was detected'
    exit 0
}

# ---- main -------------------------------------------------------------------

foreach ($hookDir in (Get-ChildItem -LiteralPath $fixturesDir -Directory | Sort-Object Name)) {
    $hookName = $hookDir.Name
    if (-not $hookNormalizers.ContainsKey($hookName)) {
        Write-Bad "unknown fixture hook '$hookName' (no normalizer registered)"
        continue
    }
    $bashHook = Join-Path $repoRoot 'hooks' 'bash' "$hookName.sh"
    $pwshHook = Join-Path $repoRoot 'hooks' 'powershell' "$hookName.ps1"
    Write-Host ''
    Write-Host "=== $hookName ==="
    foreach ($caseDir in (Get-ChildItem -LiteralPath $hookDir.FullName -Directory | Sort-Object Name)) {
        $result = Invoke-ConformanceCase -HookName $hookName -CaseDir $caseDir.FullName `
            -BashHook $bashHook -PwshHook $pwshHook
        if ($result.Match) {
            Write-Ok $result.CaseName
        } else {
            Write-Bad $result.CaseName
            Write-CaseDiff $result
        }
    }
}

Write-Host ''
Write-Host "=== Summary: $($script:pass) passed, $($script:fail) failed ==="
if ($script:fail -gt 0) { exit 1 }
exit 0
