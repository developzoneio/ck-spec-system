# sd-atomic-task-format

Canonical format for atomic implementation tasks in specwright.
Used by `sd-spec-architect` when authoring `02-tasks.md` and by `sd-implementer` when reading task contracts.

---

## Task block (9 required fields)

```markdown
### T<NN> - <imperative title>

- **Files**: <comma-separated relative paths>
- **Layer**: <Domain | Application | Infrastructure | Presentation | Tests | Config>
- **Step type**: <foundation | behavior | wiring | polish | test>
- **Test**: <which test file(s) cover this task>
- **Acceptance**: <observable criterion>
- **Depends on**: <T## | none>
- **Conflicts with**: <T## list | none>
- **Estimated complexity**: <S | M | L>
- **Reversibility**: <trivial | moderate | hard>
```

All 9 fields are **required**, not optional. A task block missing any field is malformed.

---

## Field rules

### Files
Must exist (for edits) or be a new file path consistent with project conventions. Use `Glob` to verify before writing.

### Layer
Must come from the constitution's declared layers. Do not invent layer names. If a layer is not in `constitution.md`, flag as an Open question.

### Step type
| Value | Meaning |
|---|---|
| `foundation` | New abstractions, types, interfaces, DB schema — no behavior yet |
| `behavior` | Business logic, event handlers, domain rules |
| `wiring` | DI registration, configuration, middleware, glue code |
| `polish` | Naming, comments, docs, dead-code removal |
| `test` | Test files only — no production code change |

### Acceptance
Must be **observable**: a passing test, a 201 response, a method called exactly once. "Feels right" or "code is cleaner" are not acceptable. Every acceptance criterion must be verifiable without running the full app (unit/integration test preferred).

### Estimated complexity
| Value | Guideline |
|---|---|
| `S` | ≤ 30 lines changed, single file, single concept |
| `M` | 30–100 lines, up to 3 files, one concern crossing a boundary |
| `L` | > 100 lines OR multiple files OR requires design decision at implementation time |

### Reversibility
| Value | Meaning |
|---|---|
| `trivial` | Can be undone with a single revert / delete |
| `moderate` | Requires a few file reverts; no downstream migrations |
| `hard` | Data migration, public API change, or multi-service impact |

### Depends on / Conflicts with
Drive sequencing and batch planning. Tasks that **conflict** cannot run in the same parallel batch. Tasks that **depend on** a prior task cannot start until that task's acceptance criterion is met.

---

## Atomicity rules

- **One concern per task.** If the title contains "and" connecting two distinct concerns, split into two tasks.
- **Single-file preferred.** Multi-file tasks should have a clear reason (e.g. interface + implementation pair).
- If a task feels like two changes during implementation, STOP and surface to the main thread.

---

## Anti-patterns

- Bundling interface + behavior + test into a single task — these are three tasks.
- Using vague acceptance criteria ("works correctly", "looks good").
- Listing files you haven't verified exist (for edits) or naming conventions don't match.
- Inventing layer names not declared in the constitution.
- Leaving `Depends on` / `Conflicts with` empty when sequential or conflicting relationships exist.
