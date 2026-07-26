#!/usr/bin/env bash

set -euo pipefail

_mfx_posix_suite_resolve_core_build_dir() {
    if [[ -n "$MFX_CORE_AUTOMATION_BUILD_DIR" ]]; then
        printf '%s' "$MFX_CORE_AUTOMATION_BUILD_DIR"
        return
    fi
    if [[ -n "$MFX_CORE_BUILD_DIR" ]]; then
        printf '%s' "$MFX_CORE_BUILD_DIR"
        return
    fi
    printf ''
}

mfx_posix_suite_run_objcxx_gate_phase() {
    local repo_root="$1"
    if [[ "$MFX_ENFORCE_NO_OBJCXX_EDITS" -eq 1 ]]; then
        mfx_info "run objcxx edit policy gate phase"
        "$repo_root/tools/policy/check-no-objcxx-edits.sh" --repo-root "$repo_root"
    else
        mfx_info "skip objcxx edit policy gate phase"
    fi
}

mfx_posix_suite_run_macos_objcxx_surface_gate_phase() {
    local script_dir="$1"
    if [[ "$MFX_SKIP_MACOS_OBJCXX_SURFACE_GATE" -eq 1 ]]; then
        mfx_info "skip macos objcxx surface regression phase"
        return
    fi

    mfx_info "run macos objcxx surface regression phase"
    "$script_dir/run-macos-objcxx-surface-regression.sh"
}

mfx_posix_suite_run_theme_catalog_surface_gate_phase() {
    local script_dir="$1"
    if [[ "$MFX_SKIP_THEME_CATALOG_SURFACE_GATE" -eq 1 ]]; then
        mfx_info "skip theme catalog surface regression phase"
        return
    fi

    mfx_info "run theme catalog surface regression phase"
    "$script_dir/run-theme-catalog-surface-regression.sh"
}

mfx_posix_suite_log_entry_host_presence() {
    if ! command -v pgrep >/dev/null 2>&1; then
        return
    fi
    if pgrep -f mfx_entry_posix_host >/dev/null 2>&1; then
        mfx_info "detected running mfx_entry_posix_host; phase scripts will handle cleanup under mfx-entry-posix-host lock"
    fi
}

mfx_posix_suite_run_scaffold_phase() {
    local script_dir="$1"
    if [[ "$MFX_SKIP_SCAFFOLD" -eq 1 ]]; then
        mfx_info "skip scaffold regression phase"
        return
    fi

    local args=("--platform" "$MFX_PLATFORM")
    if [[ -n "$MFX_SCAFFOLD_BUILD_DIR" ]]; then
        args+=("--build-dir" "$MFX_SCAFFOLD_BUILD_DIR")
    fi
    if [[ "$MFX_SCAFFOLD_SKIP_SMOKE" -eq 1 ]]; then
        args+=("--skip-smoke")
    fi
    if [[ "$MFX_SCAFFOLD_SKIP_HTTP" -eq 1 ]]; then
        args+=("--skip-http")
    fi

    mfx_info "run scaffold regression phase"
    "$script_dir/run-posix-scaffold-regression.sh" "${args[@]}"
}

mfx_posix_suite_run_core_smoke_phase() {
    local script_dir="$1"
    if [[ "$MFX_SKIP_CORE_SMOKE" -eq 1 ]]; then
        mfx_info "skip core-lane smoke phase"
        return
    fi

    local args=("--platform" "$MFX_PLATFORM")
    if [[ -n "$MFX_CORE_BUILD_DIR" ]]; then
        args+=("--build-dir" "$MFX_CORE_BUILD_DIR")
    fi

    mfx_info "run core-lane smoke phase"
    "$script_dir/run-posix-core-smoke.sh" "${args[@]}"
}

mfx_posix_suite_run_core_automation_phase() {
    local script_dir="$1"
    if [[ "$MFX_SKIP_CORE_AUTOMATION" -eq 1 ]]; then
        mfx_info "skip core automation contract phase"
        return
    fi

    local args=("--platform" "$MFX_PLATFORM")
    args+=("--check-scope" "$MFX_CORE_AUTOMATION_CHECK_SCOPE")
    local resolved_build_dir
    resolved_build_dir="$(_mfx_posix_suite_resolve_core_build_dir)"
    if [[ -n "$resolved_build_dir" ]]; then
        args+=("--build-dir" "$resolved_build_dir")
    fi

    mfx_info "run core automation contract phase"
    "$script_dir/run-posix-core-automation-contract-regression.sh" "${args[@]}"
}

mfx_posix_suite_run_macos_automation_injection_selfcheck_phase() {
    local repo_root="$1"
    if [[ "$MFX_SKIP_MACOS_AUTOMATION_INJECTION_SELFCHECK" -eq 1 ]]; then
        mfx_info "skip macos automation injection selfcheck phase"
        return
    fi
    if ! mfx_posix_suite_is_macos_host; then
        mfx_info "skip macos automation injection selfcheck phase (non-macos host)"
        return
    fi

    local args=("--skip-build" "--dry-run")
    local resolved_build_dir
    resolved_build_dir="$(_mfx_posix_suite_resolve_core_build_dir)"
    if [[ -n "$resolved_build_dir" ]]; then
        args+=("--build-dir" "$resolved_build_dir")
    fi

    mfx_info "run macos automation injection selfcheck phase"
    MFX_MANUAL_ALLOW_BIND_EACCES_SKIP="${MFX_MANUAL_ALLOW_BIND_EACCES_SKIP:-1}" \
        "$repo_root/tools/platform/manual/run-macos-automation-injection-selfcheck.sh" "${args[@]}"
}

mfx_posix_suite_run_macos_tray_theme_selfcheck_phase() {
    local repo_root="$1"
    # Retired with the tray-menu streamline: the tray no longer exposes
    # theme selection, and the Swift bridge dropped the
    # MFX_TEST_TRAY_AUTO_TRIGGER_THEME_VALUE hook this selfcheck drives.
    # Theme apply/persistence stays covered by the /api/state contract
    # checks in the automation contract regression.
    mfx_info "skip macos tray theme selfcheck phase (tray theme selection retired with streamlined tray menu)"
    return
}

mfx_posix_suite_run_macos_automation_app_scope_selfcheck_phase() {
    local repo_root="$1"
    if [[ "$MFX_SKIP_MACOS_AUTOMATION_APP_SCOPE_SELFCHECK" -eq 1 ]]; then
        mfx_info "skip macos automation app-scope selfcheck phase"
        return
    fi
    if ! mfx_posix_suite_is_macos_host; then
        mfx_info "skip macos automation app-scope selfcheck phase (non-macos host)"
        return
    fi

    local args=("--skip-build")
    local resolved_build_dir
    resolved_build_dir="$(_mfx_posix_suite_resolve_core_build_dir)"
    if [[ -n "$resolved_build_dir" ]]; then
        args+=("--build-dir" "$resolved_build_dir")
    fi

    mfx_info "run macos automation app-scope selfcheck phase"
    MFX_MANUAL_ALLOW_BIND_EACCES_SKIP="${MFX_MANUAL_ALLOW_BIND_EACCES_SKIP:-1}" \
        "$repo_root/tools/platform/manual/run-macos-automation-app-scope-selfcheck.sh" "${args[@]}"
}

mfx_posix_suite_run_macos_vm_suppression_selfcheck_phase() {
    mfx_info "skip retired macos vm foreground suppression selfcheck phase"
}

mfx_posix_suite_run_macos_effects_type_parity_selfcheck_phase() {
    local repo_root="$1"
    if [[ "$MFX_SKIP_MACOS_EFFECTS_TYPE_PARITY_SELFCHECK" -eq 1 ]]; then
        mfx_info "skip macos effects type parity selfcheck phase"
        return
    fi
    if ! mfx_posix_suite_is_macos_host; then
        mfx_info "skip macos effects type parity selfcheck phase (non-macos host)"
        return
    fi

    local args=("--skip-build")
    local resolved_build_dir
    resolved_build_dir="$(_mfx_posix_suite_resolve_core_build_dir)"
    if [[ -n "$resolved_build_dir" ]]; then
        args+=("--build-dir" "$resolved_build_dir")
    fi

    mfx_info "run macos effects type parity selfcheck phase"
    MFX_MANUAL_ALLOW_BIND_EACCES_SKIP="${MFX_MANUAL_ALLOW_BIND_EACCES_SKIP:-1}" \
        "$repo_root/tools/platform/manual/run-macos-effects-type-parity-selfcheck.sh" "${args[@]}"
}

mfx_posix_suite_run_macos_effects_tuning_selfcheck_phase() {
    local repo_root="$1"
    if [[ "$MFX_SKIP_MACOS_EFFECTS_TUNING_SELFCHECK" -eq 1 ]]; then
        mfx_info "skip macos effects tuning selfcheck phase"
        return
    fi
    if ! mfx_posix_suite_is_macos_host; then
        mfx_info "skip macos effects tuning selfcheck phase (non-macos host)"
        return
    fi

    local args=("--skip-build")
    local resolved_build_dir
    resolved_build_dir="$(_mfx_posix_suite_resolve_core_build_dir)"
    if [[ -n "$resolved_build_dir" ]]; then
        args+=("--build-dir" "$resolved_build_dir")
    fi

    mfx_info "run macos effects tuning selfcheck phase"
    MFX_MANUAL_ALLOW_BIND_EACCES_SKIP="${MFX_MANUAL_ALLOW_BIND_EACCES_SKIP:-1}" \
        "$repo_root/tools/platform/manual/run-macos-effects-profile-tuning-selfcheck.sh" "${args[@]}"
}

mfx_posix_suite_run_macos_wasm_selfcheck_phase() {
    local repo_root="$1"
    if [[ "$MFX_SKIP_MACOS_WASM_SELFCHECK" -eq 1 ]]; then
        mfx_info "skip macos wasm runtime selfcheck phase"
        return
    fi
    if ! mfx_posix_suite_is_macos_host; then
        mfx_info "skip macos wasm runtime selfcheck phase (non-macos host)"
        return
    fi

    local args=("--skip-build")
    local resolved_build_dir
    resolved_build_dir="$(_mfx_posix_suite_resolve_core_build_dir)"
    if [[ -n "$resolved_build_dir" ]]; then
        args+=("--build-dir" "$resolved_build_dir")
    fi

    mfx_info "run macos wasm runtime selfcheck phase"
    MFX_MANUAL_ALLOW_BIND_EACCES_SKIP="${MFX_MANUAL_ALLOW_BIND_EACCES_SKIP:-1}" \
        "$repo_root/tools/platform/manual/run-macos-wasm-runtime-selfcheck.sh" "${args[@]}"
}

mfx_posix_suite_run_linux_gate_phase() {
    local script_dir="$1"
    if [[ "$MFX_SKIP_LINUX_GATE" -eq 1 ]]; then
        mfx_info "skip linux compile gate phase"
        return
    fi

    local args=("--build-dir" "$MFX_LINUX_BUILD_DIR")
    if [[ -n "$MFX_BUILD_JOBS_VALUE" ]]; then
        args+=("--jobs" "$MFX_BUILD_JOBS_VALUE")
    fi
    if [[ "$MFX_LINUX_SKIP_CORE_RUNTIME" -eq 1 ]]; then
        args+=("--skip-core-runtime")
    fi

    mfx_info "run linux compile gate phase"
    "$script_dir/run-posix-linux-compile-gate.sh" "${args[@]}"
}

mfx_posix_suite_run_webui_semantic_phase() {
    local repo_root="$1"
    if [[ "$MFX_SKIP_AUTOMATION_TEST" -eq 1 ]]; then
        mfx_info "skip webui semantic test phase"
        return
    fi

    mfx_require_cmd pnpm
    mfx_info "run webui semantic test phase"
    (
        cd "$repo_root"
        pnpm --dir MFCMouseEffect/WebUIWorkspace run test:automation-platform
        pnpm --dir MFCMouseEffect/WebUIWorkspace run test:general-state-model
        pnpm --dir MFCMouseEffect/WebUIWorkspace run test:effects-profile-model
        pnpm --dir MFCMouseEffect/WebUIWorkspace run test:wasm-error-model
        pnpm --dir MFCMouseEffect/WebUIWorkspace run test:wasm-state-model
        pnpm --dir MFCMouseEffect/WebUIWorkspace run test:wasm-diagnostics-model
    )
}
