#pragma once

#include "MouseFx/Interfaces/IMouseEffect.h"
#include "MouseFx/Core/Config/EffectConfig.h"
#include "MouseFx/Core/Effects/TrailEffectCompute.h"
#include "MouseFx/Interfaces/ITrailEffectFallback.h"
#include <memory>

namespace mousefx {

class AppController;
class ITrailRenderer;
class TrailOverlayLayer;

class TrailEffect final : public IMouseEffect {
public:
    TrailEffect(const std::string& themeName, const std::string& type, const EffectConfig& config, AppController* controller = nullptr);
    ~TrailEffect() override;

    EffectCategory Category() const override { return EffectCategory::Trail; }
    const char* TypeName() const override { return type_.c_str(); }

    bool Initialize() override;
    void Shutdown() override;
    void OnMouseMove(const ScreenPoint& pt) override;

private:
    std::unique_ptr<ITrailRenderer> CreateRenderer() const;

    std::unique_ptr<ITrailEffectFallback> fallback_;
    TrailOverlayLayer* hostLayer_ = nullptr;
    std::string type_;
    TrailEffectProfile computeProfile_{};
    TrailEffectThrottleProfile throttleProfile_{};
    ScreenPoint lastPoint_{};
    bool hasLastPoint_ = false;
    uint64_t lastEmitTickMs_ = 0;
    int durationMs_ = 350;
    int maxPoints_ = 40;
    float lineWidth_ = 4.0f;
    TrailRendererParamsConfig params_{};
    bool isChromatic_ = false;
    AppController* controller_ = nullptr;
};

} // namespace mousefx
