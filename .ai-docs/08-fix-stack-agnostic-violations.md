# FIX: MSSQL / C# / TS references violate the stack-agnostic rule

- Priority: P2
- Area: `agents/debugger.md`, `commands/perf.md`, `commands/rca.md`, `commands/bug.md`
- Status: VERIFIED (agent-audited with quotes; re-verify each line before editing)
- Suggested branch: `fix/stack-agnostic-violations`

## Problem

CLAUDE.md rule 4: "Stack-agnostic, no exceptions... An agent that hardcodes a stack is a bug."
CLAUDE.md:9: "The engine must stay generic — all project specifics are read at runtime from
Layer 2." Violations:

1. `agents/debugger.md:6` lists `mcp__mssql__execute_sql` in the tool allowlist, and the body
   has a whole "MSSQL discipline" section (`:91-98`) plus usages at `:44,:59`. A
   Postgres/MySQL/Mongo project inherits a dead SQL-Server-specific tool.
2. `commands/perf.md:262`: "MSSQL access (via MCP) for hotspot analysis is SELECT / EXPLAIN only."
3. `commands/rca.md:94`: "For MSSQL, SELECT / EXPLAIN only" and `rca.md:155`: "MSSQL access
   (via MCP) is SELECT / EXPLAIN only."
4. `commands/perf.md:230`: reviewer checks "no `dynamic` (C#) / `any` (TS) sneaked in" —
   language-specific.
5. `commands/bug.md:157` hardcodes `tests/<mirrored path>/` and `:159` uses a C#-style test
   name example instead of referencing `paths.tests` from project-config.

## Fix

Generalize; keep the DISCIPLINE (read-only DB access, no type-safety erosion), drop the STACK:

1. debugger: remove `mcp__mssql__execute_sql` from the allowlist. Rewrite the MSSQL section
   stack-neutrally, e.g. "If the project provides a database MCP tool (see project-config /
   the project's CLAUDE.md), queries are read-only: SELECT / EXPLAIN equivalents only. Never
   INSERT/UPDATE/DELETE/DDL." Note: how a project injects extra MCP tools into a shipped agent
   allowlist is an open design question — if no mechanism exists, the honest fix is prose that
   says DB evidence goes through Bash CLI clients or a project-provided tool, and the agent
   must not assume one exists.
2. perf/rca: replace "MSSQL access (via MCP) ... SELECT / EXPLAIN only" with "database access
   (via the project's MCP or CLI) is read-only: SELECT / EXPLAIN only."
3. perf.md:230: replace the C#/TS examples with a generic phrasing like "no type-safety
   escapes for the project's language (as defined in constitution.md) sneaked in" — the
   constitution is the Layer-2 home for such rules.
4. bug.md:157-159: reference `paths.tests` from `.claude/project-config.json` and make the
   example language-neutral (or explicitly label it "example, adapt to project conventions").

## Acceptance criteria

1. `grep -rni "mssql\|dotnet \|npm test\|C#\|(TS)" agents/ commands/ skills/ templates/`
   returns no stack-coupling hits (case-by-case: quoted examples explicitly labeled as
   examples in templates may stay — judgment call, lean toward removal in engine files).
2. The read-only DB discipline still exists, phrased stack-neutrally.
3. `scripts/validate.sh` passes.

Add a CHANGELOG `### Changed` entry under `## [Unreleased]`.
