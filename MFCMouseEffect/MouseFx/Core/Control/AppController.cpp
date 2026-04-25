// AppController.cpp

#include "pch.h"

#include "AppController.h"
#include "CommandHandler.h"
#include "DispatchRouter.h"
#include "WasmDispatchFeature.h"
#include "MouseFx/Core/Protocol/MouseFxMessages.h"
#include "MouseFx/Core/Control/NullDispatchMessageHost.h"
#include "MouseFx/Core/Control/NullDispatchMessageCodec.h"
#include "MouseFx/Core/System/NullCursorPositionService.h"
#include "MouseFx/Core/System/NullForegroundProcessService.h"
#include "MouseFx/Core/System/NullForegroundSuppressionService.h"
#include "MouseFx/Core/System/NullKeyboardInjector.h"
#include "MouseFx/Core/System/GdiPlusSession.h"
#include "MouseFx/Core/System/StdMonotonicClockService.h"
#include "MouseFx/Core/Overlay/NullInputIndicatorOverlay.h"
#include "MouseFx/Core/Protocol/JsonLite.h"
#include "MouseFx/Core/Effects/ClickEffectCompute.h"
#include "MouseFx/Core/Effects/HoldEffectCompute.h"
#include "MouseFx/Core/Effects/HoverEffectCompute.h"
#include "MouseFx/Core/Effects/ScrollEffectCompute.h"
#include "MouseFx/Core/Effects/TrailEffectCompute.h"
#include "MouseFx/Core/Wasm/WasmEffectHost.h"
#include "MouseFx/Effects/HoldRouteCatalog.h"
#include "MouseFx/Core/Json/JsonFacade.h"
#include "MouseFx/Utils/MathUtils.h"
#include "MouseFx/Utils/StringUtils.h"
#include "Platform/PlatformControlServicesFactory.h"
#include "Platform/PlatformControlMessageCodecFactory.h"
#include "Platform/PlatformInputServicesFactory.h"
#include "Platform/PlatformOverlayServicesFactory.h"
#include "Platform/PlatformSystemServicesFactory.h"

#include <new>
#include <algorithm>
#include <cctype>
#include <cmath>

namespace mousefx {

using json = nlohmann::json;


AppController::AppController()
    : gdiplus_(std::make_unique<GdiPlusSession>())
    , dispatchMessageHost_(platform::CreateDispatchMessageHost())
    , dispatchMessageCodec_(platform::CreateDispatchMessageCodec())
    , cursorPositionService_(platform::CreateCursorPositionService())
    , monotonicClockService_(platform::CreateMonotonicClockService())
    , foregroundProcessService_(platform::CreateForegroundProcessService())
    , foregroundSuppressionService_(platform::CreateForegroundSuppressionService())
    , hook_(platform::CreateGlobalMouseHook())
    , keyboardInjector_(platform::CreateKeyboardInjector())
    , inputIndicatorOverlay_(platform::CreateInputIndicatorOverlay())
    , commandHandler_(std::make_unique<CommandHandler>(this))
    , dispatchRouter_(std::make_unique<DispatchRouter>(this)) {
    if (!dispatchMessageHost_) {
        dispatchMessageHost_ = std::make_unique<NullDispatchMessageHost>();
    }
    if (!dispatchMessageCodec_) {
        dispatchMessageCodec_ = std::make_unique<NullDispatchMessageCodec>();
    }
    if (!cursorPositionService_) {
        cursorPositionService_ = std::make_unique<NullCursorPositionService>();
    }
    if (!monotonicClockService_) {
        monotonicClockService_ = std::make_unique<StdMonotonicClockService>();
    }
    if (!foregroundProcessService_) {
        foregroundProcessService_ = std::make_unique<NullForegroundProcessService>();
    }
    if (!foregroundSuppressionService_) {
        foregroundSuppressionService_ = std::make_unique<NullForegroundSuppressionService>();
    }
    if (!keyboardInjector_) {
        keyboardInjector_ = std::make_unique<NullKeyboardInjector>();
    }
    shortcutCaptureSession_.SetClockService(monotonicClockService_.get());
    inputAutomationEngine_.SetForegroundProcessService(foregroundProcessService_.get());
    inputAutomationEngine_.SetKeyboardInjector(keyboardInjector_.get());
    inputAutomationEngine_.SetOpenUrlHandler([this](const std::string& url) {
        std::function<bool(const std::string&)> handler;
        {
            std::lock_guard<std::mutex> lock(automationOpenUrlHandlerMutex_);
            handler = automationOpenUrlHandler_;
        }
        return handler && handler(url);
    });
    inputAutomationEngine_.SetLaunchAppHandler([this](const std::string& appPath) {
        std::function<bool(const std::string&)> handler;
        {
            std::lock_guard<std::mutex> lock(automationLaunchAppHandlerMutex_);
            handler = automationLaunchAppHandler_;
        }
        return handler && handler(appPath);
    });
    inputAutomationEngine_.SetDiagnosticsEnabled(runtimeDiagnosticsEnabled_);
    if (!inputIndicatorOverlay_) {
        inputIndicatorOverlay_ = std::make_unique<NullInputIndicatorOverlay>();
    }
    ResetMouseCompanionPluginHosts(config_.mouseCompanion, CurrentTickMs());
    {
        std::lock_guard<std::mutex> guard(mouseCompanionRuntimeStatusMutex_);
        mouseCompanionRuntimeStatus_.runtimePresent = false;
    }
}

AppController::~AppController() {
    Stop();
}

EffectConfig AppController::GetConfigSnapshot() const {
    if (!dispatchMessageHost_ || !dispatchMessageHost_->IsCreated()) {
        return config_;
    }
    if (dispatchMessageHost_->IsOwnerThread()) {
        return config_;
    }

    EffectConfig snapshot{};
    dispatchMessageHost_->SendSync(WM_MFX_GET_CONFIG, 0, reinterpret_cast<intptr_t>(&snapshot));
    return snapshot;
}

void AppController::SetRuntimeDiagnosticsEnabled(bool enabled) {
    runtimeDiagnosticsEnabled_ = enabled;
    inputAutomationEngine_.SetDiagnosticsEnabled(enabled);
}

bool AppController::RuntimeDiagnosticsEnabled() const {
    return runtimeDiagnosticsEnabled_;
}

void AppController::PersistConfig() {
    if (!configDir_.empty()) {
        EffectConfig::Save(configDir_, config_);
    }
}

std::string AppController::ResolveRuntimeEffectType(
    EffectCategory category,
    const std::string& requestedType,
    std::string* outReason) const {
    if (outReason) outReason->clear();

    switch (category) {
    case EffectCategory::Click:
        return NormalizeClickEffectType(requestedType);
    case EffectCategory::Trail:
        return NormalizeTrailEffectType(requestedType);
    case EffectCategory::Scroll:
        return NormalizeScrollEffectType(requestedType);
    case EffectCategory::Hover:
        return NormalizeHoverEffectType(requestedType);
    case EffectCategory::Hold: {
        const std::string requestedNormalized = hold_route::NormalizeHoldEffectTypeAlias(requestedType);
        const std::string normalizedType = NormalizeHoldEffectType(requestedType);
        const char* reason = hold_route::RouteReasonForType(normalizedType);
        if ((reason == nullptr || reason[0] == '\0') && requestedNormalized != normalizedType) {
            reason = hold_route::FallbackReasonForCurrentBuild(requestedNormalized);
        }
        if (outReason && reason && reason[0] != '\0') {
            *outReason = reason;
        }
        return normalizedType;
    }
    default:
        return requestedType;
    }
}

void AppController::OnDispatchActivity(DispatchMessageKind kind, uint32_t timerId) {
    const bool isMouseInputMsg =
        (kind == DispatchMessageKind::Click ||
         kind == DispatchMessageKind::Move ||
         kind == DispatchMessageKind::Scroll ||
         kind == DispatchMessageKind::ButtonDown ||
         kind == DispatchMessageKind::ButtonUp ||
         kind == DispatchMessageKind::Key);
    const bool isStateTimerMsg =
        (kind == DispatchMessageKind::Timer &&
         (timerId == kHoverTimerId ||
          timerId == kHoldTimerId));
    const bool isInputCaptureHealthTimerMsg =
        (kind == DispatchMessageKind::Timer && timerId == kInputCaptureHealthTimerId);
    if (isStateTimerMsg || isInputCaptureHealthTimerMsg) {
        RefreshInputCaptureRuntimeState();
    }
    if (isMouseInputMsg || isStateTimerMsg || isInputCaptureHealthTimerMsg) {
        UpdateVmSuppressionState();
    }

    if (!isMouseInputMsg) {
        return;
    }

    lastInputTime_ = CurrentTickMs();
    if (!hovering_) {
        return;
    }

    bool hoverEndRenderedByWasm = false;
    bool hoverWasmRouteActive = false;
    ScreenPoint hoverPt{};
    if (QueryCursorScreenPoint(&hoverPt)) {
        RememberLastPointerPoint(hoverPt);
    } else if (!TryGetLastPointerPoint(&hoverPt)) {
        hoverPt = ScreenPoint{};
    }
    if (auto* hoverHost = WasmEffectsHostForChannel("hover");
        hoverHost && hoverHost->Enabled() && hoverHost->IsPluginLoaded()) {
        WasmDispatchFeature wasmDispatch{};
        hoverWasmRouteActive = wasmDispatch.RouteHoverEnd(*this, hoverPt, &hoverEndRenderedByWasm);
    }

    hovering_ = false;
    DispatchPetHoverEnd(hoverPt);
    if (!hoverWasmRouteActive || !hoverEndRenderedByWasm) {
        if (auto* effect = GetEffect(EffectCategory::Hover)) {
            effect->OnHoverEnd();
        }
    }
}

#ifdef _DEBUG
void AppController::LogDebugClick(const ClickEvent& ev) {
    if (debugClickCount_ >= 5) {
        return;
    }
    debugClickCount_++;
    wchar_t buf[256]{};
    wsprintfW(buf, L"MouseFx: click received (%u) pt=(%ld,%ld) button=%u\n",
        debugClickCount_, ev.pt.x, ev.pt.y, static_cast<unsigned>(ev.button));
    OutputDebugStringW(buf);
}
#endif

void AppController::HandleCommand(const std::string& jsonCmd) {
    if (!dispatchMessageHost_ || !dispatchMessageHost_->IsCreated()) {
        // Headless/HTTP-host paths may not have a dispatch window. Execute directly
        // so runtime policy and config commands still mutate the active controller.
        commandHandler_->Handle(jsonCmd);
        return;
    }

    // Thread Safety: Marshal to UI thread if we are on a background thread.
    if (!dispatchMessageHost_->IsOwnerThread()) {
        dispatchMessageHost_->SendSync(WM_MFX_EXEC_CMD, 0, reinterpret_cast<intptr_t>(&jsonCmd));
        return;
    }

    commandHandler_->Handle(jsonCmd);
}

intptr_t AppController::OnDispatchMessage(
    uintptr_t sourceHandle,
    uint32_t msg,
    uintptr_t wParam,
    intptr_t lParam) {
    if (!dispatchRouter_ || !dispatchMessageCodec_) {
        return 0;
    }

    const DispatchMessage decoded = dispatchMessageCodec_->Decode(sourceHandle, msg, wParam, lParam);
    bool handled = false;
    const intptr_t routeResult = dispatchRouter_->Route(decoded, &handled);
    if (handled) {
        return routeResult;
    }
    return dispatchMessageCodec_->DefaultResult(sourceHandle, msg, wParam, lParam);
}

void AppController::UpdateMouseSpeed(const ScreenPoint& currentPt) {
    uint64_t now = CurrentTickMs();
    if (lastMouseMoveTime_ > 0) {
        double deltaTime = (now - lastMouseMoveTime_) / 1000.0; // 转换为秒
        if (deltaTime > 0 && deltaTime < 1.0) { // 避免除以零或过大的时间差
            int dx = currentPt.x - lastMouseMovePoint_.x;
            int dy = currentPt.y - lastMouseMovePoint_.y;
            float distance = std::sqrt(dx * dx + dy * dy);
            mouseSpeed_ = distance / static_cast<float>(deltaTime);
            
            // 平滑处理，避免速度突变
            smoothedMouseSpeed_ = smoothedMouseSpeed_ * 0.7f + mouseSpeed_ * 0.3f;
        }
    }
    lastMouseMoveTime_ = now;
    lastMouseMovePoint_ = currentPt;
}

float AppController::GetMouseSpeed() const {
    return smoothedMouseSpeed_;
}

float AppController::GetSpeedAdaptiveIntensity() const {
    if (!config_.speedAdaptive.enableSpeedAdaptive) {
        return 1.0f; // 禁用时返回默认强度
    }
    
    // 计算速度因子（0.0-1.0）
    float speedFactor = std::min(smoothedMouseSpeed_ / 1000.0f, 1.0f); // 假设1000px/s为最大速度
    
    // 应用灵敏度
    speedFactor = std::pow(speedFactor, 1.0f - config_.speedAdaptive.sensitivity);
    
    // 计算最终强度
    float intensity = config_.speedAdaptive.minIntensity + 
                     (config_.speedAdaptive.maxIntensity - config_.speedAdaptive.minIntensity) * speedFactor;
    
    return intensity;
}

} // namespace mousefx
