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
| pending | WebUI 产物确定性收尾 | bundle 清单已统一（见 Archive），剩余：宿主机跑一次 `pnpm run build` 验证 purge 行为 + 干净目录打包校验（clean-room staging/package 断言）。 | `docs/reviews/2026-07-26-restart-scan.zh-CN.md` |
| pending | Windows 真实构建验证 | 脚本与边界已修（见 Archive：vswhere 探测、嵌套 `.stignore`、`D:\` 单一口径）。剩余：在当前同步 Windows 工作区跑一次真实构建 + 冒烟并记录结果。 | `docs/reviews/2026-07-26-restart-scan.zh-CN.md` |
| pending | CI 与发布信任链 | 最小干净环境 CI 矩阵；单一版本源 + tag/commit/产物映射；签名/公证决策落文档。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 有界架构拆分 | 在向 `AppController`（.h 1274 行）、伴宠诊断、Mouse Companion WebUI（2406 行）加行为前，先批准分阶段兼容拆分方案。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 本地控制面与无障碍加固 | 设置 token / probe 文件卫生；补齐 dialog/tab/mapping 键盘契约与回归。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| pending | 全量回归执行（仅剩 macOS 原生侧） | Linux 门禁等效构建已在沙箱通过（见 Archive）。剩余必须在 macOS 宿主机执行：`./mfx build`（验证 Swift 桥接编译 + WebUI 重建）后 `make check`，记录结果。 | `docs/reviews/2026-07-15-full-project-audit.md` |
| in_progress | Automation mapping 能力 | 仅经其范围内路线图推进；新的跨能力后续事项复制到本表。 | `docs/automation/automation-mapping-todo.zh-CN.md` |

## Risks / constraints

- `make check` 为高负载命令：日常用分项目标验证，需要完整回归时在外部终端执行。
- macOS 为主工作区；Windows 镜像为 `D:\language\cpp\code\MFCMouseEffect`（单一口径记录在 AGENTS.md），Windows 构建前先确认 Syncthing 新鲜度。
- 未经用户明确批准不得清理 `.git` 内 Finder 元数据；这是仓库健康项，不属于功能工作。

## Archive

完成项移到这里，附日期、结果、验证、相关提交与残余风险。

| 日期 | 事项 | 结果 / 验证 | 残余风险 |
| --- | --- | --- | --- |
| 2026-07-26 | Linux 门禁等效构建 + scaffold 冒烟（沙箱） | 无 cmake 环境下按 CMakeLists 清单手工 g++ 编译 Linux scaffold 全部 50 TU（0 失败），链接出可运行 scaffold 宿主；stdin `exit` 命令与 EOF 两条退出路径冒烟均 exit=0；`PosixStdinExitMonitor` 另以 ASan+UBSan 验证 Detach+销毁后灌入 exit/EOF 无 UAF、handler 不再触发。 | macOS 原生（Swift/AppKit）与 Windows 构建仍需真实宿主机。 |
| 2026-07-26 | WebUI bundle 清单统一 | 新增 `webui-bundle-manifest.mjs` 单一源，`vite.config.js` / `copy-output.mjs` 共用；copy 阶段自动清除未列管的退役 `js/css/html`（含 runtime webui 目录）；resolver 去掉退役 `cursor-decoration-settings.svelte.js` 强依赖；删除本地陈旧 `cursor-decoration` / `pet3d` bundle；新增 `test:webui-bundle-manifest` 4 项契约测试入链，全绿。 | 宿主机 `pnpm run build` 全链验证与 clean-room 打包断言未执行。 |
| 2026-07-26 | Windows 构建脚本与 Syncthing 边界 | `find_msbuild` 改为 `MFX_MSBUILD` 覆盖 -> `vswhere` 全版本探测 -> VS18 五版本静态回退；`.stignore` 补嵌套 `WebUIWorkspace`、`examples` 的 `node_modules/dist/build` 忽略；`bash -n` 通过。 | 真实 Windows 构建未执行（需 Windows 宿主）。 |
| 2026-07-26 | 活跃文档路径与 P1 上下文瘦身 | Windows 镜像统一为 `D:\`（AGENTS 单一口径，经用户确认）；`current.md` 由 232 行压至预算内（合并 wasm_v1 / lane-matrix 子列表），并补录 bundle 清单契约。 | 无。 |
| 2026-07-26 | P0：macOS 伴宠桥接句柄生命周期 | Swift 桥接改为 `@MainActor` 注册表 + 递增 ID：C ABI 指针位仅承载 ID，release 后到达的 hide/update/apply_pose 异步块查表落空即 no-op，双重 release 无害。静态审查全部入口收口到三个 helper；Swift 编译与运行验证待宿主机。 | 宿主机 `./mfx build` + 伴宠冒烟未执行。 |
| 2026-07-26 | WebUI 黑名单 i18n 回归 | `EffectsBlacklistFields` 改走 `i18n` prop（与 AutomationEditor 同型）+ 新共享适配器 `web-i18n-text.js`（读 `MfxWebI18n`，语言选取与 i18n-runtime 一致）；新增 `test:effects-blacklist-i18n` 并纳入 `test:webui-models`，7 用例 + 既有 11 组模型测试全绿。 | 静态 WebUI 产物需宿主机重建后才生效。 |
| 2026-07-26 | P0：stdin IPC 与 WebSettings 关停生命周期 | `IpcController` 改共享状态 + 锁内回调（Stop 后回调不可达）；新增 `PosixStdinExitMonitor` 供 core/scaffold shell 复用并在 Shutdown/析构 Detach；`StopAsync` 改为持有的可 join 线程并在析构先 join。全部受影响 TU 以 g++17 语法门禁通过；`IpcController` 以 ASan+UBSan 动态验证销毁后灌 stdin 无 UAF。 | macOS 原生构建与全量回归未在本环境执行；正式 ASan 回归尚未纳入套件。 |
| 2026-07-26 | 全量扫描复核（只读） | 复核 7-15 审计全部条目：P0×2 原样存在、伴宠桥接部分收敛待验证、P1/P2/P3 基本未动；产出 `docs/reviews/2026-07-26-restart-scan.zh-CN.md` 并刷新本表。 | 动态回归与 Windows 构建仍未执行（见上表）。 |
| 2026-07-15 | 统一 Makefile 入口 | 新增文档化薄 `build/test/check/package/audit` 目标；已验证 help、命令分发、`make audit`、WebUI 测试与 CMake configure。 | 全量原生回归与 Windows 构建仍待执行。 |
| 2026-07-15 | 仓库级静态审计 | 覆盖跟踪源码 + 当前 WebUI diff；shell/Node 语法检查、安全模式扫描、CMake configure、定向 surface 门禁通过。 | 动态全量与 Windows 覆盖仍待执行。 |
