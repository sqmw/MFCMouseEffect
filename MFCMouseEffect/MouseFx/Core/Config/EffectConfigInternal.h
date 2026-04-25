#pragma once

#include "EffectConfig.h"

#include <algorithm>
#include <cctype>
#include <string>

namespace mousefx::config_internal {

std::string ReadFileAsUtf8(const std::wstring& path);
std::string WStringToUtf8(const std::wstring& ws);
std::string ArgbToHex(Argb color);

inline bool TryNormalizeHoldFollowMode(const std::string& mode, std::string* outMode) {
    if (!outMode) {
        return false;
    }

    const auto isAsciiSpace = [](unsigned char ch) {
        return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f' || ch == '\v';
    };
    size_t start = 0;
    while (start < mode.size() && isAsciiSpace(static_cast<unsigned char>(mode[start]))) {
        ++start;
    }
    size_t end = mode.size();
    while (end > start && isAsciiSpace(static_cast<unsigned char>(mode[end - 1]))) {
        --end;
    }

    std::string normalized = mode.substr(start, end - start);
    std::transform(normalized.begin(), normalized.end(), normalized.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    std::replace(normalized.begin(), normalized.end(), '-', '_');
    std::replace(normalized.begin(), normalized.end(), ' ', '_');

    if (normalized == "precise" ||
        normalized == "low_latency" ||
        normalized == "latency_first" ||
        normalized == "raw") {
        *outMode = "precise";
        return true;
    }
    if (normalized == "smooth" ||
        normalized == "cursor_priority" ||
        normalized == "cursor_first" ||
        normalized == "recommended") {
        *outMode = "smooth";
        return true;
    }
    if (normalized == "efficient" ||
        normalized == "performance_first" ||
        normalized == "cpu_saver" ||
        normalized == "powersave" ||
        normalized == "power_save") {
        *outMode = "efficient";
        return true;
    }

    return false;
}

inline std::string NormalizeHoldFollowMode(std::string mode) {
    std::string normalized = "smooth";
    if (TryNormalizeHoldFollowMode(mode, &normalized)) {
        return normalized;
    }
    return "smooth";
}
std::string NormalizeHoldPresenterBackend(std::string backend);
std::vector<std::string> SanitizeEffectsBlacklistApps(std::vector<std::string> apps);
int SanitizeOverlayTargetFps(int targetFps);
EffectSizeScaleConfig SanitizeEffectSizeScaleConfig(EffectSizeScaleConfig scales);
EffectConflictPolicyConfig SanitizeEffectConflictPolicyConfig(EffectConflictPolicyConfig policy);
TrailHistoryProfile SanitizeTrailHistoryProfile(TrailHistoryProfile profile);
TrailRendererParamsConfig SanitizeTrailParams(TrailRendererParamsConfig params);
MouseCompanionConfig SanitizeMouseCompanionConfig(MouseCompanionConfig config);
InputIndicatorConfig SanitizeInputIndicatorConfig(InputIndicatorConfig config);
InputAutomationConfig SanitizeInputAutomationConfig(InputAutomationConfig config);
WasmConfig SanitizeWasmConfig(WasmConfig config);
SpeedAdaptiveConfig SanitizeSpeedAdaptiveConfig(SpeedAdaptiveConfig config);

} // namespace mousefx::config_internal
