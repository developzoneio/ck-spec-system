#!/usr/bin/env bash
# Repo invariant validator for specwright (Unix / bash).
#
# Mirror of scripts/validate.ps1 - see that file's header for the full check
# list. Runs every documented engine invariant as a single command:
#   1. Pure-ASCII scan of all *.ps1 files.
#   2. bash -n syntax check on hooks/bash/*.sh, install/*.sh, scripts/*.sh.
#   3. Hook-pair parity (every powershell hook has a bash twin and vice-versa).
#   4. Model-alias-only: agent frontmatter model: in {sonnet,haiku,opus,inherit}.
#   5. Install-target count: a real install to a temp base lands the expected
#      file counts under each <area>/sd/ subfolder.
#   6. CHANGELOG gate: the [Unreleased] section is non-empty.
#   7. Plugin manifest validation: claude plugin validate passes on the repo root.
#
# Exit 0 = all checks passed; 1 = at least one failed.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

# One platform's hooks land per install (bash hooks here), so 3 not 6.
EXPECTED_COMMANDS=11
EXPECTED_AGENTS=6
EXPECTED_SKILLS=6
EXPECTED_HOOKS=3
EXPECTED_TEMPLATES=9

MODEL_ALIASES="sonnet haiku opus inherit"

# Byte range 0x80-0xFF in the C locale = any non-ASCII byte.
non_ascii_re="$(printf '[\200-\377]')"

# ---- output helpers (match installer vocabulary) ---------------------------

if [[ -t 1 ]]; then
    c_reset=$'\033[0m'; c_cyan=$'\033[36m'; c_green=$'\033[32m'
    c_yellow=$'\033[33m'; c_red=$'\033[31m'
else
    c_reset=''; c_cyan=''; c_green=''; c_yellow=''; c_red=''
fi

section() { echo; echo "${c_cyan}=== $* ===${c_reset}"; }
ok()      { echo "  ${c_green}[OK]${c_reset}   $*"; }
fail()    { echo "  ${c_red}[FAIL]${c_reset} $*"; }
warn()    { echo "  ${c_yellow}[WARN]${c_reset} $*"; }

failures=()
add_failure() { failures+=("$1"); }

section "specwright validate"
echo "  Repo root: $repo_root"

# ---- Check 1: pure-ASCII scan ----------------------------------------------

section "Check 1/7: Pure-ASCII scan (*.ps1)"
ascii_bad=0
ps1_count=0
while IFS= read -r -d '' f; do
    ps1_count=$((ps1_count + 1))
    if match="$(LC_ALL=C grep -n "$non_ascii_re" "$f")"; then
        rel="${f#"$repo_root"/}"
        first_line="$(printf '%s\n' "$match" | head -n1 | cut -d: -f1)"
        fail "$rel : non-ASCII byte at line $first_line"
        add_failure "ASCII: $rel (line $first_line)"
        ascii_bad=$((ascii_bad + 1))
    fi
done < <(find "$repo_root" -type f -name '*.ps1' -not -path '*/.git/*' -print0)
if [[ $ascii_bad -eq 0 ]]; then ok "$ps1_count .ps1 file(s) are pure ASCII"; fi

# ---- Check 2: bash -n syntax -----------------------------------------------

section "Check 2/7: bash -n syntax (*.sh)"
syn_bad=0
sh_count=0
while IFS= read -r -d '' f; do
    sh_count=$((sh_count + 1))
    if ! out="$(bash -n "$f" 2>&1)"; then
        rel="${f#"$repo_root"/}"
        fail "$rel : $out"
        add_failure "bash -n: $rel"
        syn_bad=$((syn_bad + 1))
    fi
done < <(find "$repo_root/hooks/bash" "$repo_root/install" "$repo_root/scripts" \
    -maxdepth 1 -type f -name '*.sh' -print0 2>/dev/null)
if [[ $syn_bad -eq 0 ]]; then ok "$sh_count .sh file(s) pass bash -n"; fi

# ---- Check 3: hook-pair parity ---------------------------------------------

section "Check 3/7: Hook-pair parity"
parity_bad=0
ps_count=0
for psf in "$repo_root"/hooks/powershell/*.ps1; do
    [[ -e "$psf" ]] || continue
    ps_count=$((ps_count + 1))
    base="$(basename "$psf" .ps1)"
    if [[ ! -f "$repo_root/hooks/bash/$base.sh" ]]; then
        fail "hooks/powershell/$base.ps1 has no hooks/bash/$base.sh"
        add_failure "parity: missing bash twin for $base"
        parity_bad=$((parity_bad + 1))
    fi
done
for shf in "$repo_root"/hooks/bash/*.sh; do
    [[ -e "$shf" ]] || continue
    base="$(basename "$shf" .sh)"
    if [[ ! -f "$repo_root/hooks/powershell/$base.ps1" ]]; then
        fail "hooks/bash/$base.sh has no hooks/powershell/$base.ps1"
        add_failure "parity: missing PowerShell twin for $base"
        parity_bad=$((parity_bad + 1))
    fi
done
if [[ $parity_bad -eq 0 ]]; then ok "$ps_count hook pair(s) present on both platforms"; fi

# ---- Check 4: agent model aliases ------------------------------------------

section "Check 4/7: Agent model aliases"
model_bad=0
agent_count=0
for af in "$repo_root"/agents/*.md; do
    [[ -e "$af" ]] || continue
    agent_count=$((agent_count + 1))
    rel="${af#"$repo_root"/}"
    line="$(grep -m1 -E '^model:' "$af" || true)"
    if [[ -z "$line" ]]; then
        fail "$rel : no model: field"
        add_failure "model: $rel missing model field"
        model_bad=$((model_bad + 1))
        continue
    fi
    val="$(printf '%s\n' "$line" | sed -E 's/^model:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]+$//')"
    case " $MODEL_ALIASES " in
        *" $val "*) : ;;
        *)
            fail "$rel : model '$val' is not an alias ($MODEL_ALIASES)"
            add_failure "model: $rel = $val"
            model_bad=$((model_bad + 1))
            ;;
    esac
done
if [[ $model_bad -eq 0 ]]; then ok "$agent_count agent(s) use a model alias"; fi

# ---- Check 5: install-target counts ----------------------------------------

section "Check 5/7: Install-target counts"
install_sh="$repo_root/install/install.sh"
tmp="${TMPDIR:-/tmp}/sd-validate-$$"
cleanup_tmp() { [[ -n "${tmp:-}" && -d "$tmp" ]] && rm -rf "$tmp" || true; }
trap cleanup_tmp EXIT
rm -rf "$tmp"
if bash "$install_sh" --base-path "$tmp" --force >/dev/null 2>&1; then
    check_count() {
        local name="$1" dir="$2" expected="$3" cnt=0
        if [[ -d "$dir" ]]; then cnt="$(find "$dir" -type f | wc -l | tr -d ' ')"; fi
        if [[ "$cnt" -eq "$expected" ]]; then
            ok "$name/sd : $cnt file(s)"
        else
            fail "$name/sd : expected $expected, found $cnt"
            add_failure "install: $name/sd expected $expected found $cnt"
        fi
    }
    check_count "commands"  "$tmp/commands/sd"  "$EXPECTED_COMMANDS"
    check_count "agents"    "$tmp/agents/sd"    "$EXPECTED_AGENTS"
    check_count "skills"    "$tmp/skills/sd"    "$EXPECTED_SKILLS"
    check_count "hooks"     "$tmp/hooks/sd"     "$EXPECTED_HOOKS"
    check_count "templates" "$tmp/templates/sd" "$EXPECTED_TEMPLATES"
else
    fail "installer failed: bash install.sh --base-path <tmp> --force"
    add_failure "install: installer returned non-zero"
fi
cleanup_tmp
trap - EXIT

# ---- Check 6: CHANGELOG [Unreleased] non-empty -----------------------------

section "Check 6/7: CHANGELOG [Unreleased] gate"
changelog="$repo_root/CHANGELOG.md"
block="$(awk '
    /^##[[:space:]]+\[Unreleased\]/ { f=1; next }
    /^##[[:space:]]+\[/             { f=0 }
    f                               { print }
' "$changelog")"
# Header of the section immediately below [Unreleased].
next_header="$(awk '
    /^##[[:space:]]+\[Unreleased\]/ { f=1; next }
    f && /^##[[:space:]]+\[/        { print; exit }
' "$changelog")"
if printf '%s\n' "$block" | grep -qE '^[[:space:]]*-[[:space:]]+[^[:space:]]'; then
    ok "[Unreleased] has at least one entry"
elif printf '%s\n' "$next_header" \
    | grep -qE '^##[[:space:]]+\[[0-9]+\.[0-9]+\.[0-9]+\][[:space:]]+-[[:space:]]+[^[:space:]]'; then
    # Empty [Unreleased] is allowed only directly above a freshly cut release.
    ok "[Unreleased] empty but sits directly above a dated release (just cut)"
else
    fail "[Unreleased] section is empty (add a changelog entry)"
    add_failure "changelog: [Unreleased] empty"
fi

# ---- Check 7: plugin manifest validation -----------------------------------

section "Check 7/7: Plugin manifest validation"
if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI not found in PATH; skipping plugin validate (CI runs this step)."
else
    if plugin_out="$(claude plugin validate "$repo_root" 2>&1)"; then
        ok ".claude-plugin/plugin.json and marketplace.json pass claude plugin validate"
    else
        fail "claude plugin validate failed: $plugin_out"
        add_failure "plugin-validate: claude plugin validate exited non-zero"
    fi
fi

# ---- summary ---------------------------------------------------------------

section "Summary"
if [[ ${#failures[@]} -eq 0 ]]; then
    ok "All checks passed."
    exit 0
else
    fail "${#failures[@]} check(s) failed:"
    for m in "${failures[@]}"; do echo "         - $m"; done
    exit 1
fi
