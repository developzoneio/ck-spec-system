#!/usr/bin/env bash
# specwright: privacy validator for lesson files (Unix / bash).
#
# Mirror of scripts/validate-lessons.ps1 - both must accept and reject exactly
# the same lines. Unlike scripts/validate.sh (which checks THIS repo's own
# invariants), this validator runs against a consumer repo's lessons file:
# specwright itself has no .specs/ tree, so there is nothing here to check
# except the fixtures under tests/lessons/fixtures/.
#
#   bash scripts/validate-lessons.sh [FILE ...]
#
# With no argument it defaults to .specs/_lessons/lessons.md relative to the
# current directory. A missing default file is NOT an error (a repo that has
# not produced lessons yet is valid); a missing explicit argument is.
#
# Grammar enforced (see skills/sd-retro-lessons/SKILL.md):
#   - [tag] severity/scope: Rule sentence.
#
# Exit 0 = every lesson line is well-formed and identifier-free; 1 = at least
# one violation.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

DEFAULT_REL=".specs/_lessons/lessons.md"
MAX_RULE_LEN=120

# Kept in sync with $TAGS in validate-lessons.ps1 and the enum table in
# skills/sd-retro-lessons/SKILL.md. Capped at 12 by that skill; adding one
# takes a PR citing the retro that produced it.
TAGS="sibling-repo-assumption missed-context baseline-attribution tooling-surprise \
gate-friction config-drift test-fragility test-gap precedent-conflict scope-discipline"

SCOPES="feature bug refactor perf rca all"
SEVERITIES="high medium low"

# Technology proper nouns that are legitimately PascalCase. Deliberately short -
# a lesson needing a word that is not here is usually less portable than its
# author thinks. Extending this list takes a PR (and the same edit in the
# PowerShell twin).
IDENT_ALLOWLIST="PowerShell TypeScript JavaScript PostgreSQL MySQL MongoDB SQLite \
GitHub GitLab OpenAPI GraphQL WebSocket DevOps JSONPath"

# Extensions that mark a filename. An explicit list rather than a generic
# dot-letters pattern, which would flag ordinary prose such as "e.g." or a
# sentence-ending period followed by a lowercase word.
EXT_RE='\.(md|json|jsonl|ps1|sh|bash|cs|ts|tsx|js|jsx|mjs|py|go|rb|rs|java|kt|php|yml|yaml|xml|sql|txt|csv|html|css|scss|toml|ini|cfg|lua|sln|csproj)([^a-zA-Z0-9]|$)'

# Same grammar as the PowerShell twin's $LESSON_RE. Held in variables and
# referenced unquoted inside [[ =~ ]] so the spaces need no backslash escaping.
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

violations=0
lessons_seen=0

report() {
    local file="$1" lineno="$2" msg="$3"
    fail "$file:$lineno : $msg"
    violations=$((violations + 1))
}

in_list() {
    local needle="$1" list="$2" item
    for item in $list; do
        if [[ "$item" == "$needle" ]]; then return 0; fi
    done
    return 1
}

# Splits the rule text into word tokens and tests each one whole. Done this way
# rather than with a word-boundary regex because \b is not portable across the
# bash builtin [[ =~ ]] and BSD grep, and an anchored per-token test is easier
# to reason about than an embedded boundary assertion.
check_identifiers() {
    local file="$1" lineno="$2" text="$3"
    local scrubbed="$text" word token
    for word in $IDENT_ALLOWLIST; do
        scrubbed="${scrubbed//$word/}"
    done

    # Replace every character that cannot appear inside an identifier with a
    # space, then iterate the remaining tokens.
    local split
    split="$(printf '%s' "$scrubbed" | tr -c 'A-Za-z0-9_' ' ')"
    for token in $split; do
        if [[ "$token" =~ ^[A-Z][a-z]+[A-Z][A-Za-z0-9]*$ ]]; then
            report "$file" "$lineno" "PascalCase identifier '$token' in rule text"
        elif [[ "$token" =~ ^[a-z]+[A-Z][A-Za-z0-9]*$ ]]; then
            report "$file" "$lineno" "camelCase identifier '$token' in rule text"
        elif [[ "$token" =~ ^[a-z]+_[a-z0-9_]+$ ]]; then
            report "$file" "$lineno" "snake_case identifier '$token' in rule text"
        fi
    done
}

check_rule_text() {
    local file="$1" lineno="$2" text="$3"

    if [[ ${#text} -gt $MAX_RULE_LEN ]]; then
        report "$file" "$lineno" "rule is ${#text} chars (max $MAX_RULE_LEN)"
    fi
    if [[ "$text" == *'`'* ]]; then
        report "$file" "$lineno" "backtick in rule text - still describing code"
    fi
    if [[ "$text" == */* || "$text" == *'\'* ]]; then
        report "$file" "$lineno" "path separator in rule text"
    fi
    if [[ "$text" =~ $EXT_RE ]]; then
        report "$file" "$lineno" "file extension in rule text"
    fi
    if [[ "$text" =~ :[0-9]+ ]]; then
        report "$file" "$lineno" "line citation in rule text"
    fi
    check_identifiers "$file" "$lineno" "$text"
}

check_file() {
    local path="$1" rel="$2"
    local lineno=0 line

    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"

        # Only lines that open like a lesson are candidates. Prose, headers and
        # blank lines in the file are none of this validator's business.
        [[ "$line" == "- ["* ]] || continue
        lessons_seen=$((lessons_seen + 1))

        if [[ ! "$line" =~ $LESSON_RE ]]; then
            report "$rel" "$lineno" "does not match '- [tag] severity/scope: Rule sentence.'"
            continue
        fi

        local tag="${BASH_REMATCH[1]}"
        local severity="${BASH_REMATCH[2]}"
        local scope="${BASH_REMATCH[3]}"
        local rule="${BASH_REMATCH[4]}"

        # An aggregator-appended repeat count is metadata, not rule text.
        if [[ "$rule" =~ $COUNT_RE ]]; then
            rule="${BASH_REMATCH[1]}"
        fi

        in_list "$tag"      "$TAGS"       || report "$rel" "$lineno" "unknown tag '$tag'"
        in_list "$severity" "$SEVERITIES" || report "$rel" "$lineno" "unknown severity '$severity'"
        in_list "$scope"    "$SCOPES"     || report "$rel" "$lineno" "unknown scope '$scope'"

        check_rule_text "$rel" "$lineno" "$rule"
    done < "$path"
}

# ---- collect targets --------------------------------------------------------

targets=()
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        if [[ ! -f "$arg" ]]; then
            section "specwright validate-lessons"
            fail "$arg : file not found"
            exit 1
        fi
        targets+=("$arg")
    done
else
    if [[ -f "$DEFAULT_REL" ]]; then
        targets+=("$DEFAULT_REL")
    else
        section "specwright validate-lessons"
        ok "no $DEFAULT_REL in $(pwd) - nothing to validate"
        exit 0
    fi
fi

# ---- run --------------------------------------------------------------------

section "specwright validate-lessons"
for t in "${targets[@]}"; do
    rel="${t#"$repo_root"/}"
    check_file "$t" "$rel"
done

if [[ $violations -eq 0 ]]; then
    ok "$lessons_seen lesson line(s) across ${#targets[@]} file(s): well-formed, no identifiers"
    exit 0
else
    fail "$violations violation(s) across $lessons_seen lesson line(s)"
    exit 1
fi
