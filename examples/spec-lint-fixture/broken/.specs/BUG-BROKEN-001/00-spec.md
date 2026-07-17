---
id: BUG-BROKEN-999
type: bug
severity: P2
status: draft
jira: none
created: 2026-07-01
linked_specs: []
---

# Cart total ignores discount

<!-- SEEDED: SL003 - `id` says BUG-BROKEN-999, the folder is BUG-BROKEN-001. -->
<!-- SEEDED: SL030 - index.md row says `approved`, this frontmatter says `draft`. -->

## Symptom

Applying a percentage discount leaves the cart total unchanged.

## Expected

The cart total reflects the discount.

## Reproduction

1. Add an item, apply a 10% discount code.
2. Observe the total is unchanged.

## Affected

- **Users / scope**: all tenants
- **Workaround available**: no
