---
description: Filler command used only to exercise the CL500 byte-budget rule.
argument-hint: <slug>
---

# Gamma filler command

This file exists purely so its own byte count clears a small fixture-local
budget. It carries no gate headings, no references to other prompt files,
and no stack-specific vocabulary, so the byte-budget check is the only rule
it is meant to trip.

Everything past this point is harmless padding prose whose sole purpose is
to push the total size comfortably past the configured ceiling, so the
fixture behaves identically on every checkout and both linter
implementations without anyone needing to hand-count bytes to keep it
passing.

The budget for this fixture case is set above the base tree's own
`commands/alpha.md` and `commands/beta.md`, so only this file is meant to
trip CL500 here - the other two stay comfortably under the ceiling, and
this extra paragraph exists only to keep this file clearly the largest of
the three by a wide, legible margin.
