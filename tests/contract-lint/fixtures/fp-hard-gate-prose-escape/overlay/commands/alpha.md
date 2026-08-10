---
description: Demo workflow used by the contract-lint fixtures.
argument-hint: <slug>
---

# /sd:alpha

Demo workflow. Writes `.specs/ALPHA-<slug>/00-spec.md`, then `01-plan.md`.

## Phase 0 - Bootstrap

If `templates/sd/demo.template.md` is missing, STOP and report it. If the registry
is unreadable, STOP. Neither of these sits inside a gate block, and CL300 must not
mistake them for one.

## Phase 1 - Draft

Invoke `sd-keeper` with `TASK = draft`.

### ⛔ Gate 1 - Draft approved

STOP. Ask:

> Approve the draft? (yes / revise / abort)

## Phase 2 - Close

Append the outcome to `02-tasks.md`.

### ⛔ Gate 2 - Close approved (HARD)

STOP. Ask:

> Close it now? (yes / revise / abort)

<!-- contract-lint: allow CL306 - logged insist-and-proceed keeps an audit trail via the constitution exception -->
- If the user insists on closing without a draft, log a constitution exception and
  proceed at their explicit risk acknowledgement.
<!-- contract-lint: allow CL306 - described option, not a listed override token; CL305 already covers listed-choice overrides -->
- The user may override the outcome at this gate.
- On rejection: write nothing.
