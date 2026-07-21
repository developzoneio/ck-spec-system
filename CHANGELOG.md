# Changelog

All notable changes to **specwright** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Lesson surfacing, part 3 and the close of the learning loop (SW-19, under epic SW-7):
  `subagent-retro.{ps1,sh}` now emit a `<retro-lessons>` block when a subagent finishes work on an
  in-progress spec, gated by `hooks.subagentRetro.injectLessons` (default `true`) and
  `maxLessons` (default `3`). **Placement is load-bearing:** the emit sits beside the existing
  metrics call site, *before* the staleness early-exit and *before* the debounce window - moved
  down to the reminder block it would have surfaced lessons only to users already behind on their
  retros, the population that needs them least. The one gate it keeps is the in-progress-spec
  check, and that gate *is* the relevance filter: the workflow type of the in-progress spec selects
  the scope (`FEAT-` pulls `feature`, `REF-` pulls `refactor`, and `all`-scoped lessons always
  apply), so there is no ranking, no scoring, and no tie-break that could diverge between
  implementations. This replaces the `prompt-router` placement and the
  `hooks.promptRouter.injectLessons` key named in the SW-7 epic; the epic records why.
  Repetition is bounded per **session** rather than by a clock - a new `shownLessons` key in the
  hook state file records what has already been surfaced, so `maxLessons` caps how many *new*
  lessons appear at one stop and a session converges to silence once it has said everything
  relevant. A time debounce was rejected because it would suppress a lesson the user has never
  seen purely because a different one was shown recently. Four cross-implementation conformance
  fixtures cover surfacing, scope filtering, already-shown state and the disabled flag, and the
  conformance decision object now captures emitted lessons in emission order (sorting them would
  hide exactly the selection-order divergence the fixtures exist to catch).
- Lesson aggregator, part 2 of the closed learning loop (SW-18, under epic SW-7):
  `scripts/aggregate-lessons.{ps1,sh}` collect tagged lesson lines from every
  `<spec-dir>/*/05-retro.md`, dedupe them, and render `<spec-dir>/_lessons/lessons.md`.
  `--check` / `-Check` writes nothing and exits non-zero on drift, which is how idempotence is
  asserted in CI. Two decisions differ from the SW-18 description and are recorded here: (1) the
  **retros** are append-only and `lessons.md` is a derived file regenerated on every run - the
  ticket called `lessons.md` itself append-only, but dedupe-with-a-count requires rewriting the
  line, so append-only and idempotent are mutually exclusive; (2) abstraction stays in the
  `sd-retro-lessons` skill, so the aggregator makes no judgement calls and its output is
  reproducible. Deduplication is on (tag, scope, case- and whitespace-normalised rule);
  a repeat adds a count and **never** raises severity, and the surviving wording is resolved
  independently of severity (byte-smallest) so a sloppier phrasing cannot win just by carrying a
  lower one. All ordering is byte-wise - `LC_ALL=C` in bash, `[string]::CompareOrdinal` plus an
  ordinal dictionary comparer in PowerShell, whose culture-aware defaults would otherwise
  diverge - and PowerShell writes UTF-8 without BOM and LF endings rather than going through
  `Set-Content`. A committed corpus fixture and expected output pin both implementations to the
  same bytes in CI; the corpus deliberately includes retros containing only `/sd:spec status`
  transition lines (which must contribute zero lessons) and an out-of-enum tag (which must be
  skipped). No hook is modified; surfacing (SW-19) follows.
- Structured retro lessons, part 1 of the closed learning loop (SW-17, under epic SW-7): new
  `sd-retro-lessons` skill defining a 10-tag enum, the one-line lesson record
  (`- [tag] severity/scope: Rule sentence.`), and the abstraction discipline that turns a
  retro note into a rule portable to another codebase. The tag enum is **derived from a mined
  corpus of real retros**, not authored up front - two of the three tags originally proposed
  in SW-7 were confirmed by that data and one (`pattern-violation`) was retired as overlapping
  `sibling-repo-assumption` and `precedent-conflict`. New standalone validators
  `scripts/validate-lessons.ps1` / `.sh` enforce grammar, the closed tag/severity/scope sets, a
  120-character ceiling, and the privacy contract (no paths, extensions, backticks, line
  citations, or Pascal/camel/snake_case identifiers), so `.specs/_lessons/lessons.md` is
  shareable outside the org as-is. They are **separate from `scripts/validate.*` on purpose**:
  that validator checks this repo's own invariants, and specwright has no `.specs/` tree - these
  take a file argument and default to `.specs/_lessons/lessons.md` in the current directory, so
  a consumer repo can run them directly. Paired fixtures under `tests/lessons/fixtures/` assert
  both directions in CI (clean must pass, leaky must fail) - a validator that rots into a no-op
  would otherwise report green forever. No hook is modified by this change; aggregation (SW-18)
  and surfacing (SW-19) follow.
- Local, privacy-safe spec metrics (SW-10): `spec-gate` and `subagent-retro` now append one JSON
  line per gate decision, `index.md` lifecycle transition, and subagent-stop check to
  `.specs/_metrics/events.jsonl` - metadata only (timestamp, spec ID, lifecycle phase, decision,
  file extension), never a file path or code content. Controlled by `hooks.metrics.enabled` in
  `.claude/project-config.json`, which **defaults to `true`** - an existing install starts writing
  `.specs/_metrics/events.jsonl` on the next hook run after upgrading, with no action required. Set
  `hooks.metrics.enabled` to `false` to opt out entirely. No log rotation in v1 (documented as a
  known limitation; ~120 bytes/line). Foundation for the closed retro-learning loop (SW-7).
- `/sd:verify <spec-ID>` traceability gate: SC-/AC-IDs in the feature template, a `Covers`
  task field, a `06-verify.md` pass artifact, and spec-gate hook enforcement (Rule 0 in
  `spec-gate.{ps1,sh}`, flag `hooks.specGate.verifyGate`) that blocks a feature (FEAT-)
  `index.md` row transitioning to `done` without a passing artifact. The gate is deliberately
  scoped to feature specs - bug/refactor/perf/rca workflows produce no `02-tasks.md`, so
  non-FEAT rows fall through to the unconditional protected-path block exactly as before,
  pending a follow-up spec that integrates verify into those workflows. `/sd:spec status`
  pre-checks the artifact before mutating any file on a FEAT `in-progress -> done` transition
  (prevents an `SL030` frontmatter/index strand), and `/sd:feature` Phase 6 requires an
  evidence citation before ticking an `AC-<n>` checkbox. 11 new conformance fixtures pin the
  gate, including the FEAT-only scoping (`block-index-done-bug-row-protected`) and the
  documented bundled-edit limitation (`allow-index-done-with-verify-bundled-edit`). (SW-6)
- Cross-implementation hook conformance suite (`tests/hooks/`): golden fixtures are piped into
  both the bash and PowerShell implementation of every hook and the normalized decisions must
  match; wired into CI on all matrix platforms with a self-test proving divergence detection (E4).
- Six more seeded lint rules in `examples/spec-lint-fixture/broken/` (SW-4, seam 4), taking
  coverage from 18 of 26 rules to 24: `SL004` (type/prefix mismatch), `SL005` + `SL043` (illegal
  status, which cannot have a legal retro log and so always drags `SL043` with it), `SL021`
  (`done` with a header-only retro), `SL041` (non-contiguous transition chain) and `SL044`
  (`archived -> in-progress` with an empty reason, the one WARN in the transition family). The
  two remaining rules, `SL001` and `SL013`, need the fixture or the engine install itself to be
  broken, so they need a corrupting harness rather than another seeded spec.
- Boundary documentation on the four seeds whose neighbouring rules overlap (SW-4, seam 4). The
  transition rules `SL040`-`SL044` are close enough that a linter can collapse several into one
  and still look correct, so each seed is built to make exactly one fire and names in-file which
  others must stay silent - e.g. `PERF-BROKEN-012` separates `SL021` (retro exists but is empty)
  from `SL043` (no retro at all), and `REF-BROKEN-013` isolates `SL041` behind two legal edges,
  a matching last entry and a present retro.
- Severity-tagged output for `/sd:spec validate` (SW-4, seam 3), with a stable rule table
  (`SL001`-`SL054`). BLOCK is reserved for a registry that lies about itself or evidence that was
  fabricated; WARN for a real but recoverable problem that leaves the registry truthful. The
  command reads `sd-severity-taxonomy` and `sd-evidence-citation` from disk at runtime, because
  only agents load skills via frontmatter and `validate` invokes no subagent.
- Anchor table in `sd-severity-taxonomy` (SW-4, seam 3): BLOCK/WARN still requires an anchor, but
  the legal anchor now depends on the target - a constitution `§N.M` or acceptance criterion for
  code, a lint rule ID for the `.specs/` tree. The code row stays strict.
- `examples/spec-lint-fixture/` (SW-4, seam 3): a clean `.specs/` tree that must report all-PASS
  and a seeded-broken one covering 18 of the 26 lint rules, each violation self-documented with a
  `SEEDED` comment. The two perf specs are a matched pair guarding the seam-1 regression: the
  correct one (unfilled baseline at `approved`) must PASS and the fabricated one must BLOCK.
  Run by hand - the linter is a prompt, so CI cannot execute it; see the fixture README.
- `linked_specs` frontmatter field on all five spec templates (SW-4, seam 2), replacing the
  "Linked specs" body section that only `feature.template.md` ever had - `/sd:spec link` accepted
  any spec ID but had nowhere to write on the other four types. Cross-references are now a
  structured YAML list maintained by `link` on both sides.
- Four structural checks in `/sd:spec validate` (SW-4, seam 2): index <-> folder symmetry (orphan
  folders, ghost rows, duplicate rows), transition replay against the state machine from the
  `05-retro.md` append-only log (catches a hand-edited status that bypassed `/sd:spec status`),
  link resolution (no dangling links), and link symmetry (no one-sided links).
- `<<PHASE-N: ...>>` token in the spec templates (SW-4, seam 1 of the `/sd:spec validate` linter):
  a distinguishable marker for cross-phase fields, replacing 20 phase-deferred fields that were
  previously indistinguishable from author-fill `<<placeholder>>`s. This makes the engine's
  cross-phase discipline machine-checkable in both directions - `validate` can now assert that an
  author-fill token is *gone* by `approved` and that a phase-deferred token is *still there*, so
  pre-filling a field from memory is caught rather than merely discouraged.
- `specwright.manifest.json` (SW-3): canonical inventory contract declaring where assets live
  (`areas`) and where the docs publish numbers about them (`docClaims`). Stores no counts - they
  are derived from disk at runtime, so adding a command/agent/skill/template means adding the file
  and nothing else.
- Check 7 (docs consistency) in `scripts/validate.{ps1,sh}`: fails the build when a published
  number disagrees with disk. Also fails on a *vacuous* claim (a pattern that matches nothing, i.e.
  a reworded doc that silently disabled its own check) and on an *undeclared* claim (a number no
  `docClaims` entry covers). Closes the gap that let SW-1's drift reach `main` with CI green.
- `scripts/selftest-docs.{ps1,sh}`: negative self-test proving Check 7 still bites, by corrupting a
  throwaway repo copy across four scenarios. Runs in CI on Ubuntu, macOS and Windows.

### Fixed
- `subagent-retro.ps1` terminated its emitted block with `[Console]::Out.WriteLine`, which appends
  `[Environment]::NewLine` - CRLF on Windows - so its output differed from `subagent-retro.sh` by
  exactly one byte on the final line. Both the `<retro-reminder>` and the new `<retro-lessons>`
  block now `Write` an explicitly LF-terminated string. Pre-existing; surfaced by SW-19's
  byte-comparison requirement.
- `selftest-docs.{sh,ps1}` scenarios 2 and 3 had silently stopped testing anything (SW-20). Both
  planted their corruption by string-replacing the literal `**11 slash commands**`; the repo now
  ships 12, so the pattern matched nothing, the sandbox copy was never corrupted, the validator
  correctly passed, and the scenario reported `THE CHECK DID NOT BITE`. Scenario 2's setup guard
  could not catch this because it only checked that the *planted* text was present - and the
  planted value (12) had since become the **true** value already in `README.md`, so the guard
  found the real line and passed vacuously. Scenario 3 had no guard at all. Both counts are now
  derived from disk (plant `true + 1`, which can never collide), and both scenarios assert the
  *transition* rather than the destination, reporting a `fixture setup` failure when the pattern
  does not match. Check 7 itself was never broken - only the proof that it still bites, which had
  been absent since the 12th command landed on an unpushed branch CI never ran. A hardcoded count
  in the selftest was the last instance in the repo of the exact anti-pattern
  `specwright.manifest.json` exists to abolish.
- `subagent-retro`'s debounce state file, an on-disk contract shared between the two
  implementations, was not written in the same shape by both (SW-5): `subagent-retro.ps1` wrote
  the round-trip `o` format with 7 fractional digits while `subagent-retro.sh` wrote whole
  seconds, so only the bash reader ever had to cope with fractions. PowerShell now writes the same
  whole-second `yyyy-MM-ddTHH:mm:ssZ` stamp. The bash reader's two date fallbacks were also both
  wrong on BSD/macOS: neither passed `-u`, so a UTC stamp was read as local time and skewed the
  debounce window by the machine's offset, and the BSD branch handed `date -f` a string with a
  trailing `Z` it would warn about on stderr - breaking the hook's silence. Both branches now
  force UTC and the value is trimmed before parsing. The debounce branch had no fixture coverage
  at all until now; `setup.json` grew a `write` action that plants a file whose content carries a
  `{{UTCNOW-45M}}`-style token resolved at run time, so a state-file fixture cannot rot.
- `spec-gate` path matching disagreed on case (SW-5). `spec-gate.ps1` compared with
  `OrdinalIgnoreCase` throughout; `spec-gate.sh` used case-sensitive `==` and `case` globs, so a
  protected entry of `.specs/Constitution.md` blocked an edit to `.specs/CONSTITUTION.md` under
  PowerShell and allowed it under bash. bash now lowercases both sides for the protected list, the
  allow-listed directory prefixes and the cwd-prefix strip. Case-insensitive is the right
  semantics for a gate, not merely the parity-preserving one: Windows and macOS filesystems are
  case-insensitive by default, so a case-sensitive rule is bypassable there by retyping the path.
- The `spec-gate` basename allow-list let source files through under a documentation name (SW-5).
  Both implementations allow-listed anything called `README*`, so `README.py` bypassed the gate
  outright, and the two disagreed on multi-dot names - bash's `README.*` glob allowed
  `README.old.py` while the PowerShell regex's single optional extension did not match it at all.
  Only EXTENSION-LESS `README`/`CHANGELOG`/`CONTRIBUTING`/`LICENSE`/`NOTICE`/`AUTHORS` are now
  allow-listed by name; everything with an extension is decided by the extension rules, so
  `README.md` is still a doc and `README.old.py` is now correctly gated as Python.
- `spec-gate.sh` applied NO protected paths when `.claude/project-config.json` was absent or
  unparseable (SW-5), while `spec-gate.ps1` applied its built-in defaults - so on a project that
  had not run `/sd:setup` yet, the most common state there is, editing `.specs/constitution.md`
  was blocked under PowerShell and silently allowed under bash. The bash fallback is now the same
  full default document (`.specs/constitution.md`, `.specs/index.md`, `LICENSE` protected;
  `mode: warn`) instead of `{}`. `Get-ProjectConfig` in all three PowerShell hooks now reads the
  config with `-ErrorAction Stop`, since the script-wide `SilentlyContinue` preference could
  otherwise turn a malformed config into a non-terminating error that skips the `catch` and
  returns `$null` rather than the defaults. `prompt-router` and `subagent-retro` were checked for
  the same asymmetry and have none - every value they read has a matching `//` default - which is
  now stated in both scripts so a future read does not quietly reintroduce it.
- Conformance decision objects were too coarse to prove much (SW-5). `spec-gate` decisions kept
  only `decision`/`permissionDecision` and threw away the human-readable `reason`, which the two
  implementations hand-duplicate - the reason strings could have drifted completely and all 20
  cases would still have passed. The decision now carries `reason`, and reports
  `REASON-MISMATCH-BETWEEN-SCHEMA-HALVES` if the legacy and `hookSpecificOutput` copies of it ever
  disagree. `subagent-retro` decisions likewise dropped the measured age and the threshold it was
  compared against, so the two implementations could have disagreed on the arithmetic unnoticed;
  both are now asserted, and `subagent-retro.sh` rounds the age to the nearest minute instead of
  truncating it, matching `subagent-retro.ps1`'s `[Math]::Round`. Every decision object now also
  carries `stderr`, so the repo's "every failure path exits 0 SILENTLY" invariant is actually
  checked rather than assumed - a hook that regressed into printing a diagnostic on every
  invocation used to pass.
- Two bash hook bugs surfaced by the cross-implementation conformance suite (SW-5). `prompt-router`,
  `spec-gate` and `subagent-retro` all read `enabled` with jq's `//` operator, which treats an
  explicit JSON `false` as absent - a project that set `enabled: false` in `project-config.json`
  got a hook that ran anyway; the three scripts now use an `if`/`then`/`else` jq expression that
  compares directly against `false`. Separately, `spec-gate`'s protected-path loop never blocked a
  protected path on Windows because Windows `jq.exe` emits CRLF for `join("\n")` output, leaving a
  trailing `\r` on each path that broke the exact-match comparison; the loop now strips a trailing
  CR before comparing, mirroring the existing strip in `prompt-router.sh`'s keyword loop.
- Three spec stubs in `examples/spec-lint-fixture/broken/` (SW-4, seam 4) raised an unlisted
  `SL011` BLOCK: `BUG-BROKEN-001` and `BUG-BROKEN-008` carried none of the bug template's four
  phase-3 tokens and `RCA-BROKEN-005` carried four of the rca template's seven, because each had
  dropped the enclosing section wholesale. At `draft` a spec must carry at least its template's
  per-phase token count, so all three failed a rule the fixture's expected-findings table does
  not list - which would have read as a linter bug rather than a fixture one. Found by running
  the linter against the tree rather than by inspection, which is the first time the SW-4
  acceptance criterion was executed end-to-end rather than reasoned about.
- Placeholder tokens spelled out inside `<!-- SEEDED: ... -->` comments in the fixture (SW-4,
  seam 4). A token named in a comment is indistinguishable from a real one to any linter that
  scans line-wise rather than parsing, so the comments explaining the placeholder rules were
  themselves seeding phantom findings in a tree whose contract is "these findings and no others".
  The comments now describe tokens in prose.
- `/sd:spec link` inverse map (SW-4) was partial and ambiguous: it accepted 9 relations but
  defined inverses for only 5, so `blocks`, `blocked-by`, `spawned-by` and `superseded-by` had no
  defined other side. `depends-on` and `blocked-by` also asserted the same edge in two spellings.
  `blocked-by` is now an input alias normalized to `depends-on`, and the map is total and closed -
  every stored relation has exactly one inverse, which is what makes link symmetry checkable.
- `/sd:spec validate` required-field rules (SW-4) had drifted from
  `skills/sd-spec-templates/SKILL.md`, the skill that authors the specs: `validate` checked only
  `id`/`type`/`status`/`created` (+`severity` for bug, +`incident_started` for rca), so it passed
  malformed specs missing `target_metric` (perf), `smell` (refactor), `jira` (feature/bug) and
  `incident_resolved` (rca). The rules are now per-type and match the skill.
- `/sd:spec validate` placeholder rule (SW-4) contradicted the templates it validates: "status >=
  `approved` -> no `<<placeholder>>` remaining" failed a *correct* perf spec, whose baseline field
  must still be unfilled at `approved` by the cross-phase rule in `CLAUDE.md`. Author-fill and
  phase-deferred tokens are now separate forms with separate rules.
- Doc count/inventory drift (SW-1): `README.md` listed `/sd:setup` at no gates (`-` -> `2`, matching
  the two approval gates in `commands/setup.md`) and omitted `sd-docs-writer` from
  `sd-evidence-citation`'s "Used by" list (4 agents, not 3).
- Stale `MSSQL` references in the docs, left over from the stack-agnostic database rename
  (`mcp.mssql` -> `mcp.database`): `docs/architecture.md` listed a hardcoded MSSQL tool in
  `sd-debugger`'s tool surface and an `mssql` server in the project-scope MCP table; `README.md`
  named MSSQL in the MCP-friendly summary and the MCP table; `docs/troubleshooting.md` had an
  MSSQL-titled section. All now describe the project-provided database MCP, matching
  `agents/debugger.md` and `templates/project-config.template.json`. Addresses `REVIEW-TODO.md`
  item 5's doc half; the `agents/debugger.md` body-vs-allowlist defect it also names remains open.
- `spec-gate`'s protected-path matching could be bypassed via `..` path traversal under the bash
  hook: `spec-gate.ps1` normalizes `file_path` with `[System.IO.Path]::GetFullPath`, which resolves
  `..`/`.` segments before comparing against `paths.protected`, but `spec-gate.sh`'s `normalize_rel`
  only normalized separators and stripped the cwd prefix - it never collapsed `..`. A path like
  `<cwd>/src/../.specs/constitution.md` reached the protected constitution file while presenting a
  relative form (`src/../.specs/constitution.md`) that matched nothing in `paths.protected`, so
  bash exited 0 and silently allowed editing a protected file that PowerShell correctly blocked.
  `spec-gate.sh` now collapses `.`/`..` segments with pure string processing (no `realpath`,
  `readlink -f`, or `cd`, since the file may not exist yet under `Write` and the decision must not
  depend on filesystem state) before the protected-path and allow-list comparisons, clamping a
  rooted `..` at its own root the same way `GetFullPath` does, and falling back to the raw,
  un-collapsed path when resolution would escape the workspace entirely - matching
  `ConvertTo-RelativePath`'s own fallback branch. Covered by three new conformance fixtures:
  `..` traversing into a protected file, a bare `.` segment, and a benign `..` that resolves to a
  non-protected code file, proving the fix does not over-block.
- The bash-side `..` traversal fix above was one-sided: `spec-gate.ps1` had the mirror-image
  weakness, still live, letting the same class of edit through under PowerShell. Its
  `ConvertTo-RelativePath` called `[System.IO.Path]::GetFullPath($FilePath)` on a RELATIVE
  `file_path`, which resolves it against this hook PROCESS's own working directory rather than the
  `cwd` supplied in the hook payload; the result then failed the base-prefix check and fell through
  to the raw, un-collapsed path, matching nothing in `paths.protected`. A relative
  `src/../.specs/constitution.md` therefore reached the protected constitution file while
  PowerShell exited 0 silently and bash (already fixed) correctly blocked it. Separately,
  `GetFullPath` preserves a trailing path separator, so `<cwd>/.specs/constitution.md/` failed the
  protected-path equality test outright and, since `GetExtension` also returns `""` for a
  trailing-separator path, was not even caught by the code-file rule - a second silent bypass.
  `spec-gate.ps1` now collapses `.`/`..` segments with the same pure string processing as
  `spec-gate.sh`'s `collapse_dot_segments`/`normalize_rel` (a relative `file_path` is collapsed
  directly rather than joined onto the process cwd; a trailing separator collapses away as a
  no-op segment) so the two implementations resolve identically. `prompt-router` and
  `subagent-retro` were checked for the same pattern and do not have it - neither reads
  `tool_input.file_path` or compares a user-supplied path against `paths.protected`. Covered by
  three new conformance fixtures: a relative `..` traversal into the protected constitution file,
  a trailing separator on the protected constitution file, and a benign relative `..` resolving to
  a non-protected code file, proving the fix does not over-block.

## [1.4.0] - 2026-07-05

### Added
- `ROADMAP.md` - published roadmap of near-term, planned, and exploratory work, linked from
  `README.md` (new `## Roadmap` section + Documentation entry). Migrated the forward-looking items
  out of the non-standard `### Planned` subsection that sat under the `1.2.0` changelog entry into
  this dedicated file.
- `/sd:setup` codebase scan (Phase 2.5) - samples the project tree to pre-fill detected facts
  (stack, `paths.{src,tests,docs}`, `commands.*` from the project manifest, and a new ordered
  inside-out `paths.layers` map) into `CLAUDE.md` and `project-config.json`, with a single batch
  confirmation gate. Facts only - constitution rules are never auto-filled. Adds `paths.layers` to
  `templates/project-config.template.json`.
- `/sd:adr` command (11th) + `sd-docs-writer` agent (6th) - drafts a numbered, MADR-style Architecture
  Decision Record under `.specs/_adr/` from a spec's `03-decisions.md` (or an ad-hoc decision), behind one
  hard approval gate. The agent (model `sonnet`, tools Read/Write/Glob/Grep, skill `sd-evidence-citation`)
  writes only the ADR file and never invents decisions; the command owns numbering and supersession links.
  Bumps command count 10 -> 11 and agent count 5 -> 6 across docs and the validators.
- `scripts/smoke-hooks.sh` + `scripts/smoke-hooks.ps1` - pipe fixture Claude Code hook JSON into
  `prompt-router`, `spec-gate`, and `subagent-retro` against a temp `.specs/` tree and assert exit
  codes AND key output substrings, not just "did not crash": keyword-match routing (bash and
  PowerShell must agree), spec-gate allow/warn/block across in-progress / header-only-marker /
  docs-edit / malformed-stdin cases, and subagent-retro naming the real spec ID then debouncing a
  second run. `.github/workflows/ci.yml` adds `macos-latest` to the OS matrix (exercising the
  BSD-specific `stat -f %m` / `date -j -f` fallback branches that only run there) and a smoke-test
  step on every OS.

### Changed
- Removed hardcoded MSSQL/C#/TS references from `agents/debugger.md`, `commands/perf.md`,
  `commands/rca.md`, and `commands/bug.md`, per CLAUDE.md's stack-agnostic rule. `sd-debugger`'s
  tool allowlist no longer bakes in `mcp__mssql__execute_sql`; its "Database discipline" section
  (renamed from "MSSQL discipline") now describes the same read-only SELECT/EXPLAIN discipline
  generically, deferring to whatever database MCP tool or CLI client the project provides.
  `templates/project-config.template.json`'s `mcp.mssql` entry is renamed to `mcp.database`.
  `perf.md`/`rca.md` generalize "MSSQL access (via MCP)" to "database access (via the project's
  MCP tool or CLI)"; `perf.md`'s final-review check drops the C#/TS-specific `dynamic`/`any`
  example in favor of "type-safety escapes for the project's language (as defined in
  `constitution.md`)"; `bug.md`'s failing-test step now references `paths.tests` from
  project-config instead of a hardcoded `tests/<mirrored path>/` with a C#-style example name.
- De-duplicated rules that were copy-pasted from skills into agent bodies and commands (CLAUDE.md:
  "a rule used by multiple agents lives in one `SKILL.md`, never copy-pasted"), replacing each
  copy with a reference to the owning skill: `agents/debugger.md`'s and `agents/reviewer.md`'s
  Anti-patterns sections no longer restate `sd-hypothesis-tree`/`sd-severity-taxonomy`/
  `sd-evidence-citation` (role-specific bullets are kept); `agents/code-explorer.md`'s
  Anti-patterns section no longer restates `sd-evidence-citation`. `commands/feature.md` and
  `commands/refactor.md` no longer inline the atomic task-block format - both now point at
  `sd-atomic-task-format`, which gains a documented "Refactor mode" `Parallel batch` field (the
  field `refactor.md`'s inline copy had already drifted to include while `feature.md`'s copy
  lacked it). `commands/bug.md` and `commands/rca.md` no longer restate the 5-mental-models /
  `(Likelihood x Impact) / Cost-to-verify` method inline - both now point at `sd-hypothesis-tree`.
- `scripts/validate.sh` and `scripts/validate.ps1` now derive their expected install-target
  counts (commands / agents / skills / hooks / templates) from the source tree instead of
  hardcoding them as literals in both files - a new command/agent/skill/template only needs to
  land in its source dir, never a constant bumped in two scripts (this already bit PR #12, which
  had to bump both). Each derived count is asserted `> 0` so an empty or misnamed source dir
  fails loudly instead of vacuously passing Check 5.

### Fixed
- `hooks/bash/prompt-router.sh` emitted `- /sd:0` instead of `- /sd:<workflow>` under bash 3.2
  (macOS system bash): `declare -A` is a bash-4 feature, so the associative arrays silently
  degraded to indexed arrays with all string subscripts arithmetic-evaluating to `0`. Caught by
  the macOS CI smoke test (`validate (macos-latest)` was red since the matrix gained macOS).
  Rewrote keyword matching with parallel indexed arrays; the hook is now bash-3.2 compatible.
- `hooks/powershell/subagent-retro.ps1`'s debounce silently stopped persisting/reading state on
  PowerShell 7+, found by writing `scripts/smoke-hooks.ps1`: (1) `Save-State`'s
  `Split-Path -LiteralPath $StatePath -Parent` throws "Parameter set cannot be resolved" on some
  PS7 builds (`-LiteralPath` there has no `-Parent` parameter set) - the surrounding `try/catch`
  swallowed it, so the state directory/file were never written; switched to `Split-Path -Path`
  (safe here - `-Parent` does no filesystem globbing, only `-Resolve` would). (2) Even once the
  state file wrote, `Test-DebounceElapsed` re-broke: PS7's `ConvertFrom-Json` auto-converts an
  ISO-8601 `...Z` string to a `[datetime]` (PS 5.1 leaves it as a string), and re-`Parse`-ing an
  already-converted `[datetime]` stringifies it with the local culture - dropping the UTC marker -
  so `[datetimeoffset]::Parse` silently re-interpreted it as local time, skewing `$age` by the
  machine's UTC offset exactly like the bug fixed earlier in this file, just triggered a different
  way. Both are PowerShell-only; `hooks/bash/subagent-retro.sh` was unaffected (no bash twin
  change needed).
- `install/install.sh` hardening: aligned to `set -euo pipefail` (was `set -e` only, so unset-
  variable typos and mid-pipeline failures - e.g. a `sha256sum`/`shasum` error - passed silently;
  those two pipelines now end `|| true` since a hash-tool failure is expected-recoverable, not a
  reason to abort); added the same `--prefix` safety guard `uninstall.sh` already had (empty,
  `/`, `\`, or `..` components rejected) to `install/install.ps1` too, so install and uninstall
  accept the same set of prefixes on both platforms - previously only uninstall validated it, so
  `--prefix ../evil` would have written outside the intended tree; quoted the unquoted
  `rel="${f#$src_root/}"` strip pattern (glob-interpreted `$src_root` broke on a repo path
  containing `[`, `*`, or `?`); and added an `ERR` trap that reports how many files already
  landed and the exact `uninstall.sh` command to run if a copy fails mid-install (no full
  transactional rollback - per-file `.bak.*` backups already protect overwritten files).
- Post-1.3.0 docs drift: `README.md`'s tagline said "Ten slash commands, five specialized
  subagents" (now eleven / six); the Commands table was missing `/sd:adr` and listed
  `/sd:feature` at 4 hard gates (the merged review+integration gate makes it 3); the Agents table
  was missing `sd-docs-writer` and listed a hardcoded `MSSQL` tool for `sd-debugger`; the `.specs/`
  tree diagram omitted `_explorations/`, `_reviews/`, `_adr/`; the Roadmap highlights repeated two
  items that already shipped. `ROADMAP.md`'s `## Planned` section still listed the `/sd:setup`
  codebase scan and `sd-docs-writer` agent, both shipped in 1.3.0+ (CHANGELOG is the source of
  truth for shipped work). `docs/usage.md`'s Utility commands section had no `/sd:adr` entry.
  `templates/project-config.template.json`'s `workflow.gates.feature` still listed the pre-merge
  4-gate sequence; collapsed to 3 and marked `_comment`-descriptive since no hook or command reads
  the block. `CONTRIBUTING.md`'s agent frontmatter example omitted the mandated `color:` and
  `skills:` fields. `examples/README.md` gated a promised-features list on "not in v1.0.0", three
  minor versions after v1.0.0; reworded to point at `ROADMAP.md`.
- Phase 0 of `/sd:feature`, `/sd:bug`, `/sd:refactor`, `/sd:perf`, and `/sd:rca` now guards
  against missing or malformed Layer-2 context instead of silently reading `CLAUDE.md`,
  `.specs/constitution.md`, `.claude/project-config.json`, and `.specs/index.md` and letting
  later phases fail on undefined config values. Missing `.specs/`, `.specs/constitution.md`, or
  `.specs/index.md` now STOPs with "No `.specs/` found - run `/sd:setup` first." (matching
  `spec.md`/`release.md`/`adr.md`); malformed `.claude/project-config.json` STOPs naming the file;
  a missing `CLAUDE.md` only WARNs and continues, since the constitution (not `CLAUDE.md`) is the
  binding Layer-2 contract - matching the stance the four utility commands already took.
- `sd-code-explorer`'s `impact-map` task no longer instructs the agent to APPEND to
  `OUTPUT_APPEND_TO` - its tool allowlist has no `Write`/`Edit`, so it physically could not
  perform that write, silently starving `03-decisions.md` (and everything downstream that reads
  it as `IMPACT`). The task now returns the structured analysis as final output; the informational
  `OUTPUT_TARGET` input names the file, and the calling command appends it. `commands/feature.md`
  and `commands/refactor.md` each gained an explicit main-thread append step after the impact-map
  invocation. `commands/perf.md`, `commands/bug.md`, and `commands/rca.md`'s equivalent
  "Append ... to `03-decisions.md`" steps after `sd-debugger` invocations (also write-tool-less)
  are now explicitly labeled as main-thread steps for the same reason.
- `/sd:bug`, `/sd:rca`, and `/sd:perf` now walk every state in `/sd:spec`'s
  `draft -> approved -> in-progress -> done -> archived` machine instead of jumping straight from
  `draft`/`approved` to `done` - a history `/sd:spec status` itself would have refused as an
  illegal transition. `bug.md` sets `approved` at Gate 2 (reproduction confirmed) and
  `in-progress` at the start of Phase 5 (fix implementation); its Gate 3a "abort" (hypothesis tree
  exhausted) now passes through `in-progress` on its way to `done` instead of jumping directly
  from `approved`. `rca.md` sets `approved` at Gate 3 (root cause confirmed) and `in-progress` at
  the start of Phase 4 (isolate + document) - RCAs produce no code, so "in-progress" now means
  report-writing is underway. `perf.md` sets `draft` at spec creation (previously jumped straight
  to `approved` at Gate 1) and `in-progress` at the start of Phase 4 (the per-hotspot loop),
  including the Gate 2 Case A shortcut (baseline already meets SLA) which now passes through
  `in-progress` before `done`. `docs/troubleshooting.md`'s "Illegal status transition" entry no
  longer tells users that `/sd:rca` intentionally skips straight to `done`.
- `/sd:setup` now migrates `.claude/*` drift instead of exiting blind on a `complete` project. A
  new Phase 1.5 (drift check & migrate) runs whenever `.claude/project-config.json` or
  `.claude/settings.json` exists (states `complete` and `partial`) and rule-based-compares them
  against the loaded templates - catching renamed engine paths (`hooks/ck` -> `hooks/sd`), the
  `$schema` URL, `/ck:*` // `ck:*` names in `_use` docs, newly-introduced fields
  (`ticket.snapshot`, `paths.layers`), pinned model IDs (`claude-sonnet-4-6` -> `sonnet`), and
  stale `settings.local.json` permission paths. Every change is previewed in one batch gate
  (silence is not approval) and each file is backed up `.bak.<timestamp>` before a targeted,
  value-preserving patch. Fixes scaffolded projects whose three hooks silently pointed at the
  non-existent `~/.claude/hooks/ck/` directory after the `ck` -> `specwright` rename.
- `/sd:setup` Phase 7 (and Phase 1.5) now verify every hook `command` path in
  `.claude/settings.json` resolves to a file on disk, warning loudly when a hook is not firing.
- `hooks/powershell/subagent-retro.ps1`, `prompt-router.ps1`, and `spec-gate.ps1` no longer assign
  parsed hook JSON to `$input` - PowerShell's reserved automatic pipeline variable. Assigning to it
  threw a non-terminating `ParameterBindingException` on every real (piped/redirected) stdin
  invocation, leaving it unbound and causing every PowerShell hook to exit silently before reading
  any input. Renamed to `$hookInput` in all three files.
- `hooks/bash/spec-gate.sh` in-progress detection now requires `in-progress` and a spec ID on the
  SAME line, matching `spec-gate.ps1` and `prompt-router.sh`'s existing same-line semantics. The
  previous two independent file-wide `grep`s let an `in-progress` legend/header line combine with a
  spec ID on an unrelated `done` row, so bash allowed a code edit that PowerShell would warn/block
  on the identical `.specs/index.md`.
- `commands/feature.md` subagent invocations now use the field names `sd-spec-architect` and
  `sd-code-explorer` actually read: `TICKET_CONTEXT` (was `TICKET_DATA`), `TASK`/`SPEC`/`IMPACT`
  (was `TASK_TYPE`/`SPEC_REF`/`IMPACT_REF`), a full `feature.template.md` filename (was the bare
  `feature`), and both `refine` invocations now carry the required `SPEC` path. `sd-reviewer`
  invocations, which legitimately use `TASK_TYPE`/`SPEC_REF` as their own contract, are unchanged.
  `commands/refactor.md`'s characterization-test loop now invokes `sd-implementer` with
  `TASK_DETAILS`/`SPEC_REF`/`WORKFLOW_TYPE` instead of the unrecognized `TASK_TYPE`, matching every
  other implementer invocation in the repo.
- `/sd:spec validate` no longer requires `01-plan.md`/`02-tasks.md` for in-progress bug and perf
  specs. Only `/sd:feature` and `/sd:refactor` produce those artifacts; `/sd:bug` and `/sd:perf`
  go straight from spec to investigation/baseline artifacts, so the old "except RCA" exemption
  reported FAIL on every correctly executed bug/perf spec. Also corrected the same overgeneralized
  claim in `docs/usage.md`'s resume heuristic.
- `hooks/powershell/subagent-retro.ps1`'s debounce check now parses `lastReminderUtc` as UTC via
  `[datetimeoffset]::Parse(...).UtcDateTime` instead of `[datetime]::Parse(...)`, which returned a
  local-`Kind` value silently converted from the UTC string, skewing `$age` by the machine's UTC
  offset (negative for ~UTC offset hours on UTC+N machines, wrongly suppressing reminders; always
  past-debounce on UTC-N machines, never suppressing). The bash twin was already correct
  (epoch seconds throughout).
- `hooks/powershell/prompt-router.ps1` now applies the built-in default keyword list PER WORKFLOW
  when the loaded `.claude/project-config.json` has no list (or an empty list) for that workflow,
  matching `prompt-router.sh`'s per-workflow fallback. Previously PS only fell back to defaults
  when the config file itself was absent/unparseable, then silently skipped any workflow whose
  list was `$null` once a config file existed - so a valid config that simply omitted
  `workflow.keywords` (or one workflow's entry) lost keyword routing hints on Windows while bash
  kept emitting them from defaults on Linux/macOS. The five built-in keyword lists are unchanged,
  just reused instead of duplicated.
- Agent frontmatter `tools:` allowlists and body instructions in `agents/code-explorer.md`,
  `agents/debugger.md`, `agents/reviewer.md`, `agents/implementer.md`, `agents/spec-architect.md`,
  `commands/explore.md`, and `skills/sd-evidence-citation/SKILL.md` referenced MCP tool names that
  no longer exist on the live servers (`mcp__gitnexus__search`/`get_file`/`find_references`/
  `get_call_graph`/`list_symbols`, `mcp__context7__get-library-docs`, `mcp__tavily__search`),
  so every "verify via MCP" instruction pointed at a dead tool. Remapped to the current GitNexus
  surface (`query`, `context`, `impact`, `list_repos`) and renamed `context7`/`tavily` tools to
  their current names (`query-docs`, `tavily_search`), keeping each agent's frontmatter allowlist
  and body usage in parity.
- `hooks/bash/prompt-router.sh`'s per-workflow keyword lookup silently dropped every keyword but
  the last in a workflow's list when `.claude/project-config.json` defined `workflow.keywords`:
  some `jq` builds (observed with a Windows `jq.exe`) emit CRLF line endings for `join("\n")`
  output even from an LF-only input, so `while IFS= read -r kw` left a trailing `\r` on every
  keyword but the final one, and `[[ "$prompt_lower" == *"$kw_lower"* ]]` never matched a
  CR-suffixed keyword. Found by piping real prompts through the hook against a live project's
  config (not the smoke-test fixture, which omitted `workflow.keywords` and only ever exercised
  the hardcoded default-list fallback). Fixed by stripping a trailing `\r` off each line read from
  the list; also added a `workflow.keywords` block to both `scripts/smoke-hooks.sh` and
  `scripts/smoke-hooks.ps1` fixtures so the `jq`/config-driven path is exercised going forward.
  `hooks/powershell/prompt-router.ps1` was unaffected (native `ConvertFrom-Json`, no `jq`).

---

## [1.3.0] - 2026-06-18

Release-tooling and CI hardening. Adds the `/sd:release` command (10th), a single-command repo invariant
validator with a Windows + Ubuntu CI matrix, an uninstaller, and a batch of command/agent refinements.

### Added
- `/sd:release` command (10th command) - generates release notes from completed specs: collects
  every spec in `done` status (feature / bug / refactor / perf; RCA excluded), groups them into
  Keep-a-Changelog sections (FEAT -> Added, BUG -> Fixed, REF/PERF -> Changed) under an inferred
  SemVer heading (any feature -> minor bump, else patch; major never auto-inferred), then
  transitions each `done -> archived`. One hard gate previews the notes and the archive plan
  before any write; `--dry-run` stops before writing. Pure file ops, no subagent (mirrors
  `/sd:spec`). Gives the `done` (merged, unshipped) vs `archived` (shipped) states a concrete
  meaning.
- `scripts/validate.ps1` + `scripts/validate.sh` - one command that runs every documented engine
  invariant: pure-ASCII scan of `*.ps1`, `bash -n` on `*.sh`, hook-pair parity, agent `model:`
  alias-only check, install-target file counts (real install to a temp base), and a non-empty
  `[Unreleased]` CHANGELOG gate. Exit 1 on any failure.
- `.github/workflows/ci.yml` - runs `validate` on push/PR across a Windows + Ubuntu matrix, plus an
  install -> uninstall round-trip per the `CLAUDE.md` sandbox recipe.
- `install/uninstall.ps1` + `install/uninstall.sh` - removes the five `<base>/<area>/sd/`
  directories with dry-run preview, confirmation prompt (`-Force`/`--force` to skip), and
  per-project cleanup reminders (`.claude/settings.json` hook wiring, `.claude/.hookstate/`).

### Changed
- `scripts/validate.{ps1,sh}` Check 6 now treats an empty `[Unreleased]` section as passing when the
  section immediately below it is a dated `[x.y.z] - <date>` release heading (the freshly cut version),
  so a clean post-release CHANGELOG no longer fails CI. A non-release-state empty `[Unreleased]` still
  fails, preserving the "every PR adds a changelog line" invariant.
- `/sd:perf` Gate 6 now structurally refuses a no-measurable-gain "keep" instead of merely warning about
  it in prose. The gate branches on the noise check: a measurable improvement still offers `keep` /
  `revert`, but a within-noise result defaults to `revert` and allows `keep` only as an explicit logged
  constitution exception (decision `kept (exception)` + a reason recorded to `05-retro.md`). With no
  reason supplied, the change is reverted.
- `docs/architecture.md` gains two reference sections: a "Command -> agent routing" tree showing the
  subagent fan-out per command (and the three file-ops commands that invoke none), and an "Artifact
  ownership" table mapping each `.specs/<ID>/` file to its producing phase/agent and downstream readers.
  Consolidates routing/ownership that previously lived only in scattered command files.
- `/sd:setup` Q1 and the `sd-spec-architect` ticket protocol now state explicitly that automatic
  ticket-context fetch is JIRA-only: GitHub Issues and Linear are still recorded as the project
  tracker (for prompt-hook ID recognition), but their ticket content is not auto-fetched - paste it
  into the prompt instead. The ticket snapshot protocol is documented as JIRA-specific. Closes the
  silent degradation where non-JIRA projects got no ticket fetch and no explanation.

### Fixed
- `/sd:spec status` now spells out the illegal-transition refusal instead of the vague "REFUSED with
  explanation": it prints the current state, the requested state, the valid next state(s) from the
  state machine, and the shortest legal path to the requested state when reachable (e.g. `draft -> done`
  is rejected with the hint `draft -> approved -> in-progress -> done`). No file is mutated on refusal.
- `/sd:bug` Phase 3 no longer assumes a confirmed root cause always arrives. The investigation loop
  previously said "Continue until one is CONFIRMED" with no exit, so a bug whose every hypothesis is
  rejected/inconclusive had no defined stopping point. Added Gate 3a (hypothesis tree exhausted): the
  loop now terminates on a CONFIRMED hypothesis OR an exhausted tree, and the exhausted case STOPs and
  asks the user to re-enumerate (with new evidence), add observability, or abort as "root cause not
  found" - never guessing a fix from an unconfirmed tree.
- `install/install.sh` marked executable (mode `100755`, matching `uninstall.sh`); it was `100644`,
  so the documented `./install/install.sh` invocation failed with "Permission denied" on a fresh
  Linux checkout. Surfaced by the new CI round-trip.
- `install/README.md`: total file count corrected (21 -> 32), `skills/sd/` added to the layout
  tree, install table, and manual uninstall commands (skills were missed since 1.1.0), and the
  `-Prefix`/`--prefix` option documented.

---

## [1.2.0] - 2026-06-12

Pattern conformance release. Introduces `sd-pattern-discipline` (the 6th skill), wires it into spec-architect/implementer/reviewer, adds the `Pattern refs` task field, and closes the gap where impact analysis never reached implementation.

### Added
- `sd-pattern-discipline` skill (6th skill) - pattern discovery and adherence rules: precedent
  sampling, `Pattern refs` authoring (spec-architect), following (implementer), and conformance
  review (reviewer). Fixes implementations that ignored the target codebase's structure.
- `Pattern refs` task field in `sd-atomic-task-format` - 1-3 `file:line` precedent citations the
  implementer reads before writing. Required for tasks creating a new file or public symbol;
  absent field is treated as `none` (backward compatible with existing `.specs/` folders).
- `sd-code-explorer` impact-map output gains a "Precedents & conventions" section: nearest
  similar implementations, observed naming/layout conventions, and reusable existing utilities.
- Ticket snapshot protocol in `sd-spec-architect`: fetched JIRA tickets are now persisted to
  `.specs/<ID>/04-artifacts/ticket/` together with related tickets (1 hop, capped) and linked
  Confluence pages (capped). Configurable via `ticket.snapshot` in project-config (enabled by
  default, absent means enabled); fetch failures never block spec creation.
- `CLAUDE.md` added to the specwright repo itself (was previously missing).

### Changed
- `/sd:feature`, `/sd:bug`, `/sd:refactor`, `/sd:perf` now pass `IMPACT_REF` (`03-decisions.md`)
  to `sd-implementer`, closing the gap where impact analysis never reached implementation.
- `sd-spec-architect`, `sd-implementer`, `sd-reviewer` wired to the `sd-pattern-discipline`
  skill; implementer's convention discipline expanded to cover new files, new-symbol naming, and
  reuse-before-write for helpers.
- `sd-spec-architect` Atlassian tool allowlist: added `getJiraIssueRemoteIssueLinks` and
  `getConfluencePage` (snapshot collection).

### Fixed
- `sd-spec-architect` tool allowlist referenced `mcp__atlassian__searchJiraIssues`, which is not
  a real Atlassian MCP tool name - corrected to `mcp__atlassian__searchJiraIssuesUsingJql`.
  Slug-based ticket search could never have resolved before.

> Forward-looking items that previously lived here moved to [`ROADMAP.md`](ROADMAP.md).

---

## [1.1.0] - 2026-06-03

Architecture refresh. Adds an Agent Skills layer and upgrades the `spec-gate` hook to the CLI's new permission-decision schema (forward-compatible, no break for older CLIs).

### Added

#### Skills (5, new `skills/sd/` layer)
A skill is a markdown rule pack referenced by agents from their YAML frontmatter (`skills: [...]`). Skills de-duplicate rules shared across multiple agents, keep agent prompts smaller, and make the rules auditable in one place.

- `sd-severity-taxonomy` - Severity rules (BLOCK / WARN / SUGGEST / PASS) and the mandatory review output format. Applied by `sd-reviewer`.
- `sd-hypothesis-tree` - Enumerate / verify protocol with the 5 mental models, `(L × I) / C` score formula, and the proximate-vs-root "why" ladder. Applied by `sd-debugger`.
- `sd-atomic-task-format` - The 9-field atomic task block plus canonical enums (`Step type`, `Complexity`, `Reversibility`). Applied by `sd-spec-architect` (authoring) and `sd-implementer` (consuming).
- `sd-evidence-citation` - `file:line` citation discipline, snippet length rules, evidence taxonomy, grouping. Applied by `sd-code-explorer`, `sd-debugger`, `sd-reviewer`.
- `sd-spec-templates` - Per-template authoring rules (feature / bug / refactor / perf / rca). Applied by `sd-spec-architect`.

#### Agent frontmatter
- All 5 agents now declare a `skills: [...]` list in frontmatter.
- All 5 agents now declare a `color:` field for terminal rendering.
- Agent body sizes reduced where content moved into a referenced skill.

#### Installers
- `install/install.ps1` and `install/install.sh` now install `skills/<prefix>/` alongside `commands/<prefix>/`, `agents/<prefix>/`, `hooks/<prefix>/`, `templates/<prefix>/`.

### Changed

#### Hooks - dual-format block output
Both `spec-gate.ps1` and `spec-gate.sh` now emit a single JSON object that carries **both** the new and legacy schemas. The CLI reads whichever it understands:

```json
{
  "decision": "block",
  "reason": "...",
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "..."
  }
}
```

This is forward-compatible with CLI builds that read `hookSpecificOutput.permissionDecision` and backward-compatible with builds that read the top-level `decision` field. No version probing needed.

#### Documentation
- `README.md` - Added Skills section and updated Layer 1 diagram to include `skills/sd/`.
- `docs/architecture.md` - Added "Agent skills" section explaining the rule-pack pattern; added the dual-format block-output schema to the `spec-gate` description.

---

## [1.0.0] - 2026-01-15

Initial public release.

### Added

#### Slash commands (9, all under `sd:` namespace)
- `/sd:feature` - Spec-driven feature workflow with 4 hard gates (spec, plan, review, integration).
- `/sd:bug` - Root-cause-first bug fix workflow with 5 hard gates (symptom, reproduction, root cause, failing test, regression).
- `/sd:rca` - Incident root-cause analysis (output IS the spec; no code change).
- `/sd:refactor` - Coverage-gated refactor workflow with 6 hard gates (spec, coverage threshold, post-test, plan, per-batch tests, holistic review).
- `/sd:perf` - Baseline-first performance workflow with 8 hard gates (target, baseline, hotspot, hypothesis, correctness, keep/revert, regression, final review).
- `/sd:spec` - Spec registry management (list / show / status / link / archive / revive / search / validate / stats / help).
- `/sd:explore` - Read-only code exploration via the `sd-code-explorer` agent.
- `/sd:review` - Standalone constitution-compliance review on a path, recent edits, or a spec.
- `/sd:setup` - Idempotent project scaffold (CLAUDE.md + .claude/ + .specs/ + project-config.json).

#### Subagents (5, cost-aware model assignment)
- `sd-spec-architect` (sonnet) - Creates and refines specs / plans / tasks.
- `sd-code-explorer` (haiku) - Read-only code navigation with citation discipline.
- `sd-debugger` (sonnet) - Hypothesis-tree investigation with sequential-thinking.
- `sd-implementer` (haiku) - Executes ONE atomic task with scope discipline.
- `sd-reviewer` (sonnet) - Severity-tagged compliance review (BLOCK / WARN / SUGGEST / PASS).

All agents use **portable model aliases** (`sonnet`, `haiku`) - they auto-update with the latest Anthropic models and are not pinned to specific versions.

#### Hooks (3, cross-platform)
- `prompt-router` (UserPromptSubmit) - Keyword routing and spec-context injection.
- `spec-gate` (PreToolUse on Edit / Write / MultiEdit) - Guard rail blocking code edits when no in-progress spec is registered.
- `subagent-retro` (SubagentStop) - Reminder to update stale retros after subagent runs.

Each hook ships in two flavours:
- `hooks/powershell/*.ps1` - PowerShell 5.1+ (pure ASCII, Windows-1252 safe).
- `hooks/bash/*.sh` - Bash 4+ with `jq` (graceful fallback if `jq` missing).

#### Templates (9)
**Setup templates (4):**
- `CLAUDE.template.md` - Thin orchestrator pointing at `.specs/`.
- `constitution.template.md` - YAML frontmatter + 8 governance sections.
- `project-config.template.json` - Machine-readable config (paths, commands, models, MCP, hook modes).
- `settings.template.json` - Claude Code hook wiring (PowerShell variant by default).

**Spec templates (5):**
- `feature.template.md`
- `bug.template.md` (root-cause and fix fields intentionally empty until Phase 3).
- `refactor.template.md`
- `perf.template.md` (baseline and results log intentionally empty until measured).
- `rca.template.md`

#### Installer
- Cross-platform: `install/install.ps1` (Windows) and `install/install.sh` (Unix/macOS).
- Content-hash (SHA256) comparison to skip identical files.
- Timestamped backups (`*.bak.<yyyyMMdd-HHmmss>`) before overwrites.
- `--dry-run`, `--force`, and `--base-path` options.
- Interactive y/N/all prompt on existing files.

#### Documentation
- `README.md` - GitHub landing page.
- `docs/architecture.md` - 3-layer architecture, lifecycle, cost model.
- `docs/usage.md` - Command-by-command reference.
- `docs/walkthrough.md` - End-to-end fictional project demo.
- `docs/troubleshooting.md` - Common issues and fixes.
- `install/README.md` - Install guide.
- `CONTRIBUTING.md` - PR process and dev guidelines.

### Design properties
- **Stack-agnostic** - Agents read `CLAUDE.md` and `constitution.md` at runtime; no hardcoded language, framework, or layer assumptions.
- **Hard gates** - Workflows refuse to proceed without explicit user approval at named checkpoints.
- **Spec as durable memory** - Every workflow produces searchable artifacts under `.specs/<ID>/`.
- **Cost-aware models** - Heavy reasoning (spec, debug, review) on sonnet; mechanical execution and read-only exploration on haiku.

### Known compatibility
- Claude Code CLI: tested with the released version current at January 2026.
- Operating systems: Windows 11 + PowerShell 5.1 / 7.x, macOS 13+, Ubuntu 22.04+.
- Optional MCP servers: Atlassian, Context7, sequential-thinking, GitNexus, MSSQL, Playwright, Tavily.

[Unreleased]: https://github.com/developzoneio/specwright/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/developzoneio/specwright/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/developzoneio/specwright/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/developzoneio/specwright/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/developzoneio/specwright/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/developzoneio/specwright/releases/tag/v1.0.0
