# Task-block field-grammar fixtures

Conformance fixtures for the **Field label grammar** section of
`skills/sd-atomic-task-format/SKILL.md`.

**These fixtures have no automated runner.** `SL060` lives in `commands/spec.md` as
model-executed prose, and no script in this repo parses task blocks, so
`scripts/validate.{ps1,sh}` cannot exercise them. They are a *conformance contract*, not a CI
check - read them, and any reader of `02-tasks.md` must agree with the expectations below.
Wiring them to a real script is deliberately out of scope (see
`_bmad-output/SW-11-implementation-plan.md` section 5).

## Why these three label forms

Each is taken from a real spec in the only live corpus running specwright
(`asian-sportsbook-v2`, 29 tasks across 4 specs). All three occur in production; a reader built
against the canonical form alone would reject 22 of the 29 tasks - i.e. the two best-authored
specs.

| Fixture | Form | Seen in |
|---|---|---|
| `canonical-labels.md` | `- **Files**: v` | `FEAT-ASF-245` |
| `plain-labels.md` | `- Files: v` | `FEAT-ASF-251` |
| `colon-inside-emphasis.md` | `- **Files:** v` | `FEAT-ASF-251-LeagueContainer` |
| `missing-pattern-refs.md` | canonical, `Pattern refs` absent | negative case |

## Expectations

1. **The first three fixtures parse identically.** Same 11 fields, same values. Label form is
   presentation, never meaning.
2. **`colon-inside-emphasis.md` proves value extent.** Its `Acceptance` and `Pattern refs` are
   multi-line with nested sub-bullets. A reader that stops at the first newline truncates both -
   it must return the full value, up to the next field label.
3. **`missing-pattern-refs.md` is the negative case.** It is a well-formed task block with every
   other required field present, and no `Pattern refs`. `/sd:spec validate` must report exactly
   one `SL060` (WARN) against it - and must report **no** `SL060` for the other three.

Expectation 3 is the one that matters: a check that never fires is the failure mode this repo
has already shipped once (see SW-20, where `selftest-docs` hardcoded a count and silently stopped
biting). If a change makes `missing-pattern-refs.md` pass clean, the check is broken - not the
fixture.
