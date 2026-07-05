# Review findings to fix (from 2026-07-03 deep review) - delete this file when done

Branch: hotfix/ps-hooks-audit. CI is green; these are defects found in the branch's own new code.

## Must fix before PR

1. `install/install.sh:93` - guard validates PREFIX but not BASE_PATH.
   - `--base-path ""` accepted -> install plan targets filesystem root (`/commands/sd` ...).
   - Also `install.sh:74`: `--base-path` with NO value -> `shift 2` fails under `set -e`, dies exit 1 with zero output.
   - Fix: reject empty/whitespace BASE_PATH; print usage on missing flag value. Mirror in install.ps1.

2. `install/install.sh:204` - partial-install ERR trap never fires.
   - `trap on_error ERR` without `set -E` does not fire inside functions; all copy work is in copy_one().
   - Fix: change line 16 to `set -Eeuo pipefail` (or trap EXIT + exit-code check).
   - Also: install.ps1 has NO equivalent partial-install guard at all - add one (pairs rule).

3. `hooks/bash/subagent-retro.sh:~166` - UTC debounce fix landed only in the PS twin.
   - macOS fallback `date -j -f '%Y-%m-%dT%H:%M:%S'` parses saved UTC timestamp as LOCAL time.
   - On UTC+7 Mac: debounce always elapsed -> retro-reminder spam; smoke test fails locally (CI green only because runners are UTC).
   - Fix: parse as UTC (e.g. append `TZ=UTC0` / use `-u`), mirror the ps1 fix (hooks ship in pairs).

4. `commands/rca.md:78` - Phase 2 step 3 still passive: "Hypothesis tree written to 00-spec.md".
   - Debugger has no Write tool -> tree never persisted, Gate 2 empty.
   - Fix: reword to "Main thread appends the returned hypothesis tree ..." (match bug.md:111 / perf.md / rca.md Phase 3).

## Judgment calls (fix or file follow-up issues)

5. `agents/debugger.md:6` + body line ~46 - body prescribes "project-provided database MCP tool"
   but frontmatter allowlist has no DB tool -> path unreachable. Also docs/architecture.md:92,309
   still documents removed mcp__mssql__execute_sql.

6. `scripts/validate.sh:26` + `scripts/validate.ps1:39` - counts derived from source tree are
   self-referential: a deleted/renamed asset moves expected+actual in lockstep, CI stays green.
   Consider minimum-count floor or manifest.

## Cleanups (fast-follow OK)

7. `scripts/smoke-hooks.sh:1` - add `set -euo pipefail` (repo bash rule); run_hook line 96 needs
   `CODE=0; ... || CODE=$?` to stay set-e-safe.
8. `scripts/smoke-hooks.sh:106` - add jq preflight: `command -v jq || { echo 'jq required'; exit 1; }`
   (hooks exit 0 silently without jq -> assertions blame the hooks).
9. `commands/bug.md:42` (+ feature.md:32, perf.md:41, rca.md:30, refactor.md:44) - Phase 0 bootstrap
   guard copy-pasted 5x, already drifted in feature.md -> dedupe into a shared skill/rule pack.
10. `install/install.sh:94` - prefix emptiness check `${PREFIX// /}` strips spaces only; use
    `${PREFIX//[[:space:]]/}` to match install.ps1's IsNullOrWhiteSpace.
