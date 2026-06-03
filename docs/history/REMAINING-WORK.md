# Remaining Work: specwright Upgrade (Phases 5 & 6)

This document tracks the final steps of the `ck` -> `sd` rebrand and architecture upgrade. All core logic, agent rebranding, skill architecture, and hook migrations (Phases 1-4) are complete.

## Phase 5 — Documentation & Polish

### [ ] 5.1 Update README.md
- **Add "Skills" section:** Describe the new `skills/sd/` layer and the 5 specific skills (`sd-severity-taxonomy`, `sd-hypothesis-tree`, `sd-atomic-task-format`, `sd-evidence-citation`, `sd-spec-templates`).
- **Update Agent Table:** Ensure all agent names use `sd-` prefix.
- **Update Token Counts:** If any agent body sizes changed significantly during the trim, update the table counts.

### [ ] 5.2 Update docs/architecture.md
- **Add `skills/sd/` layer:** Update the architecture diagram and text to include the skills layer.
- **New Section: "Agent Skills":** Detail how agents reference skills via frontmatter.
- **Hook Schema Update:** Document the new dual-format hook output (JSON with both `decision` and `hookSpecificOutput.permissionDecision`).

### [ ] 5.3 CHANGELOG & Documentation Sweep
- **CHANGELOG.md:** Add entries for version 2.2.0 (rebrand, skills, dual-format hooks).
- **docs/usage.md:** Sweep for any remaining `ck:` or `/ck:` references.
- **docs/walkthrough.md:** Sweep for any remaining `ck:` or `/ck:` references.
- **examples/README.md:** Ensure all command examples use `/sd:`.

---

## Phase 6 — End-to-End Regression

### [ ] 6.1 Final Consistency Checks
- **Dry-run installers:** Run both `install/install.sh` and `install/install.ps1` with `--dry-run` one last time.
- **JSON Validation:** Validate `templates/*.json`.
- **Orphan Scan:** Run a final case-sensitive scan for `ck` (excluding intentional words like 'checkout' or 'backups').

### [ ] 6.2 Smoke Test Flow
- **Setup:** Run `/sd:setup` in a clean project directory.
- **Verify Wiring:** Confirm `.claude/settings.json` was generated with correct paths.
- **Test Gate (Deny):** Try to edit a file without a spec. Confirm `spec-gate` blocks with the new dual-format JSON reason.
- **Test Flow (Allow):** Start a spec (`/sd:feature`), then edit. Confirm gate allows.

---

## Technical Context for Claude Code

- **Prefix:** `sd` (Slash commands like `/sd:feature`, folders like `skills/sd/`).
- **Repo Name:** `specwright` (rebranded from `ck-spec-system`).
- **Agents:** Named `sd-<role>` (e.g., `sd-reviewer`).
- **Hooks:** Now emit dual-format JSON for compatibility:
  ```json
  {
    "decision": "block",
    "reason": "...",
    "hookSpecificOutput": {
      "permissionDecision": "deny",
      "reason": "..."
    }
  }
  ```
- **Skills:** Shared Markdown rules in `~/.claude/skills/sd/`, referenced by agents in frontmatter:
  ```yaml
  skills: [sd-severity-taxonomy, sd-evidence-citation]
  ```
