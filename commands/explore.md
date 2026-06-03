---
description: Read-only code exploration via sd-code-explorer. Single subagent invocation. No spec created.
argument-hint: <target or query>
---

# /sd:explore

Fast, read-only code navigation. One `sd-code-explorer` invocation, no spec is created, no code is modified. Optional save to `.specs/_explorations/`.

**Argument**: `$ARGUMENTS` -> free-form query.

---

## Phase 0 - Bootstrap

1. Read `.claude/project-config.json` for paths and MCP servers (GitNexus enabled?).
2. Read `CLAUDE.md` for stack hints (for query intent parsing).
3. **Do NOT** require constitution or index. This command runs on any project state, including fresh repos with no `.specs/`.

---

## Phase 1 - Parse intent

Inspect `$ARGUMENTS` to detect intent. Detect by keyword first, fall back to `pattern` if nothing matches.

| Pattern in query | Detected intent | `INTENT` value |
|---|---|---|
| "where is <X>", "define <X>", "definition of <X>" | Find definition | `definition` |
| "who calls <X>", "callers of <X>", "uses of <X>" | Find callers | `callers` |
| "trace <X>", "how does <X> flow", "follow <X>" | Trace execution | `trace` |
| "what depends on <X>", "impact of changing <X>" | Impact map | `impact` |
| "show all <X>", "list <X> patterns", "find all <pattern>" | Pattern search | `pattern` |
| "show structure", "overview", "layout of <module>" | Structural overview | `structure` |
| anything else | Default | `pattern` |

Print: "Detected intent: <INTENT>. Routing to sd-code-explorer."

---

## Phase 2 - Invoke `sd-code-explorer`

Invoke with:
- `TASK = standalone`
- `DETECTED_INTENT = <INTENT from Phase 1>`
- `QUERY = $ARGUMENTS`
- `GITNEXUS_AVAILABLE = <true|false from project-config.mcp.gitnexus.enabled>`

Explorer routes internally based on `DETECTED_INTENT`:
- `definition` -> GitNexus `list_symbols` + `get_file`, fallback to `Grep` for definition markers.
- `callers` -> GitNexus `find_references`, fallback to `Grep` for invocation patterns.
- `trace` -> GitNexus `get_call_graph` (1-2 hops).
- `impact` -> direct callers (1-hop) + transitive (2-3 hop) + tests touching the target + DI / config refs.
- `pattern` -> `Grep` with refined query, return file:line snippets.
- `structure` -> directory listing + top-level symbols per file.

Explorer's output discipline: every finding cites `file:line`. No prose without citations.

---

## Phase 3 - Present output

1. Display the explorer's findings inline.
2. Group by source file when more than 5 hits in one file.
3. At the bottom, offer:

> Save this exploration? (yes / no)

- `no` (default if user does not respond positively) -> end.
- `yes` -> proceed to save:
  1. Slugify the query for a filename: lowercase, alphanumerics + hyphens, max 40 chars.
  2. Write to `.specs/_explorations/<slug>-<YYYYMMDD-HHmm>.md`.
  3. File contents:
     ```
     ---
     type: exploration
     query: "<original query>"
     detected_intent: <INTENT>
     created: <ISO timestamp>
     ---

     # Exploration: <query>

     <explorer output>
     ```
  4. Print the saved path.

The `.specs/_explorations/` folder is NOT tracked in `.specs/index.md` - it's a scratchpad, not a workflow spec.

---

## Rules (hard constraints)

- Read-only. Code-explorer's tool allowlist does not include `Write`, `Edit`, `MultiEdit`, or `Bash` write modes. The command MUST NOT escalate.
- No spec lifecycle is started. No `00-spec.md` is created.
- Every finding cites `file:line`. If a finding has no citation, the explorer is misbehaving and should be re-prompted.
- If GitNexus is disabled or unavailable, fall back to grep / read. Tell the user "GitNexus disabled, using grep fallback - results may be less precise on transitive callers".
- If the user follows up an exploration with "now fix X" or "now refactor X", REDIRECT to the appropriate workflow command (`/sd:bug`, `/sd:refactor`, etc.). Do not implement inline.
- Save destination is always `.specs/_explorations/`. If `.specs/` does not exist, create the underscore folder ad-hoc; this does not require `/sd:setup`.
