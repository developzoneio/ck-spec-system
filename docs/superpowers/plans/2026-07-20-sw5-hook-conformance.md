# SW-5 Cross-Platform Hook Conformance Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A golden-fixture harness proving the PowerShell and bash hook implementations produce equivalent decisions for the same stdin JSON, wired into CI so a behavioral divergence in only one implementation fails the build with a clear diff.

**Architecture:** Fixture cases live under `tests/hooks/fixtures/<hook>/<case>/`, each holding an `input.json` (hook stdin with a `{{CWD}}` placeholder), an optional `workspace/` tree copied into a fresh temp dir per implementation run, an optional `setup.json` (mtime backdating), and an `expected.json` golden. A single cross-platform PowerShell 7 runner (`tests/hooks/run-conformance.ps1`) pipes each fixture into BOTH implementations, normalizes what each did into a small decision object, and asserts bash == pwsh == golden. A `-SelfTest` switch proves the harness detects divergence by substituting a stub bash hook.

**Tech Stack:** PowerShell 7 (runner), bash + jq (bash hook impls), GitHub Actions (existing `ci.yml` matrix).

## Global Constraints

- All `.ps1` files are PURE ASCII (PowerShell 5.1 reads UTF-8-no-BOM as Windows-1252). Use `-`, `->`, `[OK]`, `[WARN]`, `[FAIL]`. Verify: `grep -nP "[^\x00-\x7F]" tests/hooks/*.ps1` must output nothing.
- PowerShell style: PascalCase functions, `$camelCase` variables, 4-space indent, explicit `param()` blocks.
- Hooks themselves are NOT modified by this work. **If a fixture exposes a real behavioral divergence between the bash and pwsh implementation of a hook, STOP: do not adjust the golden or the runner to paper over it. Report the divergence to the user - fixing it is a paired hook change with its own commit.**
- The runner is deliberately a SINGLE cross-platform script, not a bash/pwsh pair: conformance must run both implementations in one process, and a duplicated runner would itself be a drift risk. This exception to the pairs convention is documented in the script header.
- Every PR adds a line under `## [Unreleased]` in `CHANGELOG.md`.
- Do not use `Date.now`-style timestamps in fixture files; the only time-dependent fixture (stale retro) uses `setup.json` mtime backdating applied by the runner at execution time.
- Branch: work happens on `feature/optimize-workflow/v1` (already checked out). Commit style: imperative mood, 50-char subject.

## File Structure

```
tests/hooks/
  run-conformance.ps1                 # single cross-platform runner + -SelfTest
  fixtures/
    spec-gate/
      allow-doc-edit/                 # each case: input.json + expected.json
      allow-in-progress-spec/         #   + optional workspace/ tree
      block-code-no-spec/
      warn-code-no-spec/
      block-protected-path/
      allow-other-tool/
      allow-mode-off/
      allow-disabled/
    prompt-router/
      route-single-keyword/
      route-multi-workflow/
      ticket-with-spec-folder/
      ticket-without-spec-folder/
      silent-no-hints/
      silent-disabled/
      in-progress-surfaced/
    subagent-retro/
      remind-missing-retro/
      remind-stale-retro/             # only case with setup.json
      silent-done-only/
      silent-rca-only/
      silent-disabled/
.github/workflows/ci.yml              # + 2 steps (conformance, self-test)
CHANGELOG.md                          # + 1 line under [Unreleased]
CONTRIBUTING.md                       # + short paragraph on the suite
```

Normalized decision schemas (also the shape of every `expected.json`; property order matters because comparison is canonical-JSON string equality):

- spec-gate: `{"exitCode": 0, "decision": "allow"|"warn"|"block", "permissionDecision": "deny"}` - `permissionDecision` present only when `decision` is `block`.
- prompt-router: `{"exitCode": 0, "emitted": bool, "workflows": [], "ticketIds": [], "specFolders": [], "inProgress": []}` - all arrays sorted.
- subagent-retro: `{"exitCode": 0, "emitted": bool, "stale": [{"id": "...", "reason": "missing"|"stale"}]}` - sorted by id.

---

### Task 1: Runner core + spec-gate fixtures

**Files:**
- Create: `tests/hooks/run-conformance.ps1`
- Create: `tests/hooks/fixtures/spec-gate/<8 cases>/input.json`, `expected.json`, `workspace/...` (detailed below)

**Interfaces:**
- Produces: `run-conformance.ps1` with functions `Resolve-BashPath`, `New-CaseWorkspace -CaseDir`, `Invoke-HookProcess -Exe -ProcArgs -Payload`, `Invoke-HookImpl -Impl -HookScript -CaseDir`, `ConvertTo-SpecGateDecision -Run`, `Get-CanonicalJson -Obj`, `Invoke-ConformanceCase -HookName -CaseDir -BashHook -PwshHook`, and a `$hookNormalizers` hashtable keyed by hook name. Tasks 2-4 add entries/normalizers and reuse `Invoke-ConformanceCase` unchanged.
- Consumes: `hooks/bash/spec-gate.sh`, `hooks/powershell/spec-gate.ps1` (read-only).

- [ ] **Step 1: Create the spec-gate fixture cases (these are the failing tests)**

Shared workspace pieces (each case gets its own copy under its `workspace/`; content per case listed after).

`index-in-progress` variant of `.specs/index.md` (marker and ID on the same line):

```markdown
| ID | Type | Status | Title |
|---|---|---|---|
| FEAT-TEST-001 | feature | in-progress | Conformance fixture feature |
```

`index-header-only` variant of `.specs/index.md` ("in-progress" appears only in a header, so NO spec is in progress - guards the same-line-detection semantics):

```markdown
| ID | Type | Status (in-progress = active work) | Title |
|---|---|---|---|
| FEAT-DONE-002 | feature | done | Finished feature |
```

Config template for `workspace/.claude/project-config.json` (vary `mode` / `enabled` per case):

```json
{
  "spec": { "dir": ".specs", "indexFile": ".specs/index.md" },
  "paths": { "protected": [".specs/constitution.md"] },
  "hooks": { "specGate": { "enabled": true, "mode": "block" } }
}
```

The 8 cases (create each dir under `tests/hooks/fixtures/spec-gate/`):

**allow-doc-edit** - docs are allow-listed even in block mode with no spec.
- `input.json`: `{"tool_name":"Edit","cwd":"{{CWD}}","tool_input":{"file_path":"{{CWD}}/docs/guide.md"}}`
- `workspace/`: config with `"mode": "block"`; index-header-only.
- `expected.json`: `{"exitCode":0,"decision":"allow"}`

**allow-in-progress-spec** - code edit passes when a spec is in progress.
- `input.json`: `{"tool_name":"Edit","cwd":"{{CWD}}","tool_input":{"file_path":"{{CWD}}/src/Foo.py"}}`
- `workspace/`: config with `"mode": "block"`; index-in-progress.
- `expected.json`: `{"exitCode":0,"decision":"allow"}`

**block-code-no-spec** - code edit blocked in block mode without a spec.
- `input.json`: `{"tool_name":"Edit","cwd":"{{CWD}}","tool_input":{"file_path":"{{CWD}}/src/Foo.py"}}`
- `workspace/`: config with `"mode": "block"`; index-header-only.
- `expected.json`: `{"exitCode":0,"decision":"block","permissionDecision":"deny"}`

**warn-code-no-spec** - same edit only warns in warn mode.
- `input.json`: same as block-code-no-spec.
- `workspace/`: config with `"mode": "warn"`; index-header-only.
- `expected.json`: `{"exitCode":0,"decision":"warn"}`

**block-protected-path** - protected beats the `.specs/` allow-list (rule ordering).
- `input.json`: `{"tool_name":"Edit","cwd":"{{CWD}}","tool_input":{"file_path":"{{CWD}}/.specs/constitution.md"}}`
- `workspace/`: config with `"mode": "block"`; index-in-progress.
- `expected.json`: `{"exitCode":0,"decision":"block","permissionDecision":"deny"}`

**allow-other-tool** - non-edit tools are ignored.
- `input.json`: `{"tool_name":"Read","cwd":"{{CWD}}","tool_input":{"file_path":"{{CWD}}/src/Foo.py"}}`
- `workspace/`: config with `"mode": "block"`; index-header-only.
- `expected.json`: `{"exitCode":0,"decision":"allow"}`

**allow-mode-off** - mode=off short-circuits everything.
- `input.json`: same as block-code-no-spec.
- `workspace/`: config with `"mode": "off"`; index-header-only.
- `expected.json`: `{"exitCode":0,"decision":"allow"}`

**allow-disabled** - enabled=false short-circuits everything.
- `input.json`: same as block-code-no-spec.
- `workspace/`: config with `"enabled": false, "mode": "block"`; index-header-only.
- `expected.json`: `{"exitCode":0,"decision":"allow"}`

- [ ] **Step 2: Verify the suite fails (runner does not exist yet)**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1`
Expected: error - file not found. (This is the red state.)

- [ ] **Step 3: Write the runner**

Create `tests/hooks/run-conformance.ps1` with exactly this content:

```powershell
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
    $stdoutTrim = $Run.Stdout.Trim()
    if ($stdoutTrim.Length -gt 0) {
        try {
            $obj = $stdoutTrim | ConvertFrom-Json
            if ($obj.decision) { $decision = [string]$obj.decision }
            if ($obj.hookSpecificOutput -and $obj.hookSpecificOutput.permissionDecision) {
                $permission = [string]$obj.hookSpecificOutput.permissionDecision
            }
        } catch {
            $decision = 'unparseable-stdout'
        }
    } elseif ($Run.Stderr.Contains('[WARN]')) {
        $decision = 'warn'
    }
    $out = [ordered]@{ exitCode = $Run.ExitCode; decision = $decision }
    if ($null -ne $permission) { $out.permissionDecision = $permission }
    return [pscustomobject]$out
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
    }
}

function ConvertTo-SubagentRetroDecision {
    param($Run)
    $stale = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($Run.Stdout -split "`n")) {
        if ($line -match '^\s+-\s+([A-Za-z0-9_\-]+): 05-retro\.md (missing|last touched)') {
            $reason = if ($Matches[2] -eq 'missing') { 'missing' } else { 'stale' }
            $stale.Add([pscustomobject][ordered]@{ id = $Matches[1]; reason = $reason })
        }
    }
    return [pscustomobject][ordered]@{
        exitCode = $Run.ExitCode
        emitted  = $Run.Stdout.Contains('<retro-reminder>')
        stale    = @($stale | Sort-Object -Property id)
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
```

- [ ] **Step 4: Run the spec-gate cases and verify green**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1`
Expected: `=== spec-gate ===` section with 8 `[OK]` lines, summary `8 passed, 0 failed`, exit 0. (prompt-router / subagent-retro fixture dirs do not exist yet, so only spec-gate runs.)

If a case fails with bash != pwsh: STOP per Global Constraints - that is a real divergence; report it.

- [ ] **Step 5: ASCII check**

Run: `grep -nP "[^\x00-\x7F]" tests/hooks/run-conformance.ps1`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add tests/hooks/
git commit -m "Add hook conformance runner + spec-gate fixtures"
```

---

### Task 2: prompt-router fixtures

**Files:**
- Create: `tests/hooks/fixtures/prompt-router/<7 cases>/input.json`, `expected.json`, `workspace/...`

**Interfaces:**
- Consumes: `Invoke-ConformanceCase` and `ConvertTo-PromptRouterDecision` from Task 1 (already registered in `$hookNormalizers`; no runner change needed).
- Produces: 7 fixture cases; the runner discovers them by directory name.

- [ ] **Step 1: Create the prompt-router fixture cases**

All `input.json` files have shape `{"prompt":"...","cwd":"{{CWD}}"}`. Deliberately do NOT write `workflow.keywords` into any config - these cases conformance-test the DEFAULT keyword lists hardcoded in both implementations, which is exactly where silent drift would hide.

Config for cases that need one (`workspace/.claude/project-config.json`):

```json
{
  "spec": { "dir": ".specs", "indexFile": ".specs/index.md" },
  "ticket": { "pattern": "^[A-Z]+-[0-9]+$" },
  "hooks": { "userPromptRouter": { "enabled": true } }
}
```

Reuse the two index variants from Task 1 (in-progress / header-only) as noted per case. Prompts below are chosen so no unintended keyword substring matches (e.g. "hello there" and "continue" contain no default keyword).

**route-single-keyword**
- `input.json`: `{"prompt":"please fix this bug","cwd":"{{CWD}}"}`
- `workspace/`: config; index-header-only.
- `expected.json`: `{"exitCode":0,"emitted":true,"workflows":["bug"],"ticketIds":[],"specFolders":[],"inProgress":[]}`

**route-multi-workflow**
- `input.json`: `{"prompt":"implement this feature, performance is slow","cwd":"{{CWD}}"}`
- `workspace/`: config; index-header-only.
- `expected.json`: `{"exitCode":0,"emitted":true,"workflows":["feature","perf"],"ticketIds":[],"specFolders":[],"inProgress":[]}`

**ticket-with-spec-folder**
- `input.json`: `{"prompt":"continue INV-2501","cwd":"{{CWD}}"}`
- `workspace/`: config; index-header-only; plus empty file `workspace/.specs/FEAT-INV-2501-payment/.gitkeep` (keeps the folder in git).
- `expected.json`: `{"exitCode":0,"emitted":true,"workflows":[],"ticketIds":["INV-2501"],"specFolders":["FEAT-INV-2501-payment"],"inProgress":[]}`

**ticket-without-spec-folder**
- `input.json`: `{"prompt":"continue INV-9999","cwd":"{{CWD}}"}`
- `workspace/`: config; index-header-only.
- `expected.json`: `{"exitCode":0,"emitted":true,"workflows":[],"ticketIds":["INV-9999"],"specFolders":[],"inProgress":[]}`

**silent-no-hints**
- `input.json`: `{"prompt":"hello there","cwd":"{{CWD}}"}`
- `workspace/`: config; index-header-only.
- `expected.json`: `{"exitCode":0,"emitted":false,"workflows":[],"ticketIds":[],"specFolders":[],"inProgress":[]}`

**silent-disabled**
- `input.json`: `{"prompt":"please fix this bug","cwd":"{{CWD}}"}`
- `workspace/`: config but with `"userPromptRouter": { "enabled": false }`; index-header-only.
- `expected.json`: `{"exitCode":0,"emitted":false,"workflows":[],"ticketIds":[],"specFolders":[],"inProgress":[]}`

**in-progress-surfaced**
- `input.json`: `{"prompt":"hello there","cwd":"{{CWD}}"}`
- `workspace/`: config; index-in-progress (FEAT-TEST-001).
- `expected.json`: `{"exitCode":0,"emitted":true,"workflows":[],"ticketIds":[],"specFolders":[],"inProgress":["FEAT-TEST-001"]}`

- [ ] **Step 2: Run and verify green**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1`
Expected: spec-gate 8 [OK] + `=== prompt-router ===` with 7 [OK], summary `15 passed, 0 failed`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add tests/hooks/fixtures/prompt-router/
git commit -m "Add prompt-router conformance fixtures"
```

---

### Task 3: subagent-retro fixtures (incl. deterministic stale-mtime case)

**Files:**
- Create: `tests/hooks/fixtures/subagent-retro/<5 cases>/input.json`, `expected.json`, `workspace/...`, one `setup.json`

**Interfaces:**
- Consumes: `Invoke-ConformanceCase`, `ConvertTo-SubagentRetroDecision`, and the `setup.json` mtime support in `New-CaseWorkspace` from Task 1.
- Produces: 5 fixture cases.

- [ ] **Step 1: Pre-check the stale comparison in both implementations**

Run: `grep -n "age" hooks/bash/subagent-retro.sh | grep -i thresh` and open the matching region of `hooks/powershell/subagent-retro.ps1`.
Expected: both treat `age >= threshold` the same way (bash uses `(( age >= threshold_secs ))`). If the PowerShell side uses a strictly-greater comparison, that is a REAL divergence - STOP and report it per Global Constraints. (The stale fixture below uses age 120 min vs threshold 30 min, so it stays deterministic either way; this check is about knowing, not about making the fixture pass.)

- [ ] **Step 2: Create the subagent-retro fixture cases**

All `input.json` files: `{"cwd":"{{CWD}}","session_id":"conformance-fixture"}`.

Config template (`workspace/.claude/project-config.json`; vary per case):

```json
{
  "spec": { "dir": ".specs", "indexFile": ".specs/index.md" },
  "hooks": { "subagentRetro": { "enabled": true, "retroStaleMinutes": 30, "debounceMinutes": 10 } }
}
```

Fresh temp workspaces per implementation mean no debounce state exists at run time, so debounce never suppresses these cases (per-impl debounce behavior stays covered by scripts/smoke-hooks).

**remind-missing-retro** - missing retro is reported; RCA row in the same index is skipped.
- `workspace/`: config; `.specs/index.md`:

```markdown
| ID | Type | Status | Title |
|---|---|---|---|
| FEAT-TEST-001 | feature | in-progress | Conformance fixture feature |
| RCA-2026-001 | rca | in-progress | Incident writeup |
```

- No `.specs/FEAT-TEST-001/` folder (retro missing).
- `expected.json`: `{"exitCode":0,"emitted":true,"stale":[{"id":"FEAT-TEST-001","reason":"missing"}]}`

**remind-stale-retro** - existing retro older than the threshold is reported as stale.
- `workspace/`: config; index with only the FEAT-TEST-001 in-progress row (first three lines of the index above); file `workspace/.specs/FEAT-TEST-001/05-retro.md` containing `# Retro`.
- `setup.json`:

```json
{ "touch": [ { "path": ".specs/FEAT-TEST-001/05-retro.md", "ageMinutes": 120 } ] }
```

- `expected.json`: `{"exitCode":0,"emitted":true,"stale":[{"id":"FEAT-TEST-001","reason":"stale"}]}`

**silent-done-only** - nothing in progress, hook stays silent.
- `workspace/`: config; index-header-only (from Task 1).
- `expected.json`: `{"exitCode":0,"emitted":false,"stale":[]}`

**silent-rca-only** - an in-progress RCA alone never triggers a reminder.
- `workspace/`: config; `.specs/index.md`:

```markdown
| ID | Type | Status | Title |
|---|---|---|---|
| RCA-2026-001 | rca | in-progress | Incident writeup |
```

- `expected.json`: `{"exitCode":0,"emitted":false,"stale":[]}`

**silent-disabled** - enabled=false short-circuits.
- `workspace/`: config with `"enabled": false`; index with the FEAT-TEST-001 in-progress row and no retro file.
- `expected.json`: `{"exitCode":0,"emitted":false,"stale":[]}`

- [ ] **Step 3: Run and verify green**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1`
Expected: 8 + 7 + 5 = `20 passed, 0 failed`, exit 0. Run it TWICE to confirm the stale-mtime case is deterministic.

- [ ] **Step 4: Commit**

```bash
git add tests/hooks/fixtures/subagent-retro/
git commit -m "Add subagent-retro conformance fixtures"
```

---

### Task 4: Self-test proves divergence detection

**Files:**
- Modify: none (the `-SelfTest` branch already shipped inside `run-conformance.ps1` in Task 1; this task VERIFIES it and fixes it if broken).

**Interfaces:**
- Consumes: `-SelfTest` switch; fixture `spec-gate/block-code-no-spec`.

- [ ] **Step 1: Run the self-test**

Run: `pwsh -NoProfile -File tests/hooks/run-conformance.ps1 -SelfTest`
Expected output ends with `[OK]   self-test: divergence in one implementation was detected`, exit 0.

- [ ] **Step 2: Negative check of the self-test itself**

Temporarily run the plain suite again (`pwsh -NoProfile -File tests/hooks/run-conformance.ps1`) and confirm it still exits 0 - i.e. the self-test's stub did not leak state into normal runs.

- [ ] **Step 3: Commit (only if fixes were needed)**

```bash
git add tests/hooks/run-conformance.ps1
git commit -m "Fix conformance self-test divergence detection"
```

---

### Task 5: CI wiring + CHANGELOG + docs

**Files:**
- Modify: `.github/workflows/ci.yml` (after the "Docs-consistency self-test (PowerShell)" step, before the round-trip steps)
- Modify: `CHANGELOG.md` (one line under `## [Unreleased]`)
- Modify: `CONTRIBUTING.md` (short paragraph near the smoke-test/validator description)

**Interfaces:**
- Consumes: `tests/hooks/run-conformance.ps1` from Tasks 1-4.

- [ ] **Step 1: Add the CI steps**

Insert into `.github/workflows/ci.yml` after the `Docs-consistency self-test (PowerShell)` step:

```yaml
      # --- Cross-impl hook conformance: pipe each golden fixture into BOTH
      # implementations (bash + pwsh); normalized decisions must match the
      # golden and each other. Runs under pwsh on every OS: ubuntu/macos get
      # bash natively + pwsh preinstalled, windows gets pwsh natively + Git
      # Bash. A divergence in only one impl fails with a three-way diff ----
      - name: Hook conformance (bash vs PowerShell)
        shell: pwsh
        run: ./tests/hooks/run-conformance.ps1

      - name: Hook conformance self-test (divergence detection)
        shell: pwsh
        run: ./tests/hooks/run-conformance.ps1 -SelfTest
```

No `if:` condition - all three matrix OSes run both implementations (that is the point of the suite).

- [ ] **Step 2: CHANGELOG entry**

Read `CHANGELOG.md`, find `## [Unreleased]`, and add under its `### Added` (create the subsection if absent, matching the file's existing style):

```markdown
- Cross-implementation hook conformance suite (`tests/hooks/`): golden fixtures are piped into
  both the bash and PowerShell implementation of every hook and the normalized decisions must
  match; wired into CI on all matrix platforms with a self-test proving divergence detection (E4).
```

- [ ] **Step 3: CONTRIBUTING paragraph**

In `CONTRIBUTING.md`, after the paragraph describing `scripts/selftest-docs.{ps1,sh}` (around line 87), add:

```markdown
`tests/hooks/run-conformance.ps1` (single cross-platform pwsh script by design - it must run BOTH
hook implementations in one process, so a bash twin would itself be a drift risk) pipes every
golden fixture under `tests/hooks/fixtures/` into the bash and PowerShell implementation of each
hook and fails if their normalized decisions diverge from each other or from the golden. Add a
fixture case whenever you add hook behavior; `-SelfTest` proves the harness still detects
divergence.
```

- [ ] **Step 4: Run the full local validation battery**

Run, in order, and require all green:

```bash
bash scripts/validate.sh
bash scripts/smoke-hooks.sh
bash scripts/selftest-docs.sh
pwsh -NoProfile -File tests/hooks/run-conformance.ps1
pwsh -NoProfile -File tests/hooks/run-conformance.ps1 -SelfTest
```

Also: `pwsh -NoProfile -File scripts/validate.ps1` (Windows-native run of the validator).
Expected: every command exits 0. If `validate` flags the new CONTRIBUTING text as an undeclared inventory claim, either register a docClaims entry or reword to avoid the claim pattern - do not weaken the validator.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml CHANGELOG.md CONTRIBUTING.md
git commit -m "Wire hook conformance suite into CI"
```

---

## Verification (whole feature)

1. `pwsh -NoProfile -File tests/hooks/run-conformance.ps1` -> 20 passed, exit 0.
2. `pwsh -NoProfile -File tests/hooks/run-conformance.ps1 -SelfTest` -> detection [OK], exit 0.
3. Acceptance criterion from SW-5 ("a behavioral divergence in only one impl fails the suite with a clear diff"): demonstrated by the self-test AND manually - edit a scratch copy of one bash hook to flip a decision, run the suite, observe the three-way diff, restore.
4. `git push` and confirm the GitHub Actions matrix (ubuntu, windows, macos) runs the two new steps green.
