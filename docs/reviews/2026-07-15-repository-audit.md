# Repository Audit — 2026-07-15

## Scope

- Tracked repository source (1,556 code/script files) and the current uncommitted WebUI automation-mapping diff.
- Build command surface, shell/Node syntax, CMake configuration, targeted regression gates, credential-pattern scan, unsafe C/C++ API scan, and source-size/SRP indicators.
- Third-party `json.hpp` and wasm3 code was inventoried but not treated as project-owned refactor scope.

## Findings

| Priority | Status | Finding | Evidence / action |
| --- | --- | --- | --- |
| P1 | done | Theme-catalog surface gate had drifted twice: it used `Server/Settings...` instead of lowercase `Server/settings/...`, then asserted theme submenu code that no longer exists in either tray builder. | Corrected the path and redirected the assertion to the active `AppShellCore` runtime-theme snapshot contract; gate passed. |
| P2 | pending | Several project-owned files exceed 1,000 lines and combine multiple responsibilities, increasing review and regression cost. | Triage bounded splits before new features in `MacosMouseCompanionPhase1Bridge.swift` (3,030), `mouse-companion-main.js` (2,406), `InputAutomationEngine.cpp` (2,207), and `AppController.Lifecycle.cpp` (2,174). This is a refactor proposal, not an approved change. |
| P3 | pending | The active P1 context document is 231 lines, over its 220-line budget. | Compact duplicated/historical detail while retaining current contracts. |

## Checks completed

- `make help`, `make audit`, and help dispatch for all build/test/package targets: passed.
- `make test-webui`: passed (11 WebUI model and source-mode contract tests).
- Shell syntax: 91 tracked shell scripts passed `bash -n`.
- Node syntax: 118 tracked `.js`/`.mjs` files passed `node --check`.
- macOS CMake configure with core runtime: passed (AppleClang 21, Swift language mode 6).
- macOS ObjC++ surface gate: passed.
- Theme-catalog surface gate: passed after the P1 path correction.
- Security-pattern scan: no project-owned embedded private-key, cloud credential, secret-like assignment, shell `eval`, or pipe-to-shell pattern found. Unsafe `strcpy`/`sprintf` results were limited to vendored wasm3 sources.
- `git diff --check`: passed.

## Not executed

- Full `make check` was intentionally not run in the IDE because it is the documented high-load build/regression path. Run it in an external terminal and record the result in `docs/TODO.md`.
- Windows native build was not run from this macOS workspace. After Syncthing is current, run `make build-windows` from `D:\language\cpp\code\MFCMouseEffect`.

## Review conclusion

The current WebUI event-forwarding change is internally consistent: add-action events are dispatched in the leaf editor, forwarded through `MappingShortcutPanel`, consumed by `MappingPanel`, and covered by the passing contract test. No blocking security or syntax defect was found in the audited project-owned source. The remaining tasks are explicitly tracked in the main TODO.
