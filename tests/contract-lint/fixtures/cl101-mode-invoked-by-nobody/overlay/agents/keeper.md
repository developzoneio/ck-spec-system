---
name: sd-keeper
color: blue
description: Demo agent used by the contract-lint fixtures.
model: haiku
tools: Read, Grep
skills:
  - sd-demo-rule
---

You are the demo agent. Follow the **sd-demo-rule** skill on every task.

## `TASK = draft`

Inputs (required): none
Inputs (optional): none

`Grep` for any existing draft first. Read `templates/sd/demo.template.md` and return
the drafted body. The main thread writes `00-spec.md`; you have no write tool.

<!-- SEEDED: unused-mode - no command in this fixture tree ever sets TASK = archive -->
## `TASK = archive`

Inputs (required): none
Inputs (optional): none

Archive the current draft. Nothing in this fixture tree invokes this mode.
