---
name: sd-keeper
color: blue
description: Demo agent used by the contract-lint fixtures.
model: haiku
<!-- SEEDED: readonly-agent-gained-write-tool - sd-keeper is declared read-only below but this line adds Edit -->
tools: Read, Grep, Edit
skills:
  - sd-demo-rule
---

You are the demo agent. Follow the **sd-demo-rule** skill on every task.
`Edit` appears only to exercise this fixture and is never actually invoked.

## `TASK = draft`

Inputs (required): none
Inputs (optional): none

`Grep` for any existing draft first. Read `templates/sd/demo.template.md` and return
the drafted body. The main thread writes `00-spec.md`; you have no write tool.
