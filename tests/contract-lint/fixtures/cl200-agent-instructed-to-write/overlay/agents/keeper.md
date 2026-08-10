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

<!-- SEEDED: no-write-tool-instructed - sd-keeper carries no Write/Edit/MultiEdit tool but the line below still tells it to save output directly -->
Append the finished draft directly to `00-spec.md` before returning control.
