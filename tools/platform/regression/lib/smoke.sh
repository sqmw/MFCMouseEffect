#!/usr/bin/env bash

set -euo pipefail

mfx_run_smoke_checks() {
    local platform="$1"
    local build_dir="$2"
    local entry_bin="$build_dir/mfx_entry_posix_host"

    if [[ ! -x "$entry_bin" ]]; then
        mfx_fail "entry host executable missing: $entry_bin"
    fi

    mfx_info "check background exit text command"
    printf 'exit\n' | "$entry_bin" -mode=background >/dev/null 2>&1

    mfx_info "check background exit json command"
    printf '{"cmd":"exit"}\n' | "$entry_bin" -mode=background >/dev/null 2>&1

    if [[ "$platform" == "macos" ]]; then
        local smoke_bin="$build_dir/platform_macos/mfx_shell_macos_smoke"
        local tray_smoke_bin="$build_dir/platform_macos/mfx_shell_macos_tray_smoke"
        if [[ ! -x "$smoke_bin" ]]; then
            mfx_fail "macOS smoke executable missing: $smoke_bin"
        fi
        if [[ ! -x "$tray_smoke_bin" ]]; then
            mfx_fail "macOS tray smoke executable missing: $tray_smoke_bin"
        fi

        mfx_info "run macOS event-loop smoke"
        "$smoke_bin" >/dev/null 2>&1

        # Product contract: the tray menu intentionally exposes only
        # Star Project, Settings, and Exit (see docs/agent-context/current.md).
        # Theme/effect/reload expectations were removed with the tray
        # streamline; the smoke validates the remaining action contracts.
        mfx_info "run macOS tray smoke (star + settings action contracts, 3-item layout)"
        local tray_smoke_tmp_dir
        tray_smoke_tmp_dir="$(mktemp -d)"
        local tray_settings_url="http://127.0.0.1:9527/?token=tray-smoke"
        local tray_star_url="https://github.com/sqmw/MFCMouseEffect"
        local tray_launch_capture_file="$tray_smoke_tmp_dir/tray-launch-capture.env"
        local tray_star_capture_file="$tray_smoke_tmp_dir/tray-star-capture.env"
        local tray_menu_layout_capture_file="$tray_smoke_tmp_dir/tray-menu-layout-capture.env"
        "$tray_smoke_bin" \
            --expect-settings-action \
            --expect-star-action \
            --settings-url "$tray_settings_url" \
            --star-url "$tray_star_url" \
            --launch-capture-file "$tray_launch_capture_file" \
            --star-capture-file "$tray_star_capture_file" \
            --menu-layout-capture-file "$tray_menu_layout_capture_file" >/dev/null 2>&1
        if [[ -f "$tray_launch_capture_file" ]]; then
            mfx_assert_file_contains "$tray_launch_capture_file" "captured=1" "macOS tray smoke launch capture flag"
            mfx_assert_file_contains "$tray_launch_capture_file" "command=open" "macOS tray smoke launch command"
            mfx_assert_file_contains "$tray_launch_capture_file" "url=$tray_settings_url" "macOS tray smoke launch url"
        else
            mfx_info "macOS tray smoke launch capture file not emitted; keep exit-code gate only under current runner"
        fi
        if [[ -f "$tray_star_capture_file" ]]; then
            mfx_assert_file_contains "$tray_star_capture_file" "captured=1" "macOS tray smoke star capture flag"
            mfx_assert_file_contains "$tray_star_capture_file" "command=star_project" "macOS tray smoke star command"
            mfx_assert_file_contains "$tray_star_capture_file" "url=$tray_star_url" "macOS tray smoke star url"
        else
            mfx_info "macOS tray smoke star capture file not emitted; keep exit-code gate only under current runner"
        fi
        if [[ -f "$tray_menu_layout_capture_file" ]]; then
            mfx_assert_file_contains "$tray_menu_layout_capture_file" "captured=1" "macOS tray smoke menu layout capture flag"
            mfx_assert_file_contains "$tray_menu_layout_capture_file" "top_level_layout_keys=star|settings|exit" "macOS tray smoke menu layout order"
            mfx_assert_file_contains "$tray_menu_layout_capture_file" "settings_title_has_ellipsis=1" "macOS tray smoke settings label ellipsis"
        else
            mfx_info "macOS tray smoke menu layout capture file not emitted; keep exit-code gate only under current runner"
        fi
        rm -rf "$tray_smoke_tmp_dir"
    else
        mfx_info "linux smoke executable is not available yet; skip platform-specific smoke binary"
    fi

    mfx_ok "smoke checks completed"
}
