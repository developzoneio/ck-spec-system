# REFACTOR: rules duplicated between agent bodies, commands, and skills

- Priority: P2
- Area: `agents/debugger.md`, `agents/reviewer.md`, `agents/code-explorer.md`,
  `commands/feature.md`, `commands/refactor.md`, `commands/bug.md`, `commands/rca.md`,
  `skills/sd-*`
- Status: VERIFIED (agent-audited with cross-quotes; re-verify each pair before deleting)
- Suggested branch: `refactor/dedup-agent-skill-rules`

## Problem

CLAUDE.md:59: "A rule used by multiple agents ... lives in one `SKILL.md`, never copy-pasted
into agent bodies." Current duplications drift independently (the refactor task block has
already gained a field the feature copy lacks):

1. **Anti-patterns copy-pasted from skills into agent bodies:**
   - `agents/debugger.md:104-110` restates `skills/sd-hypothesis-tree/SKILL.md:82-87` nearly
     verbatim (stopping at proximate cause, one-hypothesis-only, skipping REJECTED reasoning,
     inventing evidence, acting on CONFIRMED without approval).
   - `agents/reviewer.md:122-124` restates `skills/sd-severity-taxonomy/SKILL.md:71-73`
     (SUGGEST-vs-WARN conflation, style-as-BLOCK, missing `§N.M` citation).
   - `agents/code-explorer.md:148,:150` restates `skills/sd-evidence-citation/SKILL.md:90,:92`
     (memory-over-grep, vendored/generated dirs).
2. **Atomic-task block inlined in commands despite `skills/sd-atomic-task-format` existing:**
   `feature.md:87-99` and `refactor.md:127-140` inline the block verbatim while
   `spec-architect.md:65` already references the skill. The two inline copies have drifted.
3. **Hypothesis-tree method duplicated in commands:** the "5 mental models
   (boundary/state/concurrency/recent-changes/environment)" + `(Likelihood x Impact) /
   Cost-to-verify` ranking appears in both `bug.md:104` and `rca.md:70`, duplicating
   `skills/sd-hypothesis-tree`.

## Fix

For each duplication: keep the skill as the single source, replace the copy with a one-line
reference ("Anti-patterns: see `sd-hypothesis-tree`" / "Task format: per
`sd-atomic-task-format` — the architect applies it").

Cautions:

- Agents load skills via frontmatter `skills:` — a reference only works if the skill is in
  that agent's list. Verify each agent's frontmatter includes the skill being referenced;
  add it if missing (that is the mechanism, per CLAUDE.md:59).
- COMMANDS do not have a `skills:` frontmatter mechanism — they are read by the main thread.
  For command-side duplication (items 2 and 3), the right target is: the command states the
  REQUIREMENT ("tasks must follow the atomic task format; the architect enforces it via
  `sd-atomic-task-format`") and stops re-specifying the format inline. Where the drifted
  copies disagree, reconcile INTO the skill first, then delete the copies.
- Do not delete agent-body text that is genuinely role-specific (only remove what restates
  the skill).

## Acceptance criteria

1. The quoted duplicated blocks are gone from agent bodies/commands and each replacement
   points at the owning skill.
2. Any content that existed only in a drifted copy has been merged into the skill.
3. Every referenced skill appears in the referencing agent's frontmatter `skills:` list.
4. `scripts/validate.sh` passes.

Add a CHANGELOG `### Changed` entry under `## [Unreleased]`.
