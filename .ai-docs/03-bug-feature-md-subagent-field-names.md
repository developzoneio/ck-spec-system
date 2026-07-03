# BUG: feature.md passes field names that sd-spec-architect and sd-code-explorer do not read

- Priority: P1
- Area: `commands/feature.md`; contracts in `agents/spec-architect.md`, `agents/code-explorer.md`
- Status: VERIFIED by direct inspection on main @ 4d4d290
- Suggested branch: `fix/feature-md-field-names`

## Problem

`sd-spec-architect` selects its mode by reading the `TASK` field (`agents/spec-architect.md:15`)
and its inputs are `TICKET_CONTEXT` (create, `:24,:40`), `SPEC` + `IMPACT` (plan, `:50`), and
`SPEC` + `FEEDBACK` (refine, `:80`). `sd-code-explorer` likewise reads `TASK` and `SPEC`
(`agents/code-explorer.md:18,:35`).

`commands/feature.md` — the flagship workflow — sends different names to these two agents:

| feature.md line | Sends | Agent expects |
|---|---|---|
| `:46` | `TICKET_DATA = <fetched or pasted>` | `TICKET_CONTEXT` |
| `:67` | `TASK_TYPE = impact-map` | `TASK` |
| `:68` | `SPEC_REF = .specs/FEAT-<arg>/00-spec.md` | `SPEC` |
| `:81-82` | `SPEC_REF` / `IMPACT_REF` (plan invocation) | `SPEC` / `IMPACT` |
| `:59, :110` | refine calls pass `FEEDBACK` but omit the spec path | refine requires `SPEC` (`spec-architect.md:80`) |

The agent's first instruction is literally "Read the `TASK` field" — with `TASK_TYPE` the
mode selector and input paths are unrecognized on the most-used command.

## Important nuance — two conventions exist in the repo

`sd-reviewer` legitimately uses `TASK_TYPE` and `SPEC_REF` as its OWN contract
(`agents/reviewer.md:21-22,:41`). So `feature.md:153-155` (reviewer invocation with
`TASK_TYPE = holistic`) is CORRECT and must NOT be renamed. `bug.md:196-198` (reviewer,
`TASK_TYPE = bug-fix-final`) is also correct.

Scope of THIS fix: make each command invocation match the contract of the agent it invokes.
Do not change any agent contract in this PR.

## Fix

In `commands/feature.md` only, for invocations of `sd-spec-architect` and `sd-code-explorer`:

1. `:46` `TICKET_DATA` -> `TICKET_CONTEXT`.
2. `:67` `TASK_TYPE = impact-map` -> `TASK = impact-map`.
3. `:68` `SPEC_REF` -> `SPEC`.
4. `:81-82` `SPEC_REF`/`IMPACT_REF` -> `SPEC`/`IMPACT` (and `:124-125` if that block also
   targets the architect — check the surrounding invocation target first).
5. Both refine invocations (`:59`, `:110`): add `SPEC = .specs/FEAT-<arg>/00-spec.md`.
6. Cross-check the other workflow commands for the same class of error against the SAME rule
   (invocation fields must match the invoked agent's contract): `bug.md:101` (`SPEC_REF` — check
   which agent that invocation targets; if sd-debugger, check `agents/debugger.md` for its
   expected field name and align), `refactor.md:103` (`TASK_TYPE = characterization-test` to
   sd-implementer — check `agents/implementer.md` contract; other implementer calls use
   `TASK_DETAILS` + `WORKFLOW_TYPE`, e.g. `feature.md:122-125`).
7. While in `feature.md:45`: `TEMPLATE = feature` is bare while every other workflow passes the
   full filename (`bug.template.md` etc. matching `templates/specs/`); align to
   `feature.template.md`.

## Follow-up (separate PR, optional)

Standardize ONE field-name convention across all 6 agents and 11 commands (either
`TASK/SPEC/IMPACT` everywhere or `TASK_TYPE/SPEC_REF/IMPACT_REF` everywhere). That is a
breaking rename of the reviewer contract too — keep it out of this bug fix.

## Acceptance criteria

1. Every field name in every `feature.md` subagent invocation appears verbatim in the invoked
   agent's documented inputs.
2. Both refine invocations carry a `SPEC` path.
3. Reviewer invocations still use `TASK_TYPE`/`SPEC_REF` (unchanged).
4. `scripts/validate.ps1` / `.sh` passes.

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
