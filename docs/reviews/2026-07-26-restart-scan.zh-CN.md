# 全量扫描复盘 — 2026-07-26（重新上手）

## 背景

- 项目自 2026-07-15（`chore: add unified make workflow and audit gates`）后停滞 11 天。
- 本次为只读全量扫描：确认代码现状、复核 7-15 审计结论、刷新 `docs/TODO.md`。
- 上次审计：`docs/reviews/2026-07-15-full-project-audit.md`（该文件仍未提交入库）。

## 代码盘点（第一方）

| 区域 | 文件数 | 行数 | 说明 |
| --- | --- | --- | --- |
| `MouseFx/`（Core/Server/Wasm） | 479 | ~70k | 核心逻辑、设置服务、WASM 运行时 |
| `Platform/`（win/mac/posix/linux） | 768 | ~81k | 平台实现；macOS 侧 Swift + Objective-C++ 混合 |
| `WebUIWorkspace/src` | 74 | ~18k | Svelte 设置页源码 |
| `WasmRuntimeBridge/` | 29 | ~8.4k | WASM 运行时桥接 |
| `WebUI/`（生成产物） | 23 | ~4.5k | 静态输出，含陈旧 bundle（见下） |
| `tools/` | 91 | ~16k | 回归 / 手测 / 构建 / 文档治理脚本 |
| `docs/` | 52 篇 md | — | 分层治理（P0–P3） |

- 第一方代码内 **零 TODO/FIXME/HACK 注释**，待办完全依赖 `docs/TODO.md`，该文件即唯一任务面。
- 超 800 行大文件 30+ 个，前三：`MacosMouseCompanionPhase1Bridge.swift`（3030）、`mouse-companion-main.js`（2406）、`SettingsStateMapper.Diagnostics.cpp`（2289）；`AppController.h` 仍为 1274 行。

## 7-15 审计结论复核（2026-07-26）

| 原级别 | 发现 | 复核结果 |
| --- | --- | --- |
| P0 | stdin IPC 线程 detach + 裸 `this`（`IpcController.cpp`） | **仍存在**，`Stop()` 仍直接 `worker_.detach()`，`ListenerLoop` 持裸 `this` |
| P0 | WebSettings 关停 detach lambda 持 `this`（`WebSettingsServer.TokenMonitor.cpp` `StopAsync`） | **仍存在**，`std::thread([this]{...}).detach()` 未变 |
| P0 | macOS 伴宠桥接裸 Swift 句柄 | **部分收敛待验证**：`PlatformPetVisualHost::Shutdown` 现为同步 hide→release；Swift 侧 release 走 `takeRetainedValue().closeAndCleanup()`，共享访问器 `takeUnretainedValue` 已收敛到单处且 `@MainActor`。异步 hide 与 release 的主线程队列先后顺序仍需专项验证（原审计引用的行号已漂移） |
| P1 | macOS dispatch host 生命周期（SendSync/timer/析构收敛） | **未解决**：timer 已带 `stopSignal`，但无统一状态机，promise 悬挂风险未验证，TSAN 覆盖缺失 |
| P1 | WASM retained group 状态无上限 | **仍存在**：`WasmGroup*Runtime.h` upsert 任意 ID，无 quota/TTL 关键路径 |
| P1 | WebUI 产物不确定 + resolver 依赖已退役 bundle | **仍存在**：`WebUiPathResolver` 仍强制要求 `cursor-decoration-settings.svelte.js`；该文件仍留在 `WebUI/` 但 `WebUIWorkspace/src/entries/` 已无对应入口（靠陈旧产物续命） |
| P1 | 黑名单 i18n 回归（`window.MfxI18n` 不存在） | **仍存在**：`EffectsBlacklistFields.svelte` `text()` 仍读 `window.MfxI18n` |
| P1 | Windows 构建脚本仅搜 Professional/Insiders | **仍存在**：`build-windows-project.sh` 硬编码 4 个 VS18 路径，无 `vswhere` |
| P1 | Syncthing 忽略规则缺嵌套 WebUI 输出 | **仍存在**：`.stignore` 的 `/node_modules` `/dist` 均根锚定，`WebUIWorkspace/`、`examples/` 内嵌套目录不受控 |
| P1 | 无 CI / 发布信任链 | **仍存在**：无 `.github/workflows`，版本号仍分散硬编码 |
| P2 | 边界超载（`AppController.h` 1274 行、`mouse-companion-main.js` 2406 行等） | **未变** |
| P2 | 控制面 / 无障碍加固不完整 | **未变**（token 在 URL、tmp 文件权限、键盘契约） |
| P2 | 文档治理漂移 | **仍存在**：`current.md` 231 行 > 220 预算；`current.md:9` 用 `F:\`、`TODO.md` 用 `D:\`、根目录 `windows-manual-handoff.tmp` 仍指 `F:\`，Windows 镜像路径口径三处不一致 |
| P3 | dev 错误页 `innerHTML` 注入未转义内容 | **仍存在**：`src/dev/runtime.js` `renderDevRuntimeError` 未变 |

**结论：7-15 审计的发现基本全部未处理。P0 生命周期问题仍是任何新功能开发前的第一优先级。**

## 工作区未落库状态

- 已修改未提交：`docs/TODO.md`（内容已对齐 7-15 审计）、`docs/.ai/context-index.json` + `context-map.md`（按 AGENTS 规则属 hook 漂移，应随下次提交一并处理）。
- 未跟踪：`docs/reviews/2026-07-15-full-project-audit.md`、本文件。
- 根目录 `windows-manual-handoff.tmp` 与 AGENTS「不再维护同步 handoff 文件」的规则冲突，内容已过时。

## 重新上手最短路径

1. 读 `AGENTS.md` → `docs/agent-context/current.md` → `docs/TODO.md`（本次已刷新）。
2. 低成本验证环境：`make audit`（非破坏门禁），再 `./mfx run-no-build` 目测效果。
3. 先做一次收尾提交：把 7-15 / 7-26 两份复盘 + TODO + `.ai` 索引一起入库，恢复干净工作区。
4. 之后按 `docs/TODO.md` 顺序推进：P0 生命周期 → WebUI 确定性 → Windows 构建验证 → CI。

## 边界

- 本次未运行 `make check` 全量回归、未做 Windows 侧构建（均为高负载 / 跨机操作），对应事项保留在 TODO。
- 后续任务仍以 `docs/TODO.md` 为唯一状态源，本文件不另开任务体系。
