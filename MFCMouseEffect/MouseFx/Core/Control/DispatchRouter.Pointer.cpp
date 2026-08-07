// DispatchRouter.Pointer.cpp -- pointer/button/timer routing paths.

#include "pch.h"

#include "DispatchRouter.h"

#include "DispatchRouter.Internal.h"
#include "MouseFx/Core/Effects/ScrollEffectCompute.h"
#include "MouseFx/Core/Effects/TrailEffectCompute.h"
#include "MouseFx/Interfaces/IMouseEffect.h"

#include <cstdlib>

namespace mousefx {
namespace {

bool IsHoldInteractionActive(AppController* controller) {
    if (!controller) {
        return false;
    }
    return controller->CurrentHoldDurationMs() >= controller->ActiveHoldDelayMs();
}

std::string HoldMovePolicy(AppController* controller) {
    if (!controller) {
        return "hold_only";
    }
    return controller->Config().effectConflictPolicy.holdMovePolicy;
}

bool ShouldSuppressTrailWhileHold(AppController* controller) {
    if (!controller) {
        return false;
    }
    if (!controller->IsHoldButtonDown()) {
        return false;
    }
    return HoldMovePolicy(controller) == "hold_only";
}

bool ShouldSuppressHoldUpdateWhileMove(AppController* controller) {
    if (!IsHoldInteractionActive(controller)) {
        return false;
    }
    return HoldMovePolicy(controller) == "move_only";
}

bool ShouldUseHoldUpdateTimer(AppController* controller) {
    if (!controller) {
        return false;
    }
    // Stationary hold effects must keep receiving periodic updates in both
    // hold_only and blend modes. move_only remains the only policy that keeps
    // the dedicated hold lane disabled.
    return HoldMovePolicy(controller) != "move_only";
}

bool ShouldSuppressClickAfterHold(AppController* controller) {
    (void)controller;
    return true;
}

bool SyncCursorDecorationBlacklistState(AppController* controller, const ScreenPoint& pt) {
    if (!controller) {
        return false;
    }
    const bool effectsBlockedByAppBlacklist = controller->IsEffectsBlockedByAppBlacklistAtPoint(pt);
    controller->IndicatorOverlay().SetCursorDecorationBlockedByAppBlacklist(
        effectsBlockedByAppBlacklist);
    return effectsBlockedByAppBlacklist;
}

#if MFX_PLATFORM_MACOS
constexpr int kPointerOriginTolerancePx = 6;

bool RepairMacPointerPoint(AppController* controller, ScreenPoint* pt, bool dropUnknownOrigin) {
    if (!controller || !pt) {
        return false;
    }
    if (pt->x != 0 || pt->y != 0) {
        controller->RememberLastPointerPoint(*pt);
        return true;
    }

    ScreenPoint cursor{};
    if (controller->QueryCursorScreenPoint(&cursor) && (cursor.x != 0 || cursor.y != 0)) {
        *pt = cursor;
        controller->RememberLastPointerPoint(*pt);
        return true;
    }

    ScreenPoint cached{};
    if (controller->TryGetLastPointerPoint(&cached)) {
        const bool cachedAwayFromOrigin =
            (std::abs(cached.x) > kPointerOriginTolerancePx) ||
            (std::abs(cached.y) > kPointerOriginTolerancePx);
        if (cachedAwayFromOrigin) {
            *pt = cached;
        }
        controller->RememberLastPointerPoint(*pt);
        return true;
    }

    if (dropUnknownOrigin) {
        return false;
    }
    controller->RememberLastPointerPoint(*pt);
    return true;
}
#endif

} // namespace

intptr_t DispatchRouter::OnMove(const DispatchMessage& message) {
    if (ctrl_->IsVmEffectsSuppressed()) {
        return 0;
    }

    ScreenPoint pt{};
    if (!ctrl_->ConsumeLatestMove(&pt)) {
        pt = dispatch_router_detail::MessagePoint(message);
    }
#if MFX_PLATFORM_MACOS
    if (!RepairMacPointerPoint(ctrl_, &pt, true)) {
        return 0;
    }
#else
    ctrl_->RememberLastPointerPoint(pt);
#endif
    // 更新鼠标速度
    ctrl_->UpdateMouseSpeed(pt);
    const bool effectsBlockedByAppBlacklist = SyncCursorDecorationBlacklistState(ctrl_, pt);
    if (!effectsBlockedByAppBlacklist) {
        ctrl_->IndicatorOverlay().OnMove(pt);
    }

    petFeature_.OnMouseMove(*ctrl_, pt);
    automationFeature_.OnMouseMove(*ctrl_, pt);

    const bool suppressTrailByPolicy = ShouldSuppressTrailWhileHold(ctrl_);
    const bool suppressHoldUpdateByPolicy = ShouldSuppressHoldUpdateWhileMove(ctrl_);

    IMouseEffect* trailEffect = ctrl_->GetEffect(EffectCategory::Trail);
    bool moveRenderedByWasm = false;
    bool moveRouteActive = false;
    if (!effectsBlockedByAppBlacklist && !suppressTrailByPolicy) {
        moveRouteActive = wasmFeature_.RouteMove(*ctrl_, pt, &moveRenderedByWasm);
    }
    if (!effectsBlockedByAppBlacklist &&
        !suppressTrailByPolicy &&
        (!moveRouteActive || !moveRenderedByWasm) &&
        (trailEffect != nullptr)) {
        if (auto* effect = trailEffect) {
            effect->OnMouseMove(pt);
        }
    }

    if (!effectsBlockedByAppBlacklist && !suppressHoldUpdateByPolicy) {
        wasmFeature_.RouteHoldUpdateIfActive(*ctrl_, pt, static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()));
        if (auto* effect = ctrl_->GetEffect(EffectCategory::Hold)) {
            effect->OnHoldUpdate(pt, ctrl_->CurrentHoldDurationMs());
        }
    }
    return 0;
}

intptr_t DispatchRouter::OnScroll(const DispatchMessage& message) {
    if (ctrl_->IsVmEffectsSuppressed()) {
        return 0;
    }

    const short delta = static_cast<short>(message.delta);
    ScreenPoint pt{};
    if (!ctrl_->QueryCursorScreenPoint(&pt)) {
        pt = dispatch_router_detail::MessagePoint(message);
    }
#if MFX_PLATFORM_MACOS
    RepairMacPointerPoint(ctrl_, &pt, false);
#else
    ctrl_->RememberLastPointerPoint(pt);
#endif

    ScrollEvent ev{};
    ev.pt = pt;
    ev.delta = delta;
    ev.horizontal = message.scrollHorizontal;

    petFeature_.OnScroll(*ctrl_, pt, static_cast<int>(delta));
    automationFeature_.OnScroll(*ctrl_, delta);
    indicatorFeature_.OnScroll(*ctrl_, ev);
    const bool effectsBlockedByAppBlacklist = SyncCursorDecorationBlacklistState(ctrl_, pt);

    IMouseEffect* scrollEffect = ctrl_->GetEffect(EffectCategory::Scroll);
    bool scrollRenderedByWasm = false;
    bool scrollRouteActive = false;
    if (!effectsBlockedByAppBlacklist) {
        scrollRouteActive = wasmFeature_.RouteScroll(*ctrl_, ev, &scrollRenderedByWasm);
    }
    if (!effectsBlockedByAppBlacklist &&
        (!scrollRouteActive || !scrollRenderedByWasm) &&
        (scrollEffect != nullptr)) {
        scrollEffect->OnScroll(ev);
    }
    return 0;
}

intptr_t DispatchRouter::OnButtonDown(const DispatchMessage& message) {
    if (ctrl_->IsVmEffectsSuppressed()) {
        ctrl_->ClearPendingHold();
        return 0;
    }

    const int button = static_cast<int>(message.button);
    ScreenPoint pt{};
    if (!ctrl_->QueryCursorScreenPoint(&pt)) {
        pt = dispatch_router_detail::MessagePoint(message);
    }
#if MFX_PLATFORM_MACOS
    RepairMacPointerPoint(ctrl_, &pt, false);
#else
    ctrl_->RememberLastPointerPoint(pt);
#endif

    petFeature_.OnButtonDown(*ctrl_, pt, button);
    const bool effectsBlockedByAppBlacklist = SyncCursorDecorationBlacklistState(ctrl_, pt);
    ctrl_->BeginHoldTracking(pt, button);
    automationFeature_.OnButtonDown(*ctrl_, pt, button);
    if (!effectsBlockedByAppBlacklist) {
        ctrl_->ArmHoldTimer();
    }

    return 0;
}

intptr_t DispatchRouter::OnButtonUp(const DispatchMessage& message) {
    ctrl_->EndHoldTracking();
    ctrl_->CancelPendingHold();
    ctrl_->DisarmHoldUpdateTimer();

    if (ctrl_->IsVmEffectsSuppressed()) {
        automationFeature_.OnSuppressed(*ctrl_);
        return 0;
    }

    ScreenPoint pt{};
    if (!ctrl_->QueryCursorScreenPoint(&pt)) {
        pt.x = 0;
        pt.y = 0;
    }
#if MFX_PLATFORM_MACOS
    RepairMacPointerPoint(ctrl_, &pt, false);
#else
    ctrl_->RememberLastPointerPoint(pt);
#endif
    petFeature_.OnButtonUp(*ctrl_, pt, static_cast<int>(message.button));
    petFeature_.OnHoldEnd(*ctrl_, pt);
    automationFeature_.OnButtonUp(*ctrl_, pt, static_cast<int>(message.button));
    const bool effectsBlockedByAppBlacklist = SyncCursorDecorationBlacklistState(ctrl_, pt);
    if (!effectsBlockedByAppBlacklist) {
        wasmFeature_.RouteHoldEndIfActive(*ctrl_, pt);
        if (auto* effect = ctrl_->GetEffect(EffectCategory::Hold)) {
            effect->OnHoldEnd();
        }
    }
    return 0;
}

intptr_t DispatchRouter::OnTimer(const DispatchMessage& message) {
    const uintptr_t timerId = static_cast<uintptr_t>(message.timerId);
    if (timerId == AppController::WasmFrameTimerId()) {
        ctrl_->TickPetVisualFrame();
        if (ctrl_->IsVmEffectsSuppressed()) {
            return 0;
        }
        if (ctrl_->IsEffectsBlockedByAppBlacklist()) {
            return 0;
        }
        bool renderedByWasm = false;
        wasmFeature_.RouteFrameTick(*ctrl_, &renderedByWasm);
        return 0;
    }

    if (timerId == AppController::HoverTimerId()) {
        if (ctrl_->IsVmEffectsSuppressed()) {
            return 0;
        }
        if (IsHoldInteractionActive(ctrl_)) {
            return 0;
        }
        ScreenPoint pt{};
        if (!ctrl_->QueryCursorScreenPoint(&pt)) {
            pt = dispatch_router_detail::MessagePoint(message);
        }
        if (ctrl_->TryEnterHover(&pt)) {
            petFeature_.OnHoverStart(*ctrl_, pt);
            if (!SyncCursorDecorationBlacklistState(ctrl_, pt)) {
                bool hoverRenderedByWasm = false;
                const bool hoverRouteActive = wasmFeature_.RouteHoverStart(*ctrl_, pt, &hoverRenderedByWasm);
                if (!hoverRouteActive || !hoverRenderedByWasm) {
                    if (auto* effect = ctrl_->GetEffect(EffectCategory::Hover)) {
                        effect->OnHoverStart(pt);
                    }
                }
            }
        }
        return 0;
    }

    if (timerId == AppController::HoldTimerId()) {
        ctrl_->DisarmHoldTimer();
        if (ctrl_->IsVmEffectsSuppressed()) {
            ctrl_->ClearPendingHold();
            return 0;
        }
        const bool moveOnlyPolicy = (HoldMovePolicy(ctrl_) == "move_only");
        ScreenPoint pt{};
        int button = 0;
        if (ctrl_->ConsumePendingHold(&pt, &button)) {
            ScreenPoint holdStartPt = pt;
            ScreenPoint liveCursorPt{};
            if (ctrl_->QueryCursorScreenPoint(&liveCursorPt)) {
                holdStartPt = liveCursorPt;
            }
#if MFX_PLATFORM_MACOS
            RepairMacPointerPoint(ctrl_, &holdStartPt, false);
#else
            ctrl_->RememberLastPointerPoint(holdStartPt);
#endif
            if (SyncCursorDecorationBlacklistState(ctrl_, holdStartPt)) {
                return 0;
            }
            if (moveOnlyPolicy) {
                // In move-only mode, keep long-press lane disabled so trail
                // rendering is not interrupted by hold start/end churn.
                ctrl_->DisarmHoldUpdateTimer();
                return 0;
            }
            // For hold-enabled policies, start hold lane after delay.
            // move_only policy is handled above and does not enter hold lane.
            bool holdRenderedByWasm = false;
            petFeature_.OnHoldStart(
                *ctrl_,
                holdStartPt,
                button,
                static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()));
            const bool holdRouteActive = wasmFeature_.RouteHoldStart(
                *ctrl_,
                holdStartPt,
                button,
                static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()),
                &holdRenderedByWasm);
            if (!holdRouteActive || !holdRenderedByWasm) {
                if (auto* effect = ctrl_->GetEffect(EffectCategory::Hold)) {
                    effect->OnHoldStart(holdStartPt, button);
                }
            }
            if (ShouldSuppressClickAfterHold(ctrl_)) {
                ctrl_->MarkIgnoreNextClick();
            }
            // Start periodic hold-update timer so the overlay animates
            // even if the cursor is stationary.
            if (ShouldUseHoldUpdateTimer(ctrl_)) {
                ctrl_->ArmHoldUpdateTimer();
            } else {
                ctrl_->DisarmHoldUpdateTimer();
            }
        }
        return 0;
    }

    if (timerId == AppController::HoldUpdateTimerId()) {
        if (!ShouldUseHoldUpdateTimer(ctrl_)) {
            ctrl_->DisarmHoldUpdateTimer();
            return 0;
        }
        // Persistent state for cursor idle detection across timer ticks.
        static ScreenPoint sLastTimerPt{0, 0};
        static int sIdleTicks = 0;

        // Periodic hold overlay update (~60fps) for stationary hold.
        if (!ctrl_->IsHoldButtonDown() || ctrl_->IsVmEffectsSuppressed()) {
            ctrl_->DisarmHoldUpdateTimer();
            sIdleTicks = 0;
            return 0;
        }
        if (!IsHoldInteractionActive(ctrl_)) {
            return 0;
        }
        ScreenPoint pt{};
        if (!ctrl_->QueryCursorScreenPoint(&pt)) {
            pt = dispatch_router_detail::MessagePoint(message);
        }
#if MFX_PLATFORM_MACOS
        RepairMacPointerPoint(ctrl_, &pt, false);
#else
        ctrl_->RememberLastPointerPoint(pt);
#endif
        if (ctrl_->IsEffectsBlockedByAppBlacklistAtPoint(pt)) {
            ctrl_->DisarmHoldUpdateTimer();
            return 0;
        }
        // Track cursor movement across timer ticks.
        const bool cursorMoved =
            (pt.x != sLastTimerPt.x || pt.y != sLastTimerPt.y);
        sLastTimerPt = pt;
        if (cursorMoved) {
            sIdleTicks = 0;
        } else {
            ++sIdleTicks;
        }

        auto* effect = ctrl_->GetEffect(EffectCategory::Hold);
        if (effect && !effect->IsEffectActive()) {
            // Hold was ended (e.g. by move_only policy during movement).
            // Only restart once the cursor has been idle for ~100ms (6 ticks)
            // to prevent create/destroy flicker during active movement.
            constexpr int kIdleTicksBeforeRestart = 6;
            if (sIdleTicks >= kIdleTicksBeforeRestart) {
                const int trackedButton =
                    (ctrl_->HoldTrackingButton() != 0)
                        ? ctrl_->HoldTrackingButton()
                        : static_cast<int>(MouseButton::Left);
                bool holdRenderedByWasm = false;
                petFeature_.OnHoldStart(
                    *ctrl_,
                    pt,
                    trackedButton,
                    static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()));
                const bool holdRouteActive = wasmFeature_.RouteHoldStart(
                    *ctrl_,
                    pt,
                    trackedButton,
                    static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()),
                    &holdRenderedByWasm);
                if (!holdRouteActive || !holdRenderedByWasm) {
                    effect->OnHoldStart(pt, trackedButton);
                }
            }
        }
        petFeature_.OnHoldUpdate(*ctrl_, pt, static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()));
        wasmFeature_.RouteHoldUpdateIfActive(
            *ctrl_, pt, static_cast<uint32_t>(ctrl_->CurrentHoldDurationMs()));
        if (effect) {
            effect->OnHoldUpdate(pt, ctrl_->CurrentHoldDurationMs());
        }
        return 0;
    }

#ifdef _DEBUG
    static constexpr uintptr_t kSelfTestTimerId = 0x4D46;
    if (timerId == kSelfTestTimerId) {
        ctrl_->KillDispatchTimer(kSelfTestTimerId);
        ClickEvent ev{};
        ScreenPoint cursor{};
        if (!ctrl_->QueryCursorScreenPoint(&cursor)) {
            cursor.x = 0;
            cursor.y = 0;
        }
        ev.pt = cursor;
        ev.button = MouseButton::Left;
        if (auto* effect = ctrl_->GetEffect(EffectCategory::Click)) {
            effect->OnClick(ev);
        }
        OutputDebugStringW(L"MouseFx: self-test ripple fired.\n");
        return 0;
    }
#endif

    return 0;
}

} // namespace mousefx
