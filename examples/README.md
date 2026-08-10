# Examples

For a **runnable** example you can clone and drive yourself, start with
[`fixture-project/`](fixture-project/) below.

For a **narrated** end-to-end tour (illustrative, not runnable - a fictional .NET project), see:

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

- [`fixture-project/`](fixture-project/) - a tiny, runnable, non-.NET (plain Node.js) example
  project: pre-scaffolded `CLAUDE.md`, `.specs/constitution.md`, and `.claude/project-config.json`,
  plus a committed `.specs/FEAT-todo-priority/` worked example from a real `/sd:feature` run.
  Backs the SW-30 acceptance criteria - clone it, run `node --test`, and drive `/sd:feature`
  against it directly. This is what proves stack-agnosticism rather than merely asserting it.
- [`spec-lint-fixture/`](spec-lint-fixture/) - a clean `.specs/` tree and a seeded-broken one for
  exercising `/sd:spec validate`. Backs the SW-4 acceptance criterion. Run by hand, not in CI -
  the linter is a prompt, so no script can execute it; the fixture README explains the trade-off.
- [`port-parity-fixture/`](port-parity-fixture/) - matched clean and seeded-broken port trees over a
  toolchain-free plain-text donor, for exercising `sd-reviewer`'s `port-parity` adjudication. Backs
  the SW-40 acceptance criteria. Run by hand, not in CI, for the same reason `spec-lint-fixture` is:
  the adjudicator is a prompt, so no script can execute it.

---

## What this folder will hold over time

Ideas under consideration, no committed timeline (see [`../ROADMAP.md`](../ROADMAP.md) for what
is actually scheduled):

- `examples/transcripts/` - anonymized real-run transcripts showing prompt-router and spec-gate behavior.
- `examples/templates-customized/` - reference customizations of `constitution.template.md` for common stacks (Clean Architecture for .NET, hexagonal for Node, etc.).

If you want to contribute an example, see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
