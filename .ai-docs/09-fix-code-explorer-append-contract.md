# FIX: sd-code-explorer is told to APPEND to a file but has no write tool

- Priority: P2
- Area: `agents/code-explorer.md`, `commands/feature.md`, `commands/refactor.md`
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/explorer-append-contract`

## Problem

The explorer's allowlist is read-only by design (`agents/code-explorer.md:6`: Read, Grep, Glob,
gitnexus tools — no Write/Edit/Bash), and its own anti-pattern section says so
(`code-explorer.md:146`: "Modifying files. Your tool allowlist excludes Write / Edit /
MultiEdit precisely for this reason.").

Yet the impact-map task instructs (`code-explorer.md:39`):

```text
2. Produce structured analysis (sections below). APPEND to `OUTPUT_APPEND_TO`. Do not overwrite.
```

And the callers pass the target file with no command-side append step:

- `commands/feature.md:69`: `OUTPUT_APPEND_TO = .specs/FEAT-<arg>/03-decisions.md`
- `commands/refactor.md:77`: `OUTPUT_APPEND_TO = .specs/REF-<slug>-<YYYYMMDD>/03-decisions.md`

The agent physically cannot perform the write it is instructed to perform, and Phase 2 of
feature/refactor (and downstream plan phases that read `03-decisions.md` as `IMPACT`) depend
on that content existing.

## Fix (keep the read-only allowlist — it is the better design)

1. `agents/code-explorer.md` impact-map task: replace the APPEND instruction with "Return the
   structured analysis block as your final output. The calling command appends it to
   `03-decisions.md`. Do not attempt to write files." Rename the input from `OUTPUT_APPEND_TO`
   to something like `OUTPUT_TARGET` (informational) or drop it.
2. `commands/feature.md` and `commands/refactor.md`: after the explorer invocation, add an
   explicit main-thread step: "Append the explorer's returned analysis to
   `.specs/<ID>/03-decisions.md` (create the file if missing; never overwrite existing
   content)."
3. Check `commands/perf.md` and `commands/bug.md` for the same pattern (any `OUTPUT_APPEND_TO`
   or "explorer writes X" phrasing) and align.
4. Do NOT grant Write to the explorer — the structural read-only guarantee is a core design
   property (CLAUDE.md: "Tool allowlists enforce roles structurally").

## Acceptance criteria

1. `grep -rn "OUTPUT_APPEND_TO" agents/ commands/` — every remaining occurrence (if kept) is
   documented as informational, and no agent instruction tells a read-only agent to write.
2. feature.md and refactor.md each have an explicit command-side append step after the
   impact-map invocation.
3. The explorer anti-pattern section no longer contradicts any task instruction.
4. `scripts/validate.sh` passes.

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
