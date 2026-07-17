---
id: FEAT-CLEAN-001
type: feature
status: draft
jira: none
created: 2026-07-01
linked_specs:
  - depends-on: BUG-CLEAN-003
---

# Add webhook retry backoff

## Why

Webhook deliveries that fail transiently are dropped, so operators miss low-stock events.

## What

### Scenario 1: Transient failure retries

- **Given** a subscribed webhook endpoint returning 503
- **When** a low-stock event fires
- **Then** delivery is retried 3x with exponential backoff

## Success criteria

- [ ] Failed webhook retries 3x with exponential backoff
- [ ] Unit + integration tests cover all scenarios above

## Out of scope

- Email or SMS notifications - webhooks only in this iteration

## Open questions

- None.

## Constitution check

- **Result**: compliant

<!-- Cross-references live in the `linked_specs` frontmatter field. This spec is at `draft`, so
     author-fill tokens would still be legal here; none remain because the spec is complete. -->
