# MFCMouseEffect 文档

语言： [English](README.md) | [中文](README.zh-CN.md)

## 目标
本索引保持精简，优先服务 AI-IDE 快速检索。禁止在这里继续堆长历史清单。

## 建议阅读顺序（Agent-First）
1. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/AGENTS.md`
2. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/current.md`
3. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/refactoring/phase-roadmap-macos-m1-status.md`
4. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/p2-capability-index.md`
5. 仅按当前任务打开 1 篇目标文档

## 文档分层
- `P0` 全局协作约束：
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/AGENTS.md`
- `P1` 当前上下文：
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/current.md`
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/refactoring/phase-roadmap-macos-m1-status.md`
- `P2` 能力文档（按需打开）：
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/p2-capability-index.md`
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/refactoring/`
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/automation/`
- `P3` 归档区：
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/archive/README.md`

## 稳定工作流文档
- 主 TODO 与审核记录：`/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/TODO.md`、`/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/reviews/`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/agent-doc-governance.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-regression-suite-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-scaffold-regression-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-core-lane-smoke-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-core-automation-contract-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-linux-compile-gate-workflow.md`

## 能力路线图
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/automation/automation-mapping-todo.zh-CN.md`

## 营销文档
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/marketing/README.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/marketing/reddit-promo-pack.en.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/marketing/reddit-posting-playbook.zh-CN.md`

## 定向架构文档
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/custom-effects-wasm-route.zh-CN.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/wasm-plugin-abi-v3-design.zh-CN.md`

## 定向检索命令
```bash
# 最近重构文档
rg --files docs/refactoring | sort | tail -n 30

# 按能力关键词查文档
rg -n "permission|automation|app_scope|effects|wasm" docs/refactoring docs/automation docs/architecture

# 文档体积治理
./tools/docs/doc-hygiene-check.sh --strict
```

## AI 上下文路由器
```bash
# 重新生成机器索引 + 人类导航图
./tools/docs/ai-context.sh index

# 按任务生成最小读取集
./tools/docs/ai-context.sh route --task "automation gesture debug"

# 校验索引是否与 AGENTS/docs 同步（门禁用）
./tools/docs/ai-context.sh check --strict
# 可选：同时开启文档行数硬门禁
./tools/docs/ai-context.sh check --strict --enforce-line-limits

# 本地实时监听并自动刷新索引
./tools/docs/ai-context.sh watch
# 可选：安装 pre-commit 自动刷新与校验
./tools/docs/install-git-hook.sh
```
- 生成产物：
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/.ai/context-index.json`
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/.ai/context-map.md`
- 约束：
  - `route` 固定包含首读基线（P0 + P1），再按关键词和 token 预算补充 P2。
  - `check` 在 AGENTS/docs 已变化但未刷新索引时失败。
  - 已安装的 `pre-commit` hook 会在提交前重新生成并自动 stage 这两个生成文件，所以正常情况下它们不应该在提交后再次作为“预期漂移”留在工作区。

## 本地命令
```bash
# 统一 Makefile 入口；底层参数通过 ARGS 透传
make build | make test | make test-webui | make check-docs | make check

./mfx run
# 跳过 core/WebUI 编译
./mfx run-no-build
./mfx run-no-build --seconds 30
# macOS 当前宿主编译入口
./mfx build
# macOS 跳过 WebUIWorkspace 重编译
./mfx build --skip-webui-build
# Windows 最小发行编译
./mfx build --shipping
# Windows 完整 GPU 编译
./mfx build --gpu
# 完整编译后打包当前宿主平台原生产物
# macOS: .app + zip + dmg
# Windows: installer exe
./mfx package
# 跳过编译直接打包
./mfx package-no-build
# 等价于 package
./mfx pkg
./mfx effects
./mfx verify-effects
./mfx verify-full
# 兼容旧命令
./mfx start
# 等价于 run
# 等价于 run-no-build
./mfx fast
# 等价于 package
./mfx pack
./tools/platform/manual/run-macos-core-websettings-manual.sh --auto-stop-seconds 60
./tools/platform/manual/run-macos-automation-injection-selfcheck.sh --skip-build
./tools/platform/manual/run-macos-effects-type-parity-selfcheck.sh --skip-build
./tools/platform/regression/run-macos-objcxx-surface-regression.sh
./tools/platform/regression/run-theme-catalog-surface-regression.sh
```

Windows 终端包装器：
```powershell
.\mfx.cmd build
.\mfx.cmd build --shipping
.\mfx.cmd build --gpu
.\mfx.cmd package
.\mfx.cmd package-no-build
```

## 维护规则
顶层索引只保留导航，不记录过程细节；细节放在对应能力文档。
