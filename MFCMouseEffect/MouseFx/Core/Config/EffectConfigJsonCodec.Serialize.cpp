#include "pch.h"
#include "EffectConfigJsonCodec.h"

#include "EffectConfigInternal.h"
#include "EffectConfigJsonKeys.h"
#include "EffectConfigJsonCodecSerializeInternal.h"

namespace mousefx::config_json {

nlohmann::json BuildRootFromConfig(const EffectConfig& config) {
    nlohmann::json root;
    root[keys::kDefaultEffect] = config.defaultEffect;
    root[keys::kTheme] = config.theme;
    root[keys::kThemeCatalogRootPath] = config.themeCatalogRootPath;
    root[keys::kOverlayTargetFps] = config_internal::SanitizeOverlayTargetFps(config.overlayTargetFps);
    root[keys::kUiLanguage] = config.uiLanguage;
    root[keys::kLaunchAtStartup] = config.launchAtStartup;
    root[keys::kHoldFollowMode] = config_internal::NormalizeHoldFollowMode(config.holdFollowMode);
    root[keys::kHoldPresenterBackend] = config_internal::NormalizeHoldPresenterBackend(config.holdPresenterBackend);
    root[keys::kEffectsBlacklistApps] = config_internal::SanitizeEffectsBlacklistApps(config.effectsBlacklistApps);
    root[keys::kTrailStyle] = config.trailStyle;
    root[keys::kInputIndicator] = serialize_internal::BuildInputIndicatorJson(config.inputIndicator);
    root[keys::kAutomation] = serialize_internal::BuildAutomationJson(config.automation);
    root[keys::kWasm] = serialize_internal::BuildWasmJson(config.wasm);
    root[keys::kTrailProfiles] = serialize_internal::BuildTrailProfilesJson(config.trailProfiles);
    root[keys::kTrailParams] = serialize_internal::BuildTrailParamsJson(config.trailParams);
    root[keys::kActiveEffects] = serialize_internal::BuildActiveEffectsJson(config.active);
    const EffectSizeScaleConfig scales = config_internal::SanitizeEffectSizeScaleConfig(config.effectSizeScales);
    root[keys::kEffectSizeScales] = {
        {keys::effect_size_scale::kClick, scales.click},
        {keys::effect_size_scale::kTrail, scales.trail},
        {keys::effect_size_scale::kScroll, scales.scroll},
        {keys::effect_size_scale::kHold, scales.hold},
        {keys::effect_size_scale::kHover, scales.hover},
    };
    const EffectConflictPolicyConfig policy =
        config_internal::SanitizeEffectConflictPolicyConfig(config.effectConflictPolicy);
    root[keys::kEffectConflictPolicy] = {
        {keys::effect_conflict_policy::kHoldMovePolicy, policy.holdMovePolicy},
    };
    const MouseCompanionConfig companion =
        config_internal::SanitizeMouseCompanionConfig(config.mouseCompanion);
    root[keys::kMouseCompanion] = {
        {keys::mouse_companion::kEnabled, companion.enabled},
        {keys::mouse_companion::kModelPath, companion.modelPath},
        {keys::mouse_companion::kActionLibraryPath, companion.actionLibraryPath},
        {keys::mouse_companion::kAppearanceProfilePath, companion.appearanceProfilePath},
        {keys::mouse_companion::kPositionMode, companion.positionMode},
        {keys::mouse_companion::kEdgeClampMode, companion.edgeClampMode},
        {keys::mouse_companion::kSizePx, companion.sizePx},
        {keys::mouse_companion::kOffsetX, companion.offsetX},
        {keys::mouse_companion::kOffsetY, companion.offsetY},
        {keys::mouse_companion::kAbsoluteX, companion.absoluteX},
        {keys::mouse_companion::kAbsoluteY, companion.absoluteY},
        {keys::mouse_companion::kTargetMonitor, companion.targetMonitor},
        {keys::mouse_companion::kPressLiftPx, companion.pressLiftPx},
        {keys::mouse_companion::kSmoothingPercent, companion.smoothingPercent},
        {keys::mouse_companion::kFollowThresholdPx, companion.followThresholdPx},
        {keys::mouse_companion::kReleaseHoldMs, companion.releaseHoldMs},
        {keys::mouse_companion::kClickStreakBreakMs, companion.clickStreakBreakMs},
        {keys::mouse_companion::kHeadTintPerClick, companion.headTintPerClick},
        {keys::mouse_companion::kHeadTintMax, companion.headTintMax},
        {keys::mouse_companion::kHeadTintDecayPerSecond, companion.headTintDecayPerSecond},
        {keys::mouse_companion::kRendererBackendPreferenceSource, companion.rendererBackendPreferenceSource},
        {keys::mouse_companion::kRendererBackendPreferenceName, companion.rendererBackendPreferenceName},
        {keys::mouse_companion::kUseTestProfile, companion.useTestProfile},
        {keys::mouse_companion::kTestPressLiftPx, companion.testPressLiftPx},
        {keys::mouse_companion::kTestSmoothingPercent, companion.testSmoothingPercent},
        {keys::mouse_companion::kTestClickStreakBreakMs, companion.testClickStreakBreakMs},
        {keys::mouse_companion::kTestHeadTintPerClick, companion.testHeadTintPerClick},
        {keys::mouse_companion::kTestHeadTintMax, companion.testHeadTintMax},
        {keys::mouse_companion::kTestHeadTintDecayPerSecond, companion.testHeadTintDecayPerSecond},
    };
    root[keys::kSpeedAdaptive] = {
        {keys::speed_adaptive::kEnableSpeedAdaptive, config.speedAdaptive.enableSpeedAdaptive},
        {keys::speed_adaptive::kMinIntensity, config.speedAdaptive.minIntensity},
        {keys::speed_adaptive::kMaxIntensity, config.speedAdaptive.maxIntensity},
        {keys::speed_adaptive::kSensitivity, config.speedAdaptive.sensitivity},
    };
    root[keys::kEffects] = serialize_internal::BuildEffectsJson(config);
    return root;
}

} // namespace mousefx::config_json
