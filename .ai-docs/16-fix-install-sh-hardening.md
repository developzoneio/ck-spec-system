# FIX: install.sh hardening — set flags, prefix guard, quoting

- Priority: P3
- Area: `install/install.sh`, `install/install.ps1` (prefix guard parity)
- Status: VERIFIED (agent-audited with quotes; re-verify lines before editing)
- Suggested branch: `fix/install-hardening`

## Problems

1. **Inconsistent shell strictness.** `install/install.sh:16` uses `set -e` only, while
   `install/uninstall.sh:20` uses `set -euo pipefail`. Under plain `set -e`, unset-variable
   typos and mid-pipeline failures pass silently; a mid-run `cp` failure also aborts with a
   partial, non-rolled-back install (backups are per-file only).
2. **No `--prefix` validation on install.** `uninstall.sh:93` and `uninstall.ps1:73-74` guard
   against empty/path-traversal prefixes (`../`, separators), but `install.sh` and
   `install.ps1` have NO such guard — `--prefix ../foo` writes outside the intended tree.
3. **Unquoted pattern in prefix strip.** `install.sh:253`: `rel="${f#$src_root/}"` — an
   unquoted `$src_root` in the `#` pattern is glob-interpreted; a repo path containing `[`,
   `*`, or `?` breaks the strip. Fix: `rel="${f#"$src_root"/}"`.

## Fix

1. Align `install.sh` to `set -euo pipefail`; then walk the script for anything that relied on
   lax mode (unset optional vars -> give defaults with `${var:-}`; pipelines whose non-zero
   legs are expected -> `|| true` explicitly). Test the dry-run and full paths after.
2. Copy the exact prefix-validation block from `uninstall.sh:93` into `install.sh`, and the
   `uninstall.ps1:73-74` block into `install.ps1` (pair rule: both platforms get the guard).
   Reject: empty prefix, absolute-path escapes, any `/`, `\`, or `..` component — match the
   uninstall semantics exactly so install/uninstall accept the same set of prefixes.
3. Quote the strip pattern at `install.sh:253` (and grep for other unquoted `${x#$y}` /
   `${x%$y}` patterns in install/ and hooks/).
4. Partial-install behavior: full transactional rollback is likely overkill; at minimum, on a
   copy failure print which files were already installed and suggest running uninstall.
   Judgment call — keep the change small.

## Acceptance criteria

1. `bash -n install/install.sh` passes; `./install/install.sh --dry-run` output unchanged.
2. `./install/install.sh --base-path /tmp/sd-test` -> expected file counts;
   `./install/uninstall.sh --base-path /tmp/sd-test --force` round-trips clean.
3. `./install/install.sh --base-path /tmp/sd-test --prefix ../evil` is REJECTED on both
   platforms; the same invalid prefixes are rejected by install and uninstall alike.
4. An install from a path containing `[` (create a scratch clone dir like `/tmp/sd[1]/repo`)
   succeeds.
5. `scripts/validate.sh` and CI pass.

Add a CHANGELOG `### Fixed` entry under `## [Unreleased]`.
