# Contract lint (Check 8)

`scripts/contract-lint.ps1` and `scripts/contract-lint.sh` lint the **relationships between** the
engine's prompt files: which agent a command invokes, which skill an agent loads, which template a
prompt reads, how many hard gates a workflow declares.

Check 7 (`docs consistency`) already guards *inventory* -- how many files exist. That closed the
inventory drift class permanently. This closes the **contract** drift class: relationships that
were previously asserted in prose and checked only by human review.

Each of these shipped, and each was statically detectable the whole time:

| Shipped defect | Caught by |
|---|---|
| An agent told to append to a file with no write tool in its allowlist | CL200 (wave 3) |
| An input token an invocation never actually passes | CL102 (wave 2) |
| An `mcp__*` tool name that does not exist | CL202 (wave 3) |
| README claiming one gate count where `docs/architecture.md` claimed another | CL302 |

It is a **script, not a prompt**: deterministic file operations, no subagent, no model, run per PR
in CI on all three operating systems like every other check.

## Running it

```bash
bash scripts/contract-lint.sh --root .              # the repo
bash scripts/contract-lint.sh --root <tree>         # any tree with a manifest
bash scripts/contract-lint.sh --root . --rule CL305 # filter the output
```

```powershell
.\scripts\contract-lint.ps1 -Root .
.\scripts\contract-lint.ps1 -Root . -Rule CL305 -Quiet
```

`--rule` filters what is **printed**, never what runs. Every rule always executes, so `CL902`
(a suppression that suppressed nothing) stays truthful under a filter.

Output is TSV on stdout and nothing else -- one finding per line, root-relative paths, forward
slashes, sorted by file then line then rule then message:

```
CL300	BLOCK	commands/alpha.md	59	gate block contains no literal STOP
```

Exit codes: `0` no BLOCK findings, `1` at least one BLOCK, **`2` could not run** (bad root, missing
manifest, `jq` absent, registry parity guard failed). Exit 2 is separate on purpose. A validator
that cannot tell "clean" from "crashed" is worthless, so validate's Check 8 treats it as a failure.

## Rules

Severity lives in `specwright.manifest.json` under `contractLint.rules[]`, never in a rule's own
code, so a BLOCK/WARN divergence between the two implementations is structurally impossible.

### CL0xx -- reference resolution

| Rule | Severity | Fires when |
|---|---|---|
| `CL001` | BLOCK | an `sd-` token resolves to neither an agent name nor a skill folder |
| `CL002` | BLOCK | an agent's `skills:` frontmatter entry has no `skills/<name>/SKILL.md` |
| `CL003` | BLOCK | the same unresolved shape as CL001, on a line that mentions a skill |
| `CL004` | WARN | a skill folder is referenced by nothing in scan scope and is not declared in `skillConsumers` |
| `CL005` | BLOCK | a `templates/` path does not exist once the install namespace segment is folded away |
| `CL006` | BLOCK | a `/sd:<name>` reference has no `commands/<name>.md` |
| `CL007` | WARN | an agent is mentioned by no command body |
| `CL008` | BLOCK | a numbered spec-artifact filename is absent from `contractLint.specArtifacts` |

CL001 and CL003 split on whether the offending line mentions a skill; both BLOCK, so the split is
about the message a reader gets, not about severity.

### CL3xx -- gate integrity

A **gate block** runs from its heading to the next heading of any level, or end of file. That
window is why the roughly twenty literal `STOP`s in Phase 0 bootstrap error paths never satisfy or
trip a gate rule -- they all sit under a `## Phase 0` heading.

| Rule | Severity | Fires when |
|---|---|---|
| `CL300` | BLOCK | a gate block contains no literal `STOP` |
| `CL301` | BLOCK | a gate block offers no option set |
| `CL302` | BLOCK | the hard gate count on disk disagrees with `contractLint.gates.<file>.hard` |
| `CL303` | WARN | hard gate labels are not exactly `1..N` without duplicates |
| `CL304` | BLOCK | a conditional gate is on disk but undeclared, or declared and absent |
| `CL305` | BLOCK | a HARD gate lists an override token as a selectable option |

An **option set** is a slash-separated parenthetical such as `(yes / revise / abort)`, or two or
more top-level `- ` bullets. `CL303` compares **sets, never file order**: `commands/bug.md` authors
`Gate 3a` before `Gate 3` and passes.

`CL305` is scoped to the gate's **option set**, never its prose. An override is a *listed choice*,
not a *described consequence* -- `commands/release.md` may say "the user may override the version
at this gate" without tripping it, while `(yes / skip / abort)` at a HARD gate fires. Catching the
prose form honestly needs a per-gate declared-exception surface and is deferred to `CL306`.

Gate classification needs no exclusion list. `Gate` followed by a lowercase word is never a gate,
which is what makes `## Gate activity` in `commands/status.md` invisible to all six rules.

### CL9xx -- suppression hygiene

| Rule | Severity | Fires when |
|---|---|---|
| `CL900` | BLOCK | a suppression carries no usable reason |
| `CL901` | BLOCK | a suppression names a rule id absent from the registry |
| `CL902` | WARN | a suppression suppressed nothing |

## Suppressions

```
<!-- contract-lint: allow CL305 - Case A is the already-at-goal branch, and the option there buys a logged constitution exception rather than a way past the requirement -->
```

It applies to a finding of that rule, in that file, on the same line or the next one. Indexed only
inside `contractLint.scanScope` and only outside fenced code blocks, so this page and
`CONTRIBUTING.md` can show the syntax without minting a phantom suppression that then trips CL902.

**A suppression can never suppress CL900, CL901 or CL902.** That exclusion is hardcoded in both
implementations rather than manifest-driven, because `<!-- contract-lint: allow CL900 -->` would
otherwise be a self-authorizing loophole.

The reason is not decoration. CL900 rejects anything under ten non-separator characters, so
"`- x`" fails and the writer has to say why.

## Manifest surface

Everything configurable lives under one top-level `contractLint` key, so later waves nest inside it
and never touch `areas`, `derived` or `docClaims`.

| Key | Purpose |
|---|---|
| `scanScope` | globs the linter reads. Deliberately `commands/`, `agents/`, `skills/` and nothing else |
| `installNamespaceSegment` | the `sd` in `templates/sd/...`, folded away before CL005 tests disk |
| `rules` | the registry: id, severity, wave, summary. The one source of severity |
| `gates` | per file: the declared hard count, the declared conditional labels, and the Check 7 quantity name |
| `specArtifacts` | the numbered artifact filenames CL008 accepts |
| `skillConsumers` | skills whose only consumers live outside scan scope, with the reason |
| `overrideOptionTokens` | the vocabulary CL305 treats as an escape hatch |

`scanScope` is load-bearing. `CLAUDE.md` and `CONTRIBUTING.md` use `sd-test` as a sandbox path and
`docs/architecture.md` carries a `name: sd-debugger` frontmatter example, so widening the scope to
`docs/**` produces a wall of CL001 false positives on day one.

### Why the manifest stores a gate count

The manifest's own charter says it stores no counts, and `gates.<file>.hard` is a literal number.
The test that resolves it:

> Can a script count it from disk with no judgement calls?
> **Yes** -- it is inventory, it belongs in `areas`, and it must be derived.
> **No** -- it is a declared design contract, and it belongs in `contractLint`.

"How many command files exist" passes that test. "How many hard gates `/sd:feature` declares" does
not: nothing on disk is a second source for it, so a derived value would make CL302 compare disk
against itself and pass vacuously forever. The number's job is to make deleting a gate heading a
deliberate two-file edit that shows up in review.

Feeding those counts into Check 7 as quantities gives `README <- manifest` there and
`manifest <- disk` here, hence transitively `README == disk`, with no gate parser duplicated into
`scripts/validate.*`.

## Waves

Wave 1 is what ships here. Later waves are pure additions: one registry entry, one function per
implementation, one fixture, one row in the tables above.

| Wave | Band | Status |
|---|---|---|
| 1 | CL0xx reference resolution, CL3xx gate integrity, CL9xx suppression hygiene | shipped, BLOCK |
| 2 | CL1xx invocation contract (agent input declarations) | planned |
| 3 | CL2xx role and tool integrity, CL4xx stack-agnostic prose, CL306 | planned, WARN first |
| 4 | CL5xx file budgets | planned, stays WARN |

Two scope decisions were made deliberately in wave 1 and are recorded here so they read as
decisions rather than oversights:

- **CL007 is loose.** "Invoked by" means any mention of the agent name in a command body.
  Tightening it to a real invocation construct is CL1xx's job; doing it now would duplicate wave-2
  parsing.
- **CL006 does not scan `hooks/`,** although `/sd:` references live there. That is a wave-2 scope
  extension.

## Testing it

`tests/contract-lint/` holds the fixture suite; see its README for the case map and for what to do
when adding a rule. The load-bearing assertions are the fixture sweep and the line-for-line
comparison of the two implementations on every case.
