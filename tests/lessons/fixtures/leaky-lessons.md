# Lessons (fixture: must FAIL)

Each line below violates at least one rule. `scripts/validate-lessons.*` must exit 1 on
this file, on both platforms.

This fixture is the reason the validator can be trusted: `validate.*` proving the clean
fixture passes says nothing about whether the checks still fire. A validator that rotted
into a no-op would report the clean fixture green forever.

## Identifier leaks

- [sibling-repo-assumption] high/feature: Verify LeagueRedisDao casing before copying the index attribute.
- [missed-context] high/feature: The helper filterSpecialLeagues exists in only one repository, not all of them.
- [config-drift] medium/all: Check that spec_dir and index_file still point at directories that exist.

## Code content leaks

- [test-fragility] medium/all: Avoid reflection by string name, as in `ConvertToLeagueGroups`, when a rename is likely.
- [missed-context] high/feature: The landmine sits in the base repository at line :55 and again at :59.
- [test-gap] medium/feature: There was no unit test project, so BaseLeagueRepository.cs went uncovered.
- [scope-discipline] low/all: Decline the global format fix in src/WebServer and log it instead.

## Shape violations

- [pattern-violation] high/feature: This tag was retired and must no longer be accepted by the validator.
- [gate-friction] critical/refactor: Severity must come from the closed set, and critical is not in it.
- [baseline-attribution] medium/integration: Scope must come from the closed set, and integration is not in it.
- [tooling-surprise] low/all: This rule sentence is deliberately written far past the hundred and twenty character ceiling so that the length check has something real to catch.
- [missed-context] high feature: The separator between severity and scope is missing, so the grammar does not match.
