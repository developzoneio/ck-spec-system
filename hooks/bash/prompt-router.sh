#!/usr/bin/env bash
# specwright: UserPromptSubmit hook - prompt-router (bash).
#
# Reads Claude Code hook JSON from stdin. Emits a <context-router> block on
# stdout when workflow keywords, ticket IDs, or in-progress specs are detected.
# Exits 0 silently if jq is missing, if stdin is empty/invalid, or if no hints
# apply. Never writes to disk.
#
# Note: we deliberately do NOT use `set -u` because bash's empty-associative-array
# expansion is brittle under it; the hook must never fail noisily.

# --- graceful exits -----------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

# --- read stdin ---------------------------------------------------------------

input="$(cat 2>/dev/null || true)"
if [[ -z "${input}" ]]; then
    exit 0
fi

prompt="$(printf '%s' "${input}" | jq -r '.prompt // empty' 2>/dev/null)"
cwd="$(printf '%s' "${input}"    | jq -r '.cwd    // empty' 2>/dev/null)"

if [[ -z "${prompt}" || -z "${cwd}" ]]; then
    exit 0
fi
if [[ ! -d "${cwd}" ]]; then
    exit 0
fi

# --- load config (defaults if missing) ---------------------------------------

config_path="${cwd}/.claude/project-config.json"
config_json="{}"
if [[ -f "${config_path}" ]]; then
    if jq -e . "${config_path}" >/dev/null 2>&1; then
        config_json="$(cat "${config_path}")"
    fi
fi

# Hook enabled?
enabled="$(printf '%s' "${config_json}" | jq -r '.hooks.userPromptRouter.enabled // true' 2>/dev/null)"
if [[ "${enabled}" == "false" ]]; then
    exit 0
fi

spec_dir="$(printf '%s' "${config_json}"   | jq -r '.spec.dir       // ".specs"'         2>/dev/null)"
index_rel="$(printf '%s' "${config_json}"  | jq -r '.spec.indexFile // ".specs/index.md"' 2>/dev/null)"
ticket_pat="$(printf '%s' "${config_json}" | jq -r '.ticket.pattern // "^[A-Z]+-[0-9]+$"' 2>/dev/null)"

spec_path="${cwd}/${spec_dir}"
index_path="${cwd}/${index_rel}"

# --- keyword match ------------------------------------------------------------

prompt_lower="$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')"
declare -A matched
declare -A matched_terms

match_keywords() {
    local workflow="$1"
    local default_list="$2"
    local list
    list="$(printf '%s' "${config_json}" | jq -r --arg w "${workflow}" '.workflow.keywords[$w] // []  | join("\n")' 2>/dev/null)"
    if [[ -z "${list}" ]]; then
        list="${default_list}"
    fi
    local kw
    while IFS= read -r kw; do
        # Some jq builds (e.g. Windows jq.exe) emit CRLF for join("\n") output;
        # strip a trailing CR so the comparison below isn't corrupted.
        kw="${kw%$'\r'}"
        [[ -z "${kw}" ]] && continue
        local kw_lower
        kw_lower="$(printf '%s' "${kw}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${prompt_lower}" == *"${kw_lower}"* ]]; then
            matched["${workflow}"]=1
            if [[ -z "${matched_terms[${workflow}]:-}" ]]; then
                matched_terms["${workflow}"]="${kw}"
            else
                matched_terms["${workflow}"]="${matched_terms[${workflow}]}, ${kw}"
            fi
        fi
    done <<< "${list}"
}

match_keywords bug      $'bug\nfix\nbroken\nerror\ncrash\nregression\ndefect'
match_keywords feature  $'feature\nadd\nimplement\nnew\nsupport'
match_keywords refactor $'refactor\nrestructure\nclean up\nextract\nrename'
match_keywords perf     $'perf\nperformance\nslow\noptimize\nlatency\nthroughput'
match_keywords rca      $'incident\noutage\nrca\nroot cause\npost-mortem\npostmortem'

# --- ticket detection ---------------------------------------------------------

ticket_body="${ticket_pat#^}"
ticket_body="${ticket_body%\$}"

declare -a ticket_ids=()
if [[ -n "${ticket_body}" ]]; then
    while IFS= read -r tid; do
        [[ -z "${tid}" ]] && continue
        # de-dup
        local_found=0
        for existing in "${ticket_ids[@]:-}"; do
            if [[ "${existing}" == "${tid}" ]]; then local_found=1; break; fi
        done
        if [[ ${local_found} -eq 0 ]]; then
            ticket_ids+=("${tid}")
        fi
    done < <(printf '%s' "${prompt}" | grep -oE "${ticket_body}" 2>/dev/null || true)
fi

# --- spec folder match --------------------------------------------------------

declare -a ticket_specs=()
if [[ -d "${spec_path}" && ${#ticket_ids[@]} -gt 0 ]]; then
    while IFS= read -r folder; do
        base="$(basename "${folder}")"
        for tid in "${ticket_ids[@]}"; do
            if [[ "${base}" == *"${tid}"* ]]; then
                ticket_specs+=("${base}")
                break
            fi
        done
    done < <(find "${spec_path}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi

# --- in-progress specs --------------------------------------------------------

declare -a in_progress=()
if [[ -f "${index_path}" ]]; then
    while IFS= read -r id; do
        [[ -z "${id}" ]] && continue
        dup=0
        for existing in "${in_progress[@]:-}"; do
            if [[ "${existing}" == "${id}" ]]; then dup=1; break; fi
        done
        [[ ${dup} -eq 0 ]] && in_progress+=("${id}")
    done < <(grep 'in-progress' "${index_path}" 2>/dev/null | grep -oE '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' || true)
fi

# --- nothing to say? ----------------------------------------------------------

if [[ ${#matched[@]} -eq 0 && ${#ticket_ids[@]} -eq 0 && ${#in_progress[@]} -eq 0 ]]; then
    exit 0
fi

# --- emit context-router block -----------------------------------------------

{
    echo '<context-router>'
    echo 'Routing hints from specwright (UserPromptSubmit hook):'

    if [[ ${#matched[@]} -gt 0 ]]; then
        echo ''
        echo 'Workflow keyword matches:'
        for k in "${!matched[@]}"; do
            echo "  - /sd:${k}  (matched: ${matched_terms[${k}]})"
        done
    fi

    if [[ ${#ticket_ids[@]} -gt 0 ]]; then
        echo ''
        printf 'Ticket IDs detected: '
        printf '%s' "${ticket_ids[0]}"
        for ((i=1; i<${#ticket_ids[@]}; i++)); do printf ', %s' "${ticket_ids[i]}"; done
        printf '\n'

        if [[ ${#ticket_specs[@]} -gt 0 ]]; then
            echo 'Matching spec folders under .specs/:'
            for s in "${ticket_specs[@]}"; do echo "  - ${s}"; done
        else
            echo 'No matching spec folder found. Consider /sd:feature or /sd:bug to create one.'
        fi
    fi

    if [[ ${#in_progress[@]} -gt 0 ]]; then
        echo ''
        echo 'Specs currently in-progress (from .specs/index.md):'
        for s in "${in_progress[@]}"; do echo "  - ${s}"; done
    fi

    echo '</context-router>'
}

exit 0
