# FIX: stale MCP tool names baked into agents and skills

- Priority: P2
- Area: `agents/code-explorer.md`, `agents/debugger.md`, `agents/reviewer.md`,
  `agents/implementer.md`, `agents/spec-architect.md`, `skills/sd-evidence-citation/SKILL.md`
- Status: VERIFIED against a live MCP environment on 2026-07-02
- Suggested branch: `fix/stale-mcp-tool-names`

## Problem

Agent tool allowlists and body instructions reference MCP tool names that no longer exist in
the current servers. Every "verify via MCP" instruction currently points at a dead name, and
the graceful-degradation checks (e.g. "test with a cheap call") test the wrong tool.

### GitNexus — all five referenced names are gone

Referenced in `agents/code-explorer.md:6`, `agents/debugger.md:6`, `agents/reviewer.md:6`
(frontmatter) and in explorer body routing at `code-explorer.md:20,:94,:102,:110,:126`:

`mcp__gitnexus__search`, `__get_file`, `__find_references`, `__get_call_graph`,
`__list_symbols` — none exist.

The live GitNexus server exposes: `query`, `context`, `impact`, `api_impact`, `cypher`,
`route_map`, `tool_map`, `detect_changes`, `rename`, `list_repos`, `group_*`, `shape_check`.

Suggested remap (validate against the actual server docs / gitnexus-guide skill before
committing): symbol/definition lookup -> `query` or `context`; find references / impact ->
`impact` or `api_impact`; call graph / traces -> `route_map` or `cypher`; cheap availability
probe -> `list_repos`.

### context7 — renamed

`mcp__context7__get-library-docs` -> `mcp__context7__query-docs`.
Occurrences: `agents/debugger.md:6,:45,:107`, `agents/implementer.md:6,:125,:157`,
`agents/spec-architect.md:6`, `skills/sd-evidence-citation/SKILL.md:56`.
(`mcp__context7__resolve-library-id` is still correct.)

### tavily — renamed

`mcp__tavily__search` -> `mcp__tavily__tavily_search`.
Occurrences: `agents/debugger.md:6,:45`, `skills/sd-evidence-citation/SKILL.md:57`.

## Fix

1. Update frontmatter `tools:` allowlists AND every body mention consistently — grep for
   `mcp__gitnexus__`, `mcp__context7__`, `mcp__tavily__` across `agents/` and `skills/`.
2. The shared skill `sd-evidence-citation` must be updated too, or agent fixes are incomplete.
3. Keep allowlists MINIMAL (CLAUDE.md rule 5): map each old tool to the single closest new
   tool; do not add the whole new tool family.
4. Precedent: CHANGELOG already records this class of fix
   (`searchJiraIssues` -> `searchJiraIssuesUsingJql`).

## Consideration while here (do not scope-creep)

MCP names drift over time and this engine ships to arbitrary machines. Consider adding one
sentence to each agent's MCP section: "If a listed MCP tool is unavailable, fall back to
Grep/Read and note the degradation" — the explorer already has this pattern; ensure the others
match. A full "MCP tool names in project-config" indirection is a separate design decision —
note it in ROADMAP if desired, do not build it here.

## Acceptance criteria

1. `grep -rn "get-library-docs\|mcp__tavily__search\b\|mcp__gitnexus__search\|get_file\|find_references\|get_call_graph\|list_symbols" agents/ skills/` returns nothing.
2. Every MCP tool named in any agent frontmatter also appears (or is covered by a wildcard) in
   the body's usage instructions, and vice versa.
3. `scripts/validate.sh` passes.

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
