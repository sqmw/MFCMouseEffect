# Project Main TODO

跨能力工作的唯一状态源。能力文档保留细节，但产生后续事项时必须回链到这里。
（2026-07-26 全量扫描复核：7-15 审计事项基本全部未动，状态与优先级已按 `docs/reviews/2026-07-26-restart-scan.zh-CN.md` 刷新。）

## Current

| 状态 | 事项 | 验收 / 下一步 | 相关材料 |
| --- | --- | --- | --- |
| blocking | P0 生命周期收尾验证 | 三处 P0 均已修复（见 Archive）：stdin IPC、WebSettings `StopAsync`、macOS 伴宠桥接（改主线程注册表 + ID，release 后异步操作降级 no-op）。剩余：宿主机跑 `./mfx build` 验证 Swift 编译与伴宠冒烟；将 ASan/TSAN 用例正式纳入回归套件。 | `docs/reviews/2026-07-26-restart-scan.zh-CN.md` |
| pending | 收尾提交，恢复干净工作区 | 将 7-15 / 7-26 两份复盘、本文件、`docs/.ai` 索引对一起提交；同时处理与 AGENTS 规则冲突的根目录 `windows-manual-handoff.tmp`。 | `docs/reviews/2026-07-26-restart-scan.zh-CN.md` |
| pending | macOS dispatch 生命周期 | `SendSync`、timer、析构收敛到统一状态机；补 TSAN 竞态覆盖。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | WASM retained 状态配额 | 按插件/surface 限制 group 与 retained 实例数量，加 TTL/诊断，测试配额耗尽。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | WebUI 产物确定性 | 统一 bundle 清单（Vite/resolver/copy/package 共用）；清理 `WebUI/` 陈旧 `cursor-decoration-settings.svelte.js` 及 resolver 强依赖。i18n 回归已修复（见 Archive），但需在宿主机重建静态 WebUI（`pnpm run build`）使产物侧生效。 | `docs/reviews/2026-07-26-restart-scan.zh-CN.md` |
| pending | Windows 构建与 Syncthing 边界 | `vswhere`/多版本探测 MSBuild；`.stignore` 补嵌套 `WebUIWorkspace`、`examples` 的 `node_modules/dist` 忽略；统一 `F:\` vs `D:\` 镜像路径口径；然后在当前同步工作区跑一次真实 Windows 构建 + 冒烟。 | `docs/reviews/2026-07-26-restart-scan.zh-CN.md` |
| pending | CI 与发布信任链 | 最小干净环境 CI 矩阵；单一版本源 + tag/commit/产物映射；签名/公证决策落文档。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 有界架构拆分 | 在向 `AppController`（.h 1274 行）、伴宠诊断、Mouse Companion WebUI（2406 行）加行为前，先批准分阶段兼容拆分方案。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 本地控制面与无障碍加固 | 设置 token / probe 文件卫生；补齐 dialog/tab/mapping 键盘契约与回归。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 活跃文档路径与 P1 上下文瘦身 | 替换过时绝对路径 / Windows 盘符（`current.md:9` 的 `F:\` 等）；`current.md` 从 231 行压回 220 行预算。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 全量回归执行 | 外部终端跑 `make check`，记录 macOS/Linux 结果。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| in_progress | Automation mapping 能力 | 仅经其范围内路线图推进；新的跨能力后续事项复制到本表。 | `docs/automation/automation-mapping-todo.zh-CN.md` |

## Risks / constraints

- `make check` 为高负载命令：日常用分项目标验证，需要完整回归时在外部终端执行。
- macOS 为主工作区；Windows 镜像路径当前口径不一致（`F:\` vs `D:\`），Windows 构建前先确认 Syncthing 新鲜度并统一口径。
- 未经用户明确批准不得清理 `.git` 内 Finder 元数据；这是仓库健康项，不属于功能工作。

## Archive

完成项移到这里，附日期、结果、验证、相关提交与残余风险。

| 日期 | 事项 | 结果 / 验证 | 残余风险 |
| --- | --- | --- | --- |
| 2026-07-26 | P0：macOS 伴宠桥接句柄生命周期 | Swift 桥接改为 `@MainActor` 注册表 + 递增 ID：C ABI 指针位仅承载 ID，release 后到达的 hide/update/apply_pose 异步块查表落空即 no-op，双重 release 无害。静态审查全部入口收口到三个 helper；Swift 编译与运行验证待宿主机。 | 宿主机 `./mfx build` + 伴宠冒烟未执行。 |
| 2026-07-26 | WebUI 黑名单 i18n 回归 | `EffectsBlacklistFields` 改走 `i18n` prop（与 AutomationEditor 同型）+ 新共享适配器 `web-i18n-text.js`（读 `MfxWebI18n`，语言选取与 i18n-runtime 一致）；新增 `test:effects-blacklist-i18n` 并纳入 `test:webui-models`，7 用例 + 既有 11 组模型测试全绿。 | 静态 WebUI 产物需宿主机重建后才生效。 |
| 2026-07-26 | P0：stdin IPC 与 WebSettings 关停生命周期 | `IpcController` 改共享状态 + 锁内回调（Stop 后回调不可达）；新增 `PosixStdinExitMonitor` 供 core/scaffold shell 复用并在 Shutdown/析构 Detach；`StopAsync` 改为持有的可 join 线程并在析构先 join。全部受影响 TU 以 g++17 语法门禁通过；`IpcController` 以 ASan+UBSan 动态验证销毁后灌 stdin 无 UAF。 | macOS 原生构建与全量回归未在本环境执行；正式 ASan 回归尚未纳入套件。 |
| 2026-07-26 | 全量扫描复核（只读） | 复核 7-15 审计全部条目：P0×2 原样存在、伴宠桥接部分收敛待验证、P1/P2/P3 基本未动；产出 `docs/reviews/2026-07-26-restart-scan.zh-CN.md` 并刷新本表。 | 动态回归与 Windows 构建仍未执行（见上表）。 |
| 2026-07-15 | 统一 Makefile 入口 | 新增文档化薄 `build/test/check/package/audit` 目标；已验证 help、命令分发、`make audit`、WebUI 测试与 CMake configure。 | 全量原生回归与 Windows 构建仍待执行。 |
| 2026-07-15 | 仓库级静态审计 | 覆盖跟踪源码 + 当前 WebUI diff；shell/Node 语法检查、安全模式扫描、CMake configure、定向 surface 门禁通过。 | 动态全量与 Windows 覆盖仍待执行。 |
