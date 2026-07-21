#!/usr/bin/env bash
# specwright: PreToolUse hook - spec-gate (bash).
#
# Decides whether an Edit / Write / MultiEdit is allowed:
#   - Protected paths   -> always block.
#   - Allow-listed dirs / extensions -> always allow.
#   - Code files        -> require an in-progress spec in .specs/index.md.
#       mode=block -> emit block JSON (see emit_block below).
#       mode=warn  -> warn to stderr; allow.
#       mode=off   -> always allow.
# Exits 0 silently on any missing tool or parse error.
#
# Output schema (dual-format for forward + backward compatibility):
#   New:    hookSpecificOutput.permissionDecision = "deny"   (CLI >= schema v2)
#   Legacy: decision = "block"                               (CLI < schema v2)
# Both are emitted in the same JSON object so either CLI generation can act.
#
# Note: hooks must never fail noisily. `set -u` is intentionally omitted.

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat 2>/dev/null || true)"
if [[ -z "${input}" ]]; then
    exit 0
fi

tool_name="$(printf '%s' "${input}" | jq -r '.tool_name // empty' 2>/dev/null)"
case "${tool_name}" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

cwd="$(printf '%s' "${input}" | jq -r '.cwd // empty' 2>/dev/null)"
if [[ -z "${cwd}" ]]; then
    cwd="$(pwd)"
fi

file_path="$(printf '%s' "${input}" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
if [[ -z "${file_path}" ]]; then
    exit 0
fi

# --- load config --------------------------------------------------------------

# A project with no .claude/project-config.json (the normal state before
# /sd:setup has run) must still get the built-in protected paths, so the
# fallback is a full default document rather than an empty object. This must
# stay byte-identical in meaning to $defaults in spec-gate.ps1.
default_config='{"spec":{"dir":".specs","indexFile":".specs/index.md"},"paths":{"protected":[".specs/constitution.md",".specs/index.md","LICENSE"]},"hooks":{"specGate":{"enabled":true,"mode":"warn"}}}'

config_path="${cwd}/.claude/project-config.json"
config_json="${default_config}"
if [[ -f "${config_path}" ]] && jq -e . "${config_path}" >/dev/null 2>&1; then
    config_json="$(cat "${config_path}")"
fi

# `//` treats explicit `false` as absent, so compare directly against
# `false` instead of relying on the alternative operator here.
enabled="$(printf '%s' "${config_json}" | jq -r 'if .hooks.specGate.enabled == false then "false" else "true" end' 2>/dev/null)"
if [[ "${enabled}" == "false" ]]; then
    exit 0
fi

mode="$(printf '%s' "${config_json}" | jq -r '.hooks.specGate.mode // "warn"' 2>/dev/null)"
if [[ "${mode}" == "off" ]]; then
    exit 0
fi

index_rel="$(printf '%s' "${config_json}" | jq -r '.spec.indexFile // ".specs/index.md"' 2>/dev/null)"
index_path="${cwd}/${index_rel}"

# --- path helpers -------------------------------------------------------------

# All path comparisons in this hook are case-INSENSITIVE, matching
# spec-gate.ps1's OrdinalIgnoreCase. Windows and macOS filesystems are
# case-insensitive by default, so a case-sensitive gate is bypassable there by
# simply retyping the path in a different case - unacceptable for a rule whose
# whole job is to protect specific files.
to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Collapses '.' and '..' segments in a forward-slash path using pure string
# processing - no filesystem access, no `realpath`/`readlink -f`/`cd`. This
# mirrors [System.IO.Path]::GetFullPath's string-only resolution in
# spec-gate.ps1, which is what let a path like "src/../.specs/constitution.md"
# reach a protected file while presenting a relative form that never matched
# any entry in paths.protected under the un-collapsed bash comparison.
#
# A ROOTED path (Unix leading '/' or a Windows drive prefix like 'C:/') clamps
# a '..' at its own root instead of walking above it, matching GetFullPath's
# drive/root clamp. A path with no such root has nothing to clamp against, so
# an unresolved leading '..' is kept rather than discarded - it must not be
# allowed to silently walk above its own top.
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

normalize_rel() {
    local fp="$1" base="$2"
    # If fp is already relative, collapse dot segments but there is no known
    # root to compare against a cwd prefix, so return the collapsed path as-is.
    if [[ "${fp}" != /* && "${fp}" != ?:* ]]; then
        printf '%s' "$(collapse_dot_segments "${fp//\\//}")"
        return
    fi
    # Collapse '.'/'..' BEFORE the prefix strip, so a path that traverses
    # through a directory and back (e.g. cwd/src/../.specs/x) is compared
    # against base in its fully-resolved form, not its literal typed form.
    local fp_raw="${fp//\\//}"
    local base_norm="${base//\\//}"
    local fp_norm base_collapsed
    fp_norm="$(collapse_dot_segments "${fp_raw}")"
    base_collapsed="$(collapse_dot_segments "${base_norm}")"
    local fp_lower base_lower
    fp_lower="$(to_lower "${fp_norm}")"
    base_lower="$(to_lower "${base_collapsed}")"
    if [[ "${fp_lower}" == "${base_lower}"* ]]; then
        # Cut by the base's LENGTH, not by pattern, so the surviving remainder
        # keeps its original case for the user-facing reason string.
        local rel="${fp_norm:${#base_collapsed}}"
        rel="${rel#/}"
        printf '%s' "${rel}"
    else
        # Resolving fp lands outside base entirely (e.g. enough leading '..' to
        # escape the workspace) - fall back to the raw, un-collapsed path, same
        # as spec-gate.ps1's ConvertTo-RelativePath fallback branch.
        printf '%s' "${fp_raw}"
    fi
}

rel="$(normalize_rel "${file_path}" "${cwd}")"
if [[ -z "${rel}" ]]; then
    exit 0
fi

# --- emit-block helper --------------------------------------------------------
# Emits dual-format JSON: new hookSpecificOutput schema + legacy decision field.
# The CLI reads whichever field it understands; both are harmless to the other.

emit_block() {
    local reason="$1"
    jq -nc --arg r "${reason}" \
        '{decision:"block",reason:$r,hookSpecificOutput:{permissionDecision:"deny",reason:$r}}'
}

# --- Rule 0: verify gate on the spec index ------------------------------------
# A row transitioning to done requires a passing /sd:verify artifact; a
# verified close-out is allowed through the protected-path rule. Any other
# direct index edit falls through to Rule 1. Mirrors spec-gate.ps1 Rule 0.

verify_gate="$(printf '%s' "${config_json}" | jq -r 'if .hooks.specGate.verifyGate == false then "false" else "true" end' 2>/dev/null)"
spec_dir="$(printf '%s' "${config_json}" | jq -r '.spec.dir // ".specs"' 2>/dev/null)"

rel_lower="$(to_lower "${rel}")"
index_rel_norm="${index_rel//\\//}"
index_rel_lower="$(to_lower "${index_rel_norm}")"

if [[ "${verify_gate}" == "true" && "${rel_lower}" == "${index_rel_lower}" ]]; then
    fragments=""
    case "${tool_name}" in
        Edit)      fragments="$(printf '%s' "${input}" | jq -r '.tool_input.new_string // empty' 2>/dev/null)" ;;
        Write)     fragments="$(printf '%s' "${input}" | jq -r '.tool_input.content // empty' 2>/dev/null)" ;;
        MultiEdit) fragments="$(printf '%s' "${input}" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)" ;;
    esac

    if [[ -n "${fragments}" ]]; then
        # IDs marked done in the pending edit's new content.
        pending_done="$(printf '%s' "${fragments}" \
            | grep -E '\|[[:space:]]*done[[:space:]]*\|' 2>/dev/null \
            | grep -o -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' 2>/dev/null \
            | tr -d '\r' | LC_ALL=C sort -u)"
        # IDs the on-disk index already records as done (not a transition).
        already_done=""
        if [[ -f "${index_path}" ]]; then
            already_done="$(grep -E '\|[[:space:]]*done[[:space:]]*\|' "${index_path}" 2>/dev/null \
                | grep -o -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+' 2>/dev/null \
                | tr -d '\r' | LC_ALL=C sort -u)"
        fi

        transition_ids=""
        while IFS= read -r id; do
            [[ -z "${id}" ]] && continue
            if [[ -n "${already_done}" ]] && printf '%s\n' "${already_done}" | grep -qx "${id}"; then
                continue
            fi
            transition_ids="${transition_ids}${id}"$'\n'
        done <<< "${pending_done}"

        if [[ -n "${transition_ids}" ]]; then
            missing=""
            while IFS= read -r id; do
                [[ -z "${id}" ]] && continue
                artifact="${cwd}/${spec_dir}/${id}/06-verify.md"
                if [[ ! -f "${artifact}" ]] \
                   || ! grep -q -i -E '^result:[[:space:]]*pass[[:space:]]*$' "${artifact}" 2>/dev/null; then
                    if [[ -z "${missing}" ]]; then
                        missing="${id}"
                    else
                        missing="${missing}, ${id}"
                    fi
                fi
            done <<< "${transition_ids}"

            if [[ -n "${missing}" ]]; then
                emit_block "spec-gate: index row(s) [${missing}] -> done but no passing /sd:verify artifact. Run /sd:verify <spec-ID>; close-out is allowed only after ${spec_dir}/<ID>/06-verify.md records 'result: pass'."
                exit 0
            fi
            # Every transitioning spec has a passing artifact - allow the close-out.
            exit 0
        fi
    fi
fi

# --- Rule 1: protected paths -> block ----------------------------------------

is_protected=0
rel_lower="$(to_lower "${rel}")"
while IFS= read -r p; do
    # Some jq builds (e.g. Windows jq.exe) emit CRLF when a filter yields
    # multiple values, as this array iteration does; strip a trailing CR so
    # the exact-match comparison below isn't corrupted.
    p="${p%$'\r'}"
    [[ -z "${p}" ]] && continue
    p_norm="$(to_lower "${p//\\//}")"
    if [[ "${rel_lower}" == "${p_norm}" ]]; then
        is_protected=1
        break
    fi
done < <(printf '%s' "${config_json}" | jq -r '.paths.protected // [] | .[]' 2>/dev/null)

if [[ ${is_protected} -eq 1 ]]; then
    emit_block "spec-gate: '${rel}' is listed under paths.protected in .claude/project-config.json. Update via /sd:refactor or an ADR; never edit directly."
    exit 0
fi

# --- Rule 2: allow-listed paths -> allow -------------------------------------

is_allowed=0
for d in .specs/ .claude/ tests/ test/ docs/ spec/; do
    if [[ "${rel_lower}" == "${d}"* ]]; then
        is_allowed=1
        break
    fi
done

basename_only="$(basename "${rel}")"
# Only EXTENSION-LESS project files are allow-listed by name; anything with an
# extension is decided by the extension rules below. A name like README.old.py
# must not be allow-listed just because it starts with README - it is a Python
# file, and the gate exists to catch code edits.
case "$(to_lower "${basename_only}")" in
    readme|changelog|contributing|license|notice|authors)
        is_allowed=1
        ;;
esac

if [[ ${is_allowed} -eq 0 ]]; then
    ext="${basename_only##*.}"
    if [[ "${ext}" != "${basename_only}" ]]; then
        ext_lower="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
        case "${ext_lower}" in
            md|markdown|txt|rst|adoc|json|yaml|yml|toml|ini|env|example)
                is_allowed=1
                ;;
        esac
    fi
fi

if [[ ${is_allowed} -eq 1 ]]; then
    exit 0
fi

# --- Rule 3: code file -> require in-progress spec ----------------------------

is_code=0
ext="${basename_only##*.}"
if [[ "${ext}" != "${basename_only}" ]]; then
    ext_lower="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
    case "${ext_lower}" in
        cs|fs|vb|ts|tsx|js|jsx|mjs|cjs|vue|svelte|py|pyi|rs|go|java|kt|kts|scala|rb|php|swift|m|mm|c|h|cpp|cxx|cc|hpp|hxx|sql|ps1|sh|bash|zsh|razor|cshtml)
            is_code=1
            ;;
    esac
fi

if [[ ${is_code} -eq 0 ]]; then
    exit 0
fi

# Check for in-progress spec. Both markers must appear on the SAME line
# (mirrors prompt-router.sh and spec-gate.ps1's same-line semantics).
has_in_progress=0
if [[ -f "${index_path}" ]]; then
    if grep -E 'in-progress' "${index_path}" 2>/dev/null \
         | grep -q -E '(FEAT|BUG|REF|PERF|RCA)-[A-Za-z0-9_-]+'; then
        has_in_progress=1
    fi
fi

if [[ ${has_in_progress} -eq 0 ]]; then
    msg="spec-gate: editing code file '${rel}' but no in-progress spec is recorded in .specs/index.md. Run /sd:feature, /sd:bug, /sd:refactor, or /sd:perf first to create a spec, or set hooks.specGate.mode='off' in .claude/project-config.json to disable."
    if [[ "${mode}" == "block" ]]; then
        emit_block "${msg}"
        exit 0
    else
        echo "[WARN] ${msg}" 1>&2
        exit 0
    fi
fi

exit 0
