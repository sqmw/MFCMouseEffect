# Full Project Audit — 2026-07-15

## Situation

- Scope: tracked first-party C++/Swift/WebUI/shell/build/package/docs surfaces (about 1,556 code or script files), with targeted review of lifecycle, platform boundaries, release paths, and generated WebUI assets. Vendored wasm3 and `json.hpp` were inventoried but excluded from first-party refactor findings.
- Boundary: read-only audit. No production behavior was changed.
- Severity: P0 is a confirmed use-after-free/crash path; P1 is a material reliability, release, or resource-exhaustion risk; P2 is planned structural/security/UX debt; P3 is hardening.

## Task

Assess whether the current architecture can safely sustain new capability work under the repository rules: explicit ownership, low coupling, synchronized docs, reproducible cross-platform delivery, and one main TODO.

## Action

- Reviewed C++/Swift lifetimes, detached workers, queue/timer shutdown, retained WASM state, platform includes, WebUI source/output flow, build/package scripts, sync rules, and active documentation.
- Ran the non-mutating local gate: `make audit` passed. It ran `git diff --check`, AI-context/doc hygiene checks, and 11 WebUI model/dev-contract test groups. Doc hygiene correctly warned that `docs/agent-context/current.md` is above its P1 line budget.
- Configured the macOS core-runtime CMake lane successfully with AppleClang 21 and Swift 6. Full `make check`, native macOS build/run, and Windows build/run were intentionally not run here because the project classifies them as high-load or Windows-host work.

## Result

### Overall assessment

The project has meaningful strengths: thin Make entrypoints, a loopback-and-token settings-server baseline, many targeted regression scripts, clear intent to abstract platform services, and a documentation/index workflow. However, three confirmed ownership defects can dereference freed memory, and the delivery chain still depends on local generated state and stale Windows assumptions. Treat P0 work as a release blocker and freeze further expansion of the affected lifecycle paths until it is resolved.

| Priority | Finding | Evidence | Required direction |
| --- | --- | --- | --- |
| P0 | Detached stdin IPC can outlive both `IpcController` and `AppShellCore`. | `MouseFx/Core/Control/IpcController.cpp:15-55` starts a raw-`this` worker then detaches it; `MouseFx/Core/Shell/AppShellCore.cpp:386-399,412-427` captures shell state and resets it during shutdown. Later stdin input or EOF can access freed state. | Use cancellable input/wakeup plus join before destruction; add an ASan regression for open stdin -> shutdown -> input/EOF. |
| P0 | macOS mouse-companion async callbacks can use a released raw Swift handle. | `Platform/PlatformPetVisualHost.cpp:36-43,70-74` queues hide then releases; `MouseFx/Core/Control/AppController.Lifecycle.cpp:2048-2053` does this twice; the Swift bridge uses `takeUnretainedValue()` in async hide/pose paths at `Platform/macos/Pet/MacosMouseCompanionPhase1Bridge.swift:2684-2707,2736-2785,2979-3029`. | Replace raw retained pointers with a main-actor registry/opaque ID and generation token; stop producers and drain/cancel queued work before release. |
| P0 | Web settings shutdown detaches a lambda holding `this`. | `MouseFx/Server/core/WebSettingsServer.TokenMonitor.cpp:58-63`; the exit route reaches it through `WebSettingsServer.Routing.cpp:15-20`, while `WebSettingsLaunchCoordinator.cpp:24-28` immediately resets the server. | Move shutdown ownership to a joinable host executor/event-loop route and preserve the HTTP-handler self-join constraint. |
| P1 | macOS dispatch host cannot safely converge concurrent `SendSync`, timer creation, and destruction. | `Platform/macos/Control/MacosDispatchMessageHost.Messaging.cpp:12-33,47-71`, `MacosDispatchMessageHost.cpp:32-49`, and `MacosDispatchMessageHost.Timers.cpp:25-47,80-103` can leave promises unresolved or a timer using `this` before its slot is registered. | Introduce a lifecycle state machine and one timer/event queue; cancel/complete all sync requests before joining; add TSAN race tests. |
| P1 | Retained WASM group state is unbounded across frames. | `WasmGroupClipRectRuntime.h:90-110`, `WasmGroupLocalOriginRuntime.h:48-63`, `WasmGroupPresentationRuntime.h:49-64`, and `WasmGroupLayerRuntime.h:53-70` upsert arbitrary IDs; per-call limits in `WasmEffectHost.Invoke.cpp:175-214` do not bound accumulated state. | Add per-plugin/surface group and retained-instance quotas, TTL/LRU cleanup, structured rejection diagnostics, and an adversarial contract test. |
| P1 | WebUI bundle and package contents are not deterministic. | `WebUIWorkspace/scripts/clean-dist.mjs:8-9` only clears `dist`; `copy-output.mjs:11-23,68-72` does not remove retired output; ignored stale bundles remain in `WebUI`; macOS packaging copies the whole directory at `tools/platform/package/build-macos-portable.sh:182`. The core resolver still requires a retired cursor-decoration bundle at `MouseFx/Server/webui/WebSettingsServer.WebUiPathResolver.cpp:47-56`. | Define one generated bundle manifest shared by Vite, resolver, index, copy, and package staging; add a clean-room build/index/package assertion. |
| P1 | A visible WebUI localization regression is present. | `WebUIWorkspace/src/effects/EffectsBlacklistFields.svelte:47-52` reads nonexistent `window.MfxI18n`; runtime registers `MfxWebI18n` and `MfxI18nRuntime` instead. | Route text through the existing i18n adapter/props and add an English/Chinese regression before changing the visible behavior. |
| P1 | Windows delivery and source sync do not match current verified environment facts. | `tools/platform/build/build-windows-project.sh:39-55` only searches Professional/Insiders, while the global environment source records Build Tools. `.stignore:12-30` misses nested WebUI `node_modules`, `dist`, and generated bundles, despite local-only policy. Project docs still contain obsolete `F:` paths. | Detect MSBuild with `vswhere`/environment/multiple editions, document supported shells, add precise sync ignores, then perform an actual current-Windows build and smoke run. |
| P1 | There is no clean-environment CI/release trust chain. | No repository CI configuration was found; `make check` omits Windows native validation. Windows and macOS package versions are separately hard-coded, and signing/notarization is deferred. | Establish a minimum CI matrix first, then a single version source, tag/commit/artifact-hash mapping, and an explicit signing/notarization product decision. |
| P2 | Core and UI boundaries are already overloaded. | `AppController.h` is 1,274 lines and spans lifecycle, input, effects, WASM, automation, and pet runtime. `IPetVisualHost.h` mixes a stable control seam with large Windows-specific diagnostics. `mouse-companion-main.js` is 2,406 lines and the WebUI relies on script order plus `window.Mfx*` globals. | Before further feature work, propose a staged compatibility-preserving split: lifecycle ownership, `MouseCompanionCoordinator`, stable vs optional diagnostics capability, WebUI facade/state model, and narrow component contracts. |
| P2 | Local control-plane and accessibility hardening remain incomplete. | Settings token is placed in the launch URL (`WebSettingsServer.cpp:50-66`); POSIX capture files use predictable `.tmp` paths and default permissions (`Platform/posix/Shell/PosixKeyValueCaptureFile.cpp:22-59`). Dialog and tabs declare partial ARIA semantics without full keyboard/focus behavior. | Keep loopback/token baseline, then use stronger token/file handling and complete keyboard contracts; test those paths explicitly. |
| P2 | Documentation and quality governance have drifted from the global contract. | `AGENTS.md:58-60` and `docs/agent-context/current.md:9` use obsolete Windows paths; active docs contain long-lived absolute paths; `current.md` is 231+ lines vs its 220 target. | Convert active instructions to repository-relative/variable paths, route Windows facts to the global environment source, compact P1 context, and make line limits enforceable in CI when adopted. |
| P3 | Additional hardening: development error rendering uses `innerHTML`; third-party inventory/SBOM is absent; local `.git` contains Finder metadata that makes `git fsck` noisy. | `WebUIWorkspace/src/dev/runtime.js:42-60`; repository-level metadata check reported `.git/**/.DS_Store`. | Escape development diagnostics, add third-party provenance, and request explicit approval before removing files inside `.git`. |

## Verification limits and next sequence

1. Resolve P0 lifecycle ownership first, each with targeted sanitizer/race regression.
2. Make WebUI artifact production, Windows build discovery, and Syncthing boundaries deterministic; verify in a clean staging directory and on the current Windows workspace.
3. Add minimum CI and release mapping before new packaging/distribution commitments.
4. Obtain an architecture decision before the P2 controller/WebUI decomposition; do not perform a broad rewrite as a side effect of a bug fix.

All continuing work is tracked in `docs/TODO.md`; this review does not create a second task system.
