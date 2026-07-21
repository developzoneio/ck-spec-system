# Lessons (fixture: must PASS)

Every line below is a well-formed, identifier-free lesson. `scripts/validate-lessons.*`
must exit 0 on this file, on both platforms.

Prose like this paragraph, headers, and blank lines are ignored by the validator - only
lines opening with `- [` are candidates.

## Lessons

- [sibling-repo-assumption] high/feature: When mirroring a sibling repository, verify the local shared helper matches before copying an attribute.
- [missed-context] high/feature: Re-run impact analysis after any spec refinement, since a refined scope invalidates the earlier map.
- [baseline-attribution] medium/all: Confirm pre-existing failures against a clean baseline before attributing or dismissing them.
- [gate-friction] medium/refactor: When waiving a coverage gate, record measured coverage, residual risk, and what would satisfy it later.
- [config-drift] medium/all: Verify configured build and test commands still resolve before trusting a green or a red result.
- [test-gap] medium/feature: Create the missing test project before the first task rather than midway, even under PowerShell tooling.
- [test-fragility] medium/all: When a test must couple to a name, say so beside the test so a later rename carries a warning.
- [precedent-conflict] low/refactor: When a rule conflicts with an established local pattern, decide once and record which one wins.
- [scope-discipline] low/all: Decline an unrelated cleanup found mid-task and record it as a follow-up instead of absorbing it.
- [tooling-surprise] low/all: Check the working tree state after any command that stashes or regenerates project metadata. (2)
