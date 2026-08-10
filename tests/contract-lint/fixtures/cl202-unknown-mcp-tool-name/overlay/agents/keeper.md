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

Consult `mcp__demo__known-tool` for prior art.

<!-- SEEDED: unknown-mcp-tool - the next line names an mcp tool this manifest does not recognize -->
Do not consult `mcp__demo__unknown-tool`; this manifest does not recognize it.
