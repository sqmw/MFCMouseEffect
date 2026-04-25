#pragma once

namespace mousefx::config_json::keys {

inline constexpr const char kDefaultEffect[] = "default_effect";
inline constexpr const char kTheme[] = "theme";
inline constexpr const char kThemeCatalogRootPath[] = "theme_catalog_root_path";
inline constexpr const char kOverlayTargetFps[] = "overlay_target_fps";
inline constexpr const char kUiLanguage[] = "ui_language";
inline constexpr const char kLaunchAtStartup[] = "launch_at_startup";
inline constexpr const char kHoldFollowMode[] = "hold_follow_mode";
inline constexpr const char kHoldPresenterBackend[] = "hold_presenter_backend";
inline constexpr const char kEffectsBlacklistApps[] = "effects_blacklist_apps";
inline constexpr const char kTrailStyle[] = "trail_style";
inline constexpr const char kActiveEffects[] = "active_effects";
inline constexpr const char kMouseCompanion[] = "mouse_companion";
inline constexpr const char kInputIndicator[] = "input_indicator";
inline constexpr const char kMouseIndicator[] = "mouse_indicator";
inline constexpr const char kAutomation[] = "automation";
inline constexpr const char kWasm[] = "wasm";
inline constexpr const char kTrailParams[] = "trail_params";
inline constexpr const char kTrailProfiles[] = "trail_profiles";
inline constexpr const char kEffects[] = "effects";
inline constexpr const char kEffectSizeScales[] = "effect_size_scales";
inline constexpr const char kEffectConflictPolicy[] = "effect_conflict_policy";

namespace effect_conflict_policy {
inline constexpr const char kHoldMovePolicy[] = "hold_move_policy";
inline constexpr const char kHoldMoveLegacy[] = "hold_move";
} // namespace effect_conflict_policy

namespace effect_size_scale {
inline constexpr const char kClick[] = "click";
inline constexpr const char kTrail[] = "trail";
inline constexpr const char kScroll[] = "scroll";
inline constexpr const char kHold[] = "hold";
inline constexpr const char kHover[] = "hover";
} // namespace effect_size_scale

inline constexpr const char kSpeedAdaptive[] = "speed_adaptive";

namespace speed_adaptive {
inline constexpr const char kEnableSpeedAdaptive[] = "enable_speed_adaptive";
inline constexpr const char kMinIntensity[] = "min_intensity";
inline constexpr const char kMaxIntensity[] = "max_intensity";
inline constexpr const char kSensitivity[] = "sensitivity";
} // namespace speed_adaptive

namespace mouse_companion {
inline constexpr const char kEnabled[] = "enabled";
inline constexpr const char kModelPath[] = "model_path";
inline constexpr const char kActionLibraryPath[] = "action_library_path";
inline constexpr const char kAppearanceProfilePath[] = "appearance_profile_path";
inline constexpr const char kPositionMode[] = "position_mode";
inline constexpr const char kEdgeClampMode[] = "edge_clamp_mode";
inline constexpr const char kSizePx[] = "size_px";
inline constexpr const char kOffsetX[] = "offset_x";
inline constexpr const char kOffsetY[] = "offset_y";
inline constexpr const char kAbsoluteX[] = "absolute_x";
inline constexpr const char kAbsoluteY[] = "absolute_y";
inline constexpr const char kTargetMonitor[] = "target_monitor";
inline constexpr const char kPressLiftPx[] = "press_lift_px";
inline constexpr const char kSmoothingPercent[] = "smoothing_percent";
inline constexpr const char kFollowThresholdPx[] = "follow_threshold_px";
inline constexpr const char kReleaseHoldMs[] = "release_hold_ms";
inline constexpr const char kClickStreakBreakMs[] = "click_streak_break_ms";
inline constexpr const char kHeadTintPerClick[] = "head_tint_per_click";
inline constexpr const char kHeadTintMax[] = "head_tint_max";
inline constexpr const char kHeadTintDecayPerSecond[] = "head_tint_decay_per_second";
inline constexpr const char kRendererBackendPreferenceSource[] = "renderer_backend_preference_source";
inline constexpr const char kRendererBackendPreferenceName[] = "renderer_backend_preference_name";
inline constexpr const char kUseTestProfile[] = "use_test_profile";
inline constexpr const char kTestPressLiftPx[] = "test_press_lift_px";
inline constexpr const char kTestSmoothingPercent[] = "test_smoothing_percent";
inline constexpr const char kTestClickStreakBreakMs[] = "test_click_streak_break_ms";
inline constexpr const char kTestHeadTintPerClick[] = "test_head_tint_per_click";
inline constexpr const char kTestHeadTintMax[] = "test_head_tint_max";
inline constexpr const char kTestHeadTintDecayPerSecond[] = "test_head_tint_decay_per_second";
} // namespace mouse_companion

} // namespace mousefx::config_json::keys
