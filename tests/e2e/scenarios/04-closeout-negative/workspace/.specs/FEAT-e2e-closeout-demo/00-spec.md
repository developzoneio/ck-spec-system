---
id: FEAT-e2e-closeout-demo
type: feature
status: in-progress
jira: none
created: 2026-08-01
complexity: S # single-file demo spec seeded for tests/e2e scenario 04
linked_specs: []
---

# E2E closeout-negative demo spec

## Why

Seeded fixture spec for tests/e2e/scenarios/04-closeout-negative: exercises spec-gate's Rule 0
verify-gate deny path (an in-progress FEAT- spec with no passing 06-verify.md must not be flippable
to done).

## What

### SC-1: attempted close-out with no verify artifact

- **Given** this spec is `in-progress` in `.specs/index.md` and no `06-verify.md` exists
- **When** an edit attempts to change its index row to `done`
- **Then** spec-gate denies the edit

## Tasks

- [x] Seed fixture spec (this file)
