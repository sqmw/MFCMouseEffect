<p align="center">
  <img src="./MFCMouseEffect/res/logo_elegant.png" width="128" alt="MFCMouseEffect Logo">
</p>

<h1 align="center">MFCMouseEffect</h1>

<p align="center">
  <b>Make every click, drag, and scroll visible.</b><br>
  Cross-platform desktop input feedback engine · Extensible · Plugin-powered · WASM-ready
</p>

<p align="center">
  <a href="https://github.com/sqmw/MFCMouseEffect/stargazers"><img src="https://img.shields.io/github/stars/sqmw/MFCMouseEffect?style=for-the-badge&color=f5c542" alt="stars"></a>
  <a href="https://github.com/sqmw/MFCMouseEffect/releases/latest"><img src="https://img.shields.io/github/v/release/sqmw/MFCMouseEffect?style=for-the-badge&color=6c63ff" alt="release"></a>
  <a href="https://github.com/sqmw/MFCMouseEffect/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-brightgreen?style=for-the-badge" alt="license"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey?style=for-the-badge" alt="platform">
</p>

<p align="center">
  <a href="https://oosmetrics.com/repo/sqmw/MFCMouseEffect"><img src="https://api.oosmetrics.com/api/v1/badge/achievement/31e5b655-dbea-48bf-8e2d-be7763743b0c.svg" alt="oosmetrics Top 7 in WebAssembly by acceleration - 2026-05-14"></a>
</p>
<p align="center"><sub>Third-party visibility signal: featured by oosmetrics for WebAssembly acceleration</sub></p>

<p align="center">
  <a href="https://github.com/sqmw/MFCMouseEffect/releases">Download</a> ·
  <a href="./docs/README.md">Docs</a> ·
  <a href="./PRIVACY.md">Privacy</a> ·
  <a href="https://github.com/sqmw/MFCMouseEffect/issues">Issues</a> ·
  <a href="#-contributing">Contributing</a> ·
  <a href="https://github.com/sqmw/MFCMouseEffect">Star</a>
</p>

<p align="center">
  <a href="README.md"><b>🇨🇳 中文</b></a> | <b>🇬🇧 English</b>
</p>

---

<p align="center">
  <img src="./docs/images/placeholder_mouse_companion.webp" width="720" alt="MFCMouseEffect Mouse Companion showcase">
</p>

<p align="center"><i>Mouse Companion — more than an effect demo, also an important long-term capability direction for the project</i></p>

## ✨ Why Choose MFCMouseEffect

- 🎯 **Five independent effect lanes** — click, trail, scroll, hold, and hover are separate capability surfaces, not one animation reskinned five times
- 🔌 **WASM plugin runtime** — write your own effects and indicators in WASM while the host keeps rendering boundaries under control
- ⌨️ **Keyboard & Mouse Indicator** — visualize mouse clicks, wheel direction, and keyboard combos like `Cmd+Tab` and `W+ x3`
- 🤖 **Automation mapping** — map mouse actions, wheel input, and gestures to shortcut, delay, URL, and app-launch actions, connecting input feedback to real workflows
- 🐾 **Mouse Companion** — a plugin-first route for a cross-platform desktop companion that follows your cursor
- 🌐 **Unified settings UI** — shared Web settings across platforms, with one config flow, synchronized state, and recoverable behavior

> Great for screen recording, tutorials, live demos, and developers who want bounded WASM extensibility inside a C++ host.

## 🖼️ Effect Preview

<table>
  <tr>
    <td align="center"><img src="./docs/images/ripple_concept.png" width="280" alt="Click Ripple"><br><b>Click Ripple</b></td>
    <td align="center"><img src="./docs/images/trail_concept.png" width="280" alt="Particle Trail"><br><b>Particle Trail</b></td>
    <td align="center"><img src="./docs/images/scroll_concept.png" width="280" alt="Scroll Feedback"><br><b>Scroll Feedback</b></td>
  </tr>
  <tr>
    <td align="center"><img src="./docs/images/hold_concept.png" width="280" alt="Hold Charge"><br><b>Hold Charge</b></td>
    <td align="center"><img src="./docs/images/hover_concept.png" width="280" alt="Hover Glow"><br><b>Hover Glow</b></td>
    <td align="center"><img src="./docs/images/placeholder_mouse_companion.webp" width="280" alt="Mouse Companion"><br><b>Mouse Companion</b></td>
  </tr>
</table>

<p align="center">
  <img src="./docs/images/setting_en.png" width="720" alt="WebSettings UI">
</p>
<p align="center"><i>Unified Web Settings UI — shared across platforms, everything in one place</i></p>

## ⌨️ Keyboard/Mouse Indicator & Automation

<table>
  <tr>
    <td align="center"><img src="./docs/images/placeholder_input_indicator.png" width="360" alt="Keyboard and Mouse Indicator"><br><b>Keyboard & Mouse Indicator</b></td>
    <td align="center"><img src="./docs/images/placeholder_automation_mapping.png" width="360" alt="Automation Mapping"><br><b>Automation Mapping</b></td>
  </tr>
</table>

- **Keyboard & Mouse Indicator** — show mouse clicks, wheel direction, and keyboard combos together, so signals like `L x2`, `W+ x3`, and `Cmd+Tab` stay obvious in recordings and demos
- **Automation Mapping** — currently maps mouse actions, wheel input, and gestures to shortcut, delay, URL, and app-launch actions; fuller scripting, profiles, and advanced action chains are on the roadmap

<details>
<summary><b>Expand for best-fit scenarios</b></summary>

- **Screen recording / tutorials / live demos**: viewers can see not only where the cursor is, but also what you clicked, switched, or triggered
- **Productivity tools / desktop enhancement**: gestures and input mapping are not just decorative layers; they can participate in real interaction flows

</details>

## 🤝 Contributing

**The project is actively growing, and many directions are ready for contributors.**

| Area | Description | Entry Point |
|:---|:---|:---|
| 🖱️ **Mouse effects** | Click, trail, scroll, hold, hover, and cursor-decoration styles and tuning | [Effect docs](./docs/README.md) |
| 🤖 **Automation Mapping** | Map mouse actions, wheel input, and gestures to shortcut / delay / URL / app-launch actions; scripting and profiles are on the roadmap | [Automation docs](./docs/automation/automation-mapping-notes.md) |
| ⌨️ **Keyboard & Mouse Indicator** | Mouse, wheel, and keyboard-combo visualization, layout, and WASM indicator work | [Capability index](./docs/agent-context/p2-capability-index.md) |
| 🐾 **Mouse Companion** | Companion animations, interactions, and plugins | [Companion roadmap](./docs/architecture/mouse-companion-plugin-landing-roadmap.zh-CN.md) |
| 🔌 **WASM plugins** | Write effect / indicator plugins, or improve ABI, templates, and tooling | [Plugin template](./examples/wasm-plugin-template/README.md) |
| 🌐 **WebSettings** | Improve settings UX, state sync, and diagnostics entry points | [WebUI source](./MFCMouseEffect/WebUIWorkspace/) |
| 🖥️ **Cross-platform parity** | Align Windows / macOS behavior | [Issue Tracker](https://github.com/sqmw/MFCMouseEffect/issues) |
| 📝 **Docs & testing** | Documentation, self-checks, and regression tooling | [Docs](./docs/) |

**Recommended flow:**

1. Open an [Issue](https://github.com/sqmw/MFCMouseEffect/issues) describing your idea
2. Have a brief discussion to align on direction
3. Submit a PR
4. For larger features or architecture changes, email first

📮 **Contact:** `ksun22515@gmail.com`

## 🚀 Quick Start

### Windows

```powershell
# Recommended: open MFCMouseEffect.slnx in Visual Studio 2026 and build Release | x64

# Or use the wrapper commands
.\mfx.cmd build            # Default Release | x64
.\mfx.cmd build --shipping # Lean delivery build
.\mfx.cmd package          # Generate installer
```

### macOS

```bash
make build                         # Unified build entrypoint (current macOS host)
make build ARGS="--skip-webui-build"
make test                          # Full POSIX regression suite
make check                         # Docs + WebUI + POSIX regression
./mfx build                       # Build current host only
./mfx build --skip-webui-build    # Skip rebuilding WebUIWorkspace
./mfx run                         # Build and run
./mfx run-no-build                # Run without rebuilding
./mfx run-no-build --seconds 30   # Auto-stop for quick validation
./mfx package                     # Package

# Backward-compatible aliases
./mfx start                       # Same as ./mfx run
./mfx fast                        # Same as ./mfx run-no-build
```

> macOS requires **Accessibility** and **Input Monitoring** permissions for global input capture.

## 📊 Platform Status

| Platform | Status | Notes |
|:---|:---:|:---|
| **Windows 10+** | Stable mainline | Most complete capability set, regression compatibility preserved |
| **macOS** | Active mainline | Current priority development lane |
| **Linux** | Follow lane | Compile gate and contract coverage |

> Current priority: `macOS mainline first`, while keeping Windows behavior regression-free.

<details>
<summary><b>📦 Architecture Highlights (expand)</b></summary>

### Architecture Design

- **Host-owned rendering boundary** — plugins compute logic; the host owns rendering execution, budget checks, fallback, and resources
- **Clear module layering** — Core / Platform / Server / WebUI / Tools / Docs each have well-defined responsibilities
- **Progressive extensibility** — built-in effects work, WASM plugins can layer on top, and native fallback catches the rest
- **Cross-platform semantic alignment** — Windows and macOS share core semantics and settings surfaces
- **Built-in observability** — WebSettings, diagnostics, regression scripts, and self-checks were designed together

### WASM Plugin Capabilities

- Separate `effects` and `indicator` surfaces
- Manifest load, reload, import, and export flows
- Budget control, command validation, error codes, and staged diagnostics
- Transient and retained rendering semantics
- Rich command primitives: `spawn_text` / `spawn_image` / `spawn_pulse` / `spawn_polyline` / `spawn_ribbon_strip` / `spawn_glow_batch` and more

**Plugin quick start:**
- Template: [`examples/wasm-plugin-template`](./examples/wasm-plugin-template/README.md)
- Route doc: [`custom-effects-wasm-route.md`](./docs/architecture/custom-effects-wasm-route.md)
- ABI spec: [`wasm-plugin-abi-v3-design.md`](./docs/architecture/wasm-plugin-abi-v3-design.md)

</details>

<details>
<summary><b>📂 Repository Structure (expand)</b></summary>

```text
MFCMouseEffect/
├── MFCMouseEffect/
│   ├── MouseFx/                 # Core: effects, automation, WASM, diagnostics, server
│   ├── Platform/                # Windows / macOS / Linux platform implementations
│   ├── WebUIWorkspace/          # Svelte settings UI source
│   ├── Runtime/                 # Runtime resources and dependencies
│   ├── Assets/                  # Companion and visual assets
│   └── WasmRuntimeBridge/       # WASM runtime bridge
├── tools/
│   ├── platform/regression/     # Regression scripts
│   ├── platform/manual/         # Manual and self-check helpers
│   └── docs/                    # Doc routing and governance scripts
├── docs/                        # Architecture, roadmap, workflow, issue docs
├── examples/                    # Examples and templates
└── mfx / mfx.cmd                # Preferred command entrypoints
```

</details>

<details>
<summary><b>❓ FAQ (expand)</b></summary>

### Effects not showing on macOS?

Check system permissions: `Accessibility` + `Input Monitoring`. The runtime degrades gracefully when permissions are missing and recovers once they are restored.

### Why is GPU not enabled by default on Windows?

Stability and payload size. The default is `--no-gpu`. Use `./mfx.cmd build --gpu` when you explicitly want the GPU route.

### What is the difference between Shipping and Release?

Shipping keeps the main runtime and WebUI but trims heavy diagnostics and deep test surfaces. It is better for delivery.

### Settings revert after Apply?

Many settings are backend-state-driven. If the backend binding did not succeed, the UI reconciles to the real state. Check manifest paths and lane status first.

### macOS package blocked on first launch?

Current macOS builds are unsigned. Gatekeeper may block first launch; right-click `Open` in Finder to allow it.

</details>

<details>
<summary><b>🧪 Regression & Self-Check (expand)</b></summary>

```bash
# Unified make entrypoints (pass underlying options through ARGS)
make test                          # Full POSIX suite
make test ARGS="--skip-linux-gate"
make test-webui                    # WebUI model + dev-contract tests
make check-docs                    # AI-context and doc-health checks

# Full POSIX suite
./tools/platform/regression/run-posix-regression-suite.sh --platform auto

# Effects-focused regression
./tools/platform/regression/run-posix-effects-regression-suite.sh --platform auto

# Automation contract regression
./tools/platform/regression/run-posix-core-automation-contract-regression.sh --platform auto

# WASM-focused regression
./tools/platform/regression/run-posix-wasm-regression-suite.sh --platform auto
```

</details>

<details>
<summary><b>📖 Documentation (expand)</b></summary>

- Docs overview: [docs/README.md](./docs/README.md)
- Chinese docs: [docs/README.zh-CN.md](./docs/README.zh-CN.md)
- Privacy Policy: [PRIVACY.md](./PRIVACY.md)
- Chinese Privacy Policy: [PRIVACY.zh-CN.md](./PRIVACY.zh-CN.md)
- macOS mainline snapshot: [docs/refactoring/phase-roadmap-macos-m1-status.md](./docs/refactoring/phase-roadmap-macos-m1-status.md)
- P2 capability index: [docs/agent-context/p2-capability-index.md](./docs/agent-context/p2-capability-index.md)

</details>

## 📄 License

This project is released under the [MIT License](./LICENSE). Free to use, modify, and distribute under the license terms.

Privacy details are available in the [Privacy Policy](./PRIVACY.md).

---

<p align="center">
  <b>If it helps, please <a href="https://github.com/sqmw/MFCMouseEffect">star ⭐</a></b><br>
  <sub>Share feedback on <a href="https://github.com/sqmw/MFCMouseEffect/issues">Issues</a> and <a href="https://github.com/sqmw/MFCMouseEffect/discussions">Discussions</a></sub>
</p>
