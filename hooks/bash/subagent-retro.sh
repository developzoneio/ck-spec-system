#!/usr/bin/env bash
# specwright: SubagentStop hook - subagent-retro (bash).
#
# After a subagent finishes:
#   1. Load .claude/project-config.json (or defaults).
#   2. Parse .specs/index.md for in-progress specs (skip RCAs).
#   3. For each, check mtime of <spec>/05-retro.md vs retroStaleMinutes.
#   4. Debounce per session via .claude/.hookstate/subagent-retro-<sid>.json.
#   5. Emit <retro-reminder> block if any stale retros AND debounce elapsed.
#   6. Clean up state files older than 24h.
#
# Note: hooks must never fail noisily. `set -u` is intentionally omitted.

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat 2>/dev/null || true)"
if [[ -z "${input}" ]]; then
    exit 0
fi

cwd="$(printf '%s' "${input}" | jq -r '.cwd // empty' 2>/dev/null)"
if [[ -z "${cwd}" ]]; then
    cwd="$(pwd)"
fi
if [[ ! -d "${cwd}" ]]; then
    exit 0
fi

session_id="$(printf '%s' "${input}" | jq -r '.session_id // "no-session"' 2>/dev/null)"
safe_id="$(printf '%s' "${session_id}" | tr -c 'A-Za-z0-9_-' '_')"

# --- load config --------------------------------------------------------------

# An empty object is a safe fallback HERE only because every value this hook
# reads has a `//` default below, and those defaults are the same values as
# $defaults in subagent-retro.ps1. Any new read must keep that property or the
# fallback has to become a full default document, as it is in spec-gate.sh.
config_path="${cwd}/.claude/project-config.json"
config_json="{}"
if [[ -f "${config_path}" ]] && jq -e . "${config_path}" >/dev/null 2>&1; then
    config_json="$(cat "${config_path}")"
fi

# The jq alternative operator treats an explicit `false` as absent, so
# compare directly against `false` instead of relying on it here.
enabled="$(printf '%s' "${config_json}" | jq -r 'if .hooks.subagentRetro.enabled == false then "false" else "true" end' 2>/dev/null)"
if [[ "${enabled}" == "false" ]]; then
    exit 0
fi

stale_minutes="$(printf '%s' "${config_json}"    | jq -r '.hooks.subagentRetro.retroStaleMinutes // 30' 2>/dev/null)"
debounce_minutes="$(printf '%s' "${config_json}" | jq -r '.hooks.subagentRetro.debounceMinutes // 10'   2>/dev/null)"

spec_dir_rel="$(printf '%s' "${config_json}" | jq -r '.spec.dir       // ".specs"'         2>/dev/null)"
index_rel="$(printf '%s' "${config_json}"    | jq -r '.spec.indexFile // ".specs/index.md"' 2>/dev/null)"

spec_dir="${cwd}/${spec_dir_rel}"
index_path="${cwd}/${index_rel}"

state_dir="${cwd}/.claude/.hookstate"
state_path="${state_dir}/subagent-retro-${safe_id}.json"

# --- portable mtime helper (Linux: -c %Y; macOS/BSD: -f %m) -------------------

get_mtime() {
    local f="$1"
    if [[ ! -e "${f}" ]]; then
        echo "0"
        return
    fi
    if stat -c %Y "${f}" >/dev/null 2>&1; then
        stat -c %Y "${f}"
    elif stat -f %m "${f}" >/dev/null 2>&1; then
        stat -f %m "${f}"
    else
        echo "0"
    fi
}

# --- cleanup old state files (>24h) ------------------------------------------

if [[ -d "${state_dir}" ]]; then
    now_epoch="$(date +%s)"
    cutoff=$(( now_epoch - 24*3600 ))
    while IFS= read -r f; do
        [[ -z "${f}" ]] && continue
        m="$(get_mtime "${f}")"
        if [[ "${m}" =~ ^[0-9]+$ && ${m} -gt 0 && ${m} -lt ${cutoff} ]]; then
            rm -f "${f}" 2>/dev/null || true
        fi
    done < <(find "${state_dir}" -maxdepth 1 -type f -name 'subagent-retro-*.json' 2>/dev/null)
fi

# --- parse in-progress specs --------------------------------------------------

declare -a specs=()
declare -a spec_types=()

if [[ -f "${index_path}" ]]; then
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        if [[ "${line}" == *in-progress* ]]; then
            id="$(printf '%s' "${line}" | grep -oE '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' | head -n1)"
            if [[ -n "${id}" ]]; then
                dup=0
                for existing in "${specs[@]:-}"; do
                    if [[ "${existing}" == "${id}" ]]; then dup=1; break; fi
                done
                if [[ ${dup} -eq 0 ]]; then
                    specs+=("${id}")
                    spec_types+=("${id%%-*}")
                fi
            fi
        fi
    done < "${index_path}"
fi

if [[ ${#specs[@]} -eq 0 ]]; then
    exit 0
fi

# --- collect stale / missing retros (skip RCAs) ------------------------------

declare -a stale_id=()
declare -a stale_reason=()
declare -a stale_age=()

now_epoch="$(date +%s)"
threshold_secs=$(( stale_minutes * 60 ))

for i in "${!specs[@]}"; do
    sid="${specs[$i]}"
    stype="${spec_types[$i]}"
    if [[ "${stype}" == "RCA" ]]; then
        continue
    fi
    retro="${spec_dir}/${sid}/05-retro.md"
    if [[ ! -f "${retro}" ]]; then
        stale_id+=("${sid}")
        stale_reason+=("missing")
        stale_age+=("-1")
        continue
    fi
    m="$(get_mtime "${retro}")"
    if [[ ! "${m}" =~ ^[0-9]+$ || ${m} -eq 0 ]]; then
        continue
    fi
    age=$(( now_epoch - m ))
    if (( age >= threshold_secs )); then
        stale_id+=("${sid}")
        stale_reason+=("stale")
        # Round to the nearest minute rather than truncating, so the reported
        # age matches subagent-retro.ps1's [Math]::Round on the same mtime.
        stale_age+=("$(( (age + 30) / 60 ))")
    fi
done

if [[ ${#stale_id[@]} -eq 0 ]]; then
    exit 0
fi

# --- debounce -----------------------------------------------------------------

debounce_secs=$(( debounce_minutes * 60 ))
if [[ -f "${state_path}" ]]; then
    last_iso="$(jq -r '.lastReminderUtc // empty' "${state_path}" 2>/dev/null || true)"
    if [[ -n "${last_iso}" ]]; then
        # Strip the UTC marker and any fractional seconds. BSD date's -f cannot
        # be given trailing unconverted text (it warns on stderr, which would
        # break the hook's silence), and a state file written by an older
        # subagent-retro.ps1 carries 7 fractional digits.
        iso_trimmed="${last_iso%Z}"
        iso_trimmed="${iso_trimmed%.*}"
        # Convert ISO8601 to epoch. GNU date supports -d; BSD date needs -j -f.
        # Both branches must interpret the value as UTC - it is written as UTC
        # by both implementations, so a local-time reading would skew the
        # debounce window by the machine's offset.
        last_epoch=""
        if last_epoch="$(date -u -d "${last_iso}" +%s 2>/dev/null)"; then
            :
        elif last_epoch="$(date -u -j -f '%Y-%m-%dT%H:%M:%S' "${iso_trimmed}" +%s 2>/dev/null)"; then
            :
        else
            last_epoch=""
        fi
        if [[ -n "${last_epoch}" && "${last_epoch}" =~ ^[0-9]+$ ]]; then
            if (( now_epoch - last_epoch < debounce_secs )); then
                exit 0
            fi
        fi
    fi
fi

# --- emit -------------------------------------------------------------------

{
    echo '<retro-reminder>'
    echo 'Retro files appear stale or missing for the following in-progress specs:'
    for i in "${!stale_id[@]}"; do
        sid="${stale_id[$i]}"
        reason="${stale_reason[$i]}"
        age="${stale_age[$i]}"
        if [[ "${reason}" == "missing" ]]; then
            echo "  - ${sid}: 05-retro.md missing"
        else
            echo "  - ${sid}: 05-retro.md last touched ${age} min ago (threshold ${stale_minutes} min)"
        fi
    done
    echo ''
    echo 'Consider appending: decisions made, surprises encountered, follow-ups identified.'
    echo '</retro-reminder>'
}

# --- save state --------------------------------------------------------------

# State-file shape is an ON-DISK CONTRACT shared with subagent-retro.ps1: a
# session can write it under one implementation and read it under the other, so
# the single key and the whole-second UTC format must stay identical in both.
mkdir -p "${state_dir}" 2>/dev/null || true
iso_now="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u)"
jq -nc --arg t "${iso_now}" '{lastReminderUtc:$t}' > "${state_path}" 2>/dev/null || true

exit 0
