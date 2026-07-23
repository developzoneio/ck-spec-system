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
#   7. Docs consistency: published numbers in the docs match disk, per
#      specwright.manifest.json.
#
# Exit 0 = all checks passed; 1 = at least one failed.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

# Counts are derived from the source tree, not hardcoded - a new command/agent/skill/template
# only needs to land in its source dir, never a constant bumped in two scripts. Each count is
# asserted > 0 below so an empty/misnamed source dir fails loudly instead of vacuously passing.
# One platform's hooks land per install (bash hooks here), so this counts hooks/bash/*.sh only;
# Check 3 (hook-pair parity) already asserts the powershell count matches.
EXPECTED_COMMANDS="$(find "$repo_root/commands" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
EXPECTED_AGENTS="$(find "$repo_root/agents" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
EXPECTED_SKILLS="$(find "$repo_root/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' | wc -l | tr -d ' ')"
EXPECTED_HOOKS="$(find "$repo_root/hooks/bash" -maxdepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')"
EXPECTED_TEMPLATES="$(find "$repo_root/templates" -type f | wc -l | tr -d ' ')"

for pair in "commands:$EXPECTED_COMMANDS" "agents:$EXPECTED_AGENTS" "skills:$EXPECTED_SKILLS" \
    "hooks:$EXPECTED_HOOKS" "templates:$EXPECTED_TEMPLATES"; do
    if [[ "${pair#*:}" -eq 0 ]]; then
        echo "FATAL: derived expected count for ${pair%%:*} is 0 - source dir empty or missing?" >&2
        exit 1
    fi
done

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

# ---- Check 7: docs consistency ---------------------------------------------

section "Check 7/7: Docs consistency (published numbers vs disk)"
manifest="$repo_root/specwright.manifest.json"
if [[ ! -f "$manifest" ]]; then
    fail "specwright.manifest.json not found at repo root"
    add_failure "docs: manifest missing"
elif ! command -v jq >/dev/null 2>&1; then
    # Hooks exit 0 silently when jq is absent so they never block a user on their own
    # bugs. A validator must do the opposite: a missing jq that passed would turn CI
    # green while checking nothing.
    fail "jq is required to parse specwright.manifest.json - install jq"
    add_failure "docs: jq not installed"
else
    docs_bad=0
    # Plain (non-associative) arrays + linear-scan lookup functions, not `declare -A`:
    # macOS ships /bin/bash 3.2 (no associative arrays), and this script must run there.
    quantity_names=()
    quantity_values=()
    q_set() { # name value
        local name="$1" value="$2" i
        for i in "${!quantity_names[@]}"; do
            if [[ "${quantity_names[$i]}" == "$name" ]]; then
                quantity_values[$i]="$value"
                return
            fi
        done
        quantity_names+=("$name")
        quantity_values+=("$value")
    }
    q_get() { # name -> stdout value, empty if unset
        local name="$1" i
        for i in "${!quantity_names[@]}"; do
            if [[ "${quantity_names[$i]}" == "$name" ]]; then
                printf '%s' "${quantity_values[$i]}"
                return
            fi
        done
    }

    file_pattern_names=()
    file_pattern_values=()
    fp_append() { # file pattern
        local file="$1" pattern="$2" i
        for i in "${!file_pattern_names[@]}"; do
            if [[ "${file_pattern_names[$i]}" == "$file" ]]; then
                file_pattern_values[$i]="${file_pattern_values[$i]}${pattern}"$'\n'
                return
            fi
        done
        file_pattern_names+=("$file")
        file_pattern_values+=("${pattern}"$'\n')
    }
    fp_get() { # file -> stdout newline-joined patterns, empty if none
        local file="$1" i
        for i in "${!file_pattern_names[@]}"; do
            if [[ "${file_pattern_names[$i]}" == "$file" ]]; then
                printf '%s' "${file_pattern_values[$i]}"
                return
            fi
        done
    }

    # Some jq builds (notably jq.exe on Windows) emit CRLF. An unstripped \r rides on the
    # last field of every record and silently breaks glob matches, array keys and prefix
    # tests - failures that look like real drift but are not.
    mjq() { jq -r "$1" "$manifest" | tr -d '\r'; }

    # Area counts are derived from disk, never stored in the manifest.
    shopt -s nullglob
    while IFS=$'\t' read -r area_name area_kind area_value; do
        area_count=0
        if [[ "$area_kind" == "glob" ]]; then
            for p in "$repo_root"/$area_value; do
                [[ -f "$p" ]] && area_count=$((area_count + 1))
            done
        else
            for rel_f in $area_value; do
                if [[ -f "$repo_root/$rel_f" ]]; then
                    area_count=$((area_count + 1))
                else
                    fail "area '$area_name' lists a file that does not exist: $rel_f"
                    add_failure "docs: area $area_name missing $rel_f"
                    docs_bad=$((docs_bad + 1))
                fi
            done
        fi
        if [[ $area_count -eq 0 ]]; then
            fail "area '$area_name' ($area_kind '$area_value') matched 0 files"
            add_failure "docs: area $area_name derived 0"
            docs_bad=$((docs_bad + 1))
        fi
        q_set "$area_name" "$area_count"
    done < <(mjq '.areas | to_entries[] | "\(.key)\t\(if .value.glob then "glob" else "files" end)\t\(.value.glob // (.value.files | join(" ")))"')
    shopt -u nullglob

    while IFS=$'\t' read -r der_name der_parts; do
        der_total=0
        for part in $der_parts; do
            part_val="$(q_get "$part")"
            der_total=$((der_total + ${part_val:-0}))
        done
        q_set "$der_name" "$der_total"
    done < <(mjq '.derived | to_entries[] | "\(.key)\t\(.value | join(" "))"')

    while IFS=$'\t' read -r c_file c_pattern c_equals; do
        fp_append "$c_file" "$c_pattern"

        target="$repo_root/$c_file"
        if [[ ! -f "$target" ]]; then
            fail "$c_file : declared claim file does not exist"
            add_failure "docs: missing claim file $c_file"
            docs_bad=$((docs_bad + 1))
            continue
        fi
        expected="$(q_get "$c_equals")"
        if [[ -z "$expected" ]]; then
            fail "$c_file : claim references unknown quantity '$c_equals'"
            add_failure "docs: unknown quantity $c_equals"
            docs_bad=$((docs_bad + 1))
            continue
        fi

        hits=0
        lineno=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            lineno=$((lineno + 1))
            if [[ "$line" =~ $c_pattern ]]; then
                hits=$((hits + 1))
                found="${BASH_REMATCH[1]}"
                if [[ "$found" != "$expected" ]]; then
                    fail "$c_file:$lineno : says $found, disk has $expected ($c_equals)"
                    add_failure "docs: $c_file:$lineno $c_equals says $found not $expected"
                    docs_bad=$((docs_bad + 1))
                fi
            fi
        done < "$target"

        # A pattern that matches nothing is a rotted regex, not a pass - without this
        # a reworded doc sentence silently turns the claim into a no-op.
        if [[ $hits -eq 0 ]]; then
            fail "$c_file : pattern matched no lines (reworded?): $c_pattern"
            add_failure "docs: vacuous claim in $c_file ($c_equals)"
            docs_bad=$((docs_bad + 1))
        fi
    done < <(mjq '.docClaims[] | "\(.file)\t\(.pattern)\t\(.equals)"')

    # Undeclared-claim scan: any line that looks like an inventory claim but is not
    # covered by a docClaims entry. This is what keeps the manifest canonical - a new
    # doc cannot publish a number that nothing checks.
    phrases_re="$(mjq '.claimPhrases | join("|")')"
    # Not `mapfile` (bash 4+, absent from macOS's stock /bin/bash 3.2).
    exclusions=()
    while IFS= read -r ex; do
        exclusions+=("$ex")
    done < <(mjq '.historicalExclusions[]')

    while IFS= read -r -d '' f; do
        rel="${f#"$repo_root"/}"
        skip=0
        for ex in "${exclusions[@]}"; do
            if [[ "$rel" == "$ex"* ]]; then skip=1; break; fi
        done
        [[ $skip -eq 1 ]] && continue

        lineno=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            lineno=$((lineno + 1))
            [[ "$line" =~ $phrases_re ]] || continue
            covered=0
            fp_val="$(fp_get "$rel")"
            if [[ -n "$fp_val" ]]; then
                while IFS= read -r pat; do
                    [[ -z "$pat" ]] && continue
                    if [[ "$line" =~ $pat ]]; then covered=1; break; fi
                done <<< "$fp_val"
            fi
            if [[ $covered -eq 0 ]]; then
                fail "$rel:$lineno : undeclared inventory claim (add a docClaims entry or an exclusion)"
                add_failure "docs: undeclared claim $rel:$lineno"
                docs_bad=$((docs_bad + 1))
            fi
        done < "$f"
    done < <(find "$repo_root" -type f -name '*.md' -not -path '*/.git/*' -print0)

    if [[ $docs_bad -eq 0 ]]; then
        claim_total="$(mjq '.docClaims | length')"
        ok "$claim_total published claim(s) match disk; no undeclared claims"
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
