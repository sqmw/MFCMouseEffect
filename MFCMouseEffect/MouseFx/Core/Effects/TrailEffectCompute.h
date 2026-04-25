#pragma once

#include "MouseFx/Core/Protocol/InputTypes.h"

#include <cstdint>
#include <string>

namespace mousefx {

struct TrailEffectTypeTempoProfile {
    double durationScale = 1.0;
    double sizeScale = 1.0;
};

struct TrailEffectTypeColorProfile {
    uint32_t fillArgb = 0;
    uint32_t strokeArgb = 0;
};

struct TrailEffectProfile {
    int normalSizePx = 64;
    int particleSizePx = 48;
    double lineWidthPx = 4.0;
    double durationSec = 0.22;
    int closePaddingMs = 40;
    double baseOpacity = 0.95;
    TrailEffectTypeColorProfile line{};
    TrailEffectTypeColorProfile streamer{};
    TrailEffectTypeColorProfile electric{};
    TrailEffectTypeColorProfile meteor{};
    TrailEffectTypeColorProfile tubes{};
    TrailEffectTypeColorProfile particle{};
    TrailEffectTypeTempoProfile lineTempo{};
    TrailEffectTypeTempoProfile streamerTempo{};
    TrailEffectTypeTempoProfile electricTempo{};
    TrailEffectTypeTempoProfile meteorTempo{};
    TrailEffectTypeTempoProfile tubesTempo{};
    TrailEffectTypeTempoProfile particleTempo{};
};

struct TrailEffectThrottleProfile {
    uint64_t minIntervalMs = 18;
    double minDistancePx = 8.0;
};

struct TrailEffectRenderCommand {
    bool emit = false;
    ScreenPoint overlayPoint{};
    std::string normalizedType = "line";
    bool tubesMode = false;
    bool particleMode = false;
    bool glowMode = false;
    double deltaX = 0.0;
    double deltaY = 0.0;
    double speedPx = 0.0;
    double intensity = 0.0;
    int sizePx = 64;
    double lineWidthPx = 0.0;
    double durationSec = 0.22;
    int closeAfterMs = 40;
    double baseOpacity = 0.95;
    uint32_t fillArgb = 0;
    uint32_t strokeArgb = 0;
};

struct TrailEffectEmissionResult {
    bool shouldEmit = false;
    double deltaX = 0.0;
    double deltaY = 0.0;
    double distancePx = 0.0;
};

std::string NormalizeTrailEffectType(const std::string& effectType);
TrailEffectEmissionResult ComputeTrailEffectEmission(
    const ScreenPoint& currentPoint,
    const ScreenPoint& lastPoint,
    uint64_t nowMs,
    uint64_t lastEmitTickMs,
    const TrailEffectThrottleProfile& throttleProfile);
TrailEffectRenderCommand ComputeTrailEffectRenderCommand(
    const ScreenPoint& overlayPoint,
    double deltaX,
    double deltaY,
    const std::string& effectType,
    const TrailEffectProfile& profile,
    double speedAdaptiveIntensity = 1.0);

} // namespace mousefx
