#!/usr/bin/env bash
# specwright: lesson aggregator (Unix / bash).
#
# Mirror of scripts/aggregate-lessons.ps1 - both must emit byte-identical
# output for the same corpus. SW-18, under epic SW-7.
#
#   bash scripts/aggregate-lessons.sh [--spec-dir DIR] [--out FILE] [--check]
#
# Reads every <spec-dir>/*/05-retro.md, extracts well-formed lesson lines (the
# grammar in skills/sd-retro-lessons/SKILL.md), dedupes them, and renders
# <spec-dir>/_lessons/lessons.md.
#
# --check writes nothing and exits 1 if the rendered output differs from what
# is already on disk. That is how idempotence is asserted in CI.
#
# TWO DESIGN DECISIONS worth knowing before editing:
#
#   1. The RETROS are append-only; lessons.md is a DERIVED file, fully
#      regenerated on every run. SW-18 originally called lessons.md itself
#      append-only, but dedupe-with-a-count requires rewriting the line, so
#      append-only and idempotent are mutually exclusive. Regenerating makes
#      idempotence a property of the design rather than something to defend.
#
#   2. Abstraction is NOT done here. Turning a retro note into an
#      identifier-free rule is judgement work and belongs to the
#      sd-retro-lessons skill, which writes tagged lines into 05-retro.md.
#      This script only collects, dedupes and orders - no judgement, so the
#      output is reproducible.
#
# Exit 0 = rendered (or already current under --check); 1 = --check found drift
# or an argument was invalid.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SPEC_DIR=".specs"
OUT_FILE=""
CHECK_ONLY=0

# Enum order, NOT alphabetical - this array defines the section order in the
# rendered file, and it is duplicated in aggregate-lessons.ps1 and the enum
# table in skills/sd-retro-lessons/SKILL.md. All three must agree.
TAGS=(
    sibling-repo-assumption
    missed-context
    baseline-attribution
    tooling-surprise
    gate-friction
    config-drift
    test-fragility
    test-gap
    precedent-conflict
    scope-discipline
)

SEVERITIES=(high medium low)
SCOPES=(feature bug refactor perf rca all)

LESSON_RE='^- \[([a-z-]+)\] ([a-z]+)/([a-z]+): (.+)$'
COUNT_RE='^(.*) \([0-9]+\)$'

if [[ -t 1 ]]; then
    c_reset=$'\033[0m'; c_cyan=$'\033[36m'; c_green=$'\033[32m'; c_red=$'\033[31m'
else
    c_reset=''; c_cyan=''; c_green=''; c_red=''
fi
section() { echo; echo "${c_cyan}=== $* ===${c_reset}"; }
ok()      { echo "  ${c_green}[OK]${c_reset}   $*"; }
fail()    { echo "  ${c_red}[FAIL]${c_reset} $*"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --spec-dir) SPEC_DIR="$2"; shift 2 ;;
        --out)      OUT_FILE="$2"; shift 2 ;;
        --check)    CHECK_ONLY=1; shift ;;
        -h|--help)  sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)          fail "unknown argument: $1"; exit 1 ;;
    esac
done

[[ -n "$OUT_FILE" ]] || OUT_FILE="$SPEC_DIR/_lessons/lessons.md"

index_of() {
    local needle="$1"; shift
    local i=0 item
    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then echo "$i"; return 0; fi
        i=$((i + 1))
    done
    echo "-1"
}

# Dedupe identity. Case and spacing differences are not different lessons, and
# a trailing period is punctuation, not meaning.
normalize_rule() {
    local r="$1"
    r="$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')"
    r="$(printf '%s' "$r" | tr -s '[:space:]' ' ')"
    r="${r#"${r%%[![:space:]]*}"}"
    r="${r%"${r##*[![:space:]]}"}"
    r="${r%.}"
    printf '%s' "$r"
}

# ---- collect ----------------------------------------------------------------

section "specwright aggregate-lessons"
echo "  Spec dir: $SPEC_DIR"
echo "  Output:   $OUT_FILE"

if [[ ! -d "$SPEC_DIR" ]]; then
    fail "spec dir not found: $SPEC_DIR"
    exit 1
fi

raw="$(mktemp)"
grouped="$(mktemp)"
rendered="$(mktemp)"
cleanup() { rm -f "$raw" "$grouped" "$rendered"; }
trap cleanup EXIT

retro_count=0
skipped=0

# Sorted so the traversal itself is deterministic. Nothing downstream depends
# on file order (the sort below is total), but a stable walk keeps the skipped
# counter reproducible too.
while IFS= read -r retro; do
    [[ -n "$retro" ]] || continue
    retro_count=$((retro_count + 1))

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ "$line" == "- ["* ]] || continue

        # Auto-generated transition lines written by /sd:spec status and
        # /sd:release open with "- [" too (they carry a timestamp in the
        # brackets) but never match the lesson grammar, so they fall out here
        # rather than needing a rule of their own.
        if [[ ! "$line" =~ $LESSON_RE ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        tag="${BASH_REMATCH[1]}"
        severity="${BASH_REMATCH[2]}"
        scope="${BASH_REMATCH[3]}"
        rule="${BASH_REMATCH[4]}"
        if [[ "$rule" =~ $COUNT_RE ]]; then
            rule="${BASH_REMATCH[1]}"
        fi

        tag_idx="$(index_of "$tag" "${TAGS[@]}")"
        sev_idx="$(index_of "$severity" "${SEVERITIES[@]}")"
        scope_idx="$(index_of "$scope" "${SCOPES[@]}")"
        if [[ "$tag_idx" == "-1" || "$sev_idx" == "-1" || "$scope_idx" == "-1" ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        norm="$(normalize_rule "$rule")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$tag_idx" "$scope_idx" "$norm" "$sev_idx" "$rule" "$tag" >> "$raw"
    done < "$retro"
done < <(find "$SPEC_DIR" -mindepth 2 -maxdepth 2 -type f -name '05-retro.md' 2>/dev/null | LC_ALL=C sort)

# ---- dedupe -----------------------------------------------------------------
#
# Identity is (tag, scope, normalized rule).
#
# SEVERITIES is ordered high, medium, low - so a LARGER rank index means a LESS
# severe lesson. Sorting rank descending (-k4,4nr) therefore puts the least
# severe row first, and the first row of each group wins. That is deliberate: a
# lesson that reappears gets a count, never a promotion (see the anti-patterns
# in sd-retro-lessons). Ties break on the original rule text so the surviving
# wording is fixed rather than dependent on which retro was read first.
#
# Every sort here is byte-wise via LC_ALL=C so bash and PowerShell agree.
# PowerShell's default Sort-Object is culture-aware and would diverge - that
# divergence is the whole parity risk of this story.

if [[ -s "$raw" ]]; then
    LC_ALL=C sort -t $'\t' -k1,1n -k2,2n -k3,3 -k4,4nr -k5,5 "$raw" \
        | LC_ALL=C awk -F '\t' '
        {
            key = $1 "\x1f" $2 "\x1f" $3
            if (key != prev) {
                if (prev != "") { print out_tagidx "\t" out_sev "\t" out_rule "\t" out_tag "\t" out_scopeidx "\t" count }
                prev = key; count = 0
                out_tagidx = $1; out_scopeidx = $2; out_sev = $4; out_rule = $5; out_tag = $6
            }
            # Severity and surviving wording are resolved INDEPENDENTLY. Tying
            # them together means the sloppier phrasing wins whenever it happens
            # to carry the lower severity, which is how the first draft kept an
            # uncapitalised, unpunctuated variant over a well-formed one.
            #   severity -> least severe seen (largest rank): never promote.
            #   wording  -> byte-smallest seen: stable, and ASCII puts a proper
            #               capitalised sentence ahead of a lowercase one.
            if ($4 > out_sev)  { out_sev = $4 }
            if ($5 < out_rule) { out_rule = $5 }
            count++
        }
        END { if (prev != "") { print out_tagidx "\t" out_sev "\t" out_rule "\t" out_tag "\t" out_scopeidx "\t" count } }
    ' | LC_ALL=C sort -t $'\t' -k1,1n -k2,2n -k3,3 > "$grouped"
else
    : > "$grouped"
fi

# ---- render -----------------------------------------------------------------

{
    echo '# Lessons'
    echo ''
    echo 'GENERATED FILE - do not edit by hand. Regenerate with'
    echo '`scripts/aggregate-lessons.sh`; edits are lost on the next run.'
    echo ''
    echo 'Every rule below is written to be free of identifiers - no paths, file names,'
    echo 'line numbers, class or variable names - so this file can be shared outside the'
    echo 'organisation as-is. That contract is enforced by `scripts/validate-lessons.*`'
    echo 'and is the reason a lesson reads as a general rule rather than a bug report.'
    echo ''
    echo 'A trailing count is the number of retros a lesson was drawn from. Frequency'
    echo 'never raises severity.'

    current_tag=''
    while IFS=$'\t' read -r tag_idx sev_idx rule tag scope_idx count; do
        [[ -n "$tag" ]] || continue
        if [[ "$tag" != "$current_tag" ]]; then
            echo ''
            echo "## $tag"
            echo ''
            current_tag="$tag"
        fi
        severity="${SEVERITIES[$sev_idx]}"
        scope="${SCOPES[$scope_idx]}"
        if [[ "$count" -gt 1 ]]; then
            echo "- [$tag] $severity/$scope: $rule ($count)"
        else
            echo "- [$tag] $severity/$scope: $rule"
        fi
    done < "$grouped"
} > "$rendered"

lesson_count="$(wc -l < "$grouped" | tr -d ' ')"

# ---- write or check ---------------------------------------------------------

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ -f "$OUT_FILE" ]] && diff -q "$OUT_FILE" "$rendered" >/dev/null 2>&1; then
        ok "$lesson_count lesson(s) from $retro_count retro(s); $OUT_FILE is current"
        exit 0
    fi
    fail "$OUT_FILE is out of date - run without --check to regenerate"
    if [[ -f "$OUT_FILE" ]]; then
        diff "$OUT_FILE" "$rendered" | head -20 | sed 's/^/         /' || true
    else
        echo "         (file does not exist)"
    fi
    exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"
cp "$rendered" "$OUT_FILE"

ok "$lesson_count lesson(s) from $retro_count retro(s) -> $OUT_FILE"
if [[ "$skipped" -gt 0 ]]; then
    echo "         $skipped non-lesson line(s) skipped (transition logs, unknown tag/severity/scope)"
fi
exit 0
