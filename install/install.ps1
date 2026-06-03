#requires -Version 5.1
<#
.SYNOPSIS
    Installer for specwright into a Claude Code base directory.

.DESCRIPTION
    Copies the specwright engine (commands, agents, PowerShell hooks,
    templates) under a base path (default $env:USERPROFILE\.claude) into the
    "<Prefix>/" subdirectory (default "sd/") of each engine folder:

        <BasePath>\commands\sd\
        <BasePath>\agents\sd\
        <BasePath>\hooks\sd\
        <BasePath>\templates\sd\

    Features:
      - Dry-run preview (-DryRun).
      - SHA256 content-hash comparison to skip identical files.
      - Timestamped backups (.bak.<yyyyMMdd-HHmmss>) before overwrite.
      - Interactive prompt on existing differing files: [y]es / [N]o / [a]ll.
      - -Force suppresses prompts and overwrites without asking.

    PURE ASCII. PowerShell 5.1 reads UTF-8 without BOM as Windows-1252;
    em-dash and other non-ASCII bytes cause cascading parse errors.

.PARAMETER BasePath
    Claude Code base directory. Default: $env:USERPROFILE\.claude.

.PARAMETER Prefix
    Namespace subfolder under each engine directory. Default: sd.

.PARAMETER DryRun
    Show the install plan without copying anything.

.PARAMETER Force
    Overwrite all existing files without prompting (backups still made).

.EXAMPLE
    .\install.ps1 -DryRun
    .\install.ps1
    .\install.ps1 -BasePath C:\temp\sd-test -Force
#>

param(
    [string]  $BasePath = (Join-Path $env:USERPROFILE '.claude'),
    [string]  $Prefix   = 'sd',
    [switch]  $DryRun,
    [switch]  $Force
)

$ErrorActionPreference = 'Stop'

# ---- helpers ---------------------------------------------------------------

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-Info  { param([string]$m) Write-Host "  $m" }
function Write-OK    { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Skip  { param([string]$m) Write-Host "  [SKIP] $m" -ForegroundColor DarkGray }
function Write-Plan  { param([string]$m) Write-Host "  [PLAN] $m" -ForegroundColor Yellow }
function Write-Bak   { param([string]$m) Write-Host "  [BAK]  $m" -ForegroundColor DarkYellow }
function Write-Warn  { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Fail  { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }

function Get-FileHashSafe {
    param([string]$Path)
    try {
        return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop).Hash
    } catch {
        return $null
    }
}

# ---- repo root detection ---------------------------------------------------

$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path -Path $scriptDir -Parent

Write-Section 'specwright installer'
Write-Info  "Script:    $PSCommandPath"
Write-Info  "Repo root: $repoRoot"
Write-Info  "Base path: $BasePath"
Write-Info  "Prefix:    $Prefix"
Write-Info  ("Mode:      " + ($(if ($DryRun) { 'DRY RUN (no changes)' } else { 'INSTALL' })) + ($(if ($Force) { ' [Force]' } else { '' })))

# ---- verify source layout --------------------------------------------------

Write-Section 'Verifying source layout'

$requiredDirs = @(
    @{ Path = 'commands';          Required = $true  },
    @{ Path = 'agents';            Required = $true  },
    @{ Path = 'hooks\powershell';  Required = $true  },
    @{ Path = 'templates';         Required = $true  },
    @{ Path = 'skills';            Required = $true  }
)

$missing = @()
foreach ($d in $requiredDirs) {
    $full = Join-Path $repoRoot $d.Path
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        Write-Fail $d.Path
        if ($d.Required) { $missing += $d.Path }
    } else {
        Write-OK $d.Path
    }
}

if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Fail "Missing required source directories. Are you running this from a clean specwright checkout?"
    exit 1
}

# ---- install plan ----------------------------------------------------------

# Each entry: source rel path, target rel path under BasePath, recursive copy
$plan = @(
    [pscustomobject]@{ Source = 'commands';         Target = "commands\$Prefix";   Recursive = $true  ; Executable = $false }
    [pscustomobject]@{ Source = 'agents';           Target = "agents\$Prefix";     Recursive = $true  ; Executable = $false }
    [pscustomobject]@{ Source = 'hooks\powershell'; Target = "hooks\$Prefix";      Recursive = $true  ; Executable = $false }
    [pscustomobject]@{ Source = 'templates';        Target = "templates\$Prefix";  Recursive = $true  ; Executable = $false }
    [pscustomobject]@{ Source = 'skills';           Target = "skills\$Prefix";     Recursive = $true  ; Executable = $false }
)

Write-Section 'Install plan'
foreach ($p in $plan) {
    Write-Plan ("$($p.Source)  ->  " + (Join-Path $BasePath $p.Target))
}

# ---- main copy loop --------------------------------------------------------

$installed = 0
$skippedSame = 0
$skippedDecline = 0
$backedUp = 0
$applyAll = $false  # set by 'a' answer on prompt

function Copy-OneFile {
    param(
        [string]$SourceFile,
        [string]$TargetFile
    )

    if ($DryRun) {
        if (Test-Path -LiteralPath $TargetFile) {
            $srcHash = Get-FileHashSafe -Path $SourceFile
            $dstHash = Get-FileHashSafe -Path $TargetFile
            if ($srcHash -and $dstHash -and ($srcHash -eq $dstHash)) {
                Write-Skip ("would skip (identical): " + $TargetFile)
                return 'same'
            } else {
                Write-Plan ("would overwrite (with backup): " + $TargetFile)
                return 'plan'
            }
        } else {
            Write-Plan ("would install: " + $TargetFile)
            return 'plan'
        }
    }

    # Real install
    if (Test-Path -LiteralPath $TargetFile) {
        $srcHash = Get-FileHashSafe -Path $SourceFile
        $dstHash = Get-FileHashSafe -Path $TargetFile

        if ($srcHash -and $dstHash -and ($srcHash -eq $dstHash)) {
            Write-Skip ("identical: " + $TargetFile)
            return 'same'
        }

        if (-not $Force -and -not $applyAll) {
            $rel = Split-Path -Leaf $TargetFile
            $ans = Read-Host -Prompt ("Overwrite '$rel' ? [y/N/a=all]")
            if ($ans -eq 'a') {
                $script:applyAll = $true
            } elseif ($ans -ne 'y') {
                Write-Skip ("declined: " + $TargetFile)
                return 'decline'
            }
        }

        # Backup before overwrite
        $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $bak = "$TargetFile.bak.$stamp"
        Copy-Item -LiteralPath $TargetFile -Destination $bak -Force
        Write-Bak $bak
        $script:backedUp = $script:backedUp + 1
    }

    $parent = Split-Path -Path $TargetFile -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $SourceFile -Destination $TargetFile -Force
    Write-OK $TargetFile
    return 'installed'
}

Write-Section 'Copying files'

foreach ($p in $plan) {
    $sourceRoot = Join-Path $repoRoot $p.Source
    $targetRoot = Join-Path $BasePath $p.Target

    if ($p.Recursive) {
        $files = Get-ChildItem -LiteralPath $sourceRoot -File -Recurse
    } else {
        $files = Get-ChildItem -LiteralPath $sourceRoot -File
    }

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($sourceRoot.Length).TrimStart('\','/')
        $target = Join-Path $targetRoot $rel

        $result = Copy-OneFile -SourceFile $f.FullName -TargetFile $target
        switch ($result) {
            'installed' { $installed++ }
            'same'      { $skippedSame++ }
            'decline'   { $skippedDecline++ }
            'plan'      { $installed++ }   # dry-run counts as planned
        }
    }
}

# ---- summary ---------------------------------------------------------------

Write-Section 'Summary'
if ($DryRun) {
    Write-Info ("Planned to install: $installed file(s)")
    Write-Info ("Would skip identical: $skippedSame")
    Write-Info ''
    Write-Info 'Run without -DryRun to apply.'
} else {
    Write-Info ("Installed:          $installed file(s)")
    Write-Info ("Skipped identical:  $skippedSame")
    Write-Info ("Declined:           $skippedDecline")
    Write-Info ("Backups created:    $backedUp")
}

Write-Section 'Next steps'
Write-Info '1. Verify install:'
Write-Info ("     Get-ChildItem '" + (Join-Path $BasePath "commands\$Prefix") + "'")
Write-Info ("     Get-ChildItem '" + (Join-Path $BasePath "agents\$Prefix") + "'")
Write-Info ("     Get-ChildItem '" + (Join-Path $BasePath "hooks\$Prefix") + "'")
Write-Info ("     Get-ChildItem '" + (Join-Path $BasePath "skills\$Prefix") + "'")
Write-Info ''
Write-Info '2. In a project directory:'
Write-Info '     claude'
Write-Info '     /sd:setup'
Write-Info ''
Write-Info '3. Restart Claude Code so hooks are picked up.'
Write-Info ''
Write-Info '4. Hook wiring (PowerShell - add to your project .claude/settings.json):'
Write-Info '     "hooks": {'
Write-Info '       "UserPromptSubmit": [{"matcher":"*","hooks":[{"type":"command",'
Write-Info ("         " + '"command":"powershell -NoProfile -ExecutionPolicy Bypass -File ' + '${HOME}/.claude/hooks/' + "$Prefix/prompt-router.ps1" + '","timeout":5}]}],')
Write-Info '       "PreToolUse": [{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command",'
Write-Info ("         " + '"command":"powershell -NoProfile -ExecutionPolicy Bypass -File ' + '${HOME}/.claude/hooks/' + "$Prefix/spec-gate.ps1" + '","timeout":5}]}],')
Write-Info '       "SubagentStop": [{"matcher":"*","hooks":[{"type":"command",'
Write-Info ("         " + '"command":"powershell -NoProfile -ExecutionPolicy Bypass -File ' + '${HOME}/.claude/hooks/' + "$Prefix/subagent-retro.ps1" + '","timeout":3}]}]')
Write-Info '     }'
Write-Info '   (Or run /sd:setup in your project - it generates settings.json automatically.)'

exit 0
