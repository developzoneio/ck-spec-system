# sd-evidence-citation

Citation discipline for specwright agents. Every finding, claim, or observation must be anchored to evidence. This skill applies to `sd-code-explorer`, `sd-debugger`, and `sd-reviewer`.

---

## The core rule

**Every finding cites `file:line`.** Not `file`. Not `src/`. Exactly `file:line`.

A finding without a citation is not a finding — it is a guess. Re-prompt yourself before outputting.

---

## Citation formats by context

### Code locations
```
`src/Payments/PaymentHandler.cs:84`
```
Always use the relative path from the project root. Follow with a 1–5 line snippet showing the suspect logic (not more — tell the caller to `Read` directly for longer context).

### Log lines
```
`logs/2025-05-01T14:23:11Z` — "NullReferenceException in PaymentHandler.ProcessAsync"
```
Save raw log artifacts to `EVIDENCE_DIR/<hypothesis-id>-logs.txt`.

### Database query results
Save to `EVIDENCE_DIR/<hypothesis-id>-db.txt`. Cite as:
```
`EVIDENCE_DIR/H1-db.txt` — EXPLAIN shows full-table scan on Orders (est. 1.2M rows)
```

### Web / doc references
```
`https://docs.example.com/api/v2/foo` — "Method returns null when the key does not exist (undocumented)"
```

### Constitution references (reviewer)
```
§1.1 layer dependency direction
§6 forbidden patterns
```
Every BLOCK or WARN must pair a `file:line` with a `§N.M` anchor.

---

## What counts as evidence

| Type | Acceptable | Not acceptable |
|---|---|---|
| Code | `file:line` + snippet | "I recall the code does X" |
| Logs | Artifact path + quoted line | "Logs probably show..." |
| DB | Query output (read-only) | "The table is probably slow" |
| Library | `mcp__context7__get-library-docs` result | Training-data memory |
| Web | `mcp__tavily__search` result + URL | General knowledge |

If evidence is unavailable (e.g. no prod log access), state it explicitly: "Evidence unavailable — log access required. Marking INCONCLUSIVE."

---

## Snippet discipline

- Snippets are **1 to 5 lines max**.
- Longer context → instruct the caller: "Read `src/.../foo.cs` lines 80–120 for full context."
- Never truncate a snippet mid-expression (e.g., cut at the closing `}` if needed).
- Redact secrets if logs appear in output.

---

## Output grouping

When a query produces >5 results in one file, group them:
```
**`src/Orders/OrderService.cs`** (8 hits)
  - :45  ...
  - :112 ...
  - :234 ...
  (+ 5 more — narrow query or Read file directly)
```

Total results per query: cap at 50. If hit, tell the caller: "50-result cap reached — narrow the pattern."

---

## Anti-patterns

- "I noticed that..." with no `file:line` — invalid. Re-prompt.
- Trusting training-data memory over a live grep — stale by default; verify.
- Citing a directory instead of a file (`src/Payments/` is not a citation).
- Producing findings for vendored / generated directories (`node_modules/`, `bin/`, `obj/`) without explicit caller request.
- Inventing log lines or fabricating query results — verifiable fraud; immediate trust loss.
