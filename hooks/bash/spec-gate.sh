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

normalize_rel() {
    local fp="$1" base="$2"
    # If fp is already relative, just normalize separators.
    if [[ "${fp}" != /* && "${fp}" != ?:* ]]; then
        printf '%s' "${fp//\\//}"
        return
    fi
    # Strip prefix if it begins with base.
    local fp_norm="${fp//\\//}"
    local base_norm="${base//\\//}"
    local fp_lower base_lower
    fp_lower="$(to_lower "${fp_norm}")"
    base_lower="$(to_lower "${base_norm}")"
    if [[ "${fp_lower}" == "${base_lower}"* ]]; then
        # Cut by the base's LENGTH, not by pattern, so the surviving remainder
        # keeps its original case for the user-facing reason string.
        local rel="${fp_norm:${#base_norm}}"
        rel="${rel#/}"
        printf '%s' "${rel}"
    else
        printf '%s' "${fp_norm}"
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
