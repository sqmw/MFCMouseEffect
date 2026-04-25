#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "MouseFx/Core/Control/DispatchMessage.h"
#include "MouseFx/Core/Control/IDispatchMessageHandler.h"
#include "MouseFx/Core/Control/IDispatchMessageHost.h"
#include "MouseFx/Core/Control/IDispatchMessageCodec.h"
#include "MouseFx/Core/System/ICursorPositionService.h"
#include "MouseFx/Core/System/IMonotonicClockService.h"
#include "MouseFx/Core/System/IForegroundProcessService.h"
#include "MouseFx/Core/System/IForegroundSuppressionService.h"
#include "MouseFx/Core/System/IGlobalMouseHook.h"
#include "MouseFx/Core/System/IKeyboardInjector.h"
#include "MouseFx/Core/Overlay/IInputIndicatorOverlay.h"
#include "MouseFx/Core/Control/InputIndicatorWasmDispatchFeature.h"
#include "MouseFx/Core/Control/IPetVisualHost.h"
#include "MouseFx/Core/Control/MouseCompanionPluginHostPhase0.h"
#include "MouseFx/Core/Control/MouseCompanionPluginHostV1.h"
#include "MouseFx/Core/Automation/InputAutomationEngine.h"
#include "MouseFx/Core/Automation/ShortcutCaptureSession.h"
#include "MouseFx/Interfaces/IMouseEffect.h"
#include "MouseFx/Core/Config/EffectConfig.h"

namespace mousefx {

class CommandHandler;
class DispatchRouter;
class GdiPlusSession;
namespace wasm {
class WasmEffectHost;
}

// Owns the subsystem lifecycle: message-only dispatcher, GDI+ init, hook, and effects.
class AppController final : public IDispatchMessageHandler {
public:
    AppController();
    ~AppController();

    AppController(const AppController&) = delete;
    AppController& operator=(const AppController&) = delete;

    enum class StartStage : uint8_t {
        None = 0,
        GdiPlusStartup,
        DispatchWindow,
        EffectInit,
        GlobalHook,
    };

    struct StartDiagnostics {
        StartStage stage{StartStage::None};
        uint32_t error{0};
    };

    enum class InputCaptureFailureReason : uint8_t {
        None = 0,
        PermissionDenied,
        Unsupported,
        StartFailed,
    };

    struct InputCaptureRuntimeStatus {
        bool active{false};
        uint32_t error{0};
        InputCaptureFailureReason reason{InputCaptureFailureReason::None};
    };
    
    struct InputIndicatorWasmRouteStatus {
        std::string eventKind;
        std::string renderMode;
        std::string reason;
        uint64_t eventTickMs{0};
        bool routeAttempted{false};
        bool anchorsResolved{false};
        bool hostPresent{false};
        bool hostEnabled{false};
        bool pluginLoaded{false};
        bool eventSupported{false};
        bool invokeAttempted{false};
        bool renderedByWasm{false};
        bool wasmFallbackEnabled{false};
        bool nativeFallbackApplied{false};
    };

    struct MouseCompanionRuntimeStatus {
        struct ActionCoverageActionStatus {
            std::string actionName;
            bool clipPresent{false};
            int trackCount{0};
            int mappedTrackCount{0};
            float coverageRatio{0.0f};
            std::vector<std::string> missingBoneTracks;
        };

        bool configEnabled{false};
        bool runtimePresent{false};
        bool pluginHostReady{false};
        std::string pluginHostPhase{"phase0"};
        std::string activePluginId;
        std::string activePluginVersion;
        std::string engineApiVersion;
        std::string compatibilityStatus;
        std::string fallbackReason;
        std::string lastPluginEvent;
        uint64_t lastPluginEventTickMs{0};
        uint64_t pluginEventCount{0};
        bool visualHostActive{false};
        bool visualModelLoaded{false};
        bool modelLoaded{false};
        bool actionLibraryLoaded{false};
        bool effectProfileLoaded{false};
        bool appearanceProfileLoaded{false};
        bool poseFrameAvailable{false};
        bool poseBindingConfigured{false};
        int skeletonBoneCount{0};
        std::string preferredRendererBackendSource;
        std::string preferredRendererBackend;
        std::string selectedRendererBackend;
        std::string rendererBackendSelectionReason;
        std::string rendererBackendFailureReason;
        std::vector<std::string> availableRendererBackends;
        std::vector<std::string> unavailableRendererBackends;
        std::vector<PetVisualHostRendererBackendCatalogEntry> rendererBackendCatalog;
        std::vector<std::string> realRendererUnmetRequirements;
        std::string rendererRuntimeBackend;
        bool rendererRuntimeReady{false};
        bool rendererRuntimeFrameRendered{false};
        uint64_t rendererRuntimeFrameCount{0};
        uint64_t rendererRuntimeLastRenderTickMs{0};
        std::string rendererRuntimeActionName{"idle"};
        std::string rendererRuntimeReactiveActionName{"idle"};
        float rendererRuntimeActionIntensity{0.0f};
        float rendererRuntimeReactiveActionIntensity{0.0f};
        bool rendererRuntimeModelReady{false};
        bool rendererRuntimeActionLibraryReady{false};
        bool rendererRuntimeAppearanceProfileReady{false};
        bool rendererRuntimePoseFrameAvailable{false};
        bool rendererRuntimePoseBindingConfigured{false};
        #if !defined(MFX_SHIPPING_BUILD)
        std::string rendererRuntimeSceneRuntimeAdapterMode{"runtime_only"};
        uint32_t rendererRuntimeSceneRuntimePoseSampleCount{0};
        uint32_t rendererRuntimeSceneRuntimeBoundPoseSampleCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetSourceState{"preview_only"};
        float rendererRuntimeSceneRuntimeModelAssetSourceReadiness{0.0f};
        std::string rendererRuntimeSceneRuntimeModelAssetSourceBrief{
            "preview_only/unknown/model:0/action:0/appearance:0"};
        std::string rendererRuntimeSceneRuntimeModelAssetSourcePathBrief{
            "model:-|action:-|appearance:default"};
        std::string rendererRuntimeSceneRuntimeModelAssetSourceValueBrief{
            "format:unknown|readiness:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetManifestState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetManifestEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetManifestResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetManifestBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetManifestEntryBrief{
            "model:-|action:-|appearance:default"};
        std::string rendererRuntimeSceneRuntimeModelAssetManifestValueBrief{
            "model:(0,0.00)|action:(0,0.00)|appearance:(0,0.00)"};
        std::string rendererRuntimeSceneRuntimeModelAssetCatalogState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetCatalogEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetCatalogResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetCatalogBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetCatalogEntryBrief{
            "model:-|action:-|appearance:default"};
        std::string rendererRuntimeSceneRuntimeModelAssetCatalogValueBrief{
            "model:0.00|action:0.00|appearance:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetBindingTableState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetBindingTableEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetBindingTableResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetBindingTableBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetBindingTableSlotBrief{
            "model:-|action:-|appearance:-"};
        std::string rendererRuntimeSceneRuntimeModelAssetBindingTableValueBrief{
            "model:0.00|action:0.00|appearance:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetRegistryBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetRegistryAssetBrief{
            "model:-|slots:-|registry:-|binding:-"};
        std::string rendererRuntimeSceneRuntimeModelAssetRegistryValueBrief{
            "model:0.00|slots:0.00|registry:0.00|binding:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetLoadState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetLoadEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetLoadResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetLoadBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetLoadPlanBrief{
            "decode:-|actions:-|appearance:-|transforms:-|pose:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetLoadValueBrief{
            "model:0.00|actions:0.00|appearance:0.00|transforms:0.00|pose:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetDecodeState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetDecodeEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetDecodeResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetDecodeBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetDecodePipelineBrief{
            "model:stub|action:stub|appearance:stub|transforms:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetDecodeValueBrief{
            "model:0.00|action:0.00|appearance:0.00|transforms:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetResidencyState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetResidencyEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetResidencyResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetResidencyBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetResidencyCacheBrief{
            "model:cold|action:cold|appearance:cold|pose:cold|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetResidencyValueBrief{
            "model:0.00|action:0.00|appearance:0.00|pose:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetInstanceState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetInstanceEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetInstanceResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetInstanceBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetInstanceSlotBrief{
            "model:stub|action:stub|appearance:stub|pose:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetInstanceValueBrief{
            "model:0.00|action:0.00|appearance:0.00|pose:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetActivationState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetActivationEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetActivationResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetActivationBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetActivationRouteBrief{
            "action:idle|reactive:idle|follow:0|drag:0|hold:0|scroll:0|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetActivationValueBrief{
            "action:0.00|reactive:0.00|motion:0.00|pose:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetSessionState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetSessionEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetSessionResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetSessionBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetSessionSessionBrief{
            "action:idle|reactive:idle|follow:0|drag:0|hold:0|scroll:0|pose:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetSessionValueBrief{
            "session:0.00|motion:0.00|pose:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetBindReadyState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetBindReadyEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetBindReadyResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetBindReadyBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetBindReadyBindingBrief{
            "binding:stub|pose:runtime_only|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetBindReadyValueBrief{
            "bind:0.00|pose:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetHandleState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetHandleEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetHandleResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetHandleBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetHandleHandleBrief{
            "model:model_handle|action:action_handle|appearance:appearance_handle|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetHandleValueBrief{
            "model:0.00|action:0.00|appearance:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelSceneAdapterState{"preview_only"};
        float rendererRuntimeSceneRuntimeModelSceneSeamReadiness{0.0f};
        std::string rendererRuntimeSceneRuntimeModelSceneAdapterBrief{
            "preview_only/unknown/runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneHookState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetSceneHookEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetSceneHookResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneHookBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneHookHookBrief{
            "scene:stub|pose:stub|grounding:stub|overlay:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneHookValueBrief{
            "scene:0.00|pose:0.00|grounding:0.00|overlay:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneBindingState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetSceneBindingEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetSceneBindingResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneBindingBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneBindingBindingBrief{
            "scene:stub|grounding:stub|overlay:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetSceneBindingValueBrief{
            "scene:0.00|grounding:0.00|overlay:0.00|adapter:0.00"};
        float rendererRuntimeSceneRuntimeModelNodeAdapterInfluence{0.0f};
        std::string rendererRuntimeSceneRuntimeModelNodeAdapterBrief{
            "preview_only/0.00"};
        std::string rendererRuntimeSceneRuntimeModelNodeChannelBrief{
            "body:0.00|face:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeAttachState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeAttachEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeAttachResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeAttachBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeAttachAttachBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeAttachValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeLiftState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeLiftEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeLiftResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeLiftBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeLiftLiftBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeLiftValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeBindState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeBindEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeBindResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeBindBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeBindBindBrief{
            "body:stub|head:stub|appendage:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeBindValueBrief{
            "body:0.00|head:0.00|appendage:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeResolveState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeResolveEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeResolveResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeResolveBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeResolveResolveBrief{
            "body:stub|head:stub|appendage:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeResolveValueBrief{
            "body:0.00|head:0.00|appendage:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelNodeGraphState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelNodeGraphNodeCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelNodeGraphBoundNodeCount{0};
        std::string rendererRuntimeSceneRuntimeModelNodeGraphBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelNodeBindingState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelNodeBindingEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelNodeBindingBoundEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelNodeBindingBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelNodeBindingWeightBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDriveState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeDriveEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeDriveResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDriveBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDriveDriveBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDriveValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeMountState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeMountEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeMountResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeMountBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeMountMountBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeMountValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelNodeSlotState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelNodeSlotCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelNodeReadySlotCount{0};
        std::string rendererRuntimeSceneRuntimeModelNodeSlotBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelNodeSlotNameBrief{
            "body:body_root|head:head_anchor|appendage:appendage_anchor|overlay:overlay_anchor|grounding:grounding_anchor"};
        std::string rendererRuntimeSceneRuntimeModelNodeRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelNodeRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelNodeRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelNodeRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelNodeRegistryAssetNodeBrief{
            "body:asset.body.root|head:asset.head.anchor|appendage:asset.appendage.anchor|overlay:asset.overlay.anchor|grounding:asset.grounding.anchor"};
        std::string rendererRuntimeSceneRuntimeModelNodeRegistryWeightBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeRouteState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeRouteEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeRouteResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeRouteBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeRouteRouteBrief{
            "body:stub|head:stub|appendage:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeRouteValueBrief{
            "body:0.00|head:0.00|appendage:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDispatchState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeDispatchEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeDispatchResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDispatchBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDispatchDispatchBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeDispatchValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeExecuteState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeExecuteEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeExecuteResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeExecuteBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeExecuteExecuteBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeExecuteValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeCommandState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeCommandEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeCommandResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeCommandBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeCommandCommandBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeCommandValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeControllerState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeControllerEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeModelAssetNodeControllerResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeControllerBrief{
            "preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeControllerControllerBrief{
            "body:stub|head:stub|appendage:stub|overlay:stub|grounding:stub|adapter:runtime_only"};
        std::string rendererRuntimeSceneRuntimeModelAssetNodeControllerValueBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00|adapter:0.00"};
        std::string rendererRuntimeSceneRuntimeAssetNodeBindingState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeBindingEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeBindingResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeBindingBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeBindingPathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodeBindingWeightBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTransformState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeTransformEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeTransformResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeTransformBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTransformPathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTransformValueBrief{
            "body:(0.00,0.00,1.00)|head:(0.00,0.00,1.00)|appendage:(0.00,0.00,1.00)|overlay:(0.00,0.00,1.00)|grounding:(0.00,0.00,1.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeAnchorState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeAnchorEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeAnchorResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeAnchorBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeAnchorPointBrief{
            "body:(0.0,0.0)|head:(0.0,0.0)|appendage:(0.0,0.0)|overlay:(0.0,0.0)|grounding:(0.0,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeAnchorScaleBrief{
            "body:1.00|head:1.00|appendage:1.00|overlay:1.00|grounding:1.00"};
        std::string rendererRuntimeSceneRuntimeAssetNodeResolverState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeResolverEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeResolverResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeResolverBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeResolverParentBrief{
            "body:root|head:body|appendage:body|overlay:head|grounding:body"};
        std::string rendererRuntimeSceneRuntimeAssetNodeResolverValueBrief{
            "body:(0.00,0.00,1.00)|head:(0.00,0.00,1.00)|appendage:(0.00,0.00,1.00)|overlay:(0.00,0.00,1.00)|grounding:(0.00,0.00,1.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeParentSpaceState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeParentSpaceEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeParentSpaceResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeParentSpaceBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeParentSpaceParentBrief{
            "body:root|head:body|appendage:body|overlay:head|grounding:body"};
        std::string rendererRuntimeSceneRuntimeAssetNodeParentSpaceValueBrief{
            "body:(0.00,0.00,1.00)|head:(0.00,0.00,1.00)|appendage:(0.00,0.00,1.00)|overlay:(0.00,0.00,1.00)|grounding:(0.00,0.00,1.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeTargetEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeTargetResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetKindBrief{
            "body:body_target|head:head_target|appendage:appendage_target|overlay:overlay_target|grounding:grounding_target"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetValueBrief{
            "body:(0.00,0.00,1.00)|head:(0.00,0.00,1.00)|appendage:(0.00,0.00,1.00)|overlay:(0.00,0.00,1.00)|grounding:(0.00,0.00,1.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetResolverState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeTargetResolverEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeTargetResolverResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetResolverBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetResolverPathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodeTargetResolverValueBrief{
            "body:(0.00,0.00,1.00)|head:(0.00,0.00,1.00)|appendage:(0.00,0.00,1.00)|overlay:(0.00,0.00,1.00)|grounding:(0.00,0.00,1.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeWorldSpaceState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeWorldSpaceEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeWorldSpaceResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeWorldSpaceBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeWorldSpacePathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodeWorldSpaceValueBrief{
            "body:(0.0,0.0,1.00)|head:(0.0,0.0,1.00)|appendage:(0.0,0.0,1.00)|overlay:(0.0,0.0,1.00)|grounding:(0.0,0.0,1.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePosePathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseValueBrief{
            "body:(0.0,0.0,1.00,0.0)|head:(0.0,0.0,1.00,0.0)|appendage:(0.0,0.0,1.00,0.0)|overlay:(0.0,0.0,1.00,0.0)|grounding:(0.0,0.0,1.00,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseResolverState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseResolverEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseResolverResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseResolverBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseResolverPathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseResolverValueBrief{
            "body:(0.0,0.0,1.00,0.0)|head:(0.0,0.0,1.00,0.0)|appendage:(0.0,0.0,1.00,0.0)|overlay:(0.0,0.0,1.00,0.0)|grounding:(0.0,0.0,1.00,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseRegistryNodeBrief{
            "body:pose.body.root|head:pose.head.anchor|appendage:pose.appendage.anchor|overlay:pose.overlay.anchor|grounding:pose.grounding.anchor"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseRegistryWeightBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseChannelState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseChannelEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseChannelResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseChannelBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseChannelNameBrief{
            "body:channel.body.posture|head:channel.head.expression|appendage:channel.appendage.motion|overlay:channel.overlay.fx|grounding:channel.grounding.shadow"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseChannelWeightBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseConstraintState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseConstraintEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseConstraintResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseConstraintBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseConstraintNameBrief{
            "body:constraint.body.posture|head:constraint.head.expression|appendage:constraint.appendage.motion|overlay:constraint.overlay.fx|grounding:constraint.grounding.shadow"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseConstraintValueBrief{
            "body:(0.00,0.0,0.0,1.00,0.0)|head:(0.00,0.0,0.0,1.00,0.0)|appendage:(0.00,0.0,0.0,1.00,0.0)|overlay:(0.00,0.0,0.0,1.00,0.0)|grounding:(0.00,0.0,0.0,1.00,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseSolveState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseSolveEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseSolveResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseSolveBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseSolvePathBrief{
            "body:/pet/body/root|head:/pet/body/head|appendage:/pet/body/appendage|overlay:/pet/fx/overlay|grounding:/pet/fx/grounding"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseSolveValueBrief{
            "body:(0.00,0.0,0.0,1.00,0.0)|head:(0.00,0.0,0.0,1.00,0.0)|appendage:(0.00,0.0,0.0,1.00,0.0)|overlay:(0.00,0.0,0.0,1.00,0.0)|grounding:(0.00,0.0,0.0,1.00,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeJointHintState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeJointHintEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeJointHintResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeJointHintBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeJointHintNameBrief{
            "body:joint.body.spine|head:joint.head.look|appendage:joint.appendage.reach|overlay:joint.overlay.fx|grounding:joint.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeJointHintValueBrief{
            "body:(0.00,0.0,0.0,0.0)|head:(0.00,0.0,0.0,0.0)|appendage:(0.00,0.0,0.0,0.0)|overlay:(0.00,0.0,0.0,0.0)|grounding:(0.00,0.0,0.0,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeArticulationEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeArticulationResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationNameBrief{
            "body:articulation.body.spine|head:articulation.head.look|appendage:articulation.appendage.reach|overlay:articulation.overlay.fx|grounding:articulation.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationValueBrief{
            "body:(0.00,0.0,1.00,0.0)|head:(0.00,0.0,1.00,0.0)|appendage:(0.00,0.0,1.00,0.0)|overlay:(0.00,0.0,1.00,0.0)|grounding:(0.00,0.0,1.00,0.0)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeLocalJointRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeLocalJointRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeLocalJointRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeLocalJointRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeLocalJointRegistryJointBrief{
            "body:local.body.spine|head:local.head.look|appendage:local.appendage.reach|overlay:local.overlay.fx|grounding:local.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeLocalJointRegistryWeightBrief{
            "body:0.00|head:0.00|appendage:0.00|overlay:0.00|grounding:0.00"};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationMapState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeArticulationMapEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeArticulationMapResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationMapBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationMapNameBrief{
            "body:map.body.spine|head:map.head.look|appendage:map.appendage.reach|overlay:map.overlay.fx|grounding:map.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeArticulationMapValueBrief{
            "body:(0.00,0.0,0.00)|head:(0.00,0.0,0.00)|appendage:(0.00,0.0,0.00)|overlay:(0.00,0.0,0.00)|grounding:(0.00,0.0,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlRigHintState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControlRigHintEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControlRigHintResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlRigHintBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlRigHintNameBrief{
            "body:rig.body.spine|head:rig.head.look|appendage:rig.appendage.reach|overlay:rig.overlay.fx|grounding:rig.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlRigHintValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigChannelState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeRigChannelEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeRigChannelResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigChannelBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigChannelNameBrief{
            "body:rig.channel.body.spine|head:rig.channel.head.look|appendage:rig.channel.appendage.reach|overlay:rig.channel.overlay.fx|grounding:rig.channel.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigChannelValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlSurfaceState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControlSurfaceEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControlSurfaceResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlSurfaceBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlSurfaceNameBrief{
            "body:surface.body.spine|head:surface.head.look|appendage:surface.appendage.reach|overlay:surface.overlay.fx|grounding:surface.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControlSurfaceValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigDriverState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeRigDriverEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeRigDriverResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigDriverBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigDriverNameBrief{
            "body:rig.driver.body.spine|head:rig.driver.head.look|appendage:rig.driver.appendage.reach|overlay:rig.driver.overlay.fx|grounding:rig.driver.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeRigDriverValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceDriverState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceDriverEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceDriverResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceDriverBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceDriverNameBrief{
            "body:surface.driver.body.spine|head:surface.driver.head.look|appendage:surface.driver.appendage.reach|overlay:surface.driver.overlay.fx|grounding:surface.driver.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceDriverValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseBusState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseBusEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodePoseBusResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseBusBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseBusNameBrief{
            "body:pose.bus.body.spine|head:pose.bus.head.look|appendage:pose.bus.appendage.reach|overlay:pose.bus.overlay.fx|grounding:pose.bus.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodePoseBusValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerTableState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerTableEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerTableResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerTableBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerTableNameBrief{
            "body:controller.body.spine|head:controller.head.look|appendage:controller.appendage.reach|overlay:controller.overlay.fx|grounding:controller.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerTableValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerRegistryNameBrief{
            "body:registry.body.spine|head:registry.head.look|appendage:registry.appendage.reach|overlay:registry.overlay.fx|grounding:registry.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerRegistryValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeDriverBusState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeDriverBusEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeDriverBusResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeDriverBusBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeDriverBusNameBrief{
            "body:driver.bus.body.spine|head:driver.bus.head.look|appendage:driver.bus.appendage.reach|overlay:driver.bus.overlay.fx|grounding:driver.bus.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeDriverBusValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerDriverRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerDriverRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerDriverRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerDriverRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerDriverRegistryNameBrief{
            "body:controller.driver.body.spine|head:controller.driver.head.look|appendage:controller.driver.appendage.reach|overlay:controller.driver.overlay.fx|grounding:controller.driver.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerDriverRegistryValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionLaneState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionLaneEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionLaneResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionLaneBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionLaneNameBrief{
            "body:execution.lane.body.spine|head:execution.lane.head.look|appendage:execution.lane.appendage.reach|overlay:execution.lane.overlay.fx|grounding:execution.lane.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionLaneValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerPhaseEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerPhaseResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseNameBrief{
            "body:controller.phase.body.spine|head:controller.phase.head.look|appendage:controller.phase.appendage.reach|overlay:controller.phase.overlay.fx|grounding:controller.phase.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionSurfaceState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionSurfaceEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionSurfaceResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionSurfaceBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionSurfaceNameBrief{
            "body:execution.surface.body.shell|head:execution.surface.head.mask|appendage:execution.surface.appendage.trim|overlay:execution.surface.overlay.fx|grounding:execution.surface.grounding.base"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionSurfaceValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerPhaseRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeControllerPhaseRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseRegistryNameBrief{
            "body:phase.registry.body.spine|head:phase.registry.head.look|appendage:phase.registry.appendage.reach|overlay:phase.registry.overlay.fx|grounding:phase.registry.grounding.balance"};
        std::string rendererRuntimeSceneRuntimeAssetNodeControllerPhaseRegistryValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceCompositionBusState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceCompositionBusEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceCompositionBusResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceCompositionBusBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceCompositionBusNameBrief{
            "body:surface.bus.body.shell|head:surface.bus.head.mask|appendage:surface.bus.appendage.trim|overlay:surface.bus.overlay.fx|grounding:surface.bus.grounding.base"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceCompositionBusValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionStackEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionStackResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackNameBrief{
        "body:execution.stack.body.shell|head:execution.stack.head.mask|appendage:execution.stack.appendage.trim|overlay:execution.stack.overlay.fx|grounding:execution.stack.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterNameBrief{
        "body:execution.stack.router.body.shell|head:execution.stack.router.head.mask|appendage:execution.stack.router.appendage.trim|overlay:execution.stack.router.overlay.fx|grounding:execution.stack.router.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterRegistryState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterRegistryEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterRegistryResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterRegistryBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterRegistryNameBrief{
        "body:execution.stack.router.registry.body.shell|head:execution.stack.router.registry.head.mask|appendage:execution.stack.router.registry.appendage.trim|overlay:execution.stack.router.registry.overlay.fx|grounding:execution.stack.router.registry.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionStackRouterRegistryValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeCompositionRegistryState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeCompositionRegistryEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeCompositionRegistryResolvedEntryCount{0};
        std::string rendererRuntimeSceneRuntimeAssetNodeCompositionRegistryBrief{"preview_only/0/0"};
        std::string rendererRuntimeSceneRuntimeAssetNodeCompositionRegistryNameBrief{
            "body:composition.registry.body.shell|head:composition.registry.head.mask|appendage:composition.registry.appendage.trim|overlay:composition.registry.overlay.fx|grounding:composition.registry.grounding.base"};
        std::string rendererRuntimeSceneRuntimeAssetNodeCompositionRegistryValueBrief{
            "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
        std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteState{"preview_only"};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteEntryCount{0};
        uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteNameBrief{
        "body:surface.route.body.shell|head:surface.route.head.mask|appendage:surface.route.appendage.trim|overlay:surface.route.overlay.fx|grounding:surface.route.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRegistryState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRegistryEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRegistryResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRegistryBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRegistryNameBrief{
        "body:surface.route.registry.body.shell|head:surface.route.registry.head.mask|appendage:surface.route.registry.appendage.trim|overlay:surface.route.registry.overlay.fx|grounding:surface.route.registry.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRegistryValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRouterBusState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRouterBusEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRouterBusResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRouterBusBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRouterBusNameBrief{
        "body:surface.route.router.bus.body.shell|head:surface.route.router.bus.head.mask|appendage:surface.route.router.bus.appendage.trim|overlay:surface.route.router.bus.overlay.fx|grounding:surface.route.router.bus.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteRouterBusValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusRegistryState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusRegistryEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusRegistryResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusRegistryBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusRegistryNameBrief{
        "body:surface.route.bus.registry.body.shell|head:surface.route.bus.registry.head.mask|appendage:surface.route.bus.registry.appendage.trim|overlay:surface.route.bus.registry.overlay.fx|grounding:surface.route.bus.registry.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusRegistryValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverNameBrief{
        "body:surface.route.bus.driver.body.shell|head:surface.route.bus.driver.head.mask|appendage:surface.route.bus.driver.appendage.trim|overlay:surface.route.bus.driver.overlay.fx|grounding:surface.route.bus.driver.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryNameBrief{
        "body:surface.route.bus.driver.registry.body.shell|head:surface.route.bus.driver.registry.head.mask|appendage:surface.route.bus.driver.registry.appendage.trim|overlay:surface.route.bus.driver.registry.overlay.fx|grounding:surface.route.bus.driver.registry.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryRouterState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryRouterEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryRouterResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryRouterBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryRouterNameBrief{
        "body:surface.route.bus.driver.registry.router.body.shell|head:surface.route.bus.driver.registry.router.head.mask|appendage:surface.route.bus.driver.registry.router.appendage.trim|overlay:surface.route.bus.driver.registry.router.overlay.fx|grounding:surface.route.bus.driver.registry.router.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeSurfaceRouteBusDriverRegistryRouterValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverTableState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverTableEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverTableResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverTableBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverTableNameBrief{
        "body:execution.driver.body.shell|head:execution.driver.head.mask|appendage:execution.driver.appendage.trim|overlay:execution.driver.overlay.fx|grounding:execution.driver.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverTableValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterTableState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterTableEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterTableResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterTableBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterTableNameBrief{
        "body:execution.driver.router.body.shell|head:execution.driver.router.head.mask|appendage:execution.driver.router.appendage.trim|overlay:execution.driver.router.overlay.fx|grounding:execution.driver.router.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterTableValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryNameBrief{
        "body:execution.driver.router.registry.body.shell|head:execution.driver.router.registry.head.mask|appendage:execution.driver.router.registry.appendage.trim|overlay:execution.driver.router.registry.overlay.fx|grounding:execution.driver.router.registry.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusNameBrief{
        "body:execution.driver.router.registry.bus.body.shell|head:execution.driver.router.registry.bus.head.mask|appendage:execution.driver.router.registry.bus.appendage.trim|overlay:execution.driver.router.registry.bus.overlay.fx|grounding:execution.driver.router.registry.bus.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusRegistryState{"preview_only"};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusRegistryEntryCount{0};
    uint32_t rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusRegistryResolvedEntryCount{0};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusRegistryBrief{"preview_only/0/0"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusRegistryNameBrief{
        "body:execution.driver.router.registry.bus.registry.body.shell|head:execution.driver.router.registry.bus.registry.head.mask|appendage:execution.driver.router.registry.bus.registry.appendage.trim|overlay:execution.driver.router.registry.bus.registry.overlay.fx|grounding:execution.driver.router.registry.bus.registry.grounding.base"};
    std::string rendererRuntimeSceneRuntimeAssetNodeExecutionDriverRouterRegistryBusRegistryValueBrief{
        "body:(0.00,0.00,0.00)|head:(0.00,0.00,0.00)|appendage:(0.00,0.00,0.00)|overlay:(0.00,0.00,0.00)|grounding:(0.00,0.00,0.00)"};
    float rendererRuntimeSceneRuntimePoseAdapterInfluence{0.0f};
    float rendererRuntimeSceneRuntimePoseReadabilityBias{0.0f};
        std::string rendererRuntimeSceneRuntimePoseAdapterBrief{"runtime_only/0.00/0.00"};
        int rendererRuntimeFacingDirection{1};
        int rendererRuntimeSurfaceWidth{0};
        int rendererRuntimeSurfaceHeight{0};
        std::string rendererRuntimeModelSourceFormat{"unknown"};
        std::string rendererRuntimeAppearanceSkinVariantId{"default"};
        std::vector<std::string> rendererRuntimeAppearanceAccessoryIds;
        std::string rendererRuntimeAppearanceAccessoryFamily{"none"};
        std::string rendererRuntimeAppearanceComboPreset{"none"};
        std::string rendererRuntimeAppearanceRequestedPresetId;
        std::string rendererRuntimeAppearanceResolvedPresetId;
        std::string rendererRuntimeAppearancePluginId;
        std::string rendererRuntimeAppearancePluginKind;
        std::string rendererRuntimeAppearancePluginSource;
        std::string rendererRuntimeAppearancePluginSelectionReason;
        std::string rendererRuntimeAppearancePluginFailureReason;
        std::string rendererRuntimeAppearancePluginManifestPath;
        std::string rendererRuntimeAppearancePluginRuntimeBackend;
        std::string rendererRuntimeAppearancePluginMetadataPath;
        uint32_t rendererRuntimeAppearancePluginMetadataSchemaVersion{0};
        std::string rendererRuntimeAppearancePluginAppearanceSemanticsMode{
            "legacy_manifest_compat"};
        std::string rendererRuntimeAppearancePluginSampleTier;
        std::string rendererRuntimeAppearancePluginContractBrief{
            "legacy_manifest_compat/-/-"};
        std::string rendererRuntimeDefaultLaneCandidate{"builtin"};
        std::string rendererRuntimeDefaultLaneSource{"runtime_builtin_default"};
        std::string rendererRuntimeDefaultLaneRolloutStatus{"stay_on_builtin"};
        std::string rendererRuntimeDefaultLaneStyleIntent{"style_candidate:none"};
        std::string rendererRuntimeDefaultLaneCandidateTier{"builtin_shipped_default"};
        #endif
        std::string configuredModelPath;
        std::string configuredActionLibraryPath;
        std::string configuredEffectProfilePath;
        std::string configuredAppearanceProfilePath;
        std::string configuredRendererBackendPreferenceSource;
        std::string configuredRendererBackendPreferenceName;
        std::string visualModelPath;
        std::string loadedModelPath;
        std::string loadedModelSourceFormat{"unknown"};
        std::string loadedActionLibraryPath;
        std::string loadedEffectProfilePath;
        std::string loadedAppearanceProfilePath;
        bool modelConvertedToCanonical{false};
        std::vector<std::string> modelImportDiagnostics;
        std::string visualModelLoadError;
        std::string modelLoadError;
        std::string actionLibraryLoadError;
        std::string effectProfileLoadError;
        std::string appearanceProfileLoadError;
        int lastActionCode{0};
        float lastActionIntensity{0.0f};
        uint64_t lastActionTickMs{0};
        std::string lastActionName{"idle"};
        int clickStreak{0};
        float clickStreakTintAmount{0.0f};
        int clickStreakBreakMs{650};
        float clickStreakDecayPerSecond{0.36f};
        bool actionCoverageReady{false};
        int actionCoverageExpectedActionCount{0};
        int actionCoverageCoveredActionCount{0};
        int actionCoverageMissingActionCount{0};
        int actionCoverageSkeletonBoneCount{0};
        int actionCoverageTotalTrackCount{0};
        int actionCoverageMappedTrackCount{0};
        float actionCoverageOverallRatio{0.0f};
        std::string actionCoverageError;
        std::vector<std::string> actionCoverageMissingActions;
        std::vector<std::string> actionCoverageMissingBoneNames;
        std::vector<ActionCoverageActionStatus> actionCoverageActions;
    };

    bool Start();
    void Stop();
    
    // Set effect for a specific category.
    // type = "ripple", "star", "line", etc. or "none" to disable.
    void SetEffect(EffectCategory category, const std::string& type);
    
    // Clear (disable) effect for a category.
    void ClearEffect(EffectCategory category);

    // Set visual theme (affects themed effects).
    void SetTheme(const std::string& theme);

    // Set settings window UI language (persisted).
    void SetUiLanguage(const std::string& lang);
    // Set launch-at-startup preference (persisted).
    void SetLaunchAtStartup(bool enabled);
    
    // Set custom text content for Text Effect
    void SetTextEffectContent(const std::vector<std::wstring>& texts);
    // Set text click font size in point units.
    void SetTextEffectFontSize(float sizePt);
    void SetMouseCompanionConfig(const MouseCompanionConfig& cfg);
    void SetInputIndicatorConfig(const InputIndicatorConfig& cfg);
    void SetInputAutomationConfig(const InputAutomationConfig& cfg);
    void SetRuntimeDiagnosticsEnabled(bool enabled);
    bool RuntimeDiagnosticsEnabled() const;
    // Set hold follow mode (precise|smooth|efficient).
    void SetHoldFollowMode(const std::string& mode);
    // Set hold presenter backend preference (auto or backend id).
    void SetHoldPresenterBackend(const std::string& backend);
    // Set overlay target FPS (0=auto max refresh, positive value=cap).
    void SetOverlayTargetFps(int targetFps);

    // Advanced tuning: trail history + renderer params (persisted).
    void SetTrailTuning(const std::string& style, const TrailProfilesConfig& profiles, const TrailRendererParamsConfig& params);
    // Set trail line width (persisted).
    void SetTrailLineWidth(float lineWidth);
    void SetEffectSizeScales(const EffectSizeScaleConfig& scales);
    void SetEffectConflictPolicy(const EffectConflictPolicyConfig& policy);
    void SetEffectsBlacklistApps(const std::vector<std::string>& apps);

    // Get the current effect for a category (may be null).
    IMouseEffect* GetEffect(EffectCategory category) const;

    // Handle JSON command string.
    void HandleCommand(const std::string& jsonCmd);

    StartDiagnostics Diagnostics() const { return diag_; }
    InputCaptureRuntimeStatus InputCaptureStatus() const;
    bool EffectsSuspendedByInputCapture() const;
    void SetInputCaptureStatusCallback(std::function<void(const InputCaptureRuntimeStatus&)> callback);
    void SetAutomationOpenUrlHandler(std::function<bool(const std::string&)> handler);
    void SetAutomationLaunchAppHandler(std::function<bool(const std::string&)> handler);
    
    // Get current config (for effects to read)
    const EffectConfig& Config() const { return config_; }
    EffectConfig GetConfigSnapshot() const;

    // Reset settings to defaults
    void ResetConfig();

    // --- Methods exposed for CommandHandler delegation ---
    void PersistConfig();
    void SetActiveEffectType(EffectCategory category, const std::string& type);
    void ReloadConfigFromDisk();
    std::string ResolveRuntimeEffectType(EffectCategory category, const std::string& requestedType, std::string* outReason) const;
    void SetWasmEnabled(bool enabled);
    void SetWasmFallbackToBuiltinClick(bool enabled);
    void SetWasmManifestPath(const std::string& manifestPath);
    void SetWasmManifestPathForChannel(const std::string& channel, const std::string& manifestPath);
    std::string ResolveWasmManifestPathForChannel(const std::string& channel) const;
    void SetWasmCatalogRootPath(const std::string& catalogRootPath);
    void SetThemeCatalogRootPath(const std::string& rootPath);
    void SetWasmExecutionBudget(uint32_t outputBufferBytes, uint32_t maxCommands, double maxExecutionMs);
    void SyncCursorDecorationOverlaySuppression();
    bool LoadWasmPluginFromManifestPath(
        const std::string& manifestPath,
        const std::string& surface = {},
        const std::string& effectChannel = {});
    bool ShouldFallbackToBuiltinClickWhenWasmActive() const;
    
    // --- Methods exposed for DispatchRouter delegation ---
    void OnDispatchActivity(DispatchMessageKind kind, uint32_t timerId);
    bool IsVmEffectsSuppressed() const { return vmEffectsSuppressed_; }
    uint64_t VmForegroundSuppressionCheckIntervalMs() const;
    bool ConsumeIgnoreNextClick();
    void OnGlobalKey(const KeyEvent& ev);
    void DispatchInputIndicatorClick(const ClickEvent& ev);
    void DispatchInputIndicatorScroll(const ScrollEvent& ev);
    void DispatchInputIndicatorKey(const KeyEvent& ev);
    InputIndicatorWasmRouteStatus ReadInputIndicatorWasmRouteStatus() const;
    MouseCompanionRuntimeStatus ReadMouseCompanionRuntimeStatus() const;
    IInputIndicatorOverlay& IndicatorOverlay() { return *inputIndicatorOverlay_; }
    InputAutomationEngine& InputAutomation() { return inputAutomationEngine_; }
    const InputAutomationEngine& InputAutomation() const { return inputAutomationEngine_; }
    bool ConsumeLatestMove(ScreenPoint* outPt);
    uint64_t CurrentTickMs() const;
    uint32_t CurrentHoldDurationMs() const;
    void BeginHoldTracking(const ScreenPoint& pt, int button);
    void EndHoldTracking();
    void ArmHoldTimer();
    void DisarmHoldTimer();
    void ArmHoldUpdateTimer();
    void DisarmHoldUpdateTimer();
    void ArmWasmFrameTimer();
    void DisarmWasmFrameTimer();
    void ClearPendingHold();
    void CancelPendingHold();
    bool ConsumePendingHold(ScreenPoint* outPt, int* outButton);
    void MarkIgnoreNextClick();
    bool IsHoldButtonDown() const { return holdButtonDown_; }
    int HoldTrackingButton() const { return holdTrackingButton_; }
    bool IsHovering() const { return hovering_; }
    bool TryEnterHover(ScreenPoint* outPt);
    bool QueryCursorScreenPoint(ScreenPoint* outPt) const;
    void RememberLastPointerPoint(const ScreenPoint& pt);
    bool TryGetLastPointerPoint(ScreenPoint* outPt) const;
    void DispatchPetMove(const ScreenPoint& pt);
    void DispatchPetScroll(const ScreenPoint& pt, int delta);
    void DispatchPetClick(const ClickEvent& ev);
    void DispatchPetButtonDown(const ScreenPoint& pt, int button);
    void DispatchPetButtonUp(const ScreenPoint& pt, int button);
    void DispatchPetHoverStart(const ScreenPoint& pt);
    void DispatchPetHoverEnd(const ScreenPoint& pt);
    void DispatchPetHoldStart(const ScreenPoint& pt, int button, uint32_t holdMs);
    void DispatchPetHoldUpdate(const ScreenPoint& pt, uint32_t holdMs);
    void DispatchPetHoldEnd(const ScreenPoint& pt);
    void TickPetVisualFrame();
    void KillDispatchTimer(uintptr_t timerId);
    std::string CurrentForegroundProcessBaseName() const;
    std::string ProcessBaseNameForScreenPoint(const ScreenPoint& pt) const;
    bool IsEffectsBlockedByAppBlacklist();
    bool IsEffectsBlockedByAppBlacklistAtPoint(const ScreenPoint& pt) const;
    bool InjectShortcutForTest(const std::string& chordText);
    bool OpenAutomationUrlForTest(const std::string& url);
    bool LaunchAutomationAppForTest(const std::string& appPath);
    std::string StartShortcutCaptureSession(uint64_t timeoutMs);
    void StopShortcutCaptureSession(const std::string& sessionId);
    ShortcutCaptureSession::PollResult PollShortcutCaptureSession(const std::string& sessionId);
    wasm::WasmEffectHost* WasmHost() const;
    wasm::WasmEffectHost* WasmIndicatorHost() const { return wasmIndicatorHost_.get(); }
    wasm::WasmEffectHost* WasmEffectsHostForChannel(const std::string& channel) const;
    wasm::WasmEffectHost* WasmHostForSurface(const std::string& surface) const;
    static constexpr uintptr_t HoverTimerId() { return kHoverTimerId; }
    static constexpr uintptr_t HoldTimerId() { return kHoldTimerId; }
    static constexpr uintptr_t HoldUpdateTimerId() { return kHoldUpdateTimerId; }
    static constexpr uintptr_t WasmFrameTimerId() { return kWasmFrameTimerId; }
    uint32_t ActiveHoverThresholdMs() const;
    uint32_t ActiveHoldDelayMs() const;
    // Mouse speed tracking
    void UpdateMouseSpeed(const ScreenPoint& currentPt);
    float GetMouseSpeed() const;
    float GetSpeedAdaptiveIntensity() const;
#ifdef _DEBUG
    void LogDebugClick(const ClickEvent& ev);
#else
    void LogDebugClick(const ClickEvent&) {}
#endif

private:
    intptr_t OnDispatchMessage(
        uintptr_t sourceHandle,
        uint32_t msg,
        uintptr_t wParam,
        intptr_t lParam) override;
    bool CreateDispatchWindow();
    void DestroyDispatchWindow();
    
    // Factory method to create effect by category and type name.
    std::unique_ptr<IMouseEffect> CreateEffect(EffectCategory category, const std::string& type);
    const std::string* ActiveTypeForCategory(EffectCategory category) const;
    std::string* MutableActiveTypeForCategory(EffectCategory category);
    bool IsActiveEffectEnabled(EffectCategory category) const;
    void ReapplyActiveEffect(EffectCategory category);
    std::string ResolveConfiguredClickType() const;
    void ApplyConfiguredEffects();
    void ApplyOverlayTargetFpsToPlatform();
    uint32_t ResolveWasmFrameTimerIntervalMs() const;
    bool NormalizeConfiguredThemeName();
    bool NormalizeActiveEffectTypes();
    void InitializeWasmHost();
    void ShutdownWasmHost();
    void ApplyWasmConfigToHost(bool tryLoadManifest);
    bool EnsureInputIndicatorWasmBudgetFloor();
    void SyncInputIndicatorWasmHostToConfig();
    void SyncLaunchAtStartupRegistration();
    void SyncLaunchAtStartupManifest();


    void NotifyGpuFallbackIfNeeded(const std::string& reason);
    void WriteGpuRouteStatusSnapshot(EffectCategory category, const std::string& requestedType, const std::string& effectiveType, const std::string& reason) const;
    bool IsProcessBlockedByEffectsBlacklist(const std::string& processBaseName) const;
    void NotifyInputCaptureStatusChanged();
    void RefreshInputCaptureRuntimeState();
    void TryLoadDefaultPetModel();
    void TryLoadDefaultPetActionLibrary();
    void TryLoadDefaultPetEffectProfile();
    void TryLoadDefaultPetAppearanceProfile();
    void RecomputePetActionCoverageStatus();
    void EnsurePetVisualHost();
    void ShutdownPetVisualHost();
    bool TryLoadPetModelIntoVisualHost(const std::string& modelPath);
    bool TryLoadPetActionLibraryIntoVisualHost(const std::string& actionLibraryPath);
    bool TryLoadPetAppearanceProfileIntoVisualHost(const std::string& appearanceProfilePath);
    void TryApplyPetModelToVisualHost();
    void TryApplyPetActionLibraryToVisualHost();
    void ApplyPetVisualFollowProfile();
    void TryApplyPetAppearanceToVisualHost();
    bool EnsurePetVisualPoseBinding();
    void SyncPetVisualHostDiagnostics(const PetVisualHostDiagnostics& diagnostics);
    void ClearPetVisualHostDiagnostics();
    void UpdatePetVisualState(const ScreenPoint& pt, int actionCode, float actionIntensity, float headTintAmount);
    ScreenPoint ResolvePetRuntimeCursorPoint(const ScreenPoint& rawPt, double dtSeconds, int smoothingPercent);
    void ResetPetDispatchRuntimeState();
    void UpdatePetPrimaryPressTravel(const ScreenPoint& pt);
    bool EvaluatePetPrimaryClickEligibility(uint64_t nowTickMs) const;
    void SyncPetClickStreakRuntimeStatus(const MouseCompanionConfig& activeConfig);
    void UpdatePetClickStreakDecay(uint64_t nowTickMs, const MouseCompanionConfig& activeConfig);
    void RegisterPetClickStreakClick(uint64_t nowTickMs, const MouseCompanionConfig& activeConfig);
    uint32_t ResolvePetVisualHoldEnterMs(const MouseCompanionConfig& activeConfig) const;
    double ResolvePetVisualHoldStableSpeedThresholdPxPerSec(const MouseCompanionConfig& activeConfig) const;
    bool IsPetVisualHoldSuppressedByScroll(uint64_t nowTickMs, const MouseCompanionConfig& activeConfig) const;
    bool ResolvePetVisualHoldState(
        const MouseCompanionConfig& activeConfig,
        uint64_t nowTickMs,
        float* outIntensity) const;
    void UpdatePetPointerMotion(const ScreenPoint& pt, uint64_t nowTickMs);
    void DecayPetPointerMotion(uint64_t nowTickMs, const MouseCompanionConfig& activeConfig);
    void ResolvePetContinuousAction(const MouseCompanionConfig& activeConfig, int* outActionCode, float* outActionIntensity) const;
    MouseCompanionPetRuntimeConfig BuildMouseCompanionPluginRuntimeConfig(const MouseCompanionConfig& cfg) const;
    void SyncMouseCompanionPluginPhase0Status();
    void ResetMouseCompanionPluginHosts(const MouseCompanionConfig& cfg, uint64_t nowTickMs);
    void OnMouseCompanionPluginConfigChanged(const MouseCompanionConfig& cfg, uint64_t nowTickMs);
    void RecordMouseCompanionPluginPhase0Input(const char* eventName);
    void RecordMouseCompanionPluginInput(const char* eventName, const MouseCompanionPetInputEvent& event);
    void CommitMouseCompanionPluginResolvedFrame(const MouseCompanionPetPoseFrame& frame);
    void EnterInputCaptureDegradedMode(uint32_t error);
    void UpdateVmSuppressionState();
    void ApplyVmSuppression(bool suppressed);
    void SuspendEffectsForVm();
    void ResumeEffectsAfterVm();
    static InputCaptureFailureReason ClassifyInputCaptureFailure(bool active, uint32_t error);
    void RecordInputIndicatorWasmRouteStatus(
        const char* eventKind,
        const InputIndicatorWasmRouteTrace& trace,
        bool renderedByWasm,
        bool wasmFallbackEnabled,
        bool nativeFallbackApplied);

    std::unique_ptr<GdiPlusSession> gdiplus_{};
    std::unique_ptr<IDispatchMessageHost> dispatchMessageHost_{};
    std::unique_ptr<IDispatchMessageCodec> dispatchMessageCodec_{};
    std::unique_ptr<ICursorPositionService> cursorPositionService_{};
    std::unique_ptr<IMonotonicClockService> monotonicClockService_{};
    std::unique_ptr<IForegroundProcessService> foregroundProcessService_{};
    std::unique_ptr<IForegroundSuppressionService> foregroundSuppressionService_{};
    std::unique_ptr<IGlobalMouseHook> hook_{};
    std::unique_ptr<IKeyboardInjector> keyboardInjector_{};
    
    // One effect slot per category.
    static constexpr size_t kCategoryCount = static_cast<size_t>(EffectCategory::Count);
    std::array<std::unique_ptr<IMouseEffect>, kCategoryCount> effects_{};
    
    EffectConfig config_{};
    std::wstring configDir_{};
    StartDiagnostics diag_{};
    std::atomic<bool> inputCaptureActive_{false};
    std::atomic<uint32_t> inputCaptureError_{0};
    std::atomic<bool> effectsSuspendedByInputCapture_{false};
    std::function<void(const InputCaptureRuntimeStatus&)> inputCaptureStatusCallback_{};
    std::function<bool(const std::string&)> automationOpenUrlHandler_{};
    std::function<bool(const std::string&)> automationLaunchAppHandler_{};
    mutable std::mutex inputCaptureStatusCallbackMutex_{};
    mutable std::mutex automationOpenUrlHandlerMutex_{};
    mutable std::mutex automationLaunchAppHandlerMutex_{};

    uint64_t lastInputTime_ = 0;
    ScreenPoint lastPointerPoint_{};
    bool hasLastPointerPoint_ = false;
    bool hovering_ = false;
    
    // Mouse speed tracking
    float mouseSpeed_ = 0.0f;
    float smoothedMouseSpeed_ = 0.0f;
    uint64_t lastMouseMoveTime_ = 0;
    ScreenPoint lastMouseMovePoint_{};
    static constexpr uintptr_t kHoverTimerId = 2;
    static constexpr uint32_t kHoverThresholdMs = 1500;
    static constexpr uint32_t kHoverThresholdTestMs = 320;
    static constexpr uintptr_t kInputCaptureHealthTimerId = 6;
    static constexpr uintptr_t kWasmFrameTimerId = 10;

    // Hold delay logic
    static constexpr uintptr_t kHoldTimerId = 5;
    static constexpr uint32_t kHoldDelayMs = 260;
    static constexpr uint32_t kHoldDelayTestMs = 120;
    static constexpr uintptr_t kHoldUpdateTimerId = 9;
    static constexpr uint32_t kHoldUpdateIntervalMs = 16; // ~60fps periodic hold overlay update
    struct PendingHold {
        ScreenPoint pt{};
        int button;
        bool active = false;
    } pendingHold_{};
    bool ignoreNextClick_ = false; // If hold triggered, ignore the subsequent click

    bool holdButtonDown_ = false;
    int holdTrackingButton_ = 0;
    uint64_t holdDownTick_ = 0;
    uint64_t lastInputCaptureRestartAttemptTickMs_ = 0;
    static constexpr uint32_t kInputCaptureRestartRetryMs = 1000;
    uint32_t inputCaptureTransientErrorCode_ = 0;
    uint64_t inputCaptureTransientErrorSinceTickMs_ = 0;
    static constexpr uint32_t kInputCaptureTransientErrorGraceMs = 1200;
    bool gpuFallbackNotifiedThisSession_ = false;
    std::unique_ptr<CommandHandler> commandHandler_;
    std::unique_ptr<DispatchRouter> dispatchRouter_;
    std::unique_ptr<IInputIndicatorOverlay> inputIndicatorOverlay_{};
    InputIndicatorWasmDispatchFeature inputIndicatorWasmDispatch_{};
    mutable std::mutex inputIndicatorWasmRouteStatusMutex_{};
    InputIndicatorWasmRouteStatus inputIndicatorWasmRouteStatus_{};
    mutable std::mutex mouseCompanionRuntimeStatusMutex_{};
    MouseCompanionRuntimeStatus mouseCompanionRuntimeStatus_{};
    InputAutomationEngine inputAutomationEngine_{};
    std::unique_ptr<IPetVisualHost> petVisualHost_{};
    std::string loadedPetModelPath_{};
    std::string loadedPetActionLibraryPath_{};
    std::string loadedPetEffectProfilePath_{};
    std::string loadedPetAppearanceProfilePath_{};
    bool petVisualPoseBindingConfigured_{false};
    bool petVisualPoseBindingAttempted_{false};
    bool petDragging_ = false;
    uint64_t petLastTickMs_ = 0;
    static constexpr uint32_t kPetClickMaxPressMs = 220;
    static constexpr double kPetClickMaxTravelPx = 10.0;
    static constexpr double kPetDragStartTravelPx = 1.0;
    static constexpr uint32_t kPetClickSuppressAfterScrollMs = 140;
    static constexpr uint32_t kPetScrollImpulseDurationMs = 720;
    static constexpr uint32_t kPetScrollImpulseDurationTestMs = 560;
    static constexpr uint32_t kPetVisualHoldEnterMs = 130;
    static constexpr uint32_t kPetVisualHoldEnterTestMs = 90;
    static constexpr double kPetVisualHoldStableSpeedThresholdPxPerSec = 24.0;
    static constexpr double kPetVisualHoldStableSpeedThresholdTestPxPerSec = 30.0;
    static constexpr uint32_t kPetVisualHoldSuppressAfterScrollMs = 720;
    bool petHasSmoothedCursor_ = false;
    double petSmoothedCursorX_ = 0.0;
    double petSmoothedCursorY_ = 0.0;
    ScreenPoint petLastDispatchPoint_{};
    bool petHasLastDispatchPoint_ = false;
    uint64_t petReleaseHoldUntilTickMs_ = 0;
    struct PetPrimaryPressState {
        bool active = false;
        ScreenPoint downPoint{};
        uint64_t downTickMs = 0;
        double maxTravelPx = 0.0;
        bool holdTriggered = false;
        bool releaseReady = false;
        uint64_t releaseTickMs = 0;
        uint32_t releasePressMs = 0;
        double releaseMaxTravelPx = 0.0;
    } petPrimaryPress_{};
    uint64_t petLastScrollTickMs_ = 0;
    struct PetClickStreakState {
        int streak = 0;
        uint64_t lastClickTickMs = 0;
        uint64_t lastUpdateTickMs = 0;
        float tintAmount = 0.0f;
    } petClickStreak_{};
    struct PetPointerMotionState {
        bool hasSample = false;
        ScreenPoint lastSamplePoint{};
        uint64_t lastSampleTickMs = 0;
        uint64_t lastEvalTickMs = 0;
        double moveSpeedPxPerSec = 0.0;
    } petPointerMotion_{};
    struct PetVisualPoseRuntimeState {
        float holdPulse = 0.0f;
        float followWalkPhase = 0.0f;
        float scrollFlapProgress = 1.0f;
        float scrollFlapDurationSec = 0.18f;
        float scrollFlapAmplitude = 0.35f;
        float queuedScrollFlapDurationSec = 0.18f;
        float queuedScrollFlapAmplitude = 0.35f;
        uint32_t pendingScrollFlapCount = 0;
        uint64_t lastScrollEventTickMs = 0;
        uint64_t lastTickMs = 0;
    } petVisualPoseRuntime_{};
    bool runtimeDiagnosticsEnabled_ = false;
    mutable ShortcutCaptureSession shortcutCaptureSession_{};
    MouseCompanionPluginHostPhase0 petPluginHostPhase0_{};
    MouseCompanionPluginHostV1 petPluginHostV1_{};
    static constexpr size_t kWasmEffectsHostCount = 6;
    std::array<std::unique_ptr<wasm::WasmEffectHost>, kWasmEffectsHostCount> wasmEffectHosts_{};
    std::unique_ptr<wasm::WasmEffectHost> wasmIndicatorHost_{};
    bool vmEffectsSuppressed_ = false;

#ifdef _DEBUG
    uint32_t debugClickCount_ = 0;
#endif
};

} // namespace mousefx
