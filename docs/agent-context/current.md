# Agent Current Context (P1, 2026-03-23)
## Purpose
- This file is the compact daily execution truth: keep only active contracts, current boundaries, and route pointers.
- Move implementation history and detailed rollout notes to P2 docs.
## Scope And Priority
- Primary host: macOS.
- Delivery order: macOS first, Windows regression-free, Linux compile/contract-level.
- macOS stack rule: new capability modules are Swift-first; avoid expanding `.mm` for large new modules.
- Cross-machine workflow: macOS is the development source, Windows is the synced validation workspace via `Syncthing`, and Windows-side command execution should default to direct SSH against `F:\language\cpp\code\MFCMouseEffect`.
## Active Product Goals
- Keep wasm runtime bounded-but-expressive with host-owned render boundaries.
- Keep plugin lanes decoupled (`effects` vs `indicator`) with explicit diagnostics.
- Keep automation mapping accurate and observable with low regression risk.
- Rebuild `mouse_companion` on a plugin-first route with click-first visible parity.

## Capability Snapshot
### Visual Effects / WASM
- `click / trail / scroll / hold / hover` are active in `core`.
- New additive lane `cursor_decoration` is active as the sixth built-in channel under `Cursor Effects`. Native fallback tuning still persists under `input_indicator.cursor_decoration`, while `Effect Plugins` now binds a real sixth WASM lane through `wasm.manifest_path_cursor_decoration` instead of mirroring built-in preset ids. Official sample bundles now include `focus-ring / soft-orb / halo-orb` cursor-decoration plugins.
- Shared command tail (`blend_mode / sort_key / group_id`) is active.
- Group-retained model is active; transform/material/pass remain host-owned.
- Windows blacklist routing root fix is active: pointer suppression resolves the process at the current screen point first, and trail synthetic-follow is limited to a short post-input smoothing window.
- Trail slow-move continuity is reinforced: trail/particle now keep the last emitted anchor (so sub-threshold moves accumulate instead of resetting), and the throttle baseline is lighter (`minDistancePx≈2`, `minIntervalMs≈8`; particle is even lighter) to avoid broken segments during slow cursor motion.
- Scroll direction/render contract is now shared across Windows/macOS: scroll dispatch preserves horizontal-axis metadata, vertical `delta>0` always means visual up, horizontal `delta>0` means visual right, and both platforms reuse the same scroll profile builder so arrow/helix/twinkle size/style stay aligned.
- VM foreground auto-suppression is retired on Windows/macOS: VMware/VirtualBox foreground windows no longer hard-stop effects outside the user blacklist, so virtualization tools now follow the same `effects_blacklist_apps` policy as every other app.
- Cross-platform click ripple baseline is active: Windows now honors `EffectConfig.ripple`; default click is shorter, smaller, center-clear, softer-glow, and single-ring.

### Keyboard & Mouse Indicator
- macOS/Windows label and streak semantics are aligned (`L xN`, `W+ xN`); indicator wasm dispatch has dedicated lanes, auto-inferred surface loading, immediate runtime sync on apply, and clean native fallback on missing/stale manifests.
- macOS cursor-decoration visibility is now native too: `MacosInputIndicatorOverlay::OnMove(...)` drives a retained Swift decoration panel, so `ring / orb` now visibly follow the cursor head on mac instead of being Windows-only.

### Plugin Management / WebUI
- Unified top-level `Plugin Management` section is active, and sidebar order is now: `General -> Mouse Companion -> Cursor Effects -> Keyboard & Mouse Indicator -> Automation Mapping -> Plugin Management`
- Settings shell navigation is now top-oriented instead of left-sidebar-first: header/title stays on the first row, section navigation is a horizontal tab strip under it, and the long status message area shares a dedicated action bar with `Star / Reset / Stop / Reload / Apply` so wide sections such as `Automation Mapping` can use the full content width.
- The settings shell now uses an integrated, low-noise `header -> status -> tabs -> content` frame: tabs no longer carry automation diagnostics, the old current-section label/title block has been removed, the active-section description remains as a compact single-line hint, the automation debug card now renders inside the main content column as a collapsed-by-default summary strip (`title + stage + reason`), and once expanded it switches to a `left canvas + right diagnostics panel` layout with recent logs kept behind disclosures instead of an always-expanded wall of diagnostics, the header subtitle is compressed to a single metadata line, `Apply` remains the only high-weight solid button, the other header actions are now icon-first with a shared inline-SVG icon set and lighter/ghosted styling, the status bar now stays thinner in the default short-text state while still expanding for long diagnostics, section sub-tabs remain visibly lighter than the top-level navigation, and automation scope chips now force a fixed circular remove button (`18px` square + `×`) so pills such as `code.app` no longer stretch into ovals.
- WebUI apply flow is backend-state-driven (`post-apply reconcile + refresh`).
- `WebUIWorkspace` source-mode dev is now owned by `--debug`: `./mfx fast --debug` (or `./mfx start --debug` when a fresh native rebuild is required) starts the macOS host first, launches/reuses the Vite dev server, prints the Vite URL with the current token, and proxies `/api/*` back to the live host. `./mfx start` remains the release-near static validation path. `./mfx start` and `./mfx start --debug` do not open the browser automatically; use `--open` for an explicit browser launch.
- `./mfx * --debug` is now treated as a long-lived dev session instead of a short smoke run: when the user does not pass `--minutes/--seconds`, the core host no longer auto-stops after 30 minutes, so an editing session does not silently fall into `502 fetch failed` / empty plugin catalog / dead apply-reload state just because the backend aged out while Vite stayed open.
- The macOS manual core-host launcher must detach the host process from the invoking shell session (`launchctl submit` on macOS, fallback detached stdio otherwise) before reporting the probe URL; otherwise the native host can disappear as soon as the wrapper command exits even though Vite remains open.
- Timed macOS manual runs must submit a matching `launchctl` stopper job for auto-stop; a shell background sleeper can disappear with the wrapper, and killing only the child pid can leave launchd-managed debug smoke sessions alive after `--seconds/--minutes`.
- `Automation Mapping` must stay Vite-dev-safe end to end: the editor no longer calls Svelte 5 exported methods through `instance[name]()` and instead exposes plain `read/validate` closures via `onReady(api)`, mapping row add/remove/change/template actions now stay on one standard component-event channel (no mixed callback+event bridge), and the live-debug summary/card mount re-syncs through `syncMountedComponent(...)` with a short dev-only deferred refresh so `Apply`, `Reload`, row mutations, and `./mfx start --debug` keep using the latest debug-panel layout without private-field or stale shell/HMR mounts.
- Static WebUI builds now inline Svelte component CSS into each generated section bundle during `vite build`; the desktop runtime still links a single `WebUI/styles.css`, so extracted `dist/*.svelte.css` files caused `Automation Mapping` / workspace layout refinements to appear in `pnpm run dev` but disappear in compiled settings builds.
- Vite `/api/*` proxy forwarding in source-mode debug now buffers request bodies before `fetch(...)` forwarding. Passing raw Node request streams to Undici can surface `{"ok":false,"error":"terminated"}` on `POST /api/reload` and `POST /api/state`; buffered forwarding keeps `Apply/Reload` stable in `--debug`.
- Vite dev proxy now also injects `X-MFCMouseEffect-Token` from the probe runtime when the client omits it, so dev helpers that only carry `?token=` won't silently trip backend authorization.
- `tools/platform/manual/run-webui-dev-manual.sh` now starts Vite through `launchctl submit` on macOS, records the actual Vite child pid after startup, and proactively stops stale workspace Vite instances before relaunch. This prevents stacked `5173/5174/5175` dev servers from surviving across debug restarts and keeps the opened `--debug` page aligned with the current probe/backend.
- `/__mfx/dev-runtime` must verify the live backend with `/api/state` before reporting `available=true`, and the WebUI dev helper must wait for that runtime-ready state before printing `web_browser_url`; a stale probe file alone is not enough to boot the Vite UI.
- Automation row add/remove/template mutations in source-mode dev now use direct callback props again, and the editor side accepts both plain detail objects and `CustomEvent.detail` payloads so Svelte 5 compatibility wrappers cannot turn `kind` into `undefined`.
- WASM plugin panels now self-issue the first catalog scan on mount and can fall back to direct `/api/wasm/*` calls with the page token when the higher-level `onAction` bridge is temporarily unavailable in Vite dev.
- `/api/wasm/policy` must forward `manifest_path_cursor_decoration` alongside the other five effect-lane keys; otherwise the `Effect Plugins -> Cursor Decoration` toggle will look disabled briefly but snap back on after Apply/refresh because the binding never actually clears.
- When the `cursor_decoration` WASM lane is loaded and enabled, native cursor-decoration fallback must stay suppressed on both Windows and macOS overlays; only one of the two renderers may own that lane at a time.
- Built-in native cursor decoration must also obey the app blacklist at the current pointer point. `DispatchRouter::OnMove(...)` must sync blacklist state into `IInputIndicatorOverlay` before any native cursor-decoration `OnMove(...)` render path runs; otherwise the persistent overlay can leak into blocked apps even while the five main effect lanes are correctly suppressed.
- `cursor_decoration` no longer ships a standalone WebUI entry bundle, and its channel dropdown now derives the trailing disabled label from the same localized option set as the built-in plugins, so Chinese pages show `无` and English pages show `None` without relying on `document.lang`.
- `section-workspace` is now mount-order tolerant with bounded retry: if `settings_grid` cards are not yet collectable on first pass, it performs short timed retries and temporarily reveals cards instead of binding a long-lived subtree observer.
- Settings launch lifecycle is shared through `WebSettingsLaunchCoordinator`; platform shells still keep their own `OpenUrlUtf8(...)`.
- `WebSettingsLaunchCoordinator` destructor must stay out-of-line while `WebSettingsServer` is forward-declared, otherwise libc++/clang host builds can fail on incomplete-type `unique_ptr` destruction.
- POSIX/mac host runtime source lists must explicitly carry `WebSettingsLaunchCoordinator.cpp`, `PetVisualAssetCoordinator.cpp`, `MouseCompanionRendererBackendDiagnostics.cpp`, and `PlatformPetVisualHost.cpp`; missing any of them can surface as arm64 link failures during `./mfx run`.
- When `mouse-companion` is the initially visible section and it has not rendered yet, `settings-form.js` now defers the first Mouse Companion render to the next animation frame to reduce first-paint blocking.

### Mouse Companion
- Backend reset remains in effect; old skeleton runtime stays removed.
- Plugin-first landing route is active (`Phase0 -> Phase1 -> Phase2`).
- Shared `IPetVisualHost` + `PlatformPetVisualHost` abstraction is the stable cross-platform visual-host seam.
- Any Windows renderer runtime diagnostic field added in `IWin32MouseCompanionRendererBackend.h` must be mirrored in `IPetVisualHost.h` in the same change; otherwise `AppController.Lifecycle.cpp` and `Win32MouseCompanionVisualHost.cpp` will fail at compile time on Windows.

#### Windows Pet
- Current stage: `Phase1.5`.
- Current gap vs macOS: Windows still renders a stylized preview contract, not the real 3D model path, though the asset chain now reaches `scene-hook -> scene-binding -> node-attach -> node-lift -> node-bind`.
- Shared placement contract is active: `relative`, `absolute`, legacy `fixed_bottom_left`, `strict / soft / free`, and target-monitor resolution.
- Active backend path: `window -> backend factory/registry -> renderer input -> renderer runtime -> scene builder -> painter`.
- Windows appearance validation supports:
  - built-in `activePreset` values in `pet-appearance.json`
  - dedicated combo-only synced JSONs for receive-only Windows validation
  - runtime diagnostics for `appearance_requested_preset_id / appearance_resolved_preset_id / appearance_skin_variant_id / appearance_accessory_family / appearance_combo_preset`
- Combo-persona acceptance is explicit:
  - first set is `cream+moon`, `night+leaf`, `strawberry+ribbon-bow`
  - acceptance should be recorded as `pass (dynamic-biased)` when static readability is weaker than dynamic readability
  - native `.cmd`, PowerShell, and Git Bash paths are aligned

#### Windows Pet Renderer / Plugin Lane
- `Win32MouseCompanionRenderPluginHost` is the current Windows-first seam for renderer-owned appearance/persona semantics.
- Stable provider today is still `builtin native`.
- Windows renderer-plugin env entry: `MFX_WIN32_MOUSE_COMPANION_RENDER_PLUGIN`, `MFX_WIN32_MOUSE_COMPANION_RENDER_PLUGIN_WASM_MANIFEST`
- wasm request contract:
  - manifest must target `effects`
  - manifest must enable `frame_tick`
  - failure falls back to builtin immediately
- wasm preflight/load failures are normalized to machine-readable codes; do not depend on free-form text in tests.
- Optional sidecar metadata path is `<manifest>.mouse_companion_renderer.json`.
- Sidecar must declare `schema_version >= 1`, `renderer_lane = mouse_companion_renderer`, `supports_appearance_semantics = true`, and `appearance_semantics_mode = builtin_passthrough|wasm_v1`.
- Runtime plugin diagnostics surface plugin id/kind/source, selection/failure reason, manifest/runtime backend, metadata path/schema, and appearance semantics mode.

#### Windows `wasm_v1` Semantics Summary
- `builtin_passthrough` keeps host-generated semantics and only accepts bounded tuning plus optional `combo_preset_override`.
- `wasm_v1` is the first bounded renderer-owned semantics patch lane.
- `wasm_v1` host apply order is fixed:
  - `theme`
  - `shape` (`frame / face / appendage`)
  - `motion`
  - `mood`
- Current `wasm_v1` patch categories:
  - `theme`: glow/body/head/accent/accessory/pedestal color family
  - `shape`: body/head proportions, muzzle/forehead/whisker detail, ear/tail/follow-ear/click-ear detail
  - `motion`: `follow / click / drag / hold / scroll` main action multipliers
  - `mood`: glow/accent/shadow/pedestal tinting and alpha lanes, plus `hold / drag / scroll / follow` overlay emphasis
- Current design intent:
  - keep the lane bounded and host-owned
  - prefer adding high-value fields over reopening builder-local hardcoding
  - do not turn `wasm_v1` into an unrestricted free-form renderer ABI yet
- Checked-in `wasm_v1` sidecar samples are now also curated by readability intent:
  - default sample: balanced default-candidate baseline
  - agile sample: cooler / sharper `follow / drag`
  - dreamy sample: brighter / floatier `follow / scroll`
  - charming sample: rounder / warmer `click / hold`
- checked-in sidecars now declare `style_intent` and `sample_tier`, and `wasm_v1` also covers `face.brow_tilt_scale / mouth_reactive_scale`, `appendage.follow_leg_stance_scale / hold_leg_stance_scale / drag_hand_reach_scale`, `motion.body_forward_scale`, and `mood.pedestal_tint_mix_scale / click_ring_alpha_scale`, so host/runtime no longer rely only on combo-preset inference and `follow / drag / hold / click` gain stronger structure + mood readability on Win pet.

#### Windows Bring-Up / Validation
- Dedicated native validation entrypoints exist for combo-persona acceptance, renderer-sidecar smoke, renderer-sidecar `wasm_v1` smoke, and renderer lane matrix (`builtin -> builtin_passthrough -> wasm_v1`).
- Renderer lane matrix now also accepts `-WasmV1Style default|agile|dreamy|charming`, so the third lane can switch between the checked-in curated `wasm_v1` samples without manual sidecar replacement.
- Renderer lane matrix now also accepts `-AllWasmV1Styles`, which expands the third lane into `wasm_v1_default / wasm_v1_agile / wasm_v1_dreamy / wasm_v1_charming` and emits separate proof artifacts for each style.
- Checked-in samples exist at `tools/platform/manual/lib/windows-mouse-companion-renderer-sidecar.sample.json` and `tools/platform/manual/lib/windows-mouse-companion-renderer-sidecar.wasm-v1.sample.json`.
- Lane matrix now emits per-lane proof json plus `summary.json`, `summary.md`, and `observation-template.md`; summary also emits:
  - compact lane verdicts
  - per-lane default-lane snapshots
  - per-lane configured sample metadata
  - per-lane runtime sample-tier snapshot
  - compare-vs-builtin summary
  - per-lane `style` + `style_focus_profile`
  - conservative `recommended_default_lane`
  - `recommendation_style_intent` / `recommendation_style_focus_profile` / `recommended_sample_path`
  - `rollout_contract_status`
- Default lane rollout contract: machine summary may nominate a candidate, but actual default switch still requires later manual confirmation.
- Runtime diagnostics now expose both lane and scene-runtime state directly: `default_lane_candidate / source / rollout_status / style_intent / candidate_tier`, `appearance_plugin_sample_tier`, `appearance_plugin_contract_brief`, plus `scene_runtime_adapter_mode / pose_sample_count / bound_pose_sample_count / model_asset_source_brief / model_asset_manifest_brief / model_scene_adapter_brief / model_node_adapter_influence / model_node_adapter_brief / pose_adapter_influence / pose_readability_bias / pose_adapter_brief`; adapter modes are fixed to `runtime_only | pose_unbound | pose_bound`.
- `pose_bound` is now visible across appendage, motion/head-body, frame/face anchors, overlay/grounding, and painter readability: beyond geometry, it can also raise shadow/pedestal alpha, strengthen accessory stroke/fill, and make pose badges/overlays read more confidently than `runtime_only / pose_unbound`.
- That same pose-adapter profile is now surfaced through runtime, `/api/state`, test routes, WebUI Runtime Diagnostics, render-proof, and lane matrix, so later 3D-model bring-up can judge pose-lane consumption from one shared contract instead of scattered raw fields; `render-proof` can now also assert adapter mode / brief / minimum influence / minimum readability directly.
- `SceneRuntime` now owns the shared `poseAdapterProfile`; builders and backend diagnostics consume that cached profile directly instead of recomputing influence/readability per file, which keeps the upcoming model-driven seam on one adapter contract.
- `SceneRuntime` now also owns `modelSceneAdapterProfile`, exposing `seamState / seamReadiness / brief`; this lets Windows real preview report whether a frame is still preview-only, merely asset-stub-ready, already pose-sampling-ready, or pose-bound-preview-ready for later model-node consumption.
- `SceneRuntime` now also owns `modelNodeAdapterProfile`, so frame/face/adornment/overlay/grounding consume one cached node-offset seam instead of recomputing local pose averages; runtime/proof/matrix/WebUI surface `scene_runtime_model_node_adapter_influence`, `scene_runtime_model_node_adapter_brief`, and `scene_runtime_model_node_channel_brief`.
- `SceneRuntime` now also owns `modelAssetSourceProfile`, `modelAssetManifestProfile`, `modelAssetCatalogProfile`, `modelAssetBindingTableProfile`, `modelAssetRegistryProfile`, `modelAssetLoadProfile`, `modelAssetDecodeProfile`, `modelAssetResidencyProfile`, `modelAssetInstanceProfile`, `modelAssetActivationProfile`, `modelAssetSessionProfile`, `modelAssetBindReadyProfile`, `modelAssetHandleProfile`, and `modelAssetSceneHookProfile`, so Windows real renderer now walks `source -> manifest -> catalog -> binding table -> registry -> load -> decode -> residency -> instance -> activation -> session -> bind-ready -> handle -> scene-hook` before the old preview-only node chain: runtime/proof/matrix/WebUI now surface matching `scene_runtime_model_asset_*` diagnostics through `scene_hook_*`, and the backend already lets those profiles bias glow/stroke/highlight/overlay/grounding/anchor readability instead of keeping them diagnostic-only.
- `SceneRuntime` now also owns `modelNodeGraphProfile`, `modelNodeBindingProfile`, and `modelNodeSlotProfile`, so Windows preview already walks `node channel -> node graph -> binding entry -> slot` before painter geometry; runtime/proof/matrix/WebUI surface `scene_runtime_model_node_graph_*`, `scene_runtime_model_node_binding_*`, and `scene_runtime_model_node_slot_*`.
- `SceneRuntime` now also owns `modelNodeRegistryProfile` and `assetNodeBindingProfile`, lifting slots into stable future asset-node names and paths; runtime/proof/matrix/WebUI surface `scene_runtime_model_node_registry_*` and `scene_runtime_asset_node_binding_*`, while frame/adornment/overlay already consume registry/binding weight.
- Windows pet mainline intentionally rolled back the experimental native 3D bring-up on 2026-03-24: `glb` parsing, node-match/proxy/mesh layers, and the later `driver/consumer/projection/realization/materialization/presentation/visibility/presence/occupancy` seam expansion are no longer part of the shipping branch. The stable Windows contract remains the existing stylized preview path plus the cross-platform `IPetVisualHost` / `PlatformPetVisualHost` / model-action-appearance input seams, so future 3D work should restart from a separate implementation track instead of continuing on the removed native experiment.
- `SceneRuntime` now also owns `assetNodeTransformProfile` and `assetNodeAnchorProfile`, lifting asset-node paths into a minimal transform table and then shared `body/head/appendage/overlay/grounding` anchors; frame/face/adornment/overlay now consume those shared seams and runtime/proof/matrix/WebUI surface both `scene_runtime_asset_node_transform_*` and `scene_runtime_asset_node_anchor_*`.
- `SceneRuntime` now also owns `assetNodeResolverProfile` and `assetNodeParentSpaceProfile`, lifting those local transforms into shared parent-aware node tables before anchor generation; frame/face/adornment/overlay now consume resolver/parent-space seams instead of re-deriving hierarchy drift locally, and runtime/proof/matrix/WebUI surface `scene_runtime_asset_node_resolver_*` and `scene_runtime_asset_node_parent_space_*`.
- `SceneRuntime` still keeps `assetNodeTargetProfile` and `assetNodeTargetResolverProfile` as the last stable Windows asset-node seam before anchor generation; later experimental post-target chains were removed with the native 3D rollback, so downstream work should treat target-resolver + anchor/world-space as the current ceiling of the Windows preview path.
- Sidecar smoke presets now also assert `default_lane_style_intent` and `appearance_plugin_sample_tier`; lane-matrix recommendation prefers runtime `default_lane_candidate_tier`, then `sample_tier`, then `default_lane_style_intent`, and `observation-template.md` stays on the same contract vocabulary as runtime/summary.
- `default_lane_candidate_tier` uses short machine values such as `builtin_shipped_default`, `baseline_reference_candidate`, `ship_default_candidate`, and `experimental_style_candidate`; lane matrix also derives `style_focus_profile` such as `balanced_all_rounder`, `follow_drag_tension`, `follow_scroll_float`, and `click_hold_warmth`.
- Mouse Companion WebUI mirrors runtime lane state in `Runtime Diagnostics`, including a short `Lane Verdict`, `Style Intent`, `Candidate Tier`, `Sample Tier`, and `Contract Brief`.

#### Windows Renderer Backend / Preview
- Backend selection diagnostics are active for preference source/name, selected backend, selection/failure reasons, available/unavailable backends, backend catalog, `real_renderer_preview`, and `renderer_runtime_*`.
- Backend lifecycle seam treats `Start() / IsReady() / LastErrorReason()` as first-class fallback signals.
- Placeholder backend remains the always-ready reference implementation.
- `real` backend is no longer an active mainline delivery target after the native 3D rollback; keep it treated as a non-default experimental seam rather than a feature path to extend in-place.
- Real-preview dynamic readability is already stronger:
  - `dreamy` biases `follow` toward lighter lift and softer grounding
  - `agile` biases `drag/follow` toward sharper lean and reach
  - `charming` biases `hold/click` toward rounder bounce and softer face/ear response
- Current boundary:
  - visible backend is stable enough for `Phase1.5`
  - the main Windows vs macOS gap is still renderer form factor, not appearance-lane plumbing
  - future real-renderer work should stay behind existing backend/runtime seams

#### macOS Pet
- macOS Phase1 visual host is active:
  - model-first with placeholder fallback
  - `.usdz` preferred when SceneKit can load it
  - runtime action updates are forwarded (`idle / follow / click_react / drag / hold_react / scroll_react`)
- Shared placement contract is active: `relative`, `absolute`, legacy aliases, `strict / soft / free`.
- Runtime `size_px` resize path is active and no longer create-time-only.
- Idle/follow/click/scroll parity direction is active; remaining known boundary is `.usdz` framing on some paths.
### Automation Mapping
- App-scope normalization/parser contracts are stable.
- Automation scope candidate props must reference `appCatalogEntries` directly in template expressions when passed into child panels; otherwise Svelte may miss the async catalog dependency and the right-side app list can stay on the initial empty snapshot until some row-local state changes.
- Mouse action mapping now separates `执行动作 / Next trigger` as two explicit UI sections inside each rule, uses eyebrow text as `流程角色` instead of repeating titles, adds a visible connector between sections, and renames the chain-adder copy to `添加下一步鼠标动作` so trigger nodes no longer read like peer action cards.
- Mapping output config now uses `actions[]`; current executable actions are `send_shortcut`, `delay`, `open_url`, and `launch_app`, WebUI exposes a first-round action list editor for those four action types, and the current visual refresh now aligns both mouse and gesture mapping on the same card-based language with de-bordered section panels, keycap-like shortcut inputs, hover-revealed action tool icons, stronger recording-state emphasis, and header-integrated ghost delete actions while keeping mouse `blue` and gesture `teal` as separate recognition accents.
- Preset/custom gesture mapping with thresholding and ambiguity rejection is active.
- `Draw -> Save` custom gesture flow is active.
- macOS shortcut capture/injection punctuation path is aligned.
- Automation live-debug now defaults to a collapsed summary entry above the mapping cards; expanding it reveals a `observational data panel on the left + large gesture canvas on the right` layout (sidebar: matched gesture, reason, stage, trigger, modifiers, candidates, runner-up, recent events/action runs; canvas: recognized gesture hero drawing) with recent events and recent action runs folded behind disclosures.

## Observability And Debug Contract
- Runtime diagnostics are gated by debug mode where required.
- Default non-debug run avoids high-volume debug lanes.
- WebUI debug polling is adaptive and focus-aware.
- Mouse companion test route remains gated behind `MFX_ENABLE_MOUSE_COMPANION_TEST_API=1`; `Shipping|x64` keeps the main runtime/WebUI path but excludes `/api/test` compilation, skips the heavy `/api/state` render-proof/lane-matrix diagnostics composition, and now also strips the large Windows mouse-companion scene/runtime verbose contract from `AppController`, `IPetVisualHost`, and `IWin32MouseCompanionRendererBackend` after the core readiness/action booleans, so `*_brief / *_value_brief / *_path_brief` plus lane-style contract strings no longer compile into the shipping executable.
- `Shipping|x64` must exist on both Windows build projects, any `MFX_SHIPPING_BUILD` runtime-contract trim must guard the matching `AppController` reset/sync/dispatch assignments, and `MouseFx/Server/routes/testing/WebSettingsServer.TestApiRoutes.cpp` must stay compiled as the linkable `/api/test` stub; otherwise `./mfx build --shipping` will fail on `MSB8013`, removed-member errors, or a missing `HandleWebSettingsTestApiRoute` symbol.

## Regression Gates
- Canonical regression entry: `./tools/platform/regression/run-posix-regression-suite.sh --platform auto`
- macOS daily shortcut: `./mfx run-no-build` / `./mfx fast` skip both core and WebUI rebuilds; `./mfx run` / `./mfx start` perform fresh build preparation; adding `--debug` starts the Vite source-mode dev UI after the host while preserving that host build policy.

## Packaging / Startup Truth

### Tray Menus
- macOS tray menu intentionally exposes only `Star Project`, `Settings`, and `Exit`.
- Windows tray menu now follows the same product rule.

### Launch At Startup
- macOS: LaunchAgent uses `tray` mode, explicit toggle rewrites plist and applies `launchctl`, normal startup repairs plist only.
- Windows: uses `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run`, and current executable path is rewritten idempotently so relocation can self-heal.

### Packaging
- Preferred Windows user entrypoints now stay inside `./mfx`:
  - `./mfx build`
  - `./mfx build --shipping`
  - `./mfx build --gpu`
- macOS `./mfx build` is now a real first-class entrypoint again: it rebuilds `WebUIWorkspace` by default, configures the macOS core-host build with the same `mfx_entry_posix_host` contract used by manual/package flows, and accepts `--build-dir`, `--jobs`, and `--skip-webui-build` instead of falling through to the old Windows-only unsupported-path regression.
- Preferred packaging entrypoint is `./mfx package`.
- Windows installer remains Inno Setup based.
- `./mfx package` now reuses the same Windows build contract as `./mfx build`, and `--shipping` forwards `BuildConfiguration=Shipping` into Inno Setup so Windows compile/package no longer depend on raw MSBuild as the primary user-facing entrypoint.
- Windows Release/Shipping now supports build-time GPU selection through `MfxEnableWindowsGpuEffects=true|false`, and the default is now `false`:
  - `true`: compile/package the current GPU hold runtime and bundle `webgpu_dawn.dll`
  - `false` (default): exclude Windows GPU hold compile units, hide GPU-only hold choices, normalize old GPU hold configs to compatible non-GPU routes, and omit `webgpu_dawn.dll` from build output + installer payload
- Windows package naming now reflects both configuration and GPU variant: `Release` keeps `MFCMouseEffect-windows-x64-setup-<version>.exe`, `Release --gpu` switches to `...-gpu-setup-...`, `Shipping` uses `...-shipping-setup-...`, and `Shipping --gpu` uses `...-gpu-shipping-setup-...`.
- macOS package output remains `MFCMouseEffect.app`, `Install/macos`, folder + `.zip` + unsigned `.dmg`.
- Current package policy: minimal pet runtime assets only, wasm demo plugin ships runtime files only, packaged host binary is stripped in-bundle, `Install/macos/` is git-ignored, and Gatekeeper/notarization is still deferred.
### Local Dev Sync
- Repository root carries a Syncthing-focused `.stignore`; root build/cache ignores should stay root-anchored (`/x64`, `/Win32`, `/Debug`, `/Release`, `/build`, `/out`, etc.) so similarly named source paths under `tools/` are not suppressed.
- Windows-side build/package/log commands should be handled through direct SSH from macOS by default; no synced manual handoff file is maintained for normal command steps.
- Build outputs, IDE caches, package outputs, dependency caches, and generated `docs/.ai` maps should stay local.
## Contracts That Must Not Drift
- Keep stdin JSON command compatibility.
- Keep current wasm ABI compatibility unless migration is explicitly approved.
- Keep host-owned bounded rendering strategy; no raw shader ownership without architecture approval.
- Keep docs synchronized in the same change set for every behavior or contract change.

## P2 Routing
- P2 index: `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/p2-capability-index.md`
- Windows pet / plugin / checklist: `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/windows-mouse-companion-real-renderer-contract.md`, `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/mouse-companion-plugin-landing-roadmap.zh-CN.md`, `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/ops/windows-mouse-companion-manual-checklist.md`
- Server / regression: `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/server-structure.md`, `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-regression-suite-workflow.md`
