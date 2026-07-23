# Examples

The primary worked example for specwright is the end-to-end walkthrough in:

**[`../docs/walkthrough.md`](../docs/walkthrough.md)**

It covers:

1. First-time `/sd:setup` on a fictional inventory-service project.
2. A complete `/sd:feature INV-2501` run from one-line ask to closed-out code.
3. A sample task execution where the reviewer catches a layer violation.
4. Cost breakdown (~$2.45 for a 6-task feature).
5. Three months later: searchable knowledge in action.
6. Lessons learned.

---

## What is here now

- [`spec-lint-fixture/`](spec-lint-fixture/) - a clean `.specs/` tree and a seeded-broken one for
  exercising `/sd:spec validate`. Backs the SW-4 acceptance criterion. Run by hand, not in CI -
  the linter is a prompt, so no script can execute it; the fixture README explains the trade-off.

---

## What this folder will hold over time

Ideas under consideration, no committed timeline (see [`../ROADMAP.md`](../ROADMAP.md) for what
is actually scheduled):

- `examples/fixture-projects/` - tiny example repos (Node, .NET, Python) with pre-populated `.specs/` for demoing.
- `examples/transcripts/` - anonymized real-run transcripts showing prompt-router and spec-gate behavior.
- `examples/templates-customized/` - reference customizations of `constitution.template.md` for common stacks (Clean Architecture for .NET, hexagonal for Node, etc.).

If you want to contribute an example, see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
