# CI: add macOS to the matrix and smoke-test hooks with sample JSON

- Priority: P3 (land AFTER docs 01/02/05/06 so the new tests pass)
- Area: `.github/workflows/ci.yml`, possibly a new `scripts/smoke-hooks.{sh,ps1}`
- Status: VERIFIED (matrix and validate contents inspected)
- Suggested branch: `feat/ci-macos-hook-smoke`

## Problems

1. **macOS/BSD code paths never run in CI.** `.github/workflows/ci.yml:15` matrix is
   `[ubuntu-latest, windows-latest]`, but the codebase carries BSD-specific branches written
   for macOS: `stat -f %m` (`hooks/bash/subagent-retro.sh:69`), `date -j -f`
   (`subagent-retro.sh:166`), `shasum -a 256` (`install/install.sh:95`). A regression there
   ships undetected to a primary Claude Code platform.
2. **Hooks are never executed in CI.** validate covers ASCII, `bash -n`, pair parity, counts,
   changelog — but never pipes JSON into a hook. CLAUDE.md:30-32 documents exactly those smoke
   tests, manually. Neither the `$Matches` clobber (doc 01) nor the spec-gate parity gap
   (doc 02) is catchable by current CI; both would be caught by a fixture-based smoke test.

## Fix

1. Add `macos-latest` to the OS matrix. Audit each existing step for portability (the
   validate.sh Git-Bash-vs-WSL handling is Windows-specific; macOS runs plain bash).
2. Add a hook smoke-test step (or `scripts/smoke-hooks.sh` + `.ps1` so it is runnable
   locally too — if added as scripts, keep the pair rule and update any file-count
   expectations). Minimum cases, run on every OS with a small fixture repo created in the
   job's temp dir:
   - `prompt-router`: prompt with a keyword + fixture config present/absent -> exits 0,
     output contains the expected `<context-router>` hint; assert bash and PS outputs agree
     on the routed workflow.
   - `spec-gate`: (a) code edit with an in-progress row -> allow; (b) code edit with
     `in-progress` only in a header line -> warn/block consistently on both platforms;
     (c) docs edit -> allow; (d) malformed JSON on stdin -> exit 0.
   - `subagent-retro`: in-progress FEAT row without `05-retro.md` -> reminder names the real
     spec ID; run twice -> second run debounced. Exit 0 throughout.
3. Assert exit codes AND key output substrings, not just "did not crash".

## Constraints

- Windows job must run PS hooks under `powershell` (5.1) or at least `pwsh` — match what the
  installer targets; ASCII rule applies to any new `.ps1`.
- Keep runtime small; no external dependencies beyond `jq` (already a soft dep — install it in
  the job or let the hook's silent-degrade path be one of the test cases).

## Acceptance criteria

1. CI matrix includes ubuntu, windows, macos and is green.
2. Reverting the doc-01 fix (swap the `-match` order back) makes CI fail; same for doc-02.
3. `scripts/validate.*` still passes locally on Windows.

Add a CHANGELOG `### Added` entry under `## [Unreleased]`.
