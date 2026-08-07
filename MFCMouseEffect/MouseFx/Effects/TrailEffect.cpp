#include "pch.h"
#include "TrailEffect.h"
#include "MouseFx/Effects/TrailEffectCommandAdapter.h"
#include "MouseFx/Core/Effects/TrailEffectCompute.h"
#include "MouseFx/Core/Overlay/OverlayHostService.h"
#include "MouseFx/Layers/TrailOverlayLayer.h"
#include "MouseFx/Styles/ThemeStyle.h"
#include "MouseFx/Interfaces/TrailRenderStrategies.h"
#include "MouseFx/Renderers/Trail/TubesRenderer.h"
#include "MouseFx/Renderers/Trail/MeteorRenderer.h"
#include "Platform/PlatformEffectFallbackFactory.h"
#include "MouseFx/Utils/TimeUtils.h"
#include "MouseFx/Core/Control/AppController.h"
#include <algorithm>
#include <cctype>
#include <string>

namespace mousefx {

TrailEffect::TrailEffect(const std::string& themeName, const std::string& type, const EffectConfig& config, AppController* controller)
    : fallback_(platform::CreateTrailEffectFallback()), type_(type), controller_(controller) {
    type_ = NormalizeTrailEffectType(type_);
    isChromatic_ = (ToLowerAscii(themeName) == "chromatic");
    const TrailHistoryProfile history = config.GetTrailHistoryProfile(type_);
    durationMs_ = history.durationMs;
    maxPoints_ = history.maxPoints;
    params_ = config.trailParams;
    lineWidth_ = config.trail.lineWidth;
    computeProfile_ = trail_effect_adapter::BuildTrailProfileFromConfig(config, type_, durationMs_);
    throttleProfile_ = trail_effect_adapter::ResolveTrailThrottleProfile(type_);
}

TrailEffect::~TrailEffect() {
    Shutdown();
}

bool TrailEffect::Initialize() {
    hostLayer_ = OverlayHostService::Instance().AttachTrailLayer(
        CreateRenderer(), durationMs_, maxPoints_, isChromatic_);
    if (hostLayer_) return true;

    if (!fallback_ || !fallback_->Create()) return false;
    fallback_->Configure(isChromatic_, durationMs_, maxPoints_, CreateRenderer());
    return true;
}

void TrailEffect::Shutdown() {
    if (hostLayer_) {
        OverlayHostService::Instance().DetachLayer(hostLayer_);
        hostLayer_ = nullptr;
    }
    if (fallback_) {
        fallback_->Shutdown();
    }
    hasLastPoint_ = false;
    lastEmitTickMs_ = 0;
}

void TrailEffect::OnMouseMove(const ScreenPoint& pt) {
    if (!hasLastPoint_) {
        hasLastPoint_ = true;
        lastPoint_ = pt;
        return;
    }

    const uint64_t nowMs = NowMs();
    const TrailEffectEmissionResult emission = ComputeTrailEffectEmission(
        pt,
        lastPoint_,
        nowMs,
        lastEmitTickMs_,
        throttleProfile_);
    if (!emission.shouldEmit) {
        return;
    }

    // 获取速度自适应强度
    double speedAdaptiveIntensity = 1.0;
    if (controller_) {
        speedAdaptiveIntensity = controller_->GetSpeedAdaptiveIntensity();
    }
    
    const TrailEffectRenderCommand command = ComputeTrailEffectRenderCommand(
        pt,
        emission.deltaX,
        emission.deltaY,
        type_,
        computeProfile_,
        speedAdaptiveIntensity);
    // Keep the anchor at the last emitted point so small moves can
    // accumulate into visible segments instead of being discarded.
    lastPoint_ = pt;
    lastEmitTickMs_ = nowMs;
    if (!command.emit) {
        if (hostLayer_) {
            hostLayer_->Clear();
        }
        return;
    }

    const TrailPoint trailPoint = trail_effect_adapter::BuildTrailPointFromCommand(command, nowMs);
    if (hostLayer_) {
        hostLayer_->AddPoint(trailPoint);
        return;
    }
    if (fallback_) {
        fallback_->AddPoint(trailPoint);
    }
}

std::unique_ptr<ITrailRenderer> TrailEffect::CreateRenderer() const {
    if (type_ == "electric") {
        return std::make_unique<ElectricTrailRenderer>(durationMs_, params_);
    }
    if (type_ == "streamer") {
        return std::make_unique<StreamerTrailRenderer>(durationMs_, params_);
    }
    if (type_ == "tubes" || type_ == "scifi") {
        return std::make_unique<TubesRenderer>();
    }
    if (type_ == "meteor") {
        return std::make_unique<MeteorRenderer>(durationMs_, params_);
    }
    return std::make_unique<LineTrailRenderer>(durationMs_, params_);
}

} // namespace mousefx
