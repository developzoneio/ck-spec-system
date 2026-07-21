# sd-spec-templates

Per-template authoring rules for specwright. Used by `sd-spec-architect` when `TASK = create`.
Each template has a dedicated section below. Read only the section matching the spec type being authored.

---

## Common rules (apply to all templates)

- Output goes to the **file**, not to the prose response. Response = one-paragraph summary + file path.
- Follow the template structure **exactly** — sections, order, headings. Reordering breaks downstream agents.
- Cross-phase fields carry a `<<PHASE-N: description>>` token. Leave the token **verbatim** — do
  not pre-fill it, do not delete it. Phase N of the owning workflow replaces it with measured
  evidence. `/sd:spec validate` fails a `draft` or `approved` spec whose phase-deferred tokens are
  already filled, so pre-filling is caught, not just discouraged.
- Author-fill fields use the plain `<<description>>` token and must be replaced before `approved`.
- `created` = current UTC date in `YYYY-MM-DD`.
- If anything is genuinely uncertain, surface as an **Open question** — never silently allow.

### Required frontmatter fields

| Type | Fields |
|---|---|
| All | `id`, `type`, `status: draft`, `created`, `linked_specs` |
| Feature | `jira` (or `none`) |
| Bug | `severity` (P0–P3), `jira` |
| Refactor | `smell` |
| Perf | `target_metric` |
| RCA | `severity`, `incident_started`, `incident_resolved` |

`linked_specs` is always `[]` at authoring time. Cross-references are written later by
`/sd:spec link`, which maintains the inverse entry on the other spec — never hand-write the list,
and never add a "Linked specs" body section. A one-sided link fails `/sd:spec validate`.

---

## feature.template.md

Fill:
- **Why** — one paragraph, quantify impact if possible.
- **What** — Given/When/Then scenarios: happy path, edge cases, failure modes.
- **Success criteria** — concrete and checkable (observable test outcome, not "works correctly").
- **Out of scope** — explicit list; prevents scope creep disputes.
- **Open questions** — real ambiguities only; don't pad.

- Scenario headings use stable IDs: `### SC-<n>: <name>`. IDs are sequential from SC-1 and are
  never renumbered or reused after a scenario is deleted - downstream `Covers` fields and
  `/sd:verify` reports reference them.
- Success criteria use stable IDs: `- [ ] AC-<n>: <criterion>`. Same stability rule as SC IDs.
- Every SC and AC ID must be covered by at least one task's `Covers` field in `02-tasks.md`
  before `/sd:verify` can pass (see sd-atomic-task-format).

Constitution check: list applicable `§N.M` references. Flag any potential violation as an Open question.

---

## bug.template.md

Fill:
- **Symptom** — observed behavior.
- **Expected** — correct behavior.
- **Reproduction** — deterministic steps (numbered list).
- **Affected** — components, scope, first introduced (version / PR if known).
- **Severity** — P0 (production down) / P1 (major feature broken) / P2 (partial degradation) / P3 (minor).

**Leave empty**: Root cause section, Fix approach section — these are filled in Phase 3 (debugger) and Phase 5 (main thread + implementer). Pre-filling breaks the workflow gate discipline.

---

## refactor.template.md

Fill:
- **Smell / Driver** — named code smell or architectural reason.
- **Current state** — high level. Code-explorer fills detailed impact in `03-decisions.md`.
- **Target state** — the intended structure after refactor.
- **Invariants — MUST preserve** — concrete and checkable; each invariant gets a test witness.
- **Out of scope** — explicit.

Leave TBD:
- **Impact surface** — Phase 2 explorer fills.
- **Test coverage prerequisite measurements** — Phase 3 fills.

Public API: preserved by default. Any public API change requires explicit mention in the spec.

---

## perf.template.md

Fill:
- **Target** — metric (e.g. `p95 latency`), goal SLA (e.g. `< 200ms`), environment, load profile, workload type.
- **Measurement methodology** — tool, script, warm-up rounds, duration, reps, DB state, cache state.
- **Constraints** — correctness non-negotiables, behavioral invariants, forbidden side effects.
- **Out of scope**.

Leave empty:
- "Current observed" in Target table — filled by Phase 2 baseline measurement.
- **Results log** — filled iteratively in Phase 4.
- **Hypothesis tree** — filled by debugger in Phase 3.
- **Trade-offs accepted** — filled at close-out.

---

## rca.template.md

Produce skeleton only. The following are filled **interactively** by the main thread with user input in Phase 1 — do NOT pre-fill them:
- Timeline
- Symptoms
- Affected scope
- Recent changes

Leave TBD (filled by later phases):
- Hypothesis tree (Phase 2 debugger)
- Root cause (Phase 3 verification)
- Affected components, Mitigation, Follow-up actions, Spawned specs, Lessons learned

Spec ID format: `RCA-<slug>-<YYYYMMDD>` using UTC date.

---

## Anti-patterns

- Filling cross-phase fields prematurely (bug root cause, perf results log, rca root cause).
- Reordering sections in the template output — downstream agents key off section headers.
- Hardcoding stack assumptions — always read `CLAUDE.md` first; never default to a stack from prior invocations.
- Producing the spec text in the prose response — write to the file; return only the summary + path.
- Glossing over a constitution violation — if §1.1 is at risk, that is an Open question.
