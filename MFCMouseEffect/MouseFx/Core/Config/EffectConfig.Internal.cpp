#include "pch.h"
#include "EffectConfigInternal.h"

#include "MouseFx/Core/Automation/AppScopeUtils.h"
#include "MouseFx/Core/Automation/TriggerChainUtils.h"
#include "MouseFx/Utils/MathUtils.h"
#include "MouseFx/Utils/StringUtils.h"

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <cstdint>

namespace mousefx::config_internal {

std::string ArgbToHex(Argb color) {
    std::ostringstream ss;
    ss << '#' << std::uppercase << std::setfill('0') << std::hex << std::setw(8) << color.value;
    return ss.str();
}

std::string WStringToUtf8(const std::wstring& ws) {
    return Utf16ToUtf8(ws.c_str());
}

std::string NormalizeHoldPresenterBackend(std::string backend) {
    backend = ToLowerAscii(TrimAscii(backend));
    if (backend.empty()) {
        return "auto";
    }
    return backend;
}

std::vector<std::string> SanitizeEffectsBlacklistApps(std::vector<std::string> apps) {
    std::vector<std::string> out;
    out.reserve(apps.size());
    for (std::string& app : apps) {
        const std::string normalized = automation_scope::NormalizeProcessName(std::move(app));
        if (normalized.empty()) {
            continue;
        }
        bool duplicate = false;
        for (const std::string& existing : out) {
            if (automation_scope::IsSameProcessName(existing, normalized)) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            out.push_back(normalized);
        }
    }
    return out;
}

int SanitizeOverlayTargetFps(int targetFps) {
    return ClampInt(targetFps, 0, 360);
}

EffectSizeScaleConfig SanitizeEffectSizeScaleConfig(EffectSizeScaleConfig scales) {
    scales.click = ClampInt(scales.click, 50, 200);
    scales.trail = ClampInt(scales.trail, 50, 200);
    scales.scroll = ClampInt(scales.scroll, 50, 200);
    scales.hold = ClampInt(scales.hold, 50, 200);
    scales.hover = ClampInt(scales.hover, 50, 200);
    return scales;
}

namespace {

constexpr uint32_t kAutomationActionMaxDelayMs = 60000;

std::string NormalizeEffectConflictMode(std::string value, const char* onlyValue, const char* otherValue, const char* fallback) {
    value = ToLowerAscii(TrimAscii(value));
    std::replace(value.begin(), value.end(), '-', '_');
    std::replace(value.begin(), value.end(), ' ', '_');
    if ((onlyValue && value == onlyValue) ||
        (otherValue && value == otherValue) ||
        value == "blend") {
        return value;
    }
    if (value == "other_only" && otherValue) {
        return otherValue;
    }
    return fallback ? std::string(fallback) : std::string("hold_only");
}

} // namespace

EffectConflictPolicyConfig SanitizeEffectConflictPolicyConfig(EffectConflictPolicyConfig policy) {
    policy.holdMovePolicy = NormalizeEffectConflictMode(
        std::move(policy.holdMovePolicy),
        "hold_only",
        "move_only",
        "hold_only");
    return policy;
}

TrailHistoryProfile SanitizeTrailHistoryProfile(TrailHistoryProfile profile) {
    if (profile.durationMs < 80) {
        profile.durationMs = 80;
    }
    if (profile.durationMs > 2000) {
        profile.durationMs = 2000;
    }
    if (profile.maxPoints < 2) {
        profile.maxPoints = 2;
    }
    if (profile.maxPoints > 240) {
        profile.maxPoints = 240;
    }
    return profile;
}

TrailRendererParamsConfig SanitizeTrailParams(TrailRendererParamsConfig params) {
    params.streamer.glowWidthScale = ClampFloat(params.streamer.glowWidthScale, 0.5f, 4.0f);
    params.streamer.coreWidthScale = ClampFloat(params.streamer.coreWidthScale, 0.2f, 2.0f);
    params.streamer.headPower = ClampFloat(params.streamer.headPower, 0.8f, 3.0f);

    params.electric.amplitudeScale = ClampFloat(params.electric.amplitudeScale, 0.2f, 3.0f);
    params.electric.forkChance = ClampFloat(params.electric.forkChance, 0.0f, 0.5f);

    params.meteor.sparkRateScale = ClampFloat(params.meteor.sparkRateScale, 0.2f, 4.0f);
    params.meteor.sparkSpeedScale = ClampFloat(params.meteor.sparkSpeedScale, 0.2f, 4.0f);

    if (params.idleFade.startMs < 0) {
        params.idleFade.startMs = 0;
    }
    if (params.idleFade.endMs < 0) {
        params.idleFade.endMs = 0;
    }
    if (params.idleFade.startMs > 3000) {
        params.idleFade.startMs = 3000;
    }
    if (params.idleFade.endMs > 6000) {
        params.idleFade.endMs = 6000;
    }

    return params;
}

MouseCompanionConfig SanitizeMouseCompanionConfig(MouseCompanionConfig config) {
    config.modelPath = TrimAscii(config.modelPath);
    if (config.modelPath.empty()) {
        config.modelPath = "MFCMouseEffect/Assets/Pet3D/source/pet-main.glb";
    }
    config.actionLibraryPath = TrimAscii(config.actionLibraryPath);
    if (config.actionLibraryPath.empty()) {
        config.actionLibraryPath = "MFCMouseEffect/Assets/Pet3D/source/pet-actions.json";
    }
    config.appearanceProfilePath = TrimAscii(config.appearanceProfilePath);
    if (config.appearanceProfilePath.empty()) {
        config.appearanceProfilePath = "MFCMouseEffect/Assets/Pet3D/source/pet-appearance.json";
    }
    config.positionMode = ToLowerAscii(TrimAscii(config.positionMode));
    if (config.positionMode != "relative" &&
        config.positionMode != "absolute" &&
        config.positionMode != "follow" &&
        config.positionMode != "fixed_bottom_left") {
        config.positionMode = "fixed_bottom_left";
    }
    config.edgeClampMode = ToLowerAscii(TrimAscii(config.edgeClampMode));
    if (config.edgeClampMode != "strict" &&
        config.edgeClampMode != "soft" &&
        config.edgeClampMode != "free") {
        config.edgeClampMode = "soft";
    }
    config.sizePx = ClampInt(config.sizePx, 48, 360);
    config.offsetX = ClampInt(config.offsetX, -1200, 1200);
    config.offsetY = ClampInt(config.offsetY, -1200, 1200);
    config.absoluteX = ClampInt(config.absoluteX, -20000, 20000);
    config.absoluteY = ClampInt(config.absoluteY, -20000, 20000);
    config.targetMonitor = ToLowerAscii(TrimAscii(config.targetMonitor));
    if (config.targetMonitor.empty()) {
        config.targetMonitor = "cursor";
    }
    config.pressLiftPx = ClampInt(config.pressLiftPx, 0, 240);
    config.smoothingPercent = ClampInt(config.smoothingPercent, 0, 95);
    config.followThresholdPx = ClampInt(config.followThresholdPx, 0, 32);
    config.releaseHoldMs = ClampInt(config.releaseHoldMs, 0, 800);
    config.clickStreakBreakMs = ClampInt(config.clickStreakBreakMs, 120, 3000);
    config.headTintPerClick = std::clamp(config.headTintPerClick, 0.01, 1.0);
    config.headTintMax = std::clamp(config.headTintMax, config.headTintPerClick, 1.0);
    config.headTintDecayPerSecond = std::clamp(config.headTintDecayPerSecond, 0.05, 4.0);
    config.rendererBackendPreferenceSource = TrimAscii(config.rendererBackendPreferenceSource);
    config.rendererBackendPreferenceName = TrimAscii(config.rendererBackendPreferenceName);
    config.testPressLiftPx = ClampInt(config.testPressLiftPx, 0, 320);
    config.testSmoothingPercent = ClampInt(config.testSmoothingPercent, 0, 95);
    config.testClickStreakBreakMs = ClampInt(config.testClickStreakBreakMs, 120, 3000);
    config.testHeadTintPerClick = std::clamp(config.testHeadTintPerClick, 0.01, 1.0);
    config.testHeadTintMax = std::clamp(config.testHeadTintMax, config.testHeadTintPerClick, 1.0);
    config.testHeadTintDecayPerSecond = std::clamp(config.testHeadTintDecayPerSecond, 0.05, 4.0);
    return config;
}

InputIndicatorConfig SanitizeInputIndicatorConfig(InputIndicatorConfig config) {
    config.cursorDecoration.pluginId = ToLowerAscii(TrimAscii(config.cursorDecoration.pluginId));
    if (config.cursorDecoration.pluginId == "ring") {
        config.cursorDecoration.pluginId = "focus_ring";
    } else if (config.cursorDecoration.pluginId == "orb") {
        config.cursorDecoration.pluginId = "soft_orb";
    }
    if (config.cursorDecoration.pluginId != "focus_ring" &&
        config.cursorDecoration.pluginId != "signal_ring" &&
        config.cursorDecoration.pluginId != "soft_orb" &&
        config.cursorDecoration.pluginId != "halo_orb") {
        config.cursorDecoration.pluginId = "focus_ring";
    }
    config.cursorDecoration.colorHex = TrimAscii(config.cursorDecoration.colorHex);
    if (config.cursorDecoration.colorHex.size() != 7 ||
        config.cursorDecoration.colorHex[0] != '#' ||
        !std::all_of(config.cursorDecoration.colorHex.begin() + 1,
                     config.cursorDecoration.colorHex.end(),
                     [](unsigned char ch) { return std::isxdigit(ch) != 0; })) {
        config.cursorDecoration.colorHex = "#ff5a5a";
    } else {
        std::transform(
            config.cursorDecoration.colorHex.begin(),
            config.cursorDecoration.colorHex.end(),
            config.cursorDecoration.colorHex.begin(),
            [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
    }
    config.cursorDecoration.sizePx = ClampInt(config.cursorDecoration.sizePx, 12, 72);
    config.cursorDecoration.alphaPercent = ClampInt(config.cursorDecoration.alphaPercent, 15, 100);

    config.positionMode = (config.positionMode == "absolute") ? "absolute" : "relative";
    config.renderMode = ToLowerAscii(TrimAscii(config.renderMode));
    if (config.renderMode != "native" && config.renderMode != "wasm") {
        config.renderMode = "native";
    }
    config.wasmManifestPath = TrimAscii(config.wasmManifestPath);
    config.offsetX = ClampInt(config.offsetX, -2000, 2000);
    config.offsetY = ClampInt(config.offsetY, -2000, 2000);
    config.absoluteX = ClampInt(config.absoluteX, -20000, 20000);
    config.absoluteY = ClampInt(config.absoluteY, -20000, 20000);

    if (config.keyDisplayMode != "all" &&
        config.keyDisplayMode != "significant" &&
        config.keyDisplayMode != "shortcut") {
        config.keyDisplayMode = "all";
    }
    config.keyLabelLayoutMode = ToLowerAscii(TrimAscii(config.keyLabelLayoutMode));
    if (config.keyLabelLayoutMode != "fixed_font" &&
        config.keyLabelLayoutMode != "fixed_area") {
        config.keyLabelLayoutMode = "fixed_font";
    }

    for (auto& [key, value] : config.perMonitorOverrides) {
        (void)key;
        value.absoluteX = ClampInt(value.absoluteX, -20000, 20000);
        value.absoluteY = ClampInt(value.absoluteY, -20000, 20000);
    }

    config.sizePx = ClampInt(config.sizePx, 40, 200);
    config.durationMs = ClampInt(config.durationMs, 120, 2000);
    return config;
}

namespace {

std::string NormalizeId(std::string value) {
    value = ToLowerAscii(TrimAscii(value));
    std::replace(value.begin(), value.end(), '-', '_');
    std::replace(value.begin(), value.end(), ' ', '_');
    return value;
}

std::string NormalizeMouseActionId(std::string value) {
    value = NormalizeId(std::move(value));
    if (value == "left" || value == "leftclick" || value == "lclick") return "left_click";
    if (value == "right" || value == "rightclick" || value == "rclick") return "right_click";
    if (value == "middle" || value == "middleclick" || value == "mclick") return "middle_click";
    if (value == "wheel_up" || value == "scrollup") return "scroll_up";
    if (value == "wheel_down" || value == "scrolldown") return "scroll_down";
    return value;
}

std::string NormalizeGestureId(std::string value) {
    return NormalizeId(std::move(value));
}

std::string NormalizeAutomationAppScopeToken(std::string value) {
    return automation_scope::NormalizeScopeToken(std::move(value));
}

std::vector<std::string> NormalizeAutomationAppScopes(std::vector<std::string> values) {
    std::vector<std::string> out;
    out.reserve(values.size());

    for (std::string& value : values) {
        const std::string normalized = NormalizeAutomationAppScopeToken(std::move(value));
        if (normalized == "all") {
            return {"all"};
        }

        bool duplicate = (std::find(out.begin(), out.end(), normalized) != out.end());
        if (!duplicate && automation_scope::IsProcessScopeToken(normalized)) {
            const std::string normalizedProcess = automation_scope::ScopeProcessName(normalized);
            for (const std::string& existing : out) {
                if (!automation_scope::IsProcessScopeToken(existing)) {
                    continue;
                }
                if (automation_scope::IsSameProcessName(
                        normalizedProcess,
                        automation_scope::ScopeProcessName(existing))) {
                    duplicate = true;
                    break;
                }
            }
        }

        if (!duplicate) {
            out.push_back(std::move(normalized));
        }
    }

    if (out.empty()) {
        out.push_back("all");
    }
    return out;
}

std::string NormalizeGestureButton(std::string value) {
    value = NormalizeId(std::move(value));
    if (value == "none" || value == "no_button" || value == "nobutton" || value == "no") return "none";
    if (value == "l" || value == "left_button") return "left";
    if (value == "m" || value == "middle_button") return "middle";
    if (value == "r" || value == "right_button") return "right";
    if (value != "left" && value != "middle" && value != "right" && value != "none") {
        return "right";
    }
    return value;
}

std::string NormalizeModifierMode(std::string value) {
    value = NormalizeId(std::move(value));
    if (value == "ignore" || value == "optional") return "any";
    if (value == "off" || value == "plain") return "none";
    if (value == "match" || value == "specified" || value == "require") return "exact";
    if (value != "any" && value != "none" && value != "exact") {
        return "any";
    }
    return value;
}

std::string NormalizeGesturePatternMode(std::string value) {
    value = NormalizeId(std::move(value));
    if (value == "draw" || value == "drawn" || value == "freehand") {
        return "custom";
    }
    if (value != "preset" && value != "custom") {
        return "preset";
    }
    return value;
}

} // namespace

InputAutomationConfig SanitizeInputAutomationConfig(InputAutomationConfig config) {
    auto sanitizeBindingList = [](std::vector<AutomationKeyBinding>* bindings, bool gestureBinding) {
        if (!bindings) {
            return;
        }
        for (AutomationKeyBinding& binding : *bindings) {
            binding.trigger = gestureBinding
                ? automation_chain::NormalizeChainText(binding.trigger, NormalizeGestureId)
                : automation_chain::NormalizeChainText(binding.trigger, NormalizeMouseActionId);
            binding.appScopes = NormalizeAutomationAppScopes(std::move(binding.appScopes));
            binding.gesturePattern.mode = NormalizeGesturePatternMode(std::move(binding.gesturePattern.mode));
            binding.gesturePattern.matchThresholdPercent =
                ClampInt(binding.gesturePattern.matchThresholdPercent, 50, 95);
            if (binding.gesturePattern.mode != "custom") {
                binding.gesturePattern.customPoints.clear();
                binding.gesturePattern.customStrokes.clear();
            } else {
                for (AutomationKeyBinding::GesturePoint& point : binding.gesturePattern.customPoints) {
                    point.x = ClampInt(point.x, 0, 100);
                    point.y = ClampInt(point.y, 0, 100);
                }

                std::vector<std::vector<AutomationKeyBinding::GesturePoint>> normalizedStrokes;
                normalizedStrokes.reserve(binding.gesturePattern.customStrokes.size());
                for (auto& stroke : binding.gesturePattern.customStrokes) {
                    std::vector<AutomationKeyBinding::GesturePoint> normalizedStroke;
                    normalizedStroke.reserve(stroke.size());
                    for (AutomationKeyBinding::GesturePoint point : stroke) {
                        point.x = ClampInt(point.x, 0, 100);
                        point.y = ClampInt(point.y, 0, 100);
                        normalizedStroke.push_back(point);
                    }
                    if (!normalizedStroke.empty()) {
                        normalizedStrokes.push_back(std::move(normalizedStroke));
                    }
                }
                if (normalizedStrokes.empty() && !binding.gesturePattern.customPoints.empty()) {
                    normalizedStrokes.push_back(binding.gesturePattern.customPoints);
                }
                if (!normalizedStrokes.empty()) {
                    std::vector<AutomationKeyBinding::GesturePoint> flattenedPoints;
                    for (const auto& stroke : normalizedStrokes) {
                        flattenedPoints.insert(flattenedPoints.end(), stroke.begin(), stroke.end());
                    }
                    binding.gesturePattern.customStrokes = std::move(normalizedStrokes);
                    binding.gesturePattern.customPoints = std::move(flattenedPoints);
                }
            }
            if (gestureBinding) {
                binding.triggerButton = NormalizeGestureButton(std::move(binding.triggerButton));
            } else {
                binding.triggerButton.clear();
            }
            binding.modifiers.mode = NormalizeModifierMode(std::move(binding.modifiers.mode));
            if (binding.modifiers.mode != "exact") {
                binding.modifiers.primary = false;
                binding.modifiers.shift = false;
                binding.modifiers.alt = false;
            }
            std::vector<AutomationAction> normalizedActions;
            normalizedActions.reserve(binding.actions.size());
            for (AutomationAction& action : binding.actions) {
                action.type = NormalizeId(std::move(action.type));
                if (action.type.empty()) {
                    action.type = "send_shortcut";
                }
                if (action.type == "send_shortcut") {
                    action.shortcut = TrimAscii(action.shortcut);
                    action.url.clear();
                    action.appPath.clear();
                    action.delayMs = 0;
                    if (action.shortcut.empty()) {
                        continue;
                    }
                } else if (action.type == "delay") {
                    action.shortcut.clear();
                    action.url.clear();
                    action.appPath.clear();
                    action.delayMs = std::min<uint32_t>(action.delayMs, kAutomationActionMaxDelayMs);
                    if (action.delayMs == 0) {
                        continue;
                    }
                } else if (action.type == "open_url") {
                    action.shortcut.clear();
                    action.appPath.clear();
                    action.delayMs = 0;
                    action.url = TrimAscii(action.url);
                    if (action.url.empty()) {
                        continue;
                    }
                } else if (action.type == "launch_app") {
                    action.shortcut.clear();
                    action.url.clear();
                    action.delayMs = 0;
                    action.appPath = TrimAscii(action.appPath);
                    if (action.appPath.empty()) {
                        continue;
                    }
                } else {
                    continue;
                }
                normalizedActions.push_back(std::move(action));
                if (normalizedActions.size() >= 16) {
                    break;
                }
            }
            binding.actions = std::move(normalizedActions);
        }
    };

    sanitizeBindingList(&config.mouseMappings, false);
    config.gesture.triggerButton = NormalizeGestureButton(std::move(config.gesture.triggerButton));
    config.gesture.minStrokeDistancePx = ClampInt(config.gesture.minStrokeDistancePx, 10, 4000);
    config.gesture.sampleStepPx = ClampInt(config.gesture.sampleStepPx, 2, 256);
    config.gesture.maxDirections = ClampInt(config.gesture.maxDirections, 1, 8);
    for (AutomationKeyBinding& binding : config.gesture.mappings) {
        if (TrimAscii(binding.triggerButton).empty()) {
            binding.triggerButton = config.gesture.triggerButton;
        }
    }
    sanitizeBindingList(&config.gesture.mappings, true);
    return config;
}

WasmConfig SanitizeWasmConfig(WasmConfig config) {
    config.manifestPath = TrimAscii(config.manifestPath);
    config.manifestPathClick = TrimAscii(config.manifestPathClick);
    config.manifestPathTrail = TrimAscii(config.manifestPathTrail);
    config.manifestPathScroll = TrimAscii(config.manifestPathScroll);
    config.manifestPathHold = TrimAscii(config.manifestPathHold);
    config.manifestPathHover = TrimAscii(config.manifestPathHover);
    config.manifestPathCursorDecoration = TrimAscii(config.manifestPathCursorDecoration);
    config.catalogRootPath = TrimAscii(config.catalogRootPath);
    config.outputBufferBytes = static_cast<uint32_t>(ClampInt(
        static_cast<int>(config.outputBufferBytes),
        1024,
        262144));
    config.maxCommands = static_cast<uint32_t>(ClampInt(
        static_cast<int>(config.maxCommands),
        1,
        2048));
    if (!(config.maxEventExecutionMs > 0.0)) {
        config.maxEventExecutionMs = 1.0;
    }
    if (config.maxEventExecutionMs < 0.1) {
        config.maxEventExecutionMs = 0.1;
    }
    if (config.maxEventExecutionMs > 20.0) {
        config.maxEventExecutionMs = 20.0;
    }
    return config;
}

std::string ReadFileAsUtf8(const std::wstring& path) {
    // std::filesystem::path bridges wstring -> native path on every
    // platform; libc++ has no wstring ifstream constructor (MSVC extension).
    std::ifstream file(std::filesystem::path(path), std::ios::binary);
    if (!file.is_open()) {
        return "";
    }

    std::stringstream ss;
    ss << file.rdbuf();
    std::string raw = ss.str();
    if (raw.empty()) {
        return "";
    }

    if (raw.size() >= 3 &&
        static_cast<unsigned char>(raw[0]) == 0xEF &&
        static_cast<unsigned char>(raw[1]) == 0xBB &&
        static_cast<unsigned char>(raw[2]) == 0xBF) {
        raw = raw.substr(3);
    }

    if (IsValidUtf8(raw)) {
        return raw;
    }

    const std::string utf8 = EnsureUtf8(raw);
    if (utf8.empty()) {
        return raw;
    }
    return utf8;
}

} // namespace mousefx::config_internal
