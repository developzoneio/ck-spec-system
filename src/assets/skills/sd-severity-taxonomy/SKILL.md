# sd-severity-taxonomy

Severity taxonomy for specwright review findings. Apply this taxonomy in every review.
Every finding must carry exactly one severity marker. Severities are NOT interchangeable.

---

## Severity levels

| Severity | Marker | Meaning | When to use |
|---|---|---|---|
| BLOCK | 🔴 | Must fix before merge / close-out | Constitution violation, layer violation, broken behavior, security issue, regression risk, ROOT_CAUSE not addressed (bug review), invariant violated (refactor), correctness broken (perf), critical missing test for a Success criterion. |
| WARN | 🟠 | Should fix; ask user to decide | Convention drift, minor coupling concern, missing edge-case test, suboptimal naming that future-readers will pay for. |
| SUGGEST | 🟡 | Improvement opportunity; non-blocking | Cleaner alternative exists, readability improvement, dead-code candidate, dependency simplification. |
| PASS | 🟢 | Verified compliant | Explicit positive note with citation. Used sparingly to surface non-obvious compliance. |

---

## Rules

- Every BLOCK or WARN must cite a constitution `§N.M` section OR a spec acceptance criterion. No anchor = no BLOCK/WARN.
- SUGGEST is "if you have time". WARN is "we should address this". Never conflate them.
- Style preferences are WARN at most. Constitution-mandated style is the only exception that can be BLOCK.
- PASS findings are short (one-liner) and used sparingly to flag non-obvious compliance.

---

## Output structure (mandatory)

```markdown
# Review: <target summary>

**Verdict**: <N> 🔴 BLOCK, <N> 🟠 WARN, <N> 🟡 SUGGEST, <N> 🟢 PASS across <F> files.

---

## 🔴 BLOCK

### B1: <short title>
- **File:line**: `src/.../foo.cs:84`
- **Constitution**: §1.1 layer dependency direction
- **Finding**: <one-paragraph description of what is wrong>
- **Suggested direction**: <NOT exact code - direction only>

---

## 🟠 WARN

### W1: <short title>
- ... (same shape as BLOCK)

---

## 🟡 SUGGEST

### S1: ...

---

## 🟢 PASS

### P1: Layer rule §1.1 respected at `src/.../bar.cs:42` (brief explanation).
```

If a section has zero findings, write `_No findings._` — do not omit the section.

---

## Anti-patterns

- Conflating SUGGEST with WARN.
- Marking style preferences as BLOCK (unless constitution-mandated).
- Issuing BLOCK without a `§N.M` reference or spec acceptance criterion.
- Omitting PASS notes on non-obvious compliant areas (reviewer reports are also a positive signal).
