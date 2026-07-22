# ADR 0001: `/sd:spec validate` may parse artifact content, not only file structure

- Status: proposed
- Date: 2026-07-21
- Source spec: Jira SW-11 (`FEAT-context-refs-gate`); plan at
  `_bmad-output/SW-11-implementation-plan.md`
- Supersedes: none

## Context

Until now `/sd:spec validate` has been a pure file-ops command. Every rule in its table
(`commands/spec.md`, `SL001`-`SL055`) inspects a spec from the *outside*: frontmatter fields,
placeholder tokens, which artifacts exist for a given status, index/folder symmetry, transition
replay, link integrity. **No rule has ever opened `02-tasks.md` and read what is inside it.**

SW-11 asked for a gate that fails a spec whose atomic tasks carry no context reference for the
implementer. `sd-implementer` is an isolated subagent whose entire input is the task block
(`agents/implementer.md:23`), so a task with no precedent citation starves it, and the failure
surfaces late - at implement time rather than at spec time.

There was no existing home for such a check. `/sd:verify` already reads task fields
(`commands/verify.md:45-56`, `VF010`-`VF030`) but runs *after* implementation, which is exactly
the late failure SW-11 wants to eliminate. Placing the check in `/sd:spec validate` is the only
option that fires early - and it costs the command its file-ops-only character.

The measured evidence also shapes the rule's severity. In `asian-sportsbook-v2`, the only live
repo running specwright, 29 tasks span 4 specs: the 22 authored after the `Pattern refs` field
shipped (`CHANGELOG.md:558`) all carry refs, and the 7 without it belong to two specs that predate
the field. No retro in that corpus records an implementer starved of context.

Separately, the same corpus shows the field label syntax has drifted three ways
(`- **Files**:`, `- Files:`, `- **Files:**`), so any content parser needs a tolerant grammar or it
false-fails the best-authored specs.

## Decision

`/sd:spec validate` is permitted to parse the *content* of spec artifacts, not only their
structure and existence. The first such rule is `SL060` - a task block in `02-tasks.md` with no
`Pattern refs` field - at severity **WARN**.

Content parsing is bounded by three conditions:

1. **One grammar, centrally defined.** Readers use the `Field label grammar` section of
   `skills/sd-atomic-task-format/SKILL.md`. No command, agent, or script writes its own per-field
   matcher.
2. **A reserved band.** `SL060`-`SL069` belongs to task-block content rules. Future content checks
   claim from this band rather than extending an unrelated one.
3. **WARN, not BLOCK.** A missing field leaves the registry truthful and is fixed by re-planning,
   which is the existing WARN test stated in `commands/spec.md`. This is a deliberate reversal of
   what SW-11 requested.

## Consequences

**Positive.** The gate fires at spec time instead of implement time, which is the whole point of
the ticket. The tolerant grammar is defined once and fixes a latent class of bug - `Files` drifted
three ways, so `Depends on` will too. The reserved band gives SW-11's successor
(SW-13, `FEAT-complexity-triage`, which targets the same task format) a home instead of an
arbitrary number.

**Negative.** `/sd:spec validate` is no longer cheap to reason about: it now depends on a skill
file's grammar, so a change to `sd-atomic-task-format` can change validate's behavior at a
distance. The command also becomes the natural place to hang every future content check, and that
pressure needs resisting - the band is a sign, not a fence.

**Unresolved.** `SL060` has **no CI coverage**. It lives in `commands/spec.md` as model-executed
prose, and no script in this repo parses task blocks, so `scripts/validate.{ps1,sh}` cannot
exercise it. The fixtures at `tests/task-format/fixtures/` state the conformance contract but have
no runner. Building one means a new script pair and overlaps SW-4's territory (already `Done`).
This is recorded rather than solved; a check that cannot fail is a failure mode this repo has
already shipped once (SW-20).

**Scope declined.** SW-11 asked for a new field named `Context refs`. It was not created. The
existing `Pattern refs` field already covers the need, has 22-of-22 adoption under its current
name, is semantically tighter (it cites *precedent to mirror*), and renaming would touch 37 sites
across 10 live files plus 23 lines in the live corpus for no measurable gain.
