#include "pch.h"

#include "EffectFactory.h"

#include "Platform/PlatformTarget.h"

#include "MouseFx/Core/Effects/ClickEffectCompute.h"
#include "MouseFx/Core/Effects/HoldEffectCompute.h"
#include "MouseFx/Core/Effects/HoverEffectCompute.h"
#include "MouseFx/Core/Effects/ScrollEffectCompute.h"
#include "MouseFx/Core/Effects/TrailEffectCompute.h"
#if MFX_PLATFORM_WINDOWS
#include "MouseFx/Effects/HoldEffect.h"
#include "MouseFx/Effects/HoverEffect.h"
#include "MouseFx/Effects/IconEffect.h"
#include "MouseFx/Effects/ParticleTrailEffect.h"
#include "MouseFx/Effects/RippleEffect.h"
#include "MouseFx/Effects/ScrollEffect.h"
#include "MouseFx/Effects/TextEffect.h"
#include "MouseFx/Effects/TrailEffect.h"
#elif MFX_PLATFORM_MACOS
#include "Platform/macos/Effects/MacosEffectCreatorRegistry.h"
#endif

#if MFX_PLATFORM_WINDOWS
#include <array>
#include <unordered_map>
#endif

namespace mousefx {

namespace {

#if MFX_PLATFORM_WINDOWS
using EffectCreator = std::unique_ptr<IMouseEffect> (*)(const std::string& type, const EffectConfig& config, AppController* controller);

struct CategoryRegistryEntry {
    std::unordered_map<std::string, EffectCreator> typedCreators{};
    EffectCreator fallbackCreator = nullptr;
};

constexpr size_t CategoryIndex(EffectCategory category) {
    return static_cast<size_t>(category);
}

std::unique_ptr<IMouseEffect> CreateClickRipple(const std::string&, const EffectConfig& config, AppController*) {
    return std::make_unique<RippleEffect>(config.theme, config);
}

std::unique_ptr<IMouseEffect> CreateClickStar(const std::string&, const EffectConfig& config, AppController*) {
    return std::make_unique<IconEffect>(config.theme, config);
}

std::unique_ptr<IMouseEffect> CreateClickText(const std::string&, const EffectConfig& config, AppController*) {
    return std::make_unique<TextEffect>(config.textClick, config.theme);
}

std::unique_ptr<IMouseEffect> CreateTrailParticle(const std::string&, const EffectConfig& config, AppController*) {
    return std::make_unique<ParticleTrailEffect>(config);
}

std::unique_ptr<IMouseEffect> CreateTrailGeneric(const std::string& type, const EffectConfig& config, AppController* controller) {
    return std::make_unique<TrailEffect>(
        config.theme,
        type,
        config,
        controller);
}

std::unique_ptr<IMouseEffect> CreateScroll(const std::string& type, const EffectConfig& config, AppController*) {
    return std::make_unique<ScrollEffect>(config, type);
}

std::unique_ptr<IMouseEffect> CreateHold(const std::string& type, const EffectConfig& config, AppController*) {
    return std::make_unique<HoldEffect>(
        config.theme,
        type,
        config.holdFollowMode,
        config.holdPresenterBackend);
}

std::unique_ptr<IMouseEffect> CreateHover(const std::string& type, const EffectConfig& config, AppController*) {
    return std::make_unique<HoverEffect>(config.theme, type);
}

const std::array<CategoryRegistryEntry, CategoryIndex(EffectCategory::Count)>& RegistryTable() {
    static const std::array<CategoryRegistryEntry, CategoryIndex(EffectCategory::Count)> table = [] {
        std::array<CategoryRegistryEntry, CategoryIndex(EffectCategory::Count)> result{};

        auto& click = result[CategoryIndex(EffectCategory::Click)];
        click.typedCreators.emplace("ripple", &CreateClickRipple);
        click.typedCreators.emplace("star", &CreateClickStar);
        click.typedCreators.emplace("text", &CreateClickText);

        auto& trail = result[CategoryIndex(EffectCategory::Trail)];
        trail.typedCreators.emplace("particle", &CreateTrailParticle);
        trail.fallbackCreator = &CreateTrailGeneric;

        auto& scroll = result[CategoryIndex(EffectCategory::Scroll)];
        scroll.typedCreators.emplace("arrow", &CreateScroll);
        scroll.typedCreators.emplace("helix", &CreateScroll);
        scroll.typedCreators.emplace("twinkle", &CreateScroll);

        auto& hold = result[CategoryIndex(EffectCategory::Hold)];
        hold.fallbackCreator = &CreateHold;

        auto& hover = result[CategoryIndex(EffectCategory::Hover)];
        hover.fallbackCreator = &CreateHover;

        return result;
    }();
    return table;
}
#endif

std::string NormalizeRequestedEffectType(EffectCategory category, const std::string& type) {
    switch (category) {
    case EffectCategory::Click:
        return NormalizeClickEffectType(type);
    case EffectCategory::Trail:
        return NormalizeTrailEffectType(type);
    case EffectCategory::Scroll:
        return NormalizeScrollEffectType(type);
    case EffectCategory::Hold:
        return NormalizeHoldEffectType(type);
    case EffectCategory::Hover:
        return NormalizeHoverEffectType(type);
    default:
        return type;
    }
}

} // namespace

std::unique_ptr<IMouseEffect> EffectFactory::Create(EffectCategory category, const std::string& type, const EffectConfig& config, AppController* controller) {
    if (type == "none" || type.empty()) {
        return nullptr;
    }
    const std::string normalizedType = NormalizeRequestedEffectType(category, type);
    if (normalizedType == "none" || normalizedType.empty()) {
        return nullptr;
    }

#if MFX_PLATFORM_WINDOWS
    const size_t idx = CategoryIndex(category);
    const auto& registryTable = RegistryTable();
    if (idx >= registryTable.size()) {
        return nullptr;
    }
    const auto& categoryRegistry = registryTable[idx];
    if (const auto it = categoryRegistry.typedCreators.find(normalizedType); it != categoryRegistry.typedCreators.end()) {
        return it->second(normalizedType, config, controller);
    }
    if (categoryRegistry.fallbackCreator != nullptr) {
        return categoryRegistry.fallbackCreator(normalizedType, config, controller);
    }

#ifdef _DEBUG
    OutputDebugStringA(("MouseFx: unknown effect type: " + normalizedType + " (raw: " + type + ")\n").c_str());
#endif
    return nullptr;
#elif MFX_PLATFORM_MACOS
    return macos_effect_registry::Create(category, normalizedType, config);
#else
    (void)category;
    (void)type;
    (void)config;
    return nullptr;
#endif
}

} // namespace mousefx
