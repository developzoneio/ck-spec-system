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

    try {
        return (Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        return $defaults
    }
}

function ConvertTo-RelativePath {
    param(
        [string]$Cwd,
        [string]$FilePath
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $null }
    try {
        $full = [System.IO.Path]::GetFullPath($FilePath)
        $base = [System.IO.Path]::GetFullPath($Cwd)
        if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $full.Substring($base.Length).TrimStart('\','/')
            return $rel.Replace('\','/')
        }
        return $FilePath.Replace('\','/')
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
    $name = [System.IO.Path]::GetFileName($RelPath)
    if ($name -match '^(README|CHANGELOG|CONTRIBUTING|LICENSE|NOTICE|AUTHORS)(\.[A-Za-z]+)?$') { return $true }

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
