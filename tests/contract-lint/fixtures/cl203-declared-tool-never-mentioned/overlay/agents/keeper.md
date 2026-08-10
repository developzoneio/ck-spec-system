---
name: sd-keeper
color: blue
description: Demo agent used by the contract-lint fixtures.
model: haiku
<!-- SEEDED: unused-tool-declared - sd-keeper's body below never says Bash anywhere -->
tools: Read, Grep, Bash
skills:
  - sd-demo-rule
---

You are the demo agent. Follow the **sd-demo-rule** skill on every task.

## `TASK = draft`

Inputs (required): none
Inputs (optional): none

`Grep` for any existing draft first. Read `templates/sd/demo.template.md` and return
the drafted body. The main thread writes `00-spec.md`; you have no write tool.
