#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-root)
            mfx_require_option_value "$1" "${2:-}"
            REPO_ROOT="${2:-}"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: run-theme-catalog-surface-regression.sh [options]
  --repo-root <path>   repository root override
USAGE
            exit 0
            ;;
        *)
            mfx_fail "unknown argument: $1"
            ;;
    esac
done

SETTINGS_OPTIONS_FILE="$REPO_ROOT/MFCMouseEffect/Settings/SettingsOptions.h"
SCHEMA_OPTIONS_FILE="$REPO_ROOT/MFCMouseEffect/MouseFx/Server/settings/SettingsSchemaBuilder.OptionsSections.cpp"
SHELL_CORE_FILE="$REPO_ROOT/MFCMouseEffect/MouseFx/Core/Shell/AppShellCore.cpp"
HTTP_STATE_CHECKS_FILE="$REPO_ROOT/tools/platform/regression/lib/core_http_state_checks.sh"

for required_file in \
    "$SETTINGS_OPTIONS_FILE" \
    "$SCHEMA_OPTIONS_FILE" \
    "$SHELL_CORE_FILE" \
    "$HTTP_STATE_CHECKS_FILE"; do
    if [[ ! -f "$required_file" ]]; then
        mfx_fail "missing required file: $required_file"
    fi
done

mfx_info "repo root: $REPO_ROOT"
mfx_info "theme surface gate: verify runtime catalog source wiring"

mfx_assert_file_contains \
    "$SETTINGS_OPTIONS_FILE" \
    "const std::vector<mousefx::ThemeOption> runtimeThemes = mousefx::GetThemeOptions();" \
    "ThemeOptions must source runtime theme catalog"

if mfx_file_contains_fixed "$SETTINGS_OPTIONS_FILE" "static const SettingOption zhOpts[]"; then
    mfx_fail "ThemeOptions reverted to hardcoded zh theme list in $SETTINGS_OPTIONS_FILE"
fi
if mfx_file_contains_fixed "$SETTINGS_OPTIONS_FILE" "static const SettingOption enOpts[]"; then
    mfx_fail "ThemeOptions reverted to hardcoded en theme list in $SETTINGS_OPTIONS_FILE"
fi

mfx_assert_file_contains \
    "$SCHEMA_OPTIONS_FILE" \
    "for (const auto& theme : GetThemeOptions())" \
    "schema options themes must source runtime catalog"

mfx_assert_file_contains \
    "$SHELL_CORE_FILE" \
    "const std::vector<ThemeOption> options = GetThemeOptions();" \
    "shell theme snapshot must source runtime catalog"

mfx_assert_file_contains \
    "$HTTP_STATE_CHECKS_FILE" \
    "contract_external_theme" \
    "core http state checks must cover external theme contract"

mfx_assert_file_contains \
    "$HTTP_STATE_CHECKS_FILE" \
    "neon.theme.json" \
    "core http state checks must include built-in override rejection fixture"

mfx_assert_file_contains \
    "$HTTP_STATE_CHECKS_FILE" \
    "theme_catalog.scanned_external_theme_files\")\" \"3\"" \
    "core http state checks must assert scanned external theme file count contract"

mfx_assert_file_contains \
    "$HTTP_STATE_CHECKS_FILE" \
    "theme_catalog.rejected_external_theme_files\")\" \"2\"" \
    "core http state checks must assert rejected external theme file count contract"

mfx_assert_file_contains \
    "$HTTP_STATE_CHECKS_FILE" \
    "External Neon Override" \
    "core http state checks must assert built-in neon override remains rejected"

mfx_assert_file_contains \
    "$HTTP_STATE_CHECKS_FILE" \
    "rejected_external_theme_files" \
    "core http state checks must validate rejected external theme accounting"

mfx_ok "theme catalog surface regression passed"
