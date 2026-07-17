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

# Replace first match of a regex in a file, portably (macOS sed -i differs from GNU).
replace_in() {
    local file="$1" from="$2" to="$3"
    sed "s|$from|$to|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
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
replace_in "$wrong/README.md" '\*\*11 slash commands\*\*' '**12 slash commands**'
if ! grep -qF '**12 slash commands**' "$wrong/README.md"; then
    fail "fixture setup: could not plant the wrong number in README.md"
    failures=$((failures + 1))
fi
run_case "wrong-number" 0 "says 12, disk has 11" "$wrong"

# ---- Scenario 3: a reworded claim fails as vacuous --------------------------

section "Scenario 3/4: reworded claim fails as vacuous"
reworded="$work_root/reworded"
make_copy "$reworded"
replace_in "$reworded/README.md" '\*\*11 slash commands\*\*' '**11 slash cmds**'
run_case "reworded" 0 "pattern matched no lines" "$reworded"

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
