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

# --- metrics: shared event writer -----------------------------------------
# Duplicated verbatim from spec-gate.sh (hooks are standalone scripts with no
# shared library - keeping the two copies textually identical makes any
# future drift between them greppable). Append-only, metadata-only event log
# for the retro loop (SW-10). Every failure path here is a silent no-op -
# metrics must NEVER surface as a hook error. Emitted regardless of debounce;
# see the emit_subagent_stop_metric call site below.

# A metrics path is not an arbitrary-write primitive: reject anything rooted
# (leading '/' or a drive-letter prefix) or that escapes cwd via '..' rather
# than ever writing outside the workspace. Reuses the same rootedness test and
# dot-segment collapse used for the gate's own path safety above, so the two
# checks cannot silently diverge. Mirrors Test-MetricsPathSafe in
# spec-gate.ps1.
metrics_path_is_safe() {
    local p="$1"
    [[ -z "${p}" ]] && return 1
    if [[ "${p}" == /* || "${p}" == ?:* ]]; then
        return 1
    fi
    local collapsed
    collapsed="$(collapse_dot_segments "${p//\\//}")"
    if [[ "${collapsed}" == ".." || "${collapsed}" == "../"* ]]; then
        return 1
    fi
    return 0
}

# $1 = a complete JSON object literal string containing every field EXCEPT
# ts, already in fixed key order (spec_id, phase, event, ...). ts is prepended
# here so each call site only has to build the part specific to its own event
# kind. jq's object-add operator appends keys from the right operand that are
# not already present in the left, in their own original order - since ts is
# never present in the body, this reliably yields ts first followed by the
# body's keys in the order the caller wrote them.
write_metric_line() {
    local body="$1"

    local metrics_enabled
    # `//` treats an explicit `false` as absent, so compare directly against
    # `false` (type-strict: only a literal JSON boolean false disables this).
    metrics_enabled="$(printf '%s' "${config_json}" | jq -r 'if .hooks.metrics.enabled == false then "false" else "true" end' 2>/dev/null)"
    [[ "${metrics_enabled}" == "false" ]] && return 0

    local metrics_path
    metrics_path="$(printf '%s' "${config_json}" | jq -r '.hooks.metrics.path // ".specs/_metrics/events.jsonl"' 2>/dev/null)"
    metrics_path="${metrics_path//\\//}"
    metrics_path_is_safe "${metrics_path}" || return 0

    local full_path="${cwd}/${metrics_path}"
    mkdir -p "$(dirname "${full_path}")" 2>/dev/null || return 0

    local ts
    ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u)"

    local line
    line="$(printf '%s' "${body}" | jq -c --arg ts "${ts}" '{ts:$ts} + .' 2>/dev/null)"
    [[ -z "${line}" ]] && return 0

    printf '%s\n' "${line}" >> "${full_path}" 2>/dev/null || true
    return 0
}

# Collapses '.' and '..' segments in a forward-slash path using pure string
# processing - no filesystem access, no `realpath`/`readlink -f`/`cd`. Mirrors
# collapse_dot_segments in spec-gate.sh exactly (duplicated verbatim - see the
# metrics writer note above). Only used here by metrics_path_is_safe.
collapse_dot_segments() {
    local path="$1"
    local root_prefix="" body="${path}"
    if [[ "${path}" == /* ]]; then
        root_prefix="/"
        body="${path#/}"
    elif [[ "${path}" == ?:* ]]; then
        root_prefix="${path:0:2}/"
        body="${path:2}"
        body="${body#/}"
    fi

    local rooted=0
    [[ -n "${root_prefix}" ]] && rooted=1

    local acc="" seg rest="${body}"
    while [[ -n "${rest}" ]]; do
        seg="${rest%%/*}"
        if [[ "${rest}" == */* ]]; then
            rest="${rest#*/}"
        else
            rest=""
        fi
        case "${seg}" in
            ''|'.')
                continue
                ;;
            '..')
                if [[ -n "${acc}" ]]; then
                    local last="${acc##*/}"
                    if [[ "${last}" == '..' ]]; then
                        # Already-stacked leading '..' (unrooted overflow) - keep stacking.
                        acc="${acc}/.."
                    else
                        local trimmed="${acc%/*}"
                        if [[ "${trimmed}" == "${acc}" ]]; then
                            # acc was a single segment with no slash - pop to empty.
                            acc=""
                        else
                            acc="${trimmed}"
                        fi
                    fi
                elif [[ ${rooted} -eq 1 ]]; then
                    # Cannot go above the root - drop it, matching GetFullPath's clamp.
                    :
                else
                    # No root to clamp against - keep the unresolved '..'.
                    acc=".."
                fi
                ;;
            *)
                if [[ -z "${acc}" ]]; then
                    acc="${seg}"
                else
                    acc="${acc}/${seg}"
                fi
                ;;
        esac
    done

    printf '%s%s' "${root_prefix}" "${acc}"
}

# subagent_stop metric: $1=spec_id $2=phase $3=stale (0 or 1)
emit_subagent_stop_metric() {
    local spec_id="$1" phase="$2" stale="$3"
    local body
    body="$(jq -nc --arg spec_id "${spec_id}" --arg phase "${phase}" --argjson stale "${stale}" \
        '{spec_id:$spec_id,phase:$phase,event:"subagent_stop",stale:$stale}' 2>/dev/null)"
    [[ -z "${body}" ]] && return 0
    write_metric_line "${body}"
}

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

# Metrics: one subagent_stop event per in-progress spec, emitted regardless
# of staleness or debounce - debounce below only suppresses the user-facing
# reminder, never this measurement (SW-10). A spec not in stale_id[]
# (including every RCA, which the loop above always skips) reports stale=0.
for i in "${!specs[@]}"; do
    sid="${specs[$i]}"
    is_stale=0
    for s in "${stale_id[@]:-}"; do
        if [[ "${s}" == "${sid}" ]]; then
            is_stale=1
            break
        fi
    done
    emit_subagent_stop_metric "${sid}" "in-progress" "${is_stale}"
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
