#include "pch.h"

#include "AppController.h"

#include "MouseFx/Core/Config/ConfigPathResolver.h"
#include "MouseFx/Core/Automation/AppScopeUtils.h"
#include "MouseFx/Core/Config/EffectConfigInternal.h"
#include "MouseFx/Core/Control/EffectFactory.h"
#include "MouseFx/Effects/HoldRouteCatalog.h"
#include "MouseFx/Renderers/Hold/Presentation/QuantumHaloPresenterSelection.h"
#include "MouseFx/Styles/ThemeStyle.h"
#include "MouseFx/Utils/StringUtils.h"

#include <filesystem>
#include <fstream>
#include <sstream>

#if MFX_PLATFORM_WINDOWS
#include <windows.h>
#endif

namespace mousefx {
namespace {

struct ActiveCategoryDescriptor {
    EffectCategory category;
    std::string ActiveEffectConfig::*slot;
    bool themeSensitive = false;
};

constexpr std::array<ActiveCategoryDescriptor, 5> kActiveCategoryDescriptors{{
    {EffectCategory::Click, &ActiveEffectConfig::click, false},
    {EffectCategory::Trail, &ActiveEffectConfig::trail, false},
    {EffectCategory::Scroll, &ActiveEffectConfig::scroll, true},
    {EffectCategory::Hold, &ActiveEffectConfig::hold, true},
    {EffectCategory::Hover, &ActiveEffectConfig::hover, true},
}};

} // namespace

namespace {

#if MFX_PLATFORM_WINDOWS
std::string QueryProcessBaseNameFromWindowHandle(HWND hwnd, DWORD* outPid = nullptr) {
    if (!hwnd || !IsWindow(hwnd)) {
        return {};
    }

    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0) {
        return {};
    }
    if (outPid) {
        *outPid = pid;
    }

    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!process) {
        return {};
    }

    std::wstring fullPath;
    fullPath.resize(1024);
    DWORD size = static_cast<DWORD>(fullPath.size());
    const BOOL ok = QueryFullProcessImageNameW(process, 0, fullPath.data(), &size);
    CloseHandle(process);
    if (!ok || size == 0) {
        return {};
    }

    fullPath.resize(static_cast<size_t>(size));
    const size_t slashPos = fullPath.find_last_of(L"\\/");
    const std::wstring baseName = (slashPos == std::wstring::npos)
        ? fullPath
        : fullPath.substr(slashPos + 1);
    return ToLowerAscii(TrimAscii(Utf16ToUtf8(baseName.c_str())));
}
#endif

} // namespace

void AppController::NotifyGpuFallbackIfNeeded(const std::string& reason) {
    if (gpuFallbackNotifiedThisSession_) return;
    gpuFallbackNotifiedThisSession_ = true;
    // UX decision: do not block runtime with modal dialogs.
    // Fallback status is exposed through Web settings state and local diagnostics.
#ifdef _DEBUG
    std::wstring dbg = L"MouseFx: GPU route fallback detected. reason=";
    dbg += Utf8ToWString(reason);
    dbg += L"\n";
    OutputDebugStringW(dbg.c_str());
#else
    (void)reason;
#endif
}

void AppController::WriteGpuRouteStatusSnapshot(
    EffectCategory category,
    const std::string& requestedType,
    const std::string& effectiveType,
    const std::string& reason) const {
    if (category != EffectCategory::Hold) {
        return;
    }
    const std::wstring diagDir = ResolveLocalDiagDirectory();
    if (diagDir.empty()) return;
    std::error_code ec;
    std::filesystem::create_directories(diagDir, ec);
    if (ec) return;
    const std::filesystem::path file = std::filesystem::path(diagDir) / L"gpu_route_status_auto.json";
    std::ofstream out(file, std::ios::binary | std::ios::trunc);
    if (!out.is_open()) return;
    const std::string requestedNormalized = hold_route::NormalizeHoldEffectTypeAlias(requestedType);
    std::ostringstream ss;
    ss << "{"
       << "\"category\":\"hold\","
       << "\"requested\":\"" << requestedType << "\","
       << "\"requested_normalized\":\"" << requestedNormalized << "\","
       << "\"effective\":\"" << effectiveType << "\","
       << "\"fallback_applied\":" << (requestedNormalized == effectiveType ? "false" : "true") << ","
       << "\"reason\":\"" << reason << "\""
       << "}";
    out << ss.str();
}

void AppController::SetActiveEffectType(EffectCategory category, const std::string& type) {
    if (auto* slot = MutableActiveTypeForCategory(category); slot != nullptr) {
        *slot = type;
    }
}

std::unique_ptr<IMouseEffect> AppController::CreateEffect(EffectCategory category, const std::string& type) {
    return EffectFactory::Create(category, type, config_, this);
}

const std::string* AppController::ActiveTypeForCategory(EffectCategory category) const {
    for (const auto& descriptor : kActiveCategoryDescriptors) {
        if (descriptor.category != category) {
            continue;
        }
        return &(config_.active.*(descriptor.slot));
    }
    return nullptr;
}

std::string* AppController::MutableActiveTypeForCategory(EffectCategory category) {
    for (const auto& descriptor : kActiveCategoryDescriptors) {
        if (descriptor.category != category) {
            continue;
        }
        return &(config_.active.*(descriptor.slot));
    }
    return nullptr;
}

bool AppController::IsActiveEffectEnabled(EffectCategory category) const {
    const std::string* activeType = ActiveTypeForCategory(category);
    return (activeType != nullptr && !activeType->empty() && *activeType != "none");
}

void AppController::ReapplyActiveEffect(EffectCategory category) {
    if (category == EffectCategory::Click) {
        SetEffect(category, ResolveConfiguredClickType());
        return;
    }
    const std::string* activeType = ActiveTypeForCategory(category);
    if (activeType == nullptr) {
        return;
    }
    SetEffect(category, *activeType);
}

std::string AppController::ResolveConfiguredClickType() const {
    if (!config_.active.click.empty()) {
        return config_.active.click;
    }
    if (!config_.defaultEffect.empty()) {
        return config_.defaultEffect;
    }
    return "ripple";
}

void AppController::ApplyConfiguredEffects() {
    for (const auto& descriptor : kActiveCategoryDescriptors) {
        const std::string requestedType =
            (descriptor.category == EffectCategory::Click)
                ? ResolveConfiguredClickType()
                : (config_.active.*(descriptor.slot));
        SetEffect(descriptor.category, requestedType);
    }
}

bool AppController::NormalizeActiveEffectTypes() {
    bool normalizedChanged = false;
    for (const auto& descriptor : kActiveCategoryDescriptors) {
        std::string& slot = config_.active.*(descriptor.slot);
        std::string reason;
        const std::string effective = ResolveRuntimeEffectType(descriptor.category, slot, &reason);
        if (slot == effective) {
            continue;
        }
        slot = effective;
        normalizedChanged = true;
    }
    return normalizedChanged;
}

bool AppController::NormalizeConfiguredThemeName() {
    const std::string resolvedTheme = ResolveRuntimeThemeName(config_.theme);
    if (resolvedTheme.empty() || config_.theme == resolvedTheme) {
        return false;
    }
    config_.theme = resolvedTheme;
    return true;
}

void AppController::SetEffect(EffectCategory category, const std::string& type) {
    size_t idx = static_cast<size_t>(category);
    if (idx >= kCategoryCount) return;

    std::string fallbackReason;
    const std::string requestedNormalized =
        (category == EffectCategory::Hold) ? hold_route::NormalizeHoldEffectTypeAlias(type) : type;
    const std::string effectiveType = ResolveRuntimeEffectType(category, type, &fallbackReason);
    if (!fallbackReason.empty() && effectiveType != requestedNormalized) {
        NotifyGpuFallbackIfNeeded(fallbackReason);
    }
    WriteGpuRouteStatusSnapshot(category, type, effectiveType, fallbackReason);

    // Shutdown existing effect for this category
    if (effects_[idx]) {
        effects_[idx]->Shutdown();
        effects_[idx].reset();
    }

    // Create and initialize new effect
    effects_[idx] = CreateEffect(category, effectiveType);
    if (effects_[idx] && !vmEffectsSuppressed_) {
        effects_[idx]->Initialize();
    }

#ifdef _DEBUG
    wchar_t buf[256]{};
    wsprintfW(buf, L"MouseFx: SetEffect category=%hs type=%hs\n",
              CategoryToString(category), effectiveType.c_str());
    OutputDebugStringW(buf);
#endif
}

void AppController::ClearEffect(EffectCategory category) {
    SetEffect(category, "none");
}

void AppController::SetTheme(const std::string& theme) {
    if (theme.empty()) return;
    const std::string resolvedTheme = ResolveRuntimeThemeName(theme);
    if (resolvedTheme.empty()) {
        return;
    }
    if (config_.theme == resolvedTheme) {
        return;
    }
    config_.theme = resolvedTheme;
    // Re-create themed effects to pick up new palette.
    for (const auto& descriptor : kActiveCategoryDescriptors) {
        if (!descriptor.themeSensitive) {
            continue;
        }
        ReapplyActiveEffect(descriptor.category);
    }
    PersistConfig();
}

void AppController::SetHoldFollowMode(const std::string& mode) {
    const std::string normalized = config_internal::NormalizeHoldFollowMode(mode);
    if (config_.holdFollowMode == normalized) return;
    config_.holdFollowMode = normalized;
    PersistConfig();
    if (IsActiveEffectEnabled(EffectCategory::Hold)) {
        ReapplyActiveEffect(EffectCategory::Hold);
    }
}

void AppController::SetHoldPresenterBackend(const std::string& backend) {
    const std::string normalized = config_internal::NormalizeHoldPresenterBackend(backend);
    if (config_.holdPresenterBackend == normalized) {
        return;
    }
    config_.holdPresenterBackend = normalized;
    QuantumHaloPresenterSelection::SetConfiguredBackendPreference(config_.holdPresenterBackend);
    PersistConfig();
    if (IsActiveEffectEnabled(EffectCategory::Hold)) {
        ReapplyActiveEffect(EffectCategory::Hold);
    }
}

void AppController::SetEffectsBlacklistApps(const std::vector<std::string>& apps) {
    const std::vector<std::string> normalized =
        config_internal::SanitizeEffectsBlacklistApps(apps);
    if (config_.effectsBlacklistApps == normalized) {
        return;
    }
    config_.effectsBlacklistApps = normalized;
    PersistConfig();
}

bool AppController::IsProcessBlockedByEffectsBlacklist(const std::string& processBaseName) const {
    if (config_.effectsBlacklistApps.empty()) {
        return false;
    }
    if (processBaseName.empty()) {
        return false;
    }
    for (const auto& blocked : config_.effectsBlacklistApps) {
        if (automation_scope::IsSameProcessName(blocked, processBaseName)) {
            return true;
        }
    }
    return false;
}

bool AppController::IsEffectsBlockedByAppBlacklist() {
    return IsProcessBlockedByEffectsBlacklist(CurrentForegroundProcessBaseName());
}

std::string AppController::ProcessBaseNameForScreenPoint(const ScreenPoint& pt) const {
#if MFX_PLATFORM_WINDOWS
    POINT nativePt{};
    nativePt.x = pt.x;
    nativePt.y = pt.y;
    HWND hwnd = WindowFromPoint(nativePt);
    if (hwnd && IsWindow(hwnd)) {
        HWND root = GetAncestor(hwnd, GA_ROOTOWNER);
        if (root && IsWindow(root)) {
            hwnd = root;
        }
        DWORD pid = 0;
        const std::string processBaseName = QueryProcessBaseNameFromWindowHandle(hwnd, &pid);
        if (!processBaseName.empty() && pid != GetCurrentProcessId()) {
            return processBaseName;
        }
    }
#else
    (void)pt;
#endif
    return CurrentForegroundProcessBaseName();
}

bool AppController::IsEffectsBlockedByAppBlacklistAtPoint(const ScreenPoint& pt) const {
    return IsProcessBlockedByEffectsBlacklist(ProcessBaseNameForScreenPoint(pt));
}

IMouseEffect* AppController::GetEffect(EffectCategory category) const {
    size_t idx = static_cast<size_t>(category);
    if (idx >= kCategoryCount) return nullptr;
    return effects_[idx].get();
}

} // namespace mousefx
