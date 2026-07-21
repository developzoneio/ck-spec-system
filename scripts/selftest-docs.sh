#!/usr/bin/env bash
# Negative self-test for validate.sh Check 7 (docs consistency), Unix / bash.
#
# Mirror of scripts/selftest-docs.ps1.
#
# Check 7 only earns its place in CI if it FAILS when the docs lie. A check that
# silently degrades into a no-op still reports success, so this test corrupts a
# throwaway copy of the repo in three ways and asserts the validator catches each:
#
#   1. Clean copy                -> passes.
#   2. A wrong published number  -> fails, naming the number and the truth.
#   3. A reworded claim          -> fails as vacuous (pattern matched no lines).
#   4. An undeclared new claim   -> fails as undeclared.
#
# Scenarios 3 and 4 are what stop the check rotting: without them someone could
# reword or add docs and quietly leave Check 7 guarding nothing.
#
# Exit 0 = the check behaves correctly; 1 = the check is broken.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

if [[ -t 1 ]]; then
    c_reset=$'\033[0m'; c_cyan=$'\033[36m'; c_green=$'\033[32m'; c_red=$'\033[31m'
else
    c_reset=''; c_cyan=''; c_green=''; c_red=''
fi
section() { echo; echo "${c_cyan}=== $* ===${c_reset}"; }
ok()      { echo "  ${c_green}[OK]${c_reset}   $*"; }
fail()    { echo "  ${c_red}[FAIL]${c_reset} $*"; }

failures=0

# Working dirs are throwaway copies - the real repo is never mutated.
SKIP_TOP=(".git" "node_modules" "_bmad" "_bmad-output" "design-artifacts" ".claude" "dist")

work_root="$(mktemp -d)"
cleanup() { rm -rf "$work_root"; }
trap cleanup EXIT

make_copy() {
    local dest="$1" entry base skip
    mkdir -p "$dest"
    for entry in "$repo_root"/* "$repo_root"/.[!.]*; do
        [[ -e "$entry" ]] || continue
        base="$(basename "$entry")"
        skip=0
        for s in "${SKIP_TOP[@]}"; do
            [[ "$base" == "$s" ]] && { skip=1; break; }
        done
        [[ $skip -eq 1 ]] && continue
        cp -R "$entry" "$dest/"
    done
}

# The count this test corrupts is DERIVED from disk, never written down. A literal here
# would rot the moment a command is added: the pattern would stop matching, the sandbox
# copy would never be corrupted, and the scenario would report the validator as passing
# when in truth nothing was ever tested. That is exactly what happened when the 12th
# command landed against a hardcoded '11' (SW-20), and it is the same anti-pattern
# specwright.manifest.json exists to abolish.
TRUE_COMMANDS="$(find "$repo_root/commands" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
WRONG_COMMANDS=$((TRUE_COMMANDS + 1))

# Replace first match of a regex in a file, portably (macOS sed -i differs from GNU).
# Returns non-zero when the file did not change, so a corruption that silently failed to
# apply is reported as a fixture-setup error rather than sailing on as a passing validator.
replace_in() {
    local file="$1" from="$2" to="$3"
    local before after
    before="$(cat "$file")"
    sed "s|$from|$to|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    after="$(cat "$file")"
    [[ "$before" != "$after" ]]
}

# Asserts the transition, not just the destination: the original text must be GONE and the
# planted text present. Checking only for the planted text is what defeated the original
# scenario-2 guard - it planted the then-current count, which by then was also the TRUE
# value already in README.md, so the grep found the real line and passed vacuously.
corrupt_or_fail() {
    local name="$1" file="$2" from="$3" to="$4"
    if replace_in "$file" "$from" "$to"; then
        return 0
    fi
    fail "$name : fixture setup - pattern did not match, nothing was corrupted"
    failures=$((failures + 1))
    return 1
}

# Run the validator inside a copy and assert exit status + expected message.
# expect_pass=1 -> exit 0 required; expect_pass=0 -> non-zero AND $needle in output.
run_case() {
    local name="$1" expect_pass="$2" needle="${3:-}" dir="$4"
    local out status=0
    out="$(bash "$dir/scripts/validate.sh" 2>&1)" || status=$?

    if [[ "$expect_pass" -eq 1 ]]; then
        if [[ $status -eq 0 ]]; then
            ok "$name : validator passed as expected"
        else
            fail "$name : expected exit 0, got $status"
            printf '%s\n' "$out" | sed -n '/Check 7/,$p' | sed 's/^/         /'
            failures=$((failures + 1))
        fi
        return
    fi

    if [[ $status -eq 0 ]]; then
        fail "$name : expected non-zero exit, got 0 - THE CHECK DID NOT BITE"
        failures=$((failures + 1))
        return
    fi
    if printf '%s\n' "$out" | grep -qF "$needle"; then
        ok "$name : failed with the right reason (exit $status)"
    else
        # Non-zero for the wrong reason is not a pass - it would mask a broken check.
        fail "$name : exited $status but never said '$needle'"
        printf '%s\n' "$out" | sed -n '/Check 7/,$p' | sed 's/^/         /'
        failures=$((failures + 1))
    fi
}

section "selftest: docs-consistency check (Check 7)"
echo "  Repo root: $repo_root"
echo "  Sandbox:   $work_root"

# ---- Scenario 1: clean copy passes -----------------------------------------

section "Scenario 1/4: clean copy passes"
clean="$work_root/clean"
make_copy "$clean"
run_case "clean" 1 "" "$clean"

# ---- Scenario 2: a wrong published number fails ----------------------------

section "Scenario 2/4: wrong README number fails"
wrong="$work_root/wrong-number"
make_copy "$wrong"
if corrupt_or_fail "wrong-number" "$wrong/README.md" \
    "\*\*${TRUE_COMMANDS} slash commands\*\*" "**${WRONG_COMMANDS} slash commands**"; then
    run_case "wrong-number" 0 "says ${WRONG_COMMANDS}, disk has ${TRUE_COMMANDS}" "$wrong"
fi

# ---- Scenario 3: a reworded claim fails as vacuous --------------------------

section "Scenario 3/4: reworded claim fails as vacuous"
reworded="$work_root/reworded"
make_copy "$reworded"
if corrupt_or_fail "reworded" "$reworded/README.md" \
    "\*\*${TRUE_COMMANDS} slash commands\*\*" "**${TRUE_COMMANDS} slash cmds**"; then
    run_case "reworded" 0 "pattern matched no lines" "$reworded"
fi

# ---- Scenario 4: an undeclared claim fails ---------------------------------

section "Scenario 4/4: undeclared claim in a new doc fails"
undeclared="$work_root/undeclared"
make_copy "$undeclared"
printf '\nThe engine ships 99 reusable skills.\n' >> "$undeclared/docs/usage.md"
run_case "undeclared" 0 "undeclared inventory claim" "$undeclared"

# ---- summary ---------------------------------------------------------------

section "Summary"
if [[ $failures -eq 0 ]]; then
    ok "Check 7 bites on all 4 scenarios."
    exit 0
else
    fail "$failures scenario(s) behaved wrong - Check 7 is not trustworthy."
    exit 1
fi
