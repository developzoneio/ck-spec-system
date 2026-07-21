# sd-retro-lessons

Lesson-extraction discipline for specwright. Turns retro prose into privacy-safe, reusable
one-line rules that transfer to a codebase the author has never seen.

This skill is the authority on the tag enum, the lesson record shape, and the abstraction
rules. `scripts/validate-lessons.ps1` / `.sh` enforce the mechanical half; everything the
validator cannot see is your job.

---

## Why a lesson is not a retro note

A retro note records what happened *here*. A lesson records what should be done *anywhere*.

```
retro note   The League index copied CASESENSITIVE from euro-sportsbook, but the shared
             RedisQueryBuilder emits lowercase, so every dated query returned empty.

lesson       When mirroring a sibling repository's implementation, verify the local shared
             helper produces the same casing before copying an index or query attribute.
```

Same insight. The second one carries no identifiers, transfers to any stack, and can be
shared outside the org. Producing the second from the first is the whole skill.

---

## The tag enum

Ten tags, derived from a mined corpus of real retros - not authored up front. Every tag
below traces to at least one observed occurrence.

| Tag | Fires when |
|---|---|
| `sibling-repo-assumption` | Behaviour copied from a reference or sibling repo without verifying the local equivalent. |
| `missed-context` | The spec missed something that impact analysis, review, or execution later surfaced. |
| `baseline-attribution` | A pre-existing failure was blamed on, or dismissed because of, the current change without baselining. |
| `tooling-surprise` | A tool did something correct but unexpected that altered the working state. |
| `gate-friction` | A gate was waived, deferred, or satisfied by exception rather than met. |
| `config-drift` | Project configuration no longer matches the repository it describes. |
| `test-fragility` | A test was written coupled to names, literals, or reflection, knowingly or not. |
| `test-gap` | No test surface existed for the affected area and one had to be created mid-work. |
| `precedent-conflict` | A constitution rule conflicted with an established pattern already in the codebase. |
| `scope-discipline` | An in-scope-looking fix was correctly declined, or incorrectly absorbed. |

**The enum is capped at 12.** Two slots are deliberately free. Adding a tag requires a PR
that cites the retro which produced it. When a candidate lesson fits two existing tags,
pick the more specific one - do not invent a third.

**Retired:** `pattern-violation`. Every candidate instance resolved into either
`sibling-repo-assumption` or `precedent-conflict`. A tag that overlaps two others gets
applied inconsistently and poisons selection.

---

## Record shape

One line. Exactly this grammar:

```
- [tag] severity/scope: Rule sentence.
```

- `tag` - from the enum above, lowercase kebab.
- `severity` - `high` | `medium` | `low`. High means it would have shipped a defect or lost
  a day. Low means it cost minutes.
- `scope` - `feature` | `bug` | `refactor` | `perf` | `rca` | `all`. This is the selector a
  future run filters on, so `all` must be earned: use it only when the rule genuinely does
  not depend on the workflow.
- `Rule sentence` - one sentence, imperative, **120 characters maximum**.

After aggregation a repeat count may be appended - ` (3)`. Authors never write it.

```
- [sibling-repo-assumption] high/feature: When mirroring a sibling repository, verify the local shared helper matches before copying an attribute.
- [baseline-attribution] medium/all: Confirm pre-existing failures against a clean baseline before attributing or dismissing them.
- [gate-friction] medium/refactor: When waiving a coverage gate, record measured coverage, residual risk, and what would satisfy it later.
```

---

## Privacy rules

`.specs/_lessons/lessons.md` is designed to be shared outside the organisation as-is. The
rule sentence must therefore contain **zero identifiers**.

Forbidden in a rule sentence:

- Path separators (`/`, `\`) and file extensions.
- Backticks - if you need one, the sentence is still describing code.
- Line citations (`:84`).
- PascalCase or camelCase identifiers - class, method, variable, and type names.
- snake_case identifiers.
- Repository, product, team, customer, or person names.

Technology proper nouns that happen to be PascalCase (PowerShell, TypeScript, PostgreSQL,
and similar) are allowed via a small allowlist in the validator. Extending that allowlist
takes a PR - and usually means the lesson is less portable than you think.

**The validator is a lint, not a guarantee.** It cannot see "the payment team's nightly
reconciliation job" written in plain prose. That leaks just as badly as a class name. You
carry that part.

---

## Extraction procedure

1. Read the retro's **Surprises**, **Deferred follow-ups**, and **Constitution exceptions**
   sections first. That is where lessons concentrate.
2. Skip auto-generated content. A retro line matching `Status: X -> Y. Reason: ...` was
   written by `/sd:spec status` or `/sd:release`. It carries no lesson. A retro consisting
   only of such lines yields zero lessons - that is a correct outcome, not a failure.
3. For each candidate, ask: **would this have helped someone on a different codebase?**
   If no, it is a note, not a lesson. Drop it.
4. Strip identifiers. Restate as an imperative rule. Re-read it as a stranger.
5. Tag, rate severity, pick the narrowest true scope.
6. Run the validator before proposing the line.

---

## Anti-patterns

- **Tagging without abstracting.** Copying the retro sentence and prefixing a tag. The
  result leaks, and it teaches nothing outside this repo.
- **Restating the obvious.** "Write tests before merging" is not a lesson, it is a slogan.
  A lesson names a specific trap someone actually fell into.
- **`scope: all` by default.** It defeats selection; every run gets every lesson.
- **One lesson per task.** A spec with twelve tasks does not produce twelve lessons. Most
  specs produce zero to two. Zero is a normal, healthy outcome.
- **Inventing a tag** because none of the ten felt perfect. Pick the closest, or open a PR.
- **Escalating on repeat.** A lesson that reappears gets a count, never a higher severity.
  Severity describes the trap; frequency is a separate axis and is already recorded.
