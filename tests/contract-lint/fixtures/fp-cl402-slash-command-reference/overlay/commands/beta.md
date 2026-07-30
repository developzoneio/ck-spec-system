---
description: Second demo workflow used by the contract-lint fixtures.
argument-hint: <slug>
---

# /sd:beta

Runs after `/sd:alpha`. Invokes `sd-keeper` for the write step.

## Gate - confirm before writing

STOP for explicit approval:

> Reply to accept as-is, or send corrections. (go / <corrections>)

Run `/sd:alpha` before `/sd:beta` to prep the workspace, and see `~/.claude/skills/sd/`
for the shared rule packs.
