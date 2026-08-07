#include "pch.h"

#include "MouseFx/Core/Effects/TrailEffectCompute.h"
#include "MouseFx/Utils/StringUtils.h"

#include <algorithm>
#include <cmath>

namespace mousefx {
namespace {

const TrailEffectTypeTempoProfile& ResolveTempoProfile(const std::string& trailType, const TrailEffectProfile& profile) {
    if (trailType == "meteor") return profile.meteorTempo;
    if (trailType == "streamer") return profile.streamerTempo;
    if (trailType == "electric") return profile.electricTempo;
    if (trailType == "tubes") return profile.tubesTempo;
    if (trailType == "particle") return profile.particleTempo;
    return profile.lineTempo;
}

const TrailEffectTypeColorProfile& ResolveColorProfile(const std::string& trailType, const TrailEffectProfile& profile) {
    if (trailType == "meteor") return profile.meteor;
    if (trailType == "streamer") return profile.streamer;
    if (trailType == "electric") return profile.electric;
    if (trailType == "tubes") return profile.tubes;
    if (trailType == "particle") return profile.particle;
    return profile.line;
}

bool ContainsToken(const std::string& value, const char* token) {
    return value.find(token) != std::string::npos;
}

double Clamp01(double value) {
    return std::clamp(value, 0.0, 1.0);
}

double ResolveLineWidthScale(const std::string& trailType) {
    if (trailType == "streamer") {
        return 1.22;
    }
    if (trailType == "meteor") {
        return 1.18;
    }
    if (trailType == "tubes") {
        return 1.35;
    }
    if (trailType == "electric") {
        return 0.95;
    }
    if (trailType == "particle") {
        return 0.82;
    }
    return 1.0;
}

} // namespace

std::string NormalizeTrailEffectType(const std::string& effectType) {
    const std::string lowered = ToLowerAscii(effectType);
    if (lowered.empty()) {
        return "line";
    }
    if (lowered == "none") {
        return "none";
    }
    if (lowered == "scifi" || lowered == "sci-fi" || lowered == "sci_fi") {
        return "tubes";
    }
    if (ContainsToken(lowered, "meteor")) return "meteor";
    if (ContainsToken(lowered, "streamer") || ContainsToken(lowered, "stream") || ContainsToken(lowered, "neon")) {
        return "streamer";
    }
    if (ContainsToken(lowered, "electric") || ContainsToken(lowered, "arc")) return "electric";
    if (ContainsToken(lowered, "tube") || ContainsToken(lowered, "suspension")) return "tubes";
    if (ContainsToken(lowered, "particle") || ContainsToken(lowered, "spark")) return "particle";
    return "line";
}

TrailEffectEmissionResult ComputeTrailEffectEmission(
    const ScreenPoint& currentPoint,
    const ScreenPoint& lastPoint,
    uint64_t nowMs,
    uint64_t lastEmitTickMs,
    const TrailEffectThrottleProfile& throttleProfile) {
    TrailEffectEmissionResult result{};
    result.deltaX = static_cast<double>(currentPoint.x - lastPoint.x);
    result.deltaY = static_cast<double>(currentPoint.y - lastPoint.y);
    result.distancePx = std::sqrt(result.deltaX * result.deltaX + result.deltaY * result.deltaY);
    if (result.distancePx < throttleProfile.minDistancePx) {
        return result;
    }
    if (lastEmitTickMs != 0 && nowMs - lastEmitTickMs < throttleProfile.minIntervalMs) {
        return result;
    }
    result.shouldEmit = true;
    return result;
}

TrailEffectRenderCommand ComputeTrailEffectRenderCommand(
    const ScreenPoint& overlayPoint,
    double deltaX,
    double deltaY,
    const std::string& effectType,
    const TrailEffectProfile& profile,
    double speedAdaptiveIntensity) {
    TrailEffectRenderCommand command{};
    command.emit = true;
    command.overlayPoint = overlayPoint;
    command.normalizedType = NormalizeTrailEffectType(effectType);
    if (command.normalizedType == "none") {
        command.emit = false;
        return command;
    }
    command.tubesMode = (command.normalizedType == "tubes");
    command.particleMode = (command.normalizedType == "particle");
    command.glowMode = (command.normalizedType == "meteor" || command.normalizedType == "streamer");
    command.deltaX = deltaX;
    command.deltaY = deltaY;
    command.speedPx = std::sqrt(deltaX * deltaX + deltaY * deltaY);
    command.intensity = Clamp01(command.speedPx / 24.0);

    const auto& tempo = ResolveTempoProfile(command.normalizedType, profile);
    const auto& color = ResolveColorProfile(command.normalizedType, profile);
    const double baseSize = command.particleMode ? static_cast<double>(profile.particleSizePx)
                                                 : static_cast<double>(profile.normalSizePx);
    const double speedSizeScale = 0.85 + command.intensity * 0.35;
    const double speedDurationScale = 0.90 + command.intensity * 0.25;
    // 应用速度自适应强度
    command.sizePx = static_cast<int>(std::lround(std::clamp(baseSize * tempo.sizeScale * speedSizeScale * speedAdaptiveIntensity, 28.0, 180.0)));
    command.durationSec = std::clamp(profile.durationSec * tempo.durationScale * speedDurationScale, 0.08, 3.0);
    command.closeAfterMs = static_cast<int>(command.durationSec * 1000.0) + profile.closePaddingMs;
    command.baseOpacity = std::clamp(profile.baseOpacity, 0.05, 1.0);
    const double baseLineWidth = std::clamp(profile.lineWidthPx, 1.0, 18.0);
    const double typeLineScale = ResolveLineWidthScale(command.normalizedType);
    const double speedLineScale = (command.normalizedType == "line")
        ? 1.0
        : (0.88 + command.intensity * 0.52);
    // 应用速度自适应强度到线宽
    command.lineWidthPx = std::clamp(baseLineWidth * typeLineScale * speedLineScale * speedAdaptiveIntensity, 1.0, 24.0);
    command.fillArgb = color.fillArgb;
    command.strokeArgb = color.strokeArgb;
    return command;
}

} // namespace mousefx
