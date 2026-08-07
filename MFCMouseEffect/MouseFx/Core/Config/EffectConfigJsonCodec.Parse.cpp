#include "pch.h"
#include "EffectConfigJsonCodec.h"

#include "EffectConfigInternal.h"
#include "EffectConfigJsonKeys.h"
#include "EffectConfigJsonCodecParseInternal.h"
#include "MouseFx/Utils/StringUtils.h"

namespace mousefx::config_json {

void ApplyRootToConfig(const nlohmann::json& root, EffectConfig& config) {
    config.defaultEffect = parse_internal::GetOr<std::string>(root, keys::kDefaultEffect, config.defaultEffect);
    config.theme = parse_internal::GetOr<std::string>(root, keys::kTheme, config.theme);
    config.themeCatalogRootPath = TrimAscii(
        parse_internal::GetOr<std::string>(root, keys::kThemeCatalogRootPath, config.themeCatalogRootPath));
    config.overlayTargetFps = config_internal::SanitizeOverlayTargetFps(
        parse_internal::GetOr<int>(root, keys::kOverlayTargetFps, config.overlayTargetFps));
    config.uiLanguage = parse_internal::GetOr<std::string>(root, keys::kUiLanguage, config.uiLanguage);
    config.launchAtStartup = parse_internal::GetOr<bool>(root, keys::kLaunchAtStartup, config.launchAtStartup);
    config.holdFollowMode = config_internal::NormalizeHoldFollowMode(
        parse_internal::GetOr<std::string>(root, keys::kHoldFollowMode, config.holdFollowMode));
    config.holdPresenterBackend = config_internal::NormalizeHoldPresenterBackend(
        parse_internal::GetOr<std::string>(root, keys::kHoldPresenterBackend, config.holdPresenterBackend));
    if (root.contains(keys::kEffectsBlacklistApps) && root[keys::kEffectsBlacklistApps].is_array()) {
        std::vector<std::string> apps;
        for (const auto& item : root[keys::kEffectsBlacklistApps]) {
            if (item.is_string()) {
                apps.push_back(item.get<std::string>());
            }
        }
        config.effectsBlacklistApps = config_internal::SanitizeEffectsBlacklistApps(std::move(apps));
    }
    config.trailStyle = parse_internal::GetOr<std::string>(root, keys::kTrailStyle, config.trailStyle);

    if (root.contains(keys::kActiveEffects) && root[keys::kActiveEffects].is_object()) {
        const auto& active = root[keys::kActiveEffects];
        config.active.click = parse_internal::GetOr<std::string>(active, keys::active::kClick, config.active.click);
        config.active.trail = parse_internal::GetOr<std::string>(active, keys::active::kTrail, config.active.trail);
        config.active.scroll = parse_internal::GetOr<std::string>(active, keys::active::kScroll, config.active.scroll);
        config.active.hover = parse_internal::GetOr<std::string>(active, keys::active::kHover, config.active.hover);
        config.active.hold = parse_internal::GetOr<std::string>(active, keys::active::kHold, config.active.hold);
    }

    if (root.contains(keys::kEffectSizeScales) && root[keys::kEffectSizeScales].is_object()) {
        const auto& scales = root[keys::kEffectSizeScales];
        config.effectSizeScales.click =
            parse_internal::GetOr<int>(scales, keys::effect_size_scale::kClick, config.effectSizeScales.click);
        config.effectSizeScales.trail =
            parse_internal::GetOr<int>(scales, keys::effect_size_scale::kTrail, config.effectSizeScales.trail);
        config.effectSizeScales.scroll =
            parse_internal::GetOr<int>(scales, keys::effect_size_scale::kScroll, config.effectSizeScales.scroll);
        config.effectSizeScales.hold =
            parse_internal::GetOr<int>(scales, keys::effect_size_scale::kHold, config.effectSizeScales.hold);
        config.effectSizeScales.hover =
            parse_internal::GetOr<int>(scales, keys::effect_size_scale::kHover, config.effectSizeScales.hover);
    }
    config.effectSizeScales = config_internal::SanitizeEffectSizeScaleConfig(config.effectSizeScales);

    if (root.contains(keys::kEffectConflictPolicy) && root[keys::kEffectConflictPolicy].is_object()) {
        const auto& policy = root[keys::kEffectConflictPolicy];
        config.effectConflictPolicy.holdMovePolicy = parse_internal::GetOr<std::string>(
            policy,
            keys::effect_conflict_policy::kHoldMovePolicy,
            config.effectConflictPolicy.holdMovePolicy);
        config.effectConflictPolicy.holdMovePolicy = parse_internal::GetOr<std::string>(
            policy,
            keys::effect_conflict_policy::kHoldMoveLegacy,
            config.effectConflictPolicy.holdMovePolicy);
    }
    config.effectConflictPolicy = config_internal::SanitizeEffectConflictPolicyConfig(config.effectConflictPolicy);

    if (root.contains(keys::kSpeedAdaptive) && root[keys::kSpeedAdaptive].is_object()) {
        const auto& speedAdaptive = root[keys::kSpeedAdaptive];
        config.speedAdaptive.enableSpeedAdaptive = parse_internal::GetOr<bool>(
            speedAdaptive,
            keys::speed_adaptive::kEnableSpeedAdaptive,
            config.speedAdaptive.enableSpeedAdaptive);
        config.speedAdaptive.minIntensity = parse_internal::GetOr<float>(
            speedAdaptive,
            keys::speed_adaptive::kMinIntensity,
            config.speedAdaptive.minIntensity);
        config.speedAdaptive.maxIntensity = parse_internal::GetOr<float>(
            speedAdaptive,
            keys::speed_adaptive::kMaxIntensity,
            config.speedAdaptive.maxIntensity);
        config.speedAdaptive.sensitivity = parse_internal::GetOr<float>(
            speedAdaptive,
            keys::speed_adaptive::kSensitivity,
            config.speedAdaptive.sensitivity);
    }
    config.speedAdaptive = config_internal::SanitizeSpeedAdaptiveConfig(config.speedAdaptive);

    if (root.contains(keys::kMouseCompanion) && root[keys::kMouseCompanion].is_object()) {
        const auto& companion = root[keys::kMouseCompanion];
        config.mouseCompanion.enabled = parse_internal::GetOr<bool>(
            companion,
            keys::mouse_companion::kEnabled,
            config.mouseCompanion.enabled);
        config.mouseCompanion.modelPath = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kModelPath,
            config.mouseCompanion.modelPath);
        config.mouseCompanion.actionLibraryPath = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kActionLibraryPath,
            config.mouseCompanion.actionLibraryPath);
        config.mouseCompanion.appearanceProfilePath = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kAppearanceProfilePath,
            config.mouseCompanion.appearanceProfilePath);
        config.mouseCompanion.positionMode = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kPositionMode,
            config.mouseCompanion.positionMode);
        config.mouseCompanion.edgeClampMode = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kEdgeClampMode,
            config.mouseCompanion.edgeClampMode);
        config.mouseCompanion.sizePx = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kSizePx,
            config.mouseCompanion.sizePx);
        config.mouseCompanion.offsetX = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kOffsetX,
            config.mouseCompanion.offsetX);
        config.mouseCompanion.offsetY = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kOffsetY,
            config.mouseCompanion.offsetY);
        config.mouseCompanion.absoluteX = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kAbsoluteX,
            config.mouseCompanion.absoluteX);
        config.mouseCompanion.absoluteY = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kAbsoluteY,
            config.mouseCompanion.absoluteY);
        config.mouseCompanion.targetMonitor = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kTargetMonitor,
            config.mouseCompanion.targetMonitor);
        config.mouseCompanion.pressLiftPx = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kPressLiftPx,
            config.mouseCompanion.pressLiftPx);
        config.mouseCompanion.smoothingPercent = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kSmoothingPercent,
            config.mouseCompanion.smoothingPercent);
        config.mouseCompanion.followThresholdPx = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kFollowThresholdPx,
            config.mouseCompanion.followThresholdPx);
        config.mouseCompanion.releaseHoldMs = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kReleaseHoldMs,
            config.mouseCompanion.releaseHoldMs);
        config.mouseCompanion.clickStreakBreakMs = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kClickStreakBreakMs,
            config.mouseCompanion.clickStreakBreakMs);
        config.mouseCompanion.headTintPerClick = parse_internal::GetOr<double>(
            companion,
            keys::mouse_companion::kHeadTintPerClick,
            config.mouseCompanion.headTintPerClick);
        config.mouseCompanion.headTintMax = parse_internal::GetOr<double>(
            companion,
            keys::mouse_companion::kHeadTintMax,
            config.mouseCompanion.headTintMax);
        config.mouseCompanion.headTintDecayPerSecond = parse_internal::GetOr<double>(
            companion,
            keys::mouse_companion::kHeadTintDecayPerSecond,
            config.mouseCompanion.headTintDecayPerSecond);
        config.mouseCompanion.rendererBackendPreferenceSource = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kRendererBackendPreferenceSource,
            config.mouseCompanion.rendererBackendPreferenceSource);
        config.mouseCompanion.rendererBackendPreferenceName = parse_internal::GetOr<std::string>(
            companion,
            keys::mouse_companion::kRendererBackendPreferenceName,
            config.mouseCompanion.rendererBackendPreferenceName);
        config.mouseCompanion.useTestProfile = parse_internal::GetOr<bool>(
            companion,
            keys::mouse_companion::kUseTestProfile,
            config.mouseCompanion.useTestProfile);
        config.mouseCompanion.testPressLiftPx = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kTestPressLiftPx,
            config.mouseCompanion.testPressLiftPx);
        config.mouseCompanion.testSmoothingPercent = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kTestSmoothingPercent,
            config.mouseCompanion.testSmoothingPercent);
        config.mouseCompanion.testClickStreakBreakMs = parse_internal::GetOr<int>(
            companion,
            keys::mouse_companion::kTestClickStreakBreakMs,
            config.mouseCompanion.testClickStreakBreakMs);
        config.mouseCompanion.testHeadTintPerClick = parse_internal::GetOr<double>(
            companion,
            keys::mouse_companion::kTestHeadTintPerClick,
            config.mouseCompanion.testHeadTintPerClick);
        config.mouseCompanion.testHeadTintMax = parse_internal::GetOr<double>(
            companion,
            keys::mouse_companion::kTestHeadTintMax,
            config.mouseCompanion.testHeadTintMax);
        config.mouseCompanion.testHeadTintDecayPerSecond = parse_internal::GetOr<double>(
            companion,
            keys::mouse_companion::kTestHeadTintDecayPerSecond,
            config.mouseCompanion.testHeadTintDecayPerSecond);
    }
    config.mouseCompanion = config_internal::SanitizeMouseCompanionConfig(config.mouseCompanion);

    parse_internal::ParseInputIndicator(root, config);
    parse_internal::ParseAutomation(root, config);
    parse_internal::ParseWasm(root, config);
    parse_internal::ParseTrailParams(root, config);
    parse_internal::ParseTrailProfiles(root, config);
    parse_internal::ParseEffects(root, config);
}

} // namespace mousefx::config_json
