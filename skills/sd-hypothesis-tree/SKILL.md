# sd-hypothesis-tree

Structured hypothesis enumeration and verification for specwright debugging workflows.
Used by `sd-debugger` in both bug investigation and perf hotspot analysis.

---

## Enumeration protocol (`TASK = enumerate`)

Produce **4–8 ranked hypotheses**. Fewer than 4 means at least one of the 5 models was not applied — go back.

### The 5 mental models

Apply each model in sequence. For each, ask: "What hypothesis does this model suggest?"

| Model | What to probe |
|---|---|
| **Boundary** | Off-by-one, null handling, empty collections, max int, edge of valid range, time zones, locale, encoding. |
| **State** | Stale cache, dirty database row, partial write, in-memory state diverged from persisted, leftover from previous transaction. |
| **Concurrency** | Race condition, lock contention, double-execution, retry without idempotency, ordering assumption between async chains. |
| **Recent changes** | Diff vs working state at last green: which commits, deploys, config changes, dependency bumps fall in the suspect window? |
| **Environment** | Differs between prod and local: TLS, secrets, DNS, time, file-system case-sensitivity, container resource limits, OS, library versions. |

### Per-hypothesis fields

Each hypothesis must have:
- **Statement**: "X happens because Y, which violates assumption Z."
- **Mental model**: which of the 5.
- **Likelihood** (L): 1–5 — how plausible given current evidence.
- **Impact** (I): 1–5 — how much of the symptom this explains.
- **Cost to verify** (C): 1–5 — 1 = grep + read; 5 = needs prod data or load test.
- **Score**: `(L × I) / C`.
- **Verification plan**: concrete steps — files to read, queries to run, logs to inspect.

### Output format

```markdown
## Hypothesis tree (sd-debugger enumerate)

| # | Statement | Model | L | I | C | Score | Verification plan |
|---|---|---|---|---|---|---|---|
| H1 | <statement> | concurrency | 4 | 5 | 2 | 10.0 | grep for `Lock(` in PaymentHandler; read tests/concurrent/PaymentTests.cs |
| H2 | ... | ... | ... | ... | ... | ... | ... |
```

Rank rows by Score descending.

---

## Verification protocol (`TASK = verify`)

Execute the verification plan for ONE hypothesis at a time. Produce a verdict.

### Verdict format

```markdown
### H<N> verification: <CONFIRMED|REJECTED|INCONCLUSIVE>

**Evidence**:
- `file:line` - <observation>
- `EVIDENCE_DIR/<artifact>` - <what it shows>

**Reasoning**: <2–4 sentences. For REJECTED: explain WHY evidence rules out this hypothesis — this is knowledge preservation.>

**Confidence**: <low | medium | high>

**Proximate vs root**: <For CONFIRMED only> Is this the root cause, or a symptom of a deeper cause? If the latter, name the next "why" to ask.
```

### Proximate vs root — the "why" ladder

After CONFIRMING a hypothesis, ask "why" one more time. The ROOT must be: **NAMED**, **FIXABLE**, and explain why the test gap existed. If your "root" is just a deeper symptom, keep going.

Example:
- Proximate: "PaymentHandler threw NRE on line 142."
- One deeper: "`_customer` is null."
- Root: "`_customerCache.Get(id)` returns null for archived customers; PR #4521 removed the null-check; test fixtures all use active customers — regression not caught."

---

## Anti-patterns

- Stopping at proximate cause.
- Producing only one hypothesis (enumerate ≥ 4).
- Skipping REJECTED reasoning — future investigators need to know WHY it was ruled out.
- Inventing evidence — every claim cites `file:line`, log line, query result, or doc URL.
- Acting on a CONFIRMED hypothesis — the debugger reports; `/sd:bug` Phase 5 calls the implementer.
