#!/usr/bin/env bash
# Cross-file contract linter for the specwright ENGINE PRODUCT (Unix / bash).
#
# Twin of scripts/contract-lint.ps1. Both read specwright.manifest.json's
# `contractLint` subtree and MUST report the same rule ids, in the same order,
# for the same tree. Check 8 of scripts/validate.{sh,ps1} runs this as a child
# process; tests/contract-lint/run-selftest.ps1 runs both and diffs them.
#
# Where validate's Check 7 guards INVENTORY (how many files exist), this guards
# the RELATIONSHIPS between them: which agent a command invokes, which skill an
# agent loads, how many hard gates a workflow declares.
#
# Wave 1 rule bands (see the manifest's rules[] for the authoritative registry):
#   CL0xx  reference resolution
#   CL3xx  gate integrity
#   CL9xx  suppression hygiene
#
# Usage:
#   contract-lint.sh [--root <path>] [--rule <ids>] [--quiet]
#
#   --root   tree to lint (default: the repo this script lives in). The manifest
#            is read from <root>/specwright.manifest.json, which is what lets a
#            fixture tree configure itself.
#   --rule   comma-separated rule ids; filters the EMITTED findings only. Every
#            rule still runs, so CL902 (suppresses nothing) stays truthful.
#   --quiet  suppress the stderr summary line.
#
# Output is TSV on stdout, one finding per line, and nothing else:
#   <RULE>\t<SEVERITY>\t<FILE>\t<LINE>\t<MESSAGE>
# Paths are root-relative with forward slashes. Sort order is byte order on
# file, then numeric line, then rule id. The human-readable summary goes to
# stderr and is never parsed or compared.
#
# Exit codes:
#   0  no BLOCK findings
#   1  at least one BLOCK finding
#   2  cannot run (bad --root, missing manifest, missing jq, registry mismatch)
#
# Exit 2 is separate on purpose: a validator that cannot distinguish "clean"
# from "crashed" is worthless.

set -euo pipefail

# Byte-indexed string ops and byte-order sorting. The gate-marker strip below
# slices a leading run of non-ASCII BYTES; under a UTF-8 locale ${var:n} would
# slice characters instead and the two implementations would diverge.
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$script_dir/.." && pwd)"
RULE_FILTER=""
QUIET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)  ROOT="${2:-}"; shift 2 ;;
        --rule)  RULE_FILTER="${2:-}"; shift 2 ;;
        --quiet) QUIET=1; shift ;;
        -h|--help)
            grep -E '^# ' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "contract-lint: unknown argument '$1'" >&2
            exit 2 ;;
    esac
done

if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
    echo "contract-lint: --root is not a directory: '$ROOT'" >&2
    exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

MANIFEST="$ROOT/specwright.manifest.json"
if [[ ! -f "$MANIFEST" ]]; then
    echo "contract-lint: manifest not found: $MANIFEST" >&2
    exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
    # Hooks exit 0 silently without jq so they never block a user on their own
    # bugs. A linter must do the opposite - a silent pass would turn CI green
    # while checking nothing.
    echo "contract-lint: jq is required to parse specwright.manifest.json" >&2
    exit 2
fi

# Some jq builds (notably jq.exe on Windows) emit CRLF. An unstripped \r rides
# on the last field of every record and silently breaks set membership.
mjq() { jq -r "$1" "$MANIFEST" | tr -d '\r'; }

# ---- bash 3.2 collections ---------------------------------------------------
#
# macOS ships /bin/bash 3.2: no `declare -A`, no `mapfile`, no `${var^^}`.
# Two shapes only:
#   * SETS - one newline-delimited global per set, membership-tested in-process
#     with `case` glob matching. No subshell, no loop, no eval.
#   * RECORD TABLES - one newline-delimited scalar of records whose fields are
#     separated by US (0x1f), iterated with `while IFS=$'\x1f' read ...`.
#     US, not TAB: TAB is an IFS *whitespace* character, so bash collapses runs
#     of them and one empty middle field shifts every later field left.
# Nothing here is looked up by key at O(1); the sets are small and the tables
# are walked, so a linear scan is the right shape.

set_has() { # set_var_name value -> 0 if present
    local _set="${!1}" _val="$2"
    case $'\n'"$_set"$'\n' in
        *$'\n'"$_val"$'\n'*) return 0 ;;
    esac
    return 1
}

set_add() { # set_var_name value
    local _cur="${!1}"
    if [[ -z "$_cur" ]]; then
        printf -v "$1" '%s' "$2"
    else
        printf -v "$1" '%s\n%s' "$_cur" "$2"
    fi
}

# ---- regex constants --------------------------------------------------------
#
# Every pattern below must behave identically in POSIX ERE (here) and .NET
# (the twin). Use [0-9] not \d, [[:blank:]] not \s, no lookarounds.

RE_FENCE='^[[:blank:]]*```'
RE_HEADING='^(#{2,3}) (.+)$'
RE_SDREF='sd-[a-z0-9]+(-[a-z0-9]+)*'
RE_CMDREF='/sd:[a-z][a-z0-9-]*'
RE_TPLPATH='templates/[A-Za-z0-9_./-]+'
# The leading boundary alternative is load-bearing: without it the pattern also
# matches '07-cqrs-read-path.md' inside the ADR filename '0007-cqrs-read-path.md'
# (agents/docs-writer.md), which is not a spec artifact at all.
RE_ARTIFACT='(^|[^0-9A-Za-z_.-])[0-9][0-9]-[a-z0-9-]+\.md'
RE_SUPPRESS='<!--[[:blank:]]*contract-lint:[[:blank:]]*allow[[:blank:]]+CL[0-9][0-9][0-9]'
# An option set: a slash-separated parenthetical carrying no nested parens.
RE_OPTPAREN='\(([^()/]+/)+[^()]+\)'
# Byte range 0x80-0xFF in the C locale = any non-ASCII byte. Built at runtime so
# this file itself stays pure ASCII, exactly as scripts/validate.sh:45 does.
non_ascii_re="$(printf '[\200-\377]')"

# ---- Phase A: index ---------------------------------------------------------

NS_SEGMENT="$(mjq '.contractLint.installNamespaceSegment // "sd"')"

RULE_IDS=""
RULE_SEVERITY_TABLE=""
while IFS=$'\x1f' read -r r_id r_sev; do
    [[ -z "$r_id" ]] && continue
    set_add RULE_IDS "$r_id"
    RULE_SEVERITY_TABLE="${RULE_SEVERITY_TABLE}${r_id}"$'\x1f'"${r_sev}"$'\n'
done < <(mjq '.contractLint.rules[] | "\(.id)\u001f\(.severity)"')

severity_of() { # rule_id -> stdout BLOCK|WARN
    local _id="$1" _r _s
    while IFS=$'\x1f' read -r _r _s; do
        if [[ "$_r" == "$_id" ]]; then printf '%s' "$_s"; return; fi
    done <<< "$RULE_SEVERITY_TABLE"
}

# Every rule this implementation dispatches, in registry order. The parity guard
# below asserts this equals the manifest registry, so a wave-2 rule cannot land
# in the manifest, the docs or the fixtures without landing here too.
DISPATCH_IDS="CL001
CL002
CL003
CL004
CL005
CL006
CL007
CL008
CL300
CL301
CL302
CL303
CL304
CL305
CL900
CL901
CL902"

parity_bad=0
while IFS= read -r _id; do
    [[ -z "$_id" ]] && continue
    if ! set_has RULE_IDS "$_id"; then
        echo "contract-lint: dispatched rule '$_id' is absent from manifest contractLint.rules" >&2
        parity_bad=1
    fi
done <<< "$DISPATCH_IDS"
while IFS= read -r _id; do
    [[ -z "$_id" ]] && continue
    if ! set_has DISPATCH_IDS "$_id"; then
        echo "contract-lint: manifest rule '$_id' is not dispatched by this implementation" >&2
        parity_bad=1
    fi
done <<< "$RULE_IDS"
if [[ $parity_bad -ne 0 ]]; then
    echo "contract-lint: registry parity guard failed" >&2
    exit 2
fi

SPEC_ARTIFACTS=""
while IFS= read -r _a; do
    [[ -n "$_a" ]] && set_add SPEC_ARTIFACTS "$_a"
done < <(mjq '.contractLint.specArtifacts[]?')

SKILL_CONSUMERS=""
while IFS= read -r _s; do
    [[ -n "$_s" ]] && set_add SKILL_CONSUMERS "$_s"
done < <(mjq '.contractLint.skillConsumers // {} | keys[]?')

OVERRIDE_TOKENS=""
while IFS= read -r _t; do
    [[ -n "$_t" ]] && set_add OVERRIDE_TOKENS "$_t"
done < <(mjq '.contractLint.overrideOptionTokens[]?')

# gates: file <TAB> hard <TAB> conditional-labels-joined-by-comma
GATE_DECL_TABLE=""
GATE_DECL_FILES=""
while IFS=$'\x1f' read -r g_file g_hard g_cond; do
    [[ -z "$g_file" ]] && continue
    if [[ ! -f "$ROOT/$g_file" ]]; then
        echo "contract-lint: contractLint.gates names a file that does not exist: $g_file" >&2
        exit 2
    fi
    GATE_DECL_TABLE="${GATE_DECL_TABLE}${g_file}"$'\x1f'"${g_hard}"$'\x1f'"${g_cond}"$'\n'
    set_add GATE_DECL_FILES "$g_file"
done < <(mjq '.contractLint.gates // {} | to_entries[] | "\(.key)\u001f\(.value.hard)\u001f\(.value.conditional | join(","))"')

# Scan files: every scanScope glob, deduplicated, byte-sorted for a stable
# report order that the twin can reproduce exactly.
SCAN_FILES=""
shopt -s nullglob
while IFS= read -r _glob; do
    [[ -z "$_glob" ]] && continue
    for _p in "$ROOT"/$_glob; do
        [[ -f "$_p" ]] || continue
        set_add SCAN_FILES "${_p#"$ROOT"/}"
    done
done < <(mjq '.contractLint.scanScope[]')
shopt -u nullglob
SCAN_FILES="$(printf '%s\n' "$SCAN_FILES" | grep -v '^$' | sort -u || true)"

if [[ -z "$SCAN_FILES" ]]; then
    echo "contract-lint: contractLint.scanScope matched no files under $ROOT" >&2
    exit 2
fi

# Agents, skills and commands come from disk, never from the manifest - they are
# inventory, and the manifest's charter says inventory is derived.
AGENT_NAMES=""
AGENT_NAME_FILE_TABLE=""
shopt -s nullglob
for _p in "$ROOT"/agents/*.md; do
    _rel="${_p#"$ROOT"/}"
    _name="$(sed -n '1,20{s/^name:[[:space:]]*//p;}' "$_p" | head -n1 | tr -d '\r')"
    [[ -z "$_name" ]] && continue
    set_add AGENT_NAMES "$_name"
    AGENT_NAME_FILE_TABLE="${AGENT_NAME_FILE_TABLE}${_name}"$'\x1f'"${_rel}"$'\n'
done

SKILL_NAMES=""
SKILL_NAME_FILE_TABLE=""
for _p in "$ROOT"/skills/*/SKILL.md; do
    _rel="${_p#"$ROOT"/}"
    _dir="${_rel#skills/}"
    _dir="${_dir%/SKILL.md}"
    set_add SKILL_NAMES "$_dir"
    SKILL_NAME_FILE_TABLE="${SKILL_NAME_FILE_TABLE}${_dir}"$'\x1f'"${_rel}"$'\n'
done

COMMAND_NAMES=""
for _p in "$ROOT"/commands/*.md; do
    _rel="${_p#"$ROOT"/}"
    _base="${_rel#commands/}"
    set_add COMMAND_NAMES "${_base%.md}"
done
shopt -u nullglob

# ---- finding + suppression stores ------------------------------------------

F_N=0
f_rule=(); f_file=(); f_line=(); f_msg=()

add_finding() { # rule file line message
    f_rule[$F_N]="$1"
    f_file[$F_N]="$2"
    f_line[$F_N]="$3"
    # Sanitised at emit-time source, not at print-time: a tab or CR inside a
    # message silently corrupts the consumer's `IFS=$'\t' read`.
    f_msg[$F_N]="$(printf '%s' "$4" | tr -d '\r\t')"
    F_N=$((F_N + 1))
}

S_N=0
s_file=(); s_line=(); s_rule=(); s_used=(); s_bad=()

# ---- per-file line + fence cache -------------------------------------------
#
# One disk pass. Rules read these caches; none re-walks the tree.
#   FILE_LINES_<n> / FILE_FENCE_<n> are held per file inside load_file, which
#   every rule loop calls in the same byte-sorted order.

CUR_LINES=(); CUR_FENCE=(); CUR_N=0; CUR_REL=""

load_file() { # relative_path
    local _rel="$1" _abs="$ROOT/$1" _ln _i _in=0
    CUR_REL="$_rel"
    CUR_LINES=(); CUR_FENCE=(); CUR_N=0
    # Read raw and strip a trailing CR per line. .gitattributes does NOT pin
    # *.md to LF, so on a Windows checkout every file here is CRLF on disk.
    while IFS= read -r _ln || [[ -n "$_ln" ]]; do
        CUR_LINES[$CUR_N]="${_ln%$'\r'}"
        CUR_N=$((CUR_N + 1))
    done < "$_abs"
    for ((_i = 0; _i < CUR_N; _i++)); do
        if [[ "${CUR_LINES[$_i]}" =~ $RE_FENCE ]]; then
            CUR_FENCE[$_i]=1
            if [[ $_in -eq 0 ]]; then _in=1; else _in=0; fi
        else
            CUR_FENCE[$_i]=$_in
        fi
    done
}

# ---- reference index --------------------------------------------------------
#
# A flat (kind, target, file, line) table. EVERY CL0xx rule reads this table and
# none of them re-walks the disk, so a wave-2 rule means adding one kind to one
# extractor rather than a second traversal.

REFS=""   # kind \t target \t file \t line

collect_refs() {
    local _rel _lno _raw _tok _pat _kind
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        load_file "$_rel"
        for _pat in "sdref:$RE_SDREF" "commandRef:$RE_CMDREF" \
                    "templatePath:$RE_TPLPATH" "specArtifact:$RE_ARTIFACT"; do
            _kind="${_pat%%:*}"
            # grep -o once per (file, pattern) - 4 forks per file, never one per
            # line. A subshell inside a per-line loop is ~12k forks on this tree
            # and turns a 1s check into 40s on the Windows runner.
            while IFS= read -r _raw; do
                [[ -z "$_raw" ]] && continue
                _lno="${_raw%%:*}"
                _tok="${_raw#*:}"
                # grep line numbers are 1-based; the fence cache is 0-based.
                [[ "${CUR_FENCE[$((_lno - 1))]}" == "1" ]] && continue
                if [[ "$_kind" == "specArtifact" ]]; then
                    # Drop the boundary character the pattern had to consume.
                    case "$_tok" in
                        [0-9]*) : ;;
                        *) _tok="${_tok:1}" ;;
                    esac
                fi
                REFS="${REFS}${_kind}"$'\x1f'"${_tok}"$'\x1f'"${_rel}"$'\x1f'"${_lno}"$'\n'
            done < <(grep -onE "${_pat#*:}" "$ROOT/$_rel" || true)
        done
    done <<< "$SCAN_FILES"
}

collect_refs

# ---- agent `skills:` frontmatter index -------------------------------------

AGENT_SKILL_REFS=""   # agent_file \t line \t skill_name

collect_agent_skills() {
    local _rel _i _line _in_fm=0 _in_skills=0 _entry
    shopt -s nullglob
    for _p in "$ROOT"/agents/*.md; do
        _rel="${_p#"$ROOT"/}"
        load_file "$_rel"
        _in_fm=0; _in_skills=0
        for ((_i = 0; _i < CUR_N; _i++)); do
            _line="${CUR_LINES[$_i]}"
            if [[ "$_line" == "---" ]]; then
                if [[ $_in_fm -eq 0 ]]; then _in_fm=1; continue; else break; fi
            fi
            [[ $_in_fm -eq 1 ]] || continue
            if [[ "$_line" =~ ^skills:[[:blank:]]*$ ]]; then
                _in_skills=1
                continue
            fi
            if [[ $_in_skills -eq 1 ]]; then
                if [[ "$_line" =~ ^[[:blank:]]+-[[:blank:]]+(.+)$ ]]; then
                    _entry="${BASH_REMATCH[1]}"
                    AGENT_SKILL_REFS="${AGENT_SKILL_REFS}${_rel}"$'\x1f'"$((_i + 1))"$'\x1f'"${_entry}"$'\n'
                    continue
                fi
                _in_skills=0
            fi
        done
    done
    shopt -u nullglob
}

collect_agent_skills

# ---- gate index -------------------------------------------------------------
#
# A gate BLOCK is [heading line, next heading of any level or EOF). That window
# is the whole reason CL300 does not fire on the ~20 literal STOPs in Phase 0
# bootstrap error paths - they all sit under a '## Phase 0' heading, never
# inside a gate block.

GATES=""   # file \t line \t kind(hard|conditional) \t label \t isHard(0|1) \t blockEnd

# Strip the leading non-ASCII marker run, then an optional 'Phase N - ' prefix,
# and report whether the remainder names a gate. Sets GATE_KIND / GATE_LABEL.
classify_heading() { # heading_title -> 0 if a gate
    local _t="$1" _rest
    GATE_KIND=""; GATE_LABEL=""
    # Peel bytes, never encode the marker: contract-lint.ps1 must stay pure
    # ASCII and the twin peels UTF-16 chars over the same run. Both land on the
    # identical ASCII remainder, and nothing downstream reports a column offset.
    while [[ -n "$_t" && "${_t:0:1}" =~ $non_ascii_re ]]; do
        _t="${_t:1}"
    done
    while [[ "${_t:0:1}" == " " ]]; do _t="${_t:1}"; done
    if [[ "$_t" =~ ^Phase[[:blank:]]+[0-9]+[[:blank:]]+-[[:blank:]]+(.*)$ ]]; then
        _t="${BASH_REMATCH[1]}"
    fi
    case "$_t" in
        Gate*) _rest="${_t#Gate}" ;;
        *) return 1 ;;
    esac
    if [[ "$_rest" =~ ^\ ([0-9]+)([[:blank:]].*)?$ ]]; then
        GATE_KIND="hard"; GATE_LABEL="${BASH_REMATCH[1]}"; return 0
    fi
    if [[ "$_rest" =~ ^\ ([0-9]+[a-z])([[:blank:]].*)?$ ]]; then
        GATE_KIND="conditional"; GATE_LABEL="${BASH_REMATCH[1]}"; return 0
    fi
    if [[ "$_rest" =~ ^\ (Re-plan)([^A-Za-z0-9].*)?$ ]]; then
        GATE_KIND="conditional"; GATE_LABEL="Re-plan"; return 0
    fi
    if [[ "$_rest" =~ ^\ ?[-\(\[] ]]; then
        GATE_KIND="hard"; GATE_LABEL=""; return 0
    fi
    # Anything else is not a gate. This single row is the entire false-positive
    # defence and it needs no exclusion list: 'Gate' followed by a lowercase
    # word ('## Gate activity' in commands/status.md) is never a gate heading.
    return 1
}

collect_gates() {
    local _rel _i _j _line _title _end _hard
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        load_file "$_rel"
        for ((_i = 0; _i < CUR_N; _i++)); do
            [[ "${CUR_FENCE[$_i]}" == "1" ]] && continue
            _line="${CUR_LINES[$_i]}"
            [[ "$_line" =~ $RE_HEADING ]] || continue
            _title="${BASH_REMATCH[2]}"
            classify_heading "$_title" || continue
            _end=$CUR_N
            for ((_j = _i + 1; _j < CUR_N; _j++)); do
                if [[ "${CUR_FENCE[$_j]}" != "1" && "${CUR_LINES[$_j]}" =~ ^#{1,6}[[:blank:]] ]]; then
                    _end=$_j; break
                fi
            done
            _hard=0
            case "$_line" in
                *'(HARD)'*|*'[HARD]'*) _hard=1 ;;
            esac
            GATES="${GATES}${_rel}"$'\x1f'"$((_i + 1))"$'\x1f'"${GATE_KIND}"$'\x1f'"${GATE_LABEL}"$'\x1f'"${_hard}"$'\x1f'"${_end}"$'\n'
        done
    done <<< "$SCAN_FILES"
}

collect_gates

# ---- suppression index ------------------------------------------------------
#
# Indexed ONLY inside scanScope and ONLY outside fenced code blocks, so
# docs/contract-lint.md and CONTRIBUTING.md can show the syntax without minting
# a phantom suppression that then trips CL902.

collect_suppressions() {
    local _rel _i _line _rule _reason _bare
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        load_file "$_rel"
        for ((_i = 0; _i < CUR_N; _i++)); do
            [[ "${CUR_FENCE[$_i]}" == "1" ]] && continue
            _line="${CUR_LINES[$_i]}"
            [[ "$_line" =~ $RE_SUPPRESS ]] || continue
            [[ "$_line" =~ allow[[:blank:]]+(CL[0-9][0-9][0-9])(.*)$ ]] || continue
            _rule="${BASH_REMATCH[1]}"
            _reason="${BASH_REMATCH[2]}"
            _reason="${_reason%%-->*}"
            # Strip a leading separator, then measure the non-space payload.
            _bare="$(printf '%s' "$_reason" | tr -d ' \t-')"
            s_file[$S_N]="$_rel"
            s_line[$S_N]=$((_i + 1))
            s_rule[$S_N]="$_rule"
            s_used[$S_N]=0
            s_bad[$S_N]=0
            if ! set_has RULE_IDS "$_rule"; then
                s_bad[$S_N]=1
                add_finding CL901 "$_rel" "$((_i + 1))" "suppression names unknown rule '$_rule'"
            elif [[ ${#_bare} -lt 10 ]]; then
                add_finding CL900 "$_rel" "$((_i + 1))" "suppression for $_rule carries no usable reason"
            fi
            S_N=$((S_N + 1))
        done
    done <<< "$SCAN_FILES"
}

collect_suppressions

# ---- Phase B: rules ---------------------------------------------------------
#
# Each rule takes no arguments, reads the index, and calls add_finding. SEVERITY
# IS NEVER PASSED BY A RULE - it is looked up from the manifest at emit time, so
# a BLOCK/WARN divergence between the twins is structurally impossible.

line_text() { # file line -> stdout (1-based)
    local _rel="$1" _n="$2"
    if [[ "$CUR_REL" != "$_rel" ]]; then load_file "$_rel"; fi
    printf '%s' "${CUR_LINES[$((_n - 1))]}"
}

# True when (file, line) is an entry in an agent's `skills:` frontmatter list.
# CL002 owns those lines; without this both CL001 and CL002 would fire on the
# same missing skill, which is one problem reported twice - the same "one error,
# not two" doctrine that exempts a CL901 suppression from CL902.
is_agent_skill_entry() { # file line
    local _f="$1" _l="$2" _af _al _as
    while IFS=$'\x1f' read -r _af _al _as; do
        if [[ "$_af" == "$_f" && "$_al" == "$_l" ]]; then return 0; fi
    done <<< "$AGENT_SKILL_REFS"
    return 1
}

rule_CL001_CL003() {
    local _k _t _f _l _txt _lower
    while IFS=$'\x1f' read -r _k _t _f _l; do
        [[ "$_k" == "sdref" ]] || continue
        set_has AGENT_NAMES "$_t" && continue
        set_has SKILL_NAMES "$_t" && continue
        is_agent_skill_entry "$_f" "$_l" && continue
        _txt="$(line_text "$_f" "$_l")"
        _lower="$(printf '%s' "$_txt" | tr 'A-Z' 'a-z')"
        case "$_lower" in
            *skill*)
                add_finding CL003 "$_f" "$_l" "unresolved skill reference '$_t'" ;;
            *)
                add_finding CL001 "$_f" "$_l" "unresolved sd- reference '$_t'" ;;
        esac
    done <<< "$REFS"
}

rule_CL002() {
    local _f _l _s
    while IFS=$'\x1f' read -r _f _l _s; do
        [[ -z "$_f" ]] && continue
        [[ -f "$ROOT/skills/$_s/SKILL.md" ]] && continue
        add_finding CL002 "$_f" "$_l" "skills: entry '$_s' has no skills/$_s/SKILL.md"
    done <<< "$AGENT_SKILL_REFS"
}

rule_CL004() {
    local _s _self _k _t _f _l _referenced _af _al _as
    while IFS=$'\x1f' read -r _s _self; do
        [[ -z "$_s" ]] && continue
        set_has SKILL_CONSUMERS "$_s" && continue
        _referenced=0
        while IFS=$'\x1f' read -r _k _t _f _l; do
            [[ "$_k" == "sdref" ]] || continue
            [[ "$_t" == "$_s" ]] || continue
            [[ "$_f" == "$_self" ]] && continue
            _referenced=1; break
        done <<< "$REFS"
        if [[ $_referenced -eq 0 ]]; then
            while IFS=$'\x1f' read -r _af _al _as; do
                if [[ "$_as" == "$_s" ]]; then _referenced=1; break; fi
            done <<< "$AGENT_SKILL_REFS"
        fi
        if [[ $_referenced -eq 0 ]]; then
            add_finding CL004 "$_self" 1 "skill '$_s' is referenced by nothing in scan scope"
        fi
    done <<< "$SKILL_NAME_FILE_TABLE"
}

rule_CL005() {
    local _k _t _f _l _p
    while IFS=$'\x1f' read -r _k _t _f _l; do
        [[ "$_k" == "templatePath" ]] || continue
        _p="$_t"
        # templates/<ns>/... is the INSTALL target (~/.claude/templates/sd/),
        # not a repo path. Fold the namespace segment away before testing disk.
        case "$_p" in
            "templates/$NS_SEGMENT/"*) _p="templates/${_p#"templates/$NS_SEGMENT/"}" ;;
            "templates/$NS_SEGMENT") _p="templates" ;;
        esac
        _p="${_p%.}"
        _p="${_p%/}"
        [[ -e "$ROOT/$_p" ]] && continue
        add_finding CL005 "$_f" "$_l" "templates path does not exist: '$_t'"
    done <<< "$REFS"
}

rule_CL006() {
    local _k _t _f _l _name
    while IFS=$'\x1f' read -r _k _t _f _l; do
        [[ "$_k" == "commandRef" ]] || continue
        _name="${_t#/sd:}"
        set_has COMMAND_NAMES "$_name" && continue
        add_finding CL006 "$_f" "$_l" "no command file for '$_t'"
    done <<< "$REFS"
}

rule_CL007() {
    local _a _af _k _t _f _l _seen
    while IFS=$'\x1f' read -r _a _af; do
        [[ -z "$_a" ]] && continue
        _seen=0
        while IFS=$'\x1f' read -r _k _t _f _l; do
            [[ "$_k" == "sdref" ]] || continue
            [[ "$_t" == "$_a" ]] || continue
            case "$_f" in commands/*) _seen=1; break ;; esac
        done <<< "$REFS"
        if [[ $_seen -eq 0 ]]; then
            add_finding CL007 "$_af" 1 "agent '$_a' is invoked by no command"
        fi
    done <<< "$AGENT_NAME_FILE_TABLE"
}

rule_CL008() {
    local _k _t _f _l
    while IFS=$'\x1f' read -r _k _t _f _l; do
        [[ "$_k" == "specArtifact" ]] || continue
        set_has SPEC_ARTIFACTS "$_t" && continue
        add_finding CL008 "$_f" "$_l" "unknown spec artifact filename '$_t'"
    done <<< "$REFS"
}

# Collect a gate block's selectable OPTIONS: the slash-separated tokens of a
# parenthetical, plus the backticked leading token of each top-level bullet.
# Sets OPT_TOKENS (newline-delimited "line<US>token" records) and OPT_HAS_SET.
gate_options() { # file blockStartLine blockEndExclusive0
    local _rel="$1" _start="$2" _end="$3" _i _line _inner _piece _tok _bullets=0
    OPT_TOKENS=""; OPT_HAS_SET=0
    if [[ "$CUR_REL" != "$_rel" ]]; then load_file "$_rel"; fi
    for ((_i = _start - 1; _i < _end; _i++)); do
        _line="${CUR_LINES[$_i]}"
        if [[ "$_line" =~ $RE_OPTPAREN ]]; then
            OPT_HAS_SET=1
            _inner="${BASH_REMATCH[0]}"
            _inner="${_inner#\(}"
            _inner="${_inner%\)}"
            while IFS= read -r _piece; do
                _tok="$(normalize_option "$_piece")"
                [[ -n "$_tok" ]] && OPT_TOKENS="${OPT_TOKENS}$((_i + 1))"$'\x1f'"${_tok}"$'\n'
            done <<< "$(printf '%s' "$_inner" | tr '/' '\n')"
        fi
        if [[ "$_line" =~ ^-[[:blank:]] ]]; then
            _bullets=$((_bullets + 1))
            if [[ "$_line" =~ ^-[[:blank:]]+\`([^\`]+)\` ]]; then
                _tok="$(normalize_option "${BASH_REMATCH[1]}")"
                [[ -n "$_tok" ]] && OPT_TOKENS="${OPT_TOKENS}$((_i + 1))"$'\x1f'"${_tok}"$'\n'
            fi
        fi
    done
    [[ $_bullets -ge 2 ]] && OPT_HAS_SET=1
    return 0
}

trim_blank() { # string -> stdout, leading/trailing spaces and tabs removed
    local _s="$1" _c
    while [[ -n "$_s" ]]; do
        _c="${_s:0:1}"
        [[ "$_c" == " " || "$_c" == "$(printf '\t')" ]] || break
        _s="${_s:1}"
    done
    while [[ -n "$_s" ]]; do
        _c="${_s: -1}"
        [[ "$_c" == " " || "$_c" == "$(printf '\t')" ]] || break
        _s="${_s:0:${#_s}-1}"
    done
    printf '%s' "$_s"
}

# The seven steps below are a CONTRACT with contract-lint.ps1's Get-NormalizedOption.
# Both must produce byte-identical tokens or CL305 diverges between the twins.
#   1. truncate at the first backtick        5. drop every ` and " character
#   2. trim spaces/tabs                      6. lowercase A-Z only
#   3. truncate at the first " - "           7. trim spaces/tabs again
#   4. truncate at the first " <"
normalize_option() { # raw piece -> stdout lowercase leading token
    local _s="$1"
    _s="${_s%%\`*}"
    _s="$(trim_blank "$_s")"
    _s="${_s%% - *}"
    _s="${_s%% <*}"
    _s="$(printf '%s' "$_s" | tr -d '`"' | tr 'A-Z' 'a-z')"
    _s="$(trim_blank "$_s")"
    printf '%s' "$_s"
}

rule_CL300_CL301_CL305() {
    local _f _l _kind _label _hard _end _i _has_stop _ol _ot
    while IFS=$'\x1f' read -r _f _l _kind _label _hard _end; do
        [[ -z "$_f" ]] && continue
        if [[ "$CUR_REL" != "$_f" ]]; then load_file "$_f"; fi
        _has_stop=0
        for ((_i = _l - 1; _i < _end; _i++)); do
            case "${CUR_LINES[$_i]}" in
                *STOP*) _has_stop=1; break ;;
            esac
        done
        if [[ $_has_stop -eq 0 ]]; then
            add_finding CL300 "$_f" "$_l" "gate block contains no literal STOP"
        fi
        gate_options "$_f" "$_l" "$_end"
        if [[ $OPT_HAS_SET -eq 0 ]]; then
            add_finding CL301 "$_f" "$_l" "gate block offers no option set"
        fi
        if [[ $_hard -eq 1 && -n "$OPT_TOKENS" ]]; then
            while IFS=$'\x1f' read -r _ol _ot; do
                [[ -z "$_ot" ]] && continue
                if set_has OVERRIDE_TOKENS "$_ot"; then
                    add_finding CL305 "$_f" "$_ol" "HARD gate offers override option '$_ot'"
                fi
            done <<< "$OPT_TOKENS"
        fi
    done <<< "$GATES"
}

rule_CL302_CL303_CL304() {
    local _rel _f _l _kind _label _hard _end
    local _count _labels _decl_hard _decl_cond _c _want _dup _seen _n
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        _count=0; _labels=""
        while IFS=$'\x1f' read -r _f _l _kind _label _hard _end; do
            [[ "$_f" == "$_rel" ]] || continue
            if [[ "$_kind" == "hard" ]]; then
                _count=$((_count + 1))
                [[ -n "$_label" ]] && _labels="${_labels}${_label}"$'\n'
            fi
        done <<< "$GATES"

        _decl_hard=0; _decl_cond=""
        if set_has GATE_DECL_FILES "$_rel"; then
            while IFS=$'\x1f' read -r _f _c _want; do
                if [[ "$_f" == "$_rel" ]]; then _decl_hard="$_c"; _decl_cond="$_want"; fi
            done <<< "$GATE_DECL_TABLE"
        fi
        if [[ "$_count" -ne "$_decl_hard" ]]; then
            add_finding CL302 "$_rel" 1 "hard gate count is $_count on disk, manifest declares $_decl_hard"
        fi

        # CL303 is SET-based, never file order: commands/bug.md authors
        # '### Gate 3a' before '### Gate 3' and must still pass.
        _labels="$(printf '%s' "$_labels" | grep -v '^$' | sort -n || true)"
        _n=0; _dup=0; _seen=""
        while IFS= read -r _c; do
            [[ -z "$_c" ]] && continue
            _n=$((_n + 1))
            if set_has _seen "$_c"; then _dup=1; fi
            set_add _seen "$_c"
        done <<< "$_labels"
        if [[ $_n -gt 0 ]]; then
            _want=1
            while IFS= read -r _c; do
                [[ -z "$_c" ]] && continue
                if [[ "$_c" != "$_want" ]]; then _dup=1; break; fi
                _want=$((_want + 1))
            done <<< "$_labels"
            if [[ $_dup -ne 0 ]]; then
                add_finding CL303 "$_rel" 1 "hard gate numbering is not 1..$_n without duplicates"
            fi
        fi

        # CL304 - symmetric set difference, both directions BLOCK. The
        # declared-but-absent half is the anti-rot direction.
        _seen=""
        while IFS=$'\x1f' read -r _f _l _kind _label _hard _end; do
            [[ "$_f" == "$_rel" ]] || continue
            [[ "$_kind" == "conditional" ]] || continue
            set_add _seen "$_label"
            case ",$_decl_cond," in
                *",$_label,"*) ;;
                *) add_finding CL304 "$_rel" "$_l" "conditional gate '$_label' is not declared in the manifest" ;;
            esac
        done <<< "$GATES"
        if [[ -n "$_decl_cond" ]]; then
            while IFS= read -r _c; do
                [[ -z "$_c" ]] && continue
                if ! set_has _seen "$_c"; then
                    add_finding CL304 "$_rel" 1 "manifest declares conditional gate '$_c' but it is absent from disk"
                fi
            done <<< "$(printf '%s' "$_decl_cond" | tr ',' '\n')"
        fi
    done <<< "$SCAN_FILES"
}

rule_CL001_CL003
rule_CL002
rule_CL004
rule_CL005
rule_CL006
rule_CL007
rule_CL008
rule_CL300_CL301_CL305
rule_CL302_CL303_CL304

# ---- Phase C: suppressions, sort, emit -------------------------------------
#
# A suppression can never suppress CL900, CL901 or CL902 - otherwise
# '<!-- contract-lint: allow CL900 -->' would be a self-authorizing loophole.
# That exclusion is hardcoded, never manifest-driven.

resolve_suppressions() {
    local _i _j _keep_rule=() _keep_file=() _keep_line=() _keep_msg=() _n=0 _hit
    for ((_i = 0; _i < F_N; _i++)); do
        _hit=0
        case "${f_rule[$_i]}" in
            CL900|CL901|CL902) _hit=0 ;;
            *)
                for ((_j = 0; _j < S_N; _j++)); do
                    [[ "${s_bad[$_j]}" == "1" ]] && continue
                    [[ "${s_file[$_j]}" == "${f_file[$_i]}" ]] || continue
                    [[ "${s_rule[$_j]}" == "${f_rule[$_i]}" ]] || continue
                    if [[ "${s_line[$_j]}" -eq "${f_line[$_i]}" \
                       || "${s_line[$_j]}" -eq $(( ${f_line[$_i]} - 1 )) ]]; then
                        s_used[$_j]=1
                        _hit=1
                        break
                    fi
                done ;;
        esac
        if [[ $_hit -eq 0 ]]; then
            _keep_rule[$_n]="${f_rule[$_i]}"
            _keep_file[$_n]="${f_file[$_i]}"
            _keep_line[$_n]="${f_line[$_i]}"
            _keep_msg[$_n]="${f_msg[$_i]}"
            _n=$((_n + 1))
        fi
    done
    F_N=$_n
    f_rule=(); f_file=(); f_line=(); f_msg=()
    for ((_i = 0; _i < _n; _i++)); do
        f_rule[$_i]="${_keep_rule[$_i]}"
        f_file[$_i]="${_keep_file[$_i]}"
        f_line[$_i]="${_keep_line[$_i]}"
        f_msg[$_i]="${_keep_msg[$_i]}"
    done
    # CL902 runs LAST, over the used flags. A CL901-flagged suppression is
    # exempt - one error per broken suppression, never two.
    for ((_j = 0; _j < S_N; _j++)); do
        [[ "${s_bad[$_j]}" == "1" ]] && continue
        [[ "${s_used[$_j]}" == "1" ]] && continue
        add_finding CL902 "${s_file[$_j]}" "${s_line[$_j]}" \
            "suppression for ${s_rule[$_j]} suppressed nothing"
    done
}

resolve_suppressions

rule_wanted() { # rule_id -> 0 if it should be emitted
    [[ -z "$RULE_FILTER" ]] && return 0
    case ",$RULE_FILTER," in
        *",$1,"*) return 0 ;;
    esac
    return 1
}

blocks=0
warns=0
emit=""
for ((i = 0; i < F_N; i++)); do
    rule_wanted "${f_rule[$i]}" || continue
    sev="$(severity_of "${f_rule[$i]}")"
    [[ -z "$sev" ]] && sev="BLOCK"
    if [[ "$sev" == "BLOCK" ]]; then blocks=$((blocks + 1)); else warns=$((warns + 1)); fi
    # Sort key: file, then zero-padded line so lexical order IS numeric order,
    # then rule id, then message. The message is in the key so two findings that
    # agree on the first three components still order deterministically - `sort`
    # is not stable, and the twin's List.Sort is not stable either.
    printf -v padded '%09d' "${f_line[$i]}"
    emit="${emit}${f_file[$i]}"$'\x01'"${padded}"$'\x01'"${f_rule[$i]}"$'\x01'"${f_msg[$i]}"$'\t'"${f_rule[$i]}"$'\t'"${sev}"$'\t'"${f_file[$i]}"$'\t'"${f_line[$i]}"$'\t'"${f_msg[$i]}"$'\n'
done

if [[ -n "$emit" ]]; then
    printf '%s' "$emit" | grep -v '^$' | sort | cut -f2-
fi

if [[ $QUIET -eq 0 ]]; then
    echo "contract-lint: $blocks block, $warns warn (root: $ROOT)" >&2
fi

if [[ $blocks -gt 0 ]]; then exit 1; fi
exit 0
