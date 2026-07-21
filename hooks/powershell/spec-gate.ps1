#requires -Version 5.1
<#
.SYNOPSIS
    specwright: PreToolUse hook - spec-gate.

.DESCRIPTION
    Reads Claude Code hook JSON from stdin. If the tool is Edit / Write /
    MultiEdit, the hook decides whether the edit is allowed:
      - Edits to paths listed under paths.protected -> ALWAYS blocked.
      - Edits to allow-listed paths (.specs/, .claude/, tests/, *.md, *.json,
        *.yaml, README, CHANGELOG, LICENSE) -> always allowed.
      - Edits to code files (cs, ts, py, rs, go, java, kt, rb, php, swift,
        cpp, c, h, hpp, scala, js, jsx, tsx, vue, sql) -> require an
        in-progress spec recorded in .specs/index.md.
          mode=block -> output block JSON to stdout (see Write-BlockDecision).
          mode=warn  -> write a warning to stderr; allow the edit.
          mode=off   -> always allow.

    Output schema (dual-format for forward + backward compatibility):
      New:    hookSpecificOutput.permissionDecision = "deny"   (CLI >= schema v2)
      Legacy: decision = "block"                               (CLI < schema v2)
    Both are emitted in the same JSON object so either CLI generation can act.

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
        paths = [pscustomobject]@{
            protected = @('.specs/constitution.md','.specs/index.md','LICENSE')
        }
        hooks = [pscustomobject]@{
            specGate = [pscustomobject]@{ enabled = $true; mode = 'warn' }
        }
    }

    $cfgPath = Join-Path $Cwd '.claude/project-config.json'
    if (-not (Test-Path -LiteralPath $cfgPath)) { return $defaults }

    # -ErrorAction Stop is required: the script-wide SilentlyContinue preference
    # would otherwise make a malformed config a NON-terminating error, so the
    # catch never fires and the function returns $null instead of the defaults -
    # silently dropping the built-in protected paths.
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

function ConvertTo-RelativePath {
    param(
        [string]$Cwd,
        [string]$FilePath
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $null }
    try {
        # If FilePath is not rooted (no leading '/' and no drive-letter prefix
        # such as 'C:'), it is already relative to Cwd by construction, so
        # collapsing its own dot segments directly yields the correct
        # relative-to-Cwd path. Joining it onto Cwd and calling
        # [System.IO.Path]::GetFullPath would resolve against THIS SCRIPT
        # PROCESS's own working directory instead of the hook payload's Cwd -
        # that mismatch was the root cause of the
        # 'src/../.specs/constitution.md' traversal bypass, since the
        # resulting absolute path never started with $base and fell through
        # to the raw-path fallback below. This mirrors spec-gate.sh's
        # normalize_rel first branch exactly.
        if (-not (Test-IsRootedPath $FilePath)) {
            return ConvertTo-CollapsedPath -Path ($FilePath.Replace('\','/'))
        }

        # Collapse '.'/'..' BEFORE the prefix strip, so a path that traverses
        # through a directory and back (e.g. cwd/src/../.specs/x) is compared
        # against base in its fully-resolved form, not its literal typed form.
        # A trailing separator collapses away here too (see
        # ConvertTo-CollapsedPath), which fixes the second bypass: without
        # this, [System.IO.Path]::GetExtension on a path ending in '/' or '\'
        # returns "" and the path escapes both the protected-path equality
        # check and the code-file extension check.
        $fpRaw = $FilePath.Replace('\','/')
        $baseNorm = $Cwd.Replace('\','/')
        $fpNorm = ConvertTo-CollapsedPath -Path $fpRaw
        $baseCollapsed = ConvertTo-CollapsedPath -Path $baseNorm

        if ($fpNorm.StartsWith($baseCollapsed, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $fpNorm.Substring($baseCollapsed.Length).TrimStart('/')
            return $rel
        }
        # Resolving FilePath lands outside Cwd entirely (e.g. enough leading
        # '..' to escape the workspace) - fall back to the raw, un-collapsed
        # path, same as spec-gate.sh's normalize_rel fallback branch.
        return $fpRaw
    } catch {
        return $FilePath.Replace('\','/')
    }
}

function Test-IsProtected {
    param(
        [string]$RelPath,
        [string[]]$Protected
    )
    if (-not $Protected) { return $false }
    foreach ($p in $Protected) {
        $norm = $p.Replace('\','/')
        if ([string]::Equals($RelPath, $norm, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-IsAllowListed {
    param([string]$RelPath)
    $allowDirs = @('.specs/', '.claude/', 'tests/', 'test/', 'docs/', 'spec/')
    foreach ($d in $allowDirs) {
        if ($RelPath.StartsWith($d, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    # Only EXTENSION-LESS project files are allow-listed by name; anything with
    # an extension is decided by the extension rules below. The old pattern
    # accepted one optional extension, which allow-listed README.py outright and
    # (having no multi-dot form) split hairs over README.old.py. Neither should
    # bypass the gate - they are source files whatever they are called.
    $name = [System.IO.Path]::GetFileName($RelPath)
    if ($name -match '^(README|CHANGELOG|CONTRIBUTING|LICENSE|NOTICE|AUTHORS)$') { return $true }

    $ext = [System.IO.Path]::GetExtension($RelPath).ToLowerInvariant()
    $docExts = @('.md','.markdown','.txt','.rst','.adoc','.json','.yaml','.yml','.toml','.ini','.env','.example')
    if ($docExts -contains $ext) { return $true }
    return $false
}

function Test-IsCodeFile {
    param([string]$RelPath)
    $ext = [System.IO.Path]::GetExtension($RelPath).ToLowerInvariant()
    $codeExts = @(
        '.cs','.fs','.vb',
        '.ts','.tsx','.js','.jsx','.mjs','.cjs','.vue','.svelte',
        '.py','.pyi',
        '.rs',
        '.go',
        '.java','.kt','.kts','.scala',
        '.rb','.php',
        '.swift','.m','.mm',
        '.c','.h','.cpp','.cxx','.cc','.hpp','.hxx',
        '.sql','.ps1','.sh','.bash','.zsh',
        '.razor','.cshtml'
    )
    return ($codeExts -contains $ext)
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
        if ($line -match 'in-progress' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
            $result.Add($Matches[0]) | Out-Null
        }
    }
    return $result
}

function Get-DoneTransitionIds {
    param(
        [object]$HookInput,
        [string]$IndexPath
    )
    # IDs that the pending edit marks as done but that the on-disk index does
    # not yet record as done. Fragments are the tool-specific NEW content.
    # FEAT- only (see Rule 0 comment below): the id extraction here is
    # DELIBERATELY narrower than Rule 3's in-progress scan.
    $fragments = New-Object System.Collections.Generic.List[string]
    try {
        $tool = $HookInput.tool_name
        if ($tool -eq 'Edit') {
            if ($HookInput.tool_input.new_string) {
                $fragments.Add([string]$HookInput.tool_input.new_string) | Out-Null
            }
        } elseif ($tool -eq 'Write') {
            if ($HookInput.tool_input.content) {
                $fragments.Add([string]$HookInput.tool_input.content) | Out-Null
            }
        } elseif ($tool -eq 'MultiEdit') {
            foreach ($e in @($HookInput.tool_input.edits)) {
                if ($e.new_string) { $fragments.Add([string]$e.new_string) | Out-Null }
            }
        }
    } catch { }

    $alreadyDone = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $IndexPath) {
        try {
            foreach ($line in (Get-Content -LiteralPath $IndexPath -Encoding UTF8 -ErrorAction Stop)) {
                if ($line -match '\|\s*done\s*\|' -and $line -match 'FEAT-[A-Za-z0-9_\-]+') {
                    [void]$alreadyDone.Add($Matches[0])
                }
            }
        } catch { }
    }

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($frag in $fragments) {
        foreach ($line in ($frag -split "`n")) {
            if ($line -match '\|\s*done\s*\|' -and $line -match 'FEAT-[A-Za-z0-9_\-]+') {
                $id = $Matches[0]
                if (-not $alreadyDone.Contains($id) -and -not $result.Contains($id)) {
                    $result.Add($id) | Out-Null
                }
            }
        }
    }
    return ,$result
}

function Test-VerifyArtifactPass {
    param(
        [string]$Cwd,
        [string]$SpecDir,
        [string]$SpecId
    )
    $artifact = Join-Path $Cwd (Join-Path $SpecDir (Join-Path $SpecId '06-verify.md'))
    if (-not (Test-Path -LiteralPath $artifact)) { return $false }
    try {
        $content = Get-Content -LiteralPath $artifact -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
        return $false
    }
    return ($content -match '(?im)^result:\s*pass\s*$')
}

function Write-BlockDecision {
    param([string]$Reason)
    # Dual-format: new hookSpecificOutput schema + legacy decision field.
    # The CLI reads whichever field it understands; both are harmless to the other.
    $obj = [pscustomobject]@{
        decision           = 'block'
        reason             = $Reason
        hookSpecificOutput = [pscustomobject]@{
            permissionDecision = 'deny'
            reason             = $Reason
        }
    }
    [Console]::Out.WriteLine(($obj | ConvertTo-Json -Compress))
}

# ---- main ----

$hookInput = Read-StdinJson
if ($null -eq $hookInput) { exit 0 }

$toolName = $hookInput.tool_name
if ($toolName -ne 'Edit' -and $toolName -ne 'Write' -and $toolName -ne 'MultiEdit') { exit 0 }

$cwd = $hookInput.cwd
if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = (Get-Location).Path }

$config = Get-ProjectConfig -Cwd $cwd

# Hook globally disabled?
try {
    if ($null -ne $config.hooks -and $null -ne $config.hooks.specGate -and -not $config.hooks.specGate.enabled) {
        exit 0
    }
} catch { }

$mode = 'warn'
try { if ($config.hooks.specGate.mode) { $mode = [string]$config.hooks.specGate.mode } } catch { }
if ($mode -eq 'off') { exit 0 }

$filePath = $hookInput.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

$rel = ConvertTo-RelativePath -Cwd $cwd -FilePath $filePath
if ([string]::IsNullOrWhiteSpace($rel)) { exit 0 }

# Rule 0: verify gate on the spec index. A row transitioning to done requires
# a passing /sd:verify artifact; a verified close-out is allowed through the
# protected-path rule. Any other direct index edit falls through to Rule 1.
#
# Scope: FEAT- rows only. Bug/refactor/perf/rca workflows do not produce
# 02-tasks.md and never run /sd:verify, so gating them here would hard-STOP
# their close-out at VF002 with no way through. Non-FEAT rows fall through to
# the unconditional Rule 1 protected-path block, exactly as before this
# gate existed - until their workflows integrate /sd:verify (follow-up spec).
#
# Bundled-edit limitation: when every newly-done FEAT row in the pending edit
# has a passing artifact, the WHOLE edit is allowed - including any unrelated
# row changes bundled into the same Write/Edit/MultiEdit. This hook inspects
# only the done-transition lines, not a full diff, so a bundled edit could in
# principle piggyback an unrelated change. Accepted limitation (hook-scale
# diff inspection is out of scope); the /sd:spec registry commands are the
# semantic guard for anything this coarse check cannot see.
$verifyGateOn = $true
try {
    # Type-strict: only a literal JSON boolean false disables the gate. Plain
    # `-eq $false` would also match the JSON STRING "false" (PowerShell coerces
    # a string to bool via -eq's LHS type), diverging from jq's `== false`
    # in spec-gate.sh, which is type-strict and leaves the gate ON for a
    # string value. -is [bool] keeps this branch aligned with jq.
    if (($config.hooks.specGate.verifyGate -is [bool]) -and (-not $config.hooks.specGate.verifyGate)) {
        $verifyGateOn = $false
    }
} catch { }

$indexRel = '.specs/index.md'
try { if ($config.spec.indexFile) { $indexRel = ([string]$config.spec.indexFile).Replace('\','/') } } catch { }
$specDir = '.specs'
try { if ($config.spec.dir) { $specDir = [string]$config.spec.dir } } catch { }

if ($verifyGateOn -and [string]::Equals($rel, $indexRel, [System.StringComparison]::OrdinalIgnoreCase)) {
    $indexAbs = Join-Path $cwd $indexRel
    $doneIds = Get-DoneTransitionIds -HookInput $hookInput -IndexPath $indexAbs
    if ($doneIds.Count -gt 0) {
        $missing = New-Object System.Collections.Generic.List[string]
        foreach ($id in $doneIds) {
            if (-not (Test-VerifyArtifactPass -Cwd $cwd -SpecDir $specDir -SpecId $id)) {
                $missing.Add($id) | Out-Null
            }
        }
        if ($missing.Count -gt 0) {
            # Ordinal sort (PS 5.1-safe), not culture-aware Sort-Object - matches
            # `LC_ALL=C sort -u` in spec-gate.sh so both implementations order
            # a multi-ID missing list identically regardless of host locale.
            $missingArr = @($missing)
            [Array]::Sort($missingArr, [System.StringComparer]::Ordinal)
            $ids = $missingArr -join ', '
            Write-BlockDecision "spec-gate: index row(s) [$ids] -> done but no passing /sd:verify artifact. Run /sd:verify <spec-ID>; close-out is allowed only after $specDir/<ID>/06-verify.md records 'result: pass'."
            exit 0
        }
        # Every transitioning spec has a passing artifact - allow the close-out.
        exit 0
    }
}

# Rule 1: protected paths -> always block
$protected = @()
try { if ($config.paths.protected) { $protected = @($config.paths.protected) } } catch { }
if (Test-IsProtected -RelPath $rel -Protected $protected) {
    Write-BlockDecision "spec-gate: '$rel' is listed under paths.protected in .claude/project-config.json. Update via /sd:refactor or an ADR; never edit directly."
    exit 0
}

# Rule 2: allow-listed paths -> always allow
if (Test-IsAllowListed -RelPath $rel) { exit 0 }

# Rule 3: code file -> require in-progress spec
if (Test-IsCodeFile -RelPath $rel) {
    $indexFile = if ($config.spec.indexFile) { Join-Path $cwd $config.spec.indexFile } else { Join-Path $cwd '.specs/index.md' }
    $inProgress = Get-InProgressSpecs -IndexPath $indexFile
    if ($inProgress.Count -eq 0) {
        $msg = "spec-gate: editing code file '$rel' but no in-progress spec is recorded in .specs/index.md. Run /sd:feature, /sd:bug, /sd:refactor, or /sd:perf first to create a spec, or set hooks.specGate.mode='off' in .claude/project-config.json to disable."
        if ($mode -eq 'block') {
            Write-BlockDecision $msg
            exit 0
        } else {
            [Console]::Error.WriteLine("[WARN] $msg")
            exit 0
        }
    }
}

exit 0
