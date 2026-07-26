#!/usr/bin/env bash

set -euo pipefail

_mfx_core_http_automation_assert_float_within_tolerance() {
    local actual="$1"
    local expected="$2"
    local tolerance="$3"
    local label="$4"
    if [[ -z "$actual" || -z "$expected" || -z "$tolerance" ]]; then
        mfx_fail "$label: missing float comparison input"
    fi
    if ! awk -v a="$actual" -v b="$expected" -v tol="$tolerance" 'BEGIN {
        d = a - b;
        if (d < 0) {
            d = -d;
        }
        exit(d <= tol ? 0 : 1);
    }'; then
        mfx_fail "$label: expected $expected (tol=$tolerance), got $actual"
    fi
}

_mfx_core_http_automation_assert_active_and_command_type() {
    local input_file="$1"
    local effect_name="$2"
    local expected_active="$3"
    local expected_command_type="$4"
    local context="$5"

    local actual_active
    local actual_command_type
    actual_active="$(_mfx_core_http_automation_parse_path_string_field "$input_file" "active" "$effect_name")"
    actual_command_type="$(_mfx_core_http_automation_parse_command_section_scalar_field "$input_file" "$effect_name" "normalized_type")"
    actual_command_type="${actual_command_type//\"/}"

    mfx_assert_eq "$actual_active" "$expected_active" "$context active type"
    mfx_assert_eq "$actual_command_type" "$expected_command_type" "$context command normalized type"
}

_mfx_core_http_automation_assert_command_flag_eq() {
    local input_file="$1"
    local section_name="$2"
    local field_name="$3"
    local expected_value="$4"
    local context="$5"

    local actual_value
    actual_value="$(_mfx_core_http_automation_parse_command_section_scalar_field "$input_file" "$section_name" "$field_name")"
    mfx_assert_eq "$actual_value" "$expected_value" "$context"
}

_mfx_core_http_automation_assert_nested_command_field_eq() {
    local input_file="$1"
    local section_name="$2"
    local nested_section_name="$3"
    local field_name="$4"
    local expected_value="$5"
    local context="$6"

    local actual_value
    actual_value="$(_mfx_core_http_automation_parse_command_nested_section_scalar_field "$input_file" "$section_name" "$nested_section_name" "$field_name")"
    actual_value="${actual_value//\"/}"
    mfx_assert_eq "$actual_value" "$expected_value" "$context"
}

_mfx_core_http_automation_contract_effect_overlay_checks() {
    local platform="$1"
    local tmp_dir="$2"
    local base_url="$3"
    local token="$4"
    local expected_duration_scale="${MFX_EXPECT_EFFECTS_DURATION_SCALE:-1.0}"
    local expected_size_scale="${MFX_EXPECT_EFFECTS_SIZE_SCALE:-1.0}"
    local expected_opacity_scale="${MFX_EXPECT_EFFECTS_OPACITY_SCALE:-1.0}"
    local expected_trail_throttle_scale="${MFX_EXPECT_EFFECTS_TRAIL_THROTTLE_SCALE:-1.0}"
    local expected_duration_overridden="false"
    local expected_size_overridden="false"
    local expected_opacity_overridden="false"
    local expected_trail_throttle_overridden="false"

    if [[ -n "${MFX_TEST_EFFECTS_DURATION_SCALE:-}" ]]; then
        expected_duration_overridden="true"
    fi
    if [[ -n "${MFX_TEST_EFFECTS_SIZE_SCALE:-}" ]]; then
        expected_size_overridden="true"
    fi
    if [[ -n "${MFX_TEST_EFFECTS_OPACITY_SCALE:-}" ]]; then
        expected_opacity_overridden="true"
    fi
    if [[ -n "${MFX_TEST_EFFECTS_TRAIL_THROTTLE_SCALE:-}" ]]; then
        expected_trail_throttle_overridden="true"
    fi

    local code_effect_overlay_probe
    code_effect_overlay_probe="$(mfx_http_code "$tmp_dir/effect-overlay-probe.out" "$base_url/api/effects/test-overlay-windows" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"emit_click":true,"emit_trail":true,"emit_scroll":true,"emit_hold":true,"emit_hover":true,"click_type":"text","trail_type":"electric","scroll_type":"helix","hold_type":"hold_quantum_halo_gpu_v2","hover_type":"tubes","close_persistent":true,"wait_ms":80,"wait_for_clear_ms":1600}')"
    mfx_assert_eq "$code_effect_overlay_probe" "200" "core effect overlay probe status"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"ok\":true" "core effect overlay probe ok"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before\":" "core effect overlay probe before snapshot"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after\":" "core effect overlay probe after snapshot"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_line_trail\":" "core effect overlay probe before line trail snapshot"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_line_trail\":" "core effect overlay probe after line trail snapshot"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_line_trail_active\":" "core effect overlay probe before line trail active field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_line_trail_active\":" "core effect overlay probe after line trail active field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_line_trail_point_count\":" "core effect overlay probe before line trail point count field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_line_trail_point_count\":" "core effect overlay probe after line trail point count field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_line_trail_line_width_px\":" "core effect overlay probe before line trail line-width field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_line_trail_line_width_px\":" "core effect overlay probe after line trail line-width field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_text_effect\":" "core effect overlay probe before text effect snapshot"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_text_effect\":" "core effect overlay probe after text effect snapshot"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_text_effect_fallback_show_count\":" "core effect overlay probe before text effect fallback count"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_text_effect_fallback_show_count\":" "core effect overlay probe after text effect fallback count"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"before_total_matches_components\":true" "core effect overlay probe before invariant"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"after_total_matches_components\":true" "core effect overlay probe after invariant"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"restored_to_baseline\":true" "core effect overlay probe restore baseline"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"click_type\":\"text\"" "core effect overlay probe click type"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"trail_type\":\"electric\"" "core effect overlay probe trail type"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"scroll_type\":\"helix\"" "core effect overlay probe scroll type"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"hold_type\":\"hold_quantum_halo_gpu_v2\"" "core effect overlay probe hold type"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-probe.out" "\"hover_type\":\"tubes\"" "core effect overlay probe hover type"

    local before_click_count
    local before_trail_count
    local before_scroll_count
    local before_hold_count
    local before_hover_count
    local before_total_count
    local after_click_count
    local after_trail_count
    local after_scroll_count
    local after_hold_count
    local after_hover_count
    local after_total_count
    local before_text_effect_fallback_count
    local after_text_effect_fallback_count
    before_click_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_click_active_overlay_windows")"
    before_trail_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_trail_active_overlay_windows")"
    before_scroll_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_scroll_active_overlay_windows")"
    before_hold_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_hold_active_overlay_windows")"
    before_hover_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_hover_active_overlay_windows")"
    before_total_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_active_overlay_windows_total")"
    after_click_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_click_active_overlay_windows")"
    after_trail_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_trail_active_overlay_windows")"
    after_scroll_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_scroll_active_overlay_windows")"
    after_hold_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_hold_active_overlay_windows")"
    after_hover_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_hover_active_overlay_windows")"
    after_total_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_active_overlay_windows_total")"
    before_text_effect_fallback_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "before_text_effect_fallback_show_count")"
    after_text_effect_fallback_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-probe.out" "after_text_effect_fallback_show_count")"

    if [[ -z "$before_click_count" || -z "$before_trail_count" || -z "$before_scroll_count" || -z "$before_hold_count" || -z "$before_hover_count" || -z "$before_total_count" || -z "$after_click_count" || -z "$after_trail_count" || -z "$after_scroll_count" || -z "$after_hold_count" || -z "$after_hover_count" || -z "$after_total_count" || -z "$before_text_effect_fallback_count" || -z "$after_text_effect_fallback_count" ]]; then
        mfx_fail "core effect overlay probe count parse failed"
    fi

    local before_sum=$((before_click_count + before_trail_count + before_scroll_count + before_hold_count + before_hover_count))
    local after_sum=$((after_click_count + after_trail_count + after_scroll_count + after_hold_count + after_hover_count))
    if (( before_sum != before_total_count )); then
        mfx_fail "core effect overlay probe before count mismatch: total=$before_total_count sum=$before_sum"
    fi
    if (( after_sum != after_total_count )); then
        mfx_fail "core effect overlay probe after count mismatch: total=$after_total_count sum=$after_sum"
    fi
    if (( after_text_effect_fallback_count < before_text_effect_fallback_count )); then
        mfx_fail "core effect overlay probe text fallback count regressed: before=$before_text_effect_fallback_count after=$after_text_effect_fallback_count"
    fi

    if [[ "$platform" == "macos" ]]; then
        if ! mfx_file_contains_fixed "$tmp_dir/effect-overlay-probe.out" "\"supported\":true"; then
            mfx_fail "core effect overlay probe support on macos: expected supported=true"
        fi
    fi

    local code_effect_text_click_probe
    code_effect_text_click_probe="$(mfx_http_code "$tmp_dir/effect-overlay-text-click-probe.out" "$base_url/api/effects/test-overlay-windows" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"emit_text_click_effect":true,"text_click_text":"MFX_TEXT_CLICK_PROBE","text_click_font_size_px":112,"close_persistent":true,"wait_ms":140,"wait_for_clear_ms":400}')"
    mfx_assert_eq "$code_effect_text_click_probe" "200" "core effect overlay text-click probe status"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-text-click-probe.out" "\"ok\":true" "core effect overlay text-click probe ok"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-text-click-probe.out" "\"emit_text_click_effect\":true" "core effect overlay text-click probe emit flag"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-text-click-probe.out" "\"text_click_text\":\"MFX_TEXT_CLICK_PROBE\"" "core effect overlay text-click probe text echo"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-text-click-probe.out" "\"before_text_effect_fallback_show_count\":" "core effect overlay text-click probe before fallback count"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-text-click-probe.out" "\"after_text_effect_fallback_show_count\":" "core effect overlay text-click probe after fallback count"
    if [[ "$platform" == "macos" ]]; then
        local text_click_before_count
        local text_click_after_count
        text_click_before_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-text-click-probe.out" "before_text_effect_fallback_show_count")"
        text_click_after_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-text-click-probe.out" "after_text_effect_fallback_show_count")"
        if [[ -z "$text_click_before_count" || -z "$text_click_after_count" ]]; then
            mfx_fail "core effect overlay text-click probe fallback count parse failed"
        fi
        if (( text_click_after_count <= text_click_before_count )); then
            mfx_fail "core effect overlay text-click probe expected fallback show increase on macos: before=$text_click_before_count after=$text_click_after_count"
        fi

        local code_effect_factory_click_text_probe
        code_effect_factory_click_text_probe="$(mfx_http_code "$tmp_dir/effect-overlay-factory-click-text-probe.out" "$base_url/api/effects/test-overlay-windows" \
            -X POST \
            -H "x-mfcmouseeffect-token: $token" \
            -H "Content-Type: application/json" \
            -d '{"emit_click_via_effect_factory":true,"click_type":"text","text_click_text":"MFX_FACTORY_CLICK_TEXT","text_click_font_size_px":116,"close_persistent":true,"wait_ms":120,"wait_for_clear_ms":500}')"
        mfx_assert_eq "$code_effect_factory_click_text_probe" "200" "core effect overlay factory click-text probe status"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"ok\":true" "core effect overlay factory click-text probe ok"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"emit_click_via_effect_factory\":true" "core effect overlay factory click-text probe emit flag"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"click_type\":\"text\"" "core effect overlay factory click-text probe click type"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"before_click_active_overlay_windows\":" "core effect overlay factory click-text probe before click count"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"after_click_active_overlay_windows\":" "core effect overlay factory click-text probe after click count"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"before_text_effect_fallback_show_count\":" "core effect overlay factory click-text probe before fallback count"
        mfx_assert_file_contains "$tmp_dir/effect-overlay-factory-click-text-probe.out" "\"after_text_effect_fallback_show_count\":" "core effect overlay factory click-text probe after fallback count"

        local factory_click_before_count
        local factory_click_after_count
        local factory_text_fallback_before_count
        local factory_text_fallback_after_count
        factory_click_before_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-factory-click-text-probe.out" "before_click_active_overlay_windows")"
        factory_click_after_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-factory-click-text-probe.out" "after_click_active_overlay_windows")"
        factory_text_fallback_before_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-factory-click-text-probe.out" "before_text_effect_fallback_show_count")"
        factory_text_fallback_after_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-factory-click-text-probe.out" "after_text_effect_fallback_show_count")"
        if [[ -z "$factory_click_before_count" || -z "$factory_click_after_count" || -z "$factory_text_fallback_before_count" || -z "$factory_text_fallback_after_count" ]]; then
            mfx_fail "core effect overlay factory click-text probe count parse failed"
        fi
        if (( factory_click_after_count <= factory_click_before_count )); then
            mfx_fail "core effect overlay factory click-text probe expected click overlay increase on macos: before=$factory_click_before_count after=$factory_click_after_count"
        fi
        if (( factory_text_fallback_after_count != factory_text_fallback_before_count )); then
            mfx_fail "core effect overlay factory click-text probe should not touch TextEffect fallback counter on macos: before=$factory_text_fallback_before_count after=$factory_text_fallback_after_count"
        fi
    fi

    local code_effect_overlay_line_trail_probe
    code_effect_overlay_line_trail_probe="$(mfx_http_code "$tmp_dir/effect-overlay-line-trail-probe.out" "$base_url/api/effects/test-overlay-windows" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"emit_line_trail":true,"reset_line_trail":true,"close_persistent":false,"wait_ms":160,"wait_for_clear_ms":0,"line_trail_steps":10,"line_trail_duration_ms":1200,"line_trail_line_width_px":4}')"
    mfx_assert_eq "$code_effect_overlay_line_trail_probe" "200" "core effect overlay line-trail probe status"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-line-trail-probe.out" "\"ok\":true" "core effect overlay line-trail probe ok"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-line-trail-probe.out" "\"emit_line_trail\":true" "core effect overlay line-trail probe emit flag"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-line-trail-probe.out" "\"after_line_trail_active\":" "core effect overlay line-trail probe active field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-line-trail-probe.out" "\"after_line_trail_point_count\":" "core effect overlay line-trail probe point count field"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-line-trail-probe.out" "\"after_line_trail_line_width_px\":" "core effect overlay line-trail probe line-width field"
    if [[ "$platform" == "macos" ]]; then
        mfx_assert_file_contains "$tmp_dir/effect-overlay-line-trail-probe.out" "\"after_line_trail_active\":true" "core effect overlay line-trail probe active on macos"
        local line_trail_after_count
        local line_trail_after_width
        line_trail_after_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-line-trail-probe.out" "after_line_trail_point_count")"
        line_trail_after_width="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-overlay-line-trail-probe.out" "after_line_trail_line_width_px")"
        if [[ -z "$line_trail_after_count" ]]; then
            mfx_fail "core effect overlay line-trail probe count parse failed"
        fi
        if [[ -z "$line_trail_after_width" ]]; then
            mfx_fail "core effect overlay line-trail probe line-width parse failed"
        fi
        if (( line_trail_after_count <= 0 )); then
            mfx_fail "core effect overlay line-trail probe expected point count > 0 on macos, got $line_trail_after_count"
        fi
        _mfx_core_http_automation_assert_float_within_tolerance "$line_trail_after_width" "4.0" "0.001" "core effect overlay line-trail probe expected line width"
    fi

    local code_effect_state_line_trail_active
    code_effect_state_line_trail_active="$(mfx_http_code "$tmp_dir/effect-state-line-trail-active.out" "$base_url/api/state" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_state_line_trail_active" "200" "core effect line-trail active state status"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"line_trail_active\":" "core effect line-trail active state field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"line_trail_point_count\":" "core effect line-trail active state point field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"line_trail_line_width_px\":" "core effect line-trail active state line-width field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"trail_move_samples\":" "core effect line-trail active state move sample field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"trail_origin_connector_drop_count\":" "core effect line-trail active state origin connector drop field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"trail_teleport_drop_count\":" "core effect line-trail active state teleport drop field"
    if [[ "$platform" == "macos" ]]; then
        mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-active.out" "\"line_trail_active\":true" "core effect line-trail active state on macos"
        local state_line_trail_active_count
        local state_line_trail_active_width
        state_line_trail_active_count="$(_mfx_core_http_automation_parse_path_value "$tmp_dir/effect-state-line-trail-active.out" "uint" "effects_runtime" "line_trail_point_count")"
        state_line_trail_active_width="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-state-line-trail-active.out" "effects_runtime" "line_trail_line_width_px")"
        if [[ -z "$state_line_trail_active_count" ]]; then
            mfx_fail "core effect line-trail active state count parse failed"
        fi
        if [[ -z "$state_line_trail_active_width" ]]; then
            mfx_fail "core effect line-trail active state line-width parse failed"
        fi
        if (( state_line_trail_active_count <= 0 )); then
            mfx_fail "core effect line-trail active state expected point count > 0 on macos, got $state_line_trail_active_count"
        fi
        _mfx_core_http_automation_assert_float_within_tolerance "$state_line_trail_active_width" "4.0" "0.001" "core effect line-trail active state expected line width"
    fi

    local code_effect_overlay_trail_line_probe
    code_effect_overlay_trail_line_probe="$(mfx_http_code "$tmp_dir/effect-overlay-trail-line-probe.out" "$base_url/api/effects/test-overlay-windows" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"emit_trail":true,"trail_type":"line","close_persistent":true,"reset_line_trail":true,"wait_ms":80,"wait_for_clear_ms":0}')"
    mfx_assert_eq "$code_effect_overlay_trail_line_probe" "200" "core effect overlay trail-line probe status"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-line-probe.out" "\"ok\":true" "core effect overlay trail-line probe ok"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-line-probe.out" "\"trail_type\":\"line\"" "core effect overlay trail-line probe trail type"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-line-probe.out" "\"before_trail_active_overlay_windows\":" "core effect overlay trail-line probe before trail count"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-line-probe.out" "\"after_trail_active_overlay_windows\":" "core effect overlay trail-line probe after trail count"
    if [[ "$platform" == "macos" ]]; then
        local trail_line_before_count
        local trail_line_after_count
        trail_line_before_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-trail-line-probe.out" "before_trail_active_overlay_windows")"
        trail_line_after_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-trail-line-probe.out" "after_trail_active_overlay_windows")"
        if [[ -z "$trail_line_before_count" || -z "$trail_line_after_count" ]]; then
            mfx_fail "core effect overlay trail-line probe trail count parse failed"
        fi
        if (( trail_line_after_count <= trail_line_before_count )); then
            mfx_fail "core effect overlay trail-line probe expected trail overlay increase on macos: before=$trail_line_before_count after=$trail_line_after_count"
        fi
    fi

    local code_effect_overlay_trail_none_probe
    code_effect_overlay_trail_none_probe="$(mfx_http_code "$tmp_dir/effect-overlay-trail-none-probe.out" "$base_url/api/effects/test-overlay-windows" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"emit_trail":true,"trail_type":"none","close_persistent":true,"reset_line_trail":true,"wait_ms":40,"wait_for_clear_ms":400}')"
    mfx_assert_eq "$code_effect_overlay_trail_none_probe" "200" "core effect overlay trail-none probe status"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"ok\":true" "core effect overlay trail-none probe ok"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"trail_type\":\"none\"" "core effect overlay trail-none probe trail type"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"reset_line_trail\":true" "core effect overlay trail-none probe reset flag"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"before_line_trail_active\":false" "core effect overlay trail-none probe before line trail inactive"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"after_line_trail_active\":false" "core effect overlay trail-none probe after line trail inactive"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"before_line_trail_point_count\":0" "core effect overlay trail-none probe before line trail count zero"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"after_line_trail_point_count\":0" "core effect overlay trail-none probe after line trail count zero"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"before_trail_active_overlay_windows\":" "core effect overlay trail-none probe before trail count"
    mfx_assert_file_contains "$tmp_dir/effect-overlay-trail-none-probe.out" "\"after_trail_active_overlay_windows\":" "core effect overlay trail-none probe after trail count"
    if [[ "$platform" == "macos" ]]; then
        local trail_none_before_count
        local trail_none_after_count
        trail_none_before_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-trail-none-probe.out" "before_trail_active_overlay_windows")"
        trail_none_after_count="$(_mfx_core_http_automation_parse_uint_field "$tmp_dir/effect-overlay-trail-none-probe.out" "after_trail_active_overlay_windows")"
        if [[ -z "$trail_none_before_count" || -z "$trail_none_after_count" ]]; then
            mfx_fail "core effect overlay trail-none probe trail count parse failed"
        fi
        if (( trail_none_after_count > trail_none_before_count )); then
            mfx_fail "core effect overlay trail-none probe should not increase trail overlays on macos: before=$trail_none_before_count after=$trail_none_after_count"
        fi
    fi

    local code_effect_state_line_trail_cleared
    code_effect_state_line_trail_cleared="$(mfx_http_code "$tmp_dir/effect-state-line-trail-cleared.out" "$base_url/api/state" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_state_line_trail_cleared" "200" "core effect line-trail cleared state status"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"line_trail_active\":" "core effect line-trail cleared state field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"line_trail_point_count\":" "core effect line-trail cleared state point field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"line_trail_line_width_px\":" "core effect line-trail cleared state line-width field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"trail_move_samples\":" "core effect line-trail cleared state move sample field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"trail_origin_connector_drop_count\":" "core effect line-trail cleared state origin connector drop field"
    mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"trail_teleport_drop_count\":" "core effect line-trail cleared state teleport drop field"
    if [[ "$platform" == "macos" ]]; then
        mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"line_trail_active\":false" "core effect line-trail cleared state on macos"
        mfx_assert_file_contains "$tmp_dir/effect-state-line-trail-cleared.out" "\"line_trail_point_count\":0" "core effect line-trail cleared point count on macos"
    fi

    local code_effect_profile_probe
    code_effect_profile_probe="$(mfx_http_code "$tmp_dir/effect-render-profile-probe.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe" "200" "core effect render profile probe status"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"ok\":true" "core effect render profile probe ok"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"active\":" "core effect render profile probe active section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"command_samples\":" "core effect render profile probe command samples section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"sample_input\":" "core effect render profile probe command sample input"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"active_raw\":" "core effect render profile probe active raw sample input"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"active_normalized\":" "core effect render profile probe active normalized sample input"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"active_normalized\":{\"click\":" "core effect render profile probe active normalized click field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail\":" "core effect render profile probe active normalized trail field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"scroll\":" "core effect render profile probe active normalized scroll field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold\":" "core effect render profile probe active normalized hold field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hover\":" "core effect render profile probe active normalized hover field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_emission\":" "core effect render profile probe trail emission sample"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"alias_matrix\":" "core effect render profile probe alias matrix section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"effective_timing\":" "core effect render profile probe effective timing section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"click_duration_sec\":" "core effect render profile probe effective click duration"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"click_text_font_size_px\":" "core effect render profile probe effective click text font-size"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"click_text_float_distance_px\":" "core effect render profile probe effective click text float distance"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_duration_sec\":" "core effect render profile probe effective trail duration"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_command_line_width_px\":" "core effect render profile probe effective trail command line-width"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_profile_line_width_px\":" "core effect render profile probe effective trail profile line-width"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_planner_teleport_skip_distance_px\":" "core effect render profile probe trail planner teleport distance"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_planner_max_segments\":" "core effect render profile probe trail planner max segments"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"scroll_duration_sec\":" "core effect render profile probe effective scroll duration"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"scroll_emit_interval_ms\":" "core effect render profile probe effective scroll emit interval"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"scroll_max_duration_ms\":" "core effect render profile probe effective scroll max duration"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold_progress_full_ms\":" "core effect render profile probe effective hold progress"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"stream\",\"normalized\":\"streamer\"" "core effect render profile probe trail stream alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"scifi\",\"normalized\":\"tubes\"" "core effect render profile probe trail scifi alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"stardust\",\"normalized\":\"twinkle\"" "core effect render profile probe scroll stardust alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"none\",\"normalized\":\"none\"" "core effect render profile probe scroll none passthrough (none is a first-class disable value)"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"suspension\",\"normalized\":\"tubes\"" "core effect render profile probe hover suspension alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"none\",\"normalized\":\"none\"" "core effect render profile probe hover none passthrough (none is a first-class disable value)"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"hold_neon3d_gpu_v2\",\"normalized\":\"hold_quantum_halo_gpu_v2\"" "core effect render profile probe hold legacy alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"scifi3d\",\"normalized\":\"hologram\"" "core effect render profile probe hold scifi3d alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"neon3d\",\"normalized\":\"hold_neon3d\"" "core effect render profile probe hold neon3d alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold_follow_mode\":" "core effect render profile probe hold follow mode alias matrix section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"none\",\"normalized\":\"none\"" "core effect render profile probe click none passthrough (none is a first-class disable value)"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"none\",\"normalized\":\"none\"" "core effect render profile probe trail none alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"default\",\"normalized\":\"line\"" "core effect render profile probe trail default alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"cursor_priority\",\"normalized\":\"smooth\"" "core effect render profile probe hold follow cursor_priority alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"performance_first\",\"normalized\":\"efficient\"" "core effect render profile probe hold follow performance_first alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"cpu_saver\",\"normalized\":\"efficient\"" "core effect render profile probe hold follow cpu_saver alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"TEXT\",\"normalized\":\"text\"" "core effect render profile probe click uppercase alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"icon\",\"normalized\":\"star\"" "core effect render profile probe click icon alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"input\":\"textclick\",\"normalized\":\"text\"" "core effect render profile probe click textclick alias"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"normalized_type\":\"" "core effect render profile probe normalized type sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"strength_level\":" "core effect render profile probe scroll strength sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"strength_scalar\":" "core effect render profile probe scroll strength scalar sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"intensity\":" "core effect render profile probe scroll intensity sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"tubes_spin_duration_sec\":" "core effect render profile probe hover spin sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"progress_full_ms\":" "core effect render profile probe hold progress sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"overlay_x\":" "core effect render profile probe hold update sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"size_px\":" "core effect render profile probe command size field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"duration_sec\":" "core effect render profile probe command duration field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"stroke_argb\":" "core effect render profile probe command color field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"text_font_size_px\":" "core effect render profile probe click text font-size field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"text_float_distance_px\":" "core effect render profile probe click text float-distance field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"text_font_family_utf8\":" "core effect render profile probe click text font-family field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"text_emoji\":" "core effect render profile probe click text emoji flag field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"speed_px\":" "core effect render profile probe trail speed sample field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"active_resolved\":" "core effect render profile probe active resolved section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold_follow_mode_normalized\":" "core effect render profile probe hold follow mode normalized field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold\":\"" "core effect render profile probe active hold field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hover\":\"" "core effect render profile probe active hover field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold_follow_mode_samples\":" "core effect render profile probe hold follow mode samples section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"profiles\":" "core effect render profile probe profiles"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"click\":" "core effect render profile click section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail\":" "core effect render profile trail section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_throttle\":" "core effect render profile trail throttle section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"scroll\":" "core effect render profile scroll section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hold\":" "core effect render profile hold section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"hover\":" "core effect render profile hover section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"normal_duration_sec\":" "core effect render profile click duration field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"duration_sec\":" "core effect render profile trail duration field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"base_duration_sec\":" "core effect render profile scroll duration field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"min_interval_ms\":" "core effect render profile throttle interval field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"progress_full_ms\":" "core effect render profile hold progress field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"spin_duration_sec\":" "core effect render profile hover spin field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"line_stroke_argb\":" "core effect render profile trail line stroke color field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"line_width_px\":" "core effect render profile trail line width field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"meteor_duration_scale\":" "core effect render profile trail tempo scale field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"test_tuning\":" "core effect render profile test tuning section"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"duration_scale\":" "core effect render profile duration test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"size_scale\":" "core effect render profile size test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"opacity_scale\":" "core effect render profile opacity test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_throttle_scale\":" "core effect render profile trail throttle test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"duration_overridden\":$expected_duration_overridden" "core effect render profile expected duration override marker"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"size_overridden\":$expected_size_overridden" "core effect render profile expected size override marker"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"opacity_overridden\":$expected_opacity_overridden" "core effect render profile expected opacity override marker"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"trail_throttle_overridden\":$expected_trail_throttle_overridden" "core effect render profile expected trail throttle override marker"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"horizontal_positive_stroke_argb\":" "core effect render profile scroll direction stroke color field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"helix_duration_scale\":" "core effect render profile scroll tempo scale field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"left_base_stroke_argb\":" "core effect render profile hold base stroke color field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"tubes_spin_scale\":" "core effect render profile hover tempo scale field"
    mfx_assert_file_contains "$tmp_dir/effect-render-profile-probe.out" "\"tubes_stroke_argb\":" "core effect render profile hover tubes stroke color field"

    local code_effect_profile_state
    code_effect_profile_state="$(mfx_http_code "$tmp_dir/effect-profile-state.out" "$base_url/api/state" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_state" "200" "core effect profile state status"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"effects_profile\":" "core effect profile state section"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"meteor_duration_scale\":" "core effect profile state trail tempo field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"helix_duration_scale\":" "core effect profile state scroll tempo field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"tubes_spin_scale\":" "core effect profile state hover tempo field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"duration_scale\":" "core effect profile state duration test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"size_scale\":" "core effect profile state size test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"opacity_scale\":" "core effect profile state opacity test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"trail_throttle_scale\":" "core effect profile state trail throttle test tuning field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"line_width_px\":" "core effect profile state trail line width field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"trail_emission_planner\":" "core effect profile state trail emission planner section"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"teleport_skip_distance_px\":" "core effect profile state trail planner teleport distance"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"max_segments\":" "core effect profile state trail planner max segments"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"line_trail_active\":" "core effect runtime state line trail active field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"line_trail_point_count\":" "core effect runtime state line trail point count field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"line_trail_line_width_px\":" "core effect runtime state line trail line-width field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"trail_move_samples\":" "core effect runtime state trail move sample field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"trail_origin_connector_drop_count\":" "core effect runtime state trail origin connector drop field"
    mfx_assert_file_contains "$tmp_dir/effect-profile-state.out" "\"trail_teleport_drop_count\":" "core effect runtime state trail teleport drop field"

    local probe_meteor_scale
    local state_meteor_scale
    local probe_helix_scale
    local state_helix_scale
    local probe_tubes_spin_scale
    local state_tubes_spin_scale
    local probe_line_stroke
    local state_line_stroke
    local probe_duration_scale
    local state_duration_scale
    local probe_size_scale
    local state_size_scale
    local probe_opacity_scale
    local state_opacity_scale
    local probe_trail_throttle_scale
    local state_trail_throttle_scale
    local probe_active_click
    local state_active_click
    local probe_active_trail
    local state_active_trail
    local probe_active_scroll
    local state_active_scroll
    local probe_active_hold
    local state_active_hold
    local probe_active_hover
    local state_active_hover
    local probe_click_base_opacity
    local state_click_base_opacity
    local probe_trail_base_opacity
    local state_trail_base_opacity
    local probe_scroll_base_opacity
    local state_scroll_base_opacity
    local probe_hold_base_opacity
    local state_hold_base_opacity
    local probe_hover_base_opacity
    local state_hover_base_opacity
    local probe_click_text_font_size
    local probe_click_text_float_distance
    local probe_trail_command_line_width
    local probe_trail_profile_line_width
    local probe_trail_command_emit
    local probe_trail_command_type
    probe_meteor_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "trail" "meteor_duration_scale")"
    state_meteor_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "trail" "meteor_duration_scale")"
    probe_helix_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "scroll" "helix_duration_scale")"
    state_helix_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "scroll" "helix_duration_scale")"
    probe_tubes_spin_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "hover" "tubes_spin_scale")"
    state_tubes_spin_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "hover" "tubes_spin_scale")"
    probe_line_stroke="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "trail" "line_stroke_argb")"
    state_line_stroke="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "trail" "line_stroke_argb")"
    probe_duration_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "config_basis" "test_tuning" "duration_scale")"
    state_duration_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "config_basis" "test_tuning" "duration_scale")"
    probe_size_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "config_basis" "test_tuning" "size_scale")"
    state_size_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "config_basis" "test_tuning" "size_scale")"
    probe_opacity_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "config_basis" "test_tuning" "opacity_scale")"
    state_opacity_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "config_basis" "test_tuning" "opacity_scale")"
    probe_trail_throttle_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "config_basis" "test_tuning" "trail_throttle_scale")"
    state_trail_throttle_scale="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "config_basis" "test_tuning" "trail_throttle_scale")"
    probe_active_click="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-render-profile-probe.out" "active" "click")"
    state_active_click="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-profile-state.out" "effects_profile" "active" "click")"
    probe_active_trail="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-render-profile-probe.out" "active" "trail")"
    state_active_trail="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-profile-state.out" "effects_profile" "active" "trail")"
    probe_active_scroll="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-render-profile-probe.out" "active" "scroll")"
    state_active_scroll="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-profile-state.out" "effects_profile" "active" "scroll")"
    probe_active_hold="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-render-profile-probe.out" "active" "hold")"
    state_active_hold="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-profile-state.out" "effects_profile" "active" "hold")"
    probe_active_hover="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-render-profile-probe.out" "active" "hover")"
    state_active_hover="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-profile-state.out" "effects_profile" "active" "hover")"
    probe_click_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "click" "base_opacity")"
    state_click_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "click" "base_opacity")"
    probe_trail_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "trail" "base_opacity")"
    state_trail_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "trail" "base_opacity")"
    probe_scroll_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "scroll" "base_opacity")"
    state_scroll_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "scroll" "base_opacity")"
    probe_hold_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "hold" "base_opacity")"
    state_hold_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "hold" "base_opacity")"
    probe_hover_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "profiles" "hover" "base_opacity")"
    state_hover_base_opacity="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-profile-state.out" "effects_profile" "hover" "base_opacity")"
    probe_click_text_font_size="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "command_samples" "effective_timing" "click_text_font_size_px")"
    probe_click_text_float_distance="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "command_samples" "effective_timing" "click_text_float_distance_px")"
    probe_trail_command_line_width="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "command_samples" "effective_timing" "trail_command_line_width_px")"
    probe_trail_profile_line_width="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe.out" "command_samples" "effective_timing" "trail_profile_line_width_px")"
    probe_trail_command_emit="$(_mfx_core_http_automation_parse_command_section_scalar_field "$tmp_dir/effect-render-profile-probe.out" "trail" "emit")"
    probe_trail_command_type="$(_mfx_core_http_automation_parse_command_section_scalar_field "$tmp_dir/effect-render-profile-probe.out" "trail" "normalized_type")"
    probe_trail_command_type="${probe_trail_command_type//\"/}"

    local missing_profile_fields=()
    [[ -z "$probe_meteor_scale" ]] && missing_profile_fields+=("probe_meteor_scale")
    [[ -z "$state_meteor_scale" ]] && missing_profile_fields+=("state_meteor_scale")
    [[ -z "$probe_helix_scale" ]] && missing_profile_fields+=("probe_helix_scale")
    [[ -z "$state_helix_scale" ]] && missing_profile_fields+=("state_helix_scale")
    [[ -z "$probe_tubes_spin_scale" ]] && missing_profile_fields+=("probe_tubes_spin_scale")
    [[ -z "$state_tubes_spin_scale" ]] && missing_profile_fields+=("state_tubes_spin_scale")
    [[ -z "$probe_line_stroke" ]] && missing_profile_fields+=("probe_line_stroke")
    [[ -z "$state_line_stroke" ]] && missing_profile_fields+=("state_line_stroke")
    [[ -z "$probe_duration_scale" ]] && missing_profile_fields+=("probe_duration_scale")
    [[ -z "$state_duration_scale" ]] && missing_profile_fields+=("state_duration_scale")
    [[ -z "$probe_size_scale" ]] && missing_profile_fields+=("probe_size_scale")
    [[ -z "$state_size_scale" ]] && missing_profile_fields+=("state_size_scale")
    [[ -z "$probe_opacity_scale" ]] && missing_profile_fields+=("probe_opacity_scale")
    [[ -z "$state_opacity_scale" ]] && missing_profile_fields+=("state_opacity_scale")
    [[ -z "$probe_trail_throttle_scale" ]] && missing_profile_fields+=("probe_trail_throttle_scale")
    [[ -z "$state_trail_throttle_scale" ]] && missing_profile_fields+=("state_trail_throttle_scale")
    [[ -z "$probe_active_click" ]] && missing_profile_fields+=("probe_active_click")
    [[ -z "$state_active_click" ]] && missing_profile_fields+=("state_active_click")
    [[ -z "$probe_active_trail" ]] && missing_profile_fields+=("probe_active_trail")
    [[ -z "$state_active_trail" ]] && missing_profile_fields+=("state_active_trail")
    [[ -z "$probe_active_scroll" ]] && missing_profile_fields+=("probe_active_scroll")
    [[ -z "$state_active_scroll" ]] && missing_profile_fields+=("state_active_scroll")
    [[ -z "$probe_active_hold" ]] && missing_profile_fields+=("probe_active_hold")
    [[ -z "$state_active_hold" ]] && missing_profile_fields+=("state_active_hold")
    [[ -z "$probe_active_hover" ]] && missing_profile_fields+=("probe_active_hover")
    [[ -z "$state_active_hover" ]] && missing_profile_fields+=("state_active_hover")
    [[ -z "$probe_click_base_opacity" ]] && missing_profile_fields+=("probe_click_base_opacity")
    [[ -z "$state_click_base_opacity" ]] && missing_profile_fields+=("state_click_base_opacity")
    [[ -z "$probe_trail_base_opacity" ]] && missing_profile_fields+=("probe_trail_base_opacity")
    [[ -z "$state_trail_base_opacity" ]] && missing_profile_fields+=("state_trail_base_opacity")
    [[ -z "$probe_scroll_base_opacity" ]] && missing_profile_fields+=("probe_scroll_base_opacity")
    [[ -z "$state_scroll_base_opacity" ]] && missing_profile_fields+=("state_scroll_base_opacity")
    [[ -z "$probe_hold_base_opacity" ]] && missing_profile_fields+=("probe_hold_base_opacity")
    [[ -z "$state_hold_base_opacity" ]] && missing_profile_fields+=("state_hold_base_opacity")
    [[ -z "$probe_hover_base_opacity" ]] && missing_profile_fields+=("probe_hover_base_opacity")
    [[ -z "$state_hover_base_opacity" ]] && missing_profile_fields+=("state_hover_base_opacity")
    [[ -z "$probe_click_text_font_size" ]] && missing_profile_fields+=("probe_click_text_font_size")
    [[ -z "$probe_click_text_float_distance" ]] && missing_profile_fields+=("probe_click_text_float_distance")
    [[ -z "$probe_trail_command_line_width" ]] && missing_profile_fields+=("probe_trail_command_line_width")
    [[ -z "$probe_trail_profile_line_width" ]] && missing_profile_fields+=("probe_trail_profile_line_width")
    [[ -z "$probe_trail_command_emit" ]] && missing_profile_fields+=("probe_trail_command_emit")
    [[ -z "$probe_trail_command_type" ]] && missing_profile_fields+=("probe_trail_command_type")
    if (( ${#missing_profile_fields[@]} > 0 )); then
        mfx_fail "core effect profile parity parse failed: ${missing_profile_fields[*]}"
    fi
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_duration_scale" "$expected_duration_scale" "0.0001" "core effect render profile expected duration test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_size_scale" "$expected_size_scale" "0.0001" "core effect render profile expected size test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_opacity_scale" "$expected_opacity_scale" "0.0001" "core effect render profile expected opacity test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_trail_throttle_scale" "$expected_trail_throttle_scale" "0.0001" "core effect render profile expected trail throttle test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$state_duration_scale" "$expected_duration_scale" "0.0001" "core effect profile state expected duration test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$state_size_scale" "$expected_size_scale" "0.0001" "core effect profile state expected size test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$state_opacity_scale" "$expected_opacity_scale" "0.0001" "core effect profile state expected opacity test tuning"
    _mfx_core_http_automation_assert_float_within_tolerance "$state_trail_throttle_scale" "$expected_trail_throttle_scale" "0.0001" "core effect profile state expected trail throttle test tuning"
    mfx_assert_eq "$probe_meteor_scale" "$state_meteor_scale" "core effect profile parity meteor duration scale"
    mfx_assert_eq "$probe_helix_scale" "$state_helix_scale" "core effect profile parity helix duration scale"
    mfx_assert_eq "$probe_tubes_spin_scale" "$state_tubes_spin_scale" "core effect profile parity tubes spin scale"
    mfx_assert_eq "$probe_line_stroke" "$state_line_stroke" "core effect profile parity trail line stroke argb"
    mfx_assert_eq "$probe_duration_scale" "$state_duration_scale" "core effect profile parity duration test tuning scale"
    mfx_assert_eq "$probe_size_scale" "$state_size_scale" "core effect profile parity size test tuning scale"
    mfx_assert_eq "$probe_opacity_scale" "$state_opacity_scale" "core effect profile parity opacity test tuning scale"
    mfx_assert_eq "$probe_trail_throttle_scale" "$state_trail_throttle_scale" "core effect profile parity trail throttle test tuning scale"
    mfx_assert_eq "$probe_active_click" "$state_active_click" "core effect profile parity active click"
    mfx_assert_eq "$probe_active_trail" "$state_active_trail" "core effect profile parity active trail"
    mfx_assert_eq "$probe_active_scroll" "$state_active_scroll" "core effect profile parity active scroll"
    mfx_assert_eq "$probe_active_hold" "$state_active_hold" "core effect profile parity active hold"
    mfx_assert_eq "$probe_active_hover" "$state_active_hover" "core effect profile parity active hover"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_click_base_opacity" "$state_click_base_opacity" "0.0001" "core effect profile parity click base opacity"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_trail_base_opacity" "$state_trail_base_opacity" "0.0001" "core effect profile parity trail base opacity"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_scroll_base_opacity" "$state_scroll_base_opacity" "0.0001" "core effect profile parity scroll base opacity"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_hold_base_opacity" "$state_hold_base_opacity" "0.0001" "core effect profile parity hold base opacity"
    _mfx_core_http_automation_assert_float_within_tolerance "$probe_hover_base_opacity" "$state_hover_base_opacity" "0.0001" "core effect profile parity hover base opacity"
    if ! awk -v font="$probe_click_text_font_size" -v dist="$probe_click_text_float_distance" 'BEGIN { exit(font > 0 && dist > 0 ? 0 : 1); }'; then
        mfx_fail "core effect profile parity click text geometry invalid: font_size=$probe_click_text_font_size float_distance=$probe_click_text_float_distance"
    fi
    if [[ "$probe_active_trail" != "none" && "$probe_trail_command_emit" == "true" && "$probe_trail_command_type" == "line" ]]; then
        _mfx_core_http_automation_assert_float_within_tolerance "$probe_trail_command_line_width" "$probe_trail_profile_line_width" "0.0001" "core effect profile parity trail command/profile line width"
    fi

    if [[ "$platform" == "macos" ]]; then
        if ! mfx_file_contains_fixed "$tmp_dir/effect-render-profile-probe.out" "\"supported\":true"; then
            mfx_fail "core effect render profile probe support on macos: expected supported=true"
        fi
    fi

    local code_effect_state_set_legacy_aliases
    code_effect_state_set_legacy_aliases="$(mfx_http_code "$tmp_dir/effect-state-set-legacy-aliases.out" "$base_url/api/state" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"active":{"click":"textclick","trail":"scifi","scroll":"stardust","hold":"scifi3d","hover":"suspension"},"hold_follow_mode":"cursor_priority"}')"
    mfx_assert_eq "$code_effect_state_set_legacy_aliases" "200" "core effect set legacy aliases state post status"

    local code_effect_state_get_legacy_aliases
    code_effect_state_get_legacy_aliases="$(mfx_http_code "$tmp_dir/effect-state-get-legacy-aliases.out" "$base_url/api/state" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_state_get_legacy_aliases" "200" "core effect set legacy aliases state get status"

    local state_legacy_click
    local state_legacy_trail
    local state_legacy_scroll
    local state_legacy_hold
    local state_legacy_hover
    local state_legacy_hold_follow_mode
    state_legacy_click="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-state-get-legacy-aliases.out" "effects_profile" "active" "click")"
    state_legacy_trail="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-state-get-legacy-aliases.out" "effects_profile" "active" "trail")"
    state_legacy_scroll="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-state-get-legacy-aliases.out" "effects_profile" "active" "scroll")"
    state_legacy_hold="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-state-get-legacy-aliases.out" "effects_profile" "active" "hold")"
    state_legacy_hover="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-state-get-legacy-aliases.out" "effects_profile" "active" "hover")"
    state_legacy_hold_follow_mode="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-state-get-legacy-aliases.out" "hold_follow_mode")"
    state_legacy_hold_follow_mode="${state_legacy_hold_follow_mode//\"/}"

    mfx_assert_eq "$state_legacy_click" "text" "core effect state legacy alias normalize click"
    mfx_assert_eq "$state_legacy_trail" "tubes" "core effect state legacy alias normalize trail"
    mfx_assert_eq "$state_legacy_scroll" "twinkle" "core effect state legacy alias normalize scroll"
    mfx_assert_eq "$state_legacy_hold" "hologram" "core effect state legacy alias normalize hold"
    mfx_assert_eq "$state_legacy_hover" "tubes" "core effect state legacy alias normalize hover"
    mfx_assert_eq "$state_legacy_hold_follow_mode" "smooth" "core effect state legacy alias normalize hold follow mode"

    local code_effect_profile_probe_legacy_aliases
    code_effect_profile_probe_legacy_aliases="$(mfx_http_code "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe_legacy_aliases" "200" "core effect legacy alias render profile probe status"

    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "click" \
        "text" \
        "text" \
        "core effect render profile legacy alias normalize click"
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "trail" \
        "tubes" \
        "tubes" \
        "core effect render profile legacy alias normalize trail"
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "scroll" \
        "twinkle" \
        "twinkle" \
        "core effect render profile legacy alias normalize scroll"
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "hover" \
        "tubes" \
        "tubes" \
        "core effect render profile legacy alias normalize hover"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "hold" \
        "start" \
        "normalized_type" \
        "hologram" \
        "core effect render profile legacy alias normalize hold"

    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "trail" \
        "tubes_mode" \
        "true" \
        "core effect render profile legacy alias command trail tubes mode"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "scroll" \
        "twinkle_mode" \
        "true" \
        "core effect render profile legacy alias command scroll twinkle mode"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-legacy-aliases.out" \
        "hover" \
        "tubes_mode" \
        "true" \
        "core effect render profile legacy alias command hover tubes mode"

    local code_effect_state_set_none_fallback_modes
    code_effect_state_set_none_fallback_modes="$(mfx_http_code "$tmp_dir/effect-state-set-none-fallback-modes.out" "$base_url/api/state" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"active":{"click":"none","trail":"line","scroll":"none","hold":"hologram","hover":"none"}}')"
    mfx_assert_eq "$code_effect_state_set_none_fallback_modes" "200" "core effect set none-fallback modes state post status"

    local code_effect_profile_probe_none_fallback_modes
    code_effect_profile_probe_none_fallback_modes="$(mfx_http_code "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe_none_fallback_modes" "200" "core effect set none-fallback modes render profile probe status"

    # Contract update: "none" is a first-class disable value and is honored
    # as-is; it no longer falls back to each channel's default type.
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" \
        "click" \
        "none" \
        "none" \
        "core effect render profile none passthrough click"
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" \
        "scroll" \
        "none" \
        "none" \
        "core effect render profile none passthrough scroll"
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" \
        "hover" \
        "none" \
        "none" \
        "core effect render profile none passthrough hover"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" \
        "scroll" \
        "helix_mode" \
        "false" \
        "core effect render profile none fallback command scroll helix mode"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" \
        "scroll" \
        "twinkle_mode" \
        "false" \
        "core effect render profile none fallback command scroll twinkle mode"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-none-fallback-modes.out" \
        "hover" \
        "tubes_mode" \
        "false" \
        "core effect render profile none fallback command hover tubes mode"

    local code_effect_state_set_trail_line
    code_effect_state_set_trail_line="$(mfx_http_code "$tmp_dir/effect-state-set-trail-line.out" "$base_url/api/state" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"active":{"click":"ripple","trail":"line","scroll":"helix","hold":"hologram","hover":"tubes"}}')"
    mfx_assert_eq "$code_effect_state_set_trail_line" "200" "core effect set trail-line state post status"

    local code_effect_profile_probe_trail_line
    code_effect_profile_probe_trail_line="$(mfx_http_code "$tmp_dir/effect-render-profile-probe-trail-line.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe_trail_line" "200" "core effect set trail-line render profile probe status"

    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-trail-line.out" \
        "trail" \
        "line" \
        "line" \
        "core effect set trail-line render profile"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-trail-line.out" \
        "trail" \
        "emit" \
        "true" \
        "core effect set trail-line command emit"

    local code_effect_state_set_trail_particle
    code_effect_state_set_trail_particle="$(mfx_http_code "$tmp_dir/effect-state-set-trail-particle.out" "$base_url/api/state" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"active":{"click":"ripple","trail":"particle","scroll":"helix","hold":"hologram","hover":"tubes"}}')"
    mfx_assert_eq "$code_effect_state_set_trail_particle" "200" "core effect set trail-particle state post status"

    local code_effect_profile_probe_trail_particle
    code_effect_profile_probe_trail_particle="$(mfx_http_code "$tmp_dir/effect-render-profile-probe-trail-particle.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe_trail_particle" "200" "core effect set trail-particle render profile probe status"

    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-trail-particle.out" \
        "trail" \
        "particle" \
        "particle" \
        "core effect set trail-particle render profile"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-trail-particle.out" \
        "trail" \
        "emit" \
        "true" \
        "core effect set trail-particle command emit"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-trail-particle.out" \
        "trail" \
        "particle_mode" \
        "true" \
        "core effect set trail-particle command particle mode"

    local code_effect_state_set_trail_none
    code_effect_state_set_trail_none="$(mfx_http_code "$tmp_dir/effect-state-set-trail-none.out" "$base_url/api/state" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"active":{"click":"ripple","trail":"none","scroll":"helix","hold":"hologram","hover":"tubes"}}')"
    mfx_assert_eq "$code_effect_state_set_trail_none" "200" "core effect set trail-none state post status"

    local code_effect_state_get_trail_none
    code_effect_state_get_trail_none="$(mfx_http_code "$tmp_dir/effect-state-get-trail-none.out" "$base_url/api/state" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_state_get_trail_none" "200" "core effect set trail-none state get status"

    local get_trail_none_active_trail
    get_trail_none_active_trail="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-state-get-trail-none.out" "effects_profile" "active" "trail")"
    if [[ "$get_trail_none_active_trail" != "none" ]]; then
        mfx_fail "core effect set trail-none state get active trail mismatch: expected none, got ${get_trail_none_active_trail:-<empty>}"
    fi

    local code_effect_profile_probe_trail_none
    code_effect_profile_probe_trail_none="$(mfx_http_code "$tmp_dir/effect-render-profile-probe-trail-none.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe_trail_none" "200" "core effect set trail-none render profile probe status"

    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-trail-none.out" \
        "trail" \
        "none" \
        "none" \
        "core effect set trail-none render profile"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-trail-none.out" \
        "trail" \
        "emit" \
        "false" \
        "core effect set trail-none command emit"

    local code_effect_state_set_scroll_hover_hold_modes
    code_effect_state_set_scroll_hover_hold_modes="$(mfx_http_code "$tmp_dir/effect-state-set-scroll-hover-hold-modes.out" "$base_url/api/state" \
        -X POST \
        -H "x-mfcmouseeffect-token: $token" \
        -H "Content-Type: application/json" \
        -d '{"active":{"click":"text","trail":"line","scroll":"helix","hold":"hologram","hover":"tubes"}}')"
    mfx_assert_eq "$code_effect_state_set_scroll_hover_hold_modes" "200" "core effect set scroll-hover-hold modes state post status"

    local code_effect_profile_probe_scroll_hover_hold_modes
    code_effect_profile_probe_scroll_hover_hold_modes="$(mfx_http_code "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" "$base_url/api/effects/test-render-profiles" \
        -X GET \
        -H "x-mfcmouseeffect-token: $token")"
    mfx_assert_eq "$code_effect_profile_probe_scroll_hover_hold_modes" "200" "core effect set scroll-hover-hold modes render profile probe status"

    local probe_scroll_hover_hold_active_hold
    local probe_scroll_strength_level
    local probe_hold_progress_full_ms
    probe_scroll_hover_hold_active_hold="$(_mfx_core_http_automation_parse_path_string_field "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" "active" "hold")"
    probe_scroll_strength_level="$(_mfx_core_http_automation_parse_command_section_scalar_field "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" "scroll" "strength_level")"
    probe_hold_progress_full_ms="$(_mfx_core_http_automation_parse_path_scalar_field "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" "command_samples" "effective_timing" "hold_progress_full_ms")"

    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "scroll" \
        "helix" \
        "helix" \
        "core effect render profile parity scroll"
    _mfx_core_http_automation_assert_active_and_command_type \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hover" \
        "tubes" \
        "tubes" \
        "core effect render profile parity hover"
    mfx_assert_eq "$probe_scroll_hover_hold_active_hold" "hologram" "core effect render profile parity hold active type"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "scroll" \
        "emit" \
        "true" \
        "core effect render profile parity scroll command emit"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "scroll" \
        "helix_mode" \
        "true" \
        "core effect render profile parity scroll command helix mode"
    _mfx_core_http_automation_assert_command_flag_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hover" \
        "tubes_mode" \
        "true" \
        "core effect render profile parity hover command tubes mode"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold" \
        "start" \
        "normalized_type" \
        "hologram" \
        "core effect render profile parity hold start command normalized type"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold" \
        "update" \
        "emit" \
        "true" \
        "core effect render profile parity hold update command emit"
    if ! awk -v level="$probe_scroll_strength_level" -v progress="$probe_hold_progress_full_ms" 'BEGIN { exit(level > 0 && progress > 0 ? 0 : 1); }'; then
        mfx_fail "core effect render profile parity scroll/hold command metrics invalid: scroll_strength_level=$probe_scroll_strength_level hold_progress_full_ms=$probe_hold_progress_full_ms"
    fi

    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold_follow_mode_samples" \
        "smooth_second" \
        "overlay_x" \
        "635" \
        "core effect render profile parity hold smooth mode second overlay x"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold_follow_mode_samples" \
        "smooth_second" \
        "overlay_y" \
        "368" \
        "core effect render profile parity hold smooth mode second overlay y"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold_follow_mode_samples" \
        "efficient_first" \
        "emit" \
        "true" \
        "core effect render profile parity hold efficient mode first emit"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold_follow_mode_samples" \
        "efficient_suppressed" \
        "emit" \
        "false" \
        "core effect render profile parity hold efficient mode suppressed emit"
    _mfx_core_http_automation_assert_nested_command_field_eq \
        "$tmp_dir/effect-render-profile-probe-scroll-hover-hold-modes.out" \
        "hold_follow_mode_samples" \
        "efficient_resumed" \
        "emit" \
        "true" \
        "core effect render profile parity hold efficient mode resumed emit"
}
