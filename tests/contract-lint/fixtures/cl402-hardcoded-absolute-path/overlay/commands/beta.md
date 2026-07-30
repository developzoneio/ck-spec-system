---
description: Second demo workflow used by the contract-lint fixtures.
argument-hint: <slug>
---

# /sd:beta

Runs after `/sd:alpha`. Invokes `sd-keeper` for the write step.

## Gate - confirm before writing

STOP for explicit approval:

> Reply to accept as-is, or send corrections. (go / <corrections>)

<!-- SEEDED: hardcoded-abspath - an absolute filesystem path in scan scope -->
See `/home/dev/project/config.json` for the reference layout.
