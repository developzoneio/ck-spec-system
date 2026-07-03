# BUG: spec-gate in-progress detection diverges — bash is file-wide, PowerShell is same-line

- Priority: P1
- Area: `hooks/bash/spec-gate.sh` (the outlier), `hooks/powershell/spec-gate.ps1` (reference)
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/spec-gate-same-line-parity`

## Problem

The gate decision — whether a code edit is allowed — is computed differently per OS.

Bash uses two INDEPENDENT file-wide greps (`hooks/bash/spec-gate.sh:171-176`):

```bash
if grep -q 'in-progress' "${index_path}" 2>/dev/null && \
   grep -q -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' "${index_path}" 2>/dev/null; then
    has_in_progress=1
```

PowerShell requires BOTH the word `in-progress` and a spec ID on the SAME line
(`hooks/powershell/spec-gate.ps1:145`):

```powershell
if ($line -match 'in-progress' -and $line -match '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_\-]+') {
```

Failure scenario: an `index.md` where the string `in-progress` appears only in a legend/header
line and all spec IDs sit on `done` rows. Bash ALLOWS the edit; PowerShell WARNS/BLOCKS. The
same repo passes the gate on Linux and fails it on Windows.

Same-line is the intended semantics: the bash prompt-router already uses a same-line pipeline
(`hooks/bash/prompt-router.sh:133-141` extracts IDs from lines that contain `in-progress`).

## Fix

Rework `spec-gate.sh` to use same-line logic, mirroring the prompt-router bash approach:

```bash
if grep -E 'in-progress' "${index_path}" 2>/dev/null \
     | grep -q -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+'; then
    has_in_progress=1
fi
```

Keep the defensive posture: any failure path must still `exit 0`.

## Acceptance criteria

1. Fixture A (`in-progress` in a header line, IDs only on `done` rows): both platforms treat
   it as NO in-progress spec.
2. Fixture B (a real `| FEAT-1 | ... | in-progress |` row): both platforms treat it as
   in-progress present, edit allowed.
3. `bash -n hooks/bash/spec-gate.sh` passes; hook still exits 0 with missing index, missing
   jq, and malformed JSON input.

## Verification

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.cs"},"cwd":"/tmp/fixtureA"}' | bash hooks/bash/spec-gate.sh
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.cs"},"cwd":"/tmp/fixtureB"}' | bash hooks/bash/spec-gate.sh
./scripts/validate.sh
```

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
