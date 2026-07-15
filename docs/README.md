# MFCMouseEffect Documentation

Language: [English](README.md) | [中文](README.zh-CN.md)

## Purpose
Compact AI-first index for fast navigation. This file is intentionally short and avoids historical long lists.

## Read Order (Agent-First)
1. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/AGENTS.md`
2. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/current.md`
3. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/refactoring/phase-roadmap-macos-m1-status.md`
4. `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/p2-capability-index.md`
5. One targeted capability doc

## Priority Layers
- `P0` global contract:
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/AGENTS.md`
- `P1` active context:
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/current.md`
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/refactoring/phase-roadmap-macos-m1-status.md`
- `P2` capability docs:
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/agent-context/p2-capability-index.md`
  - targeted docs under `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/refactoring/`
- `P3` archive:
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/archive/README.md`

## Stable Workflow Docs
- Main TODO and audit reviews: `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/TODO.md`, `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/reviews/`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/agent-doc-governance.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-regression-suite-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-scaffold-regression-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-core-lane-smoke-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-core-automation-contract-workflow.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/posix-linux-compile-gate-workflow.md`

## Capability Roadmaps
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/automation/automation-mapping-todo.zh-CN.md`

## Marketing Docs
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/marketing/README.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/marketing/reddit-promo-pack.en.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/marketing/reddit-posting-playbook.zh-CN.md`

## Targeted Architecture Docs
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/custom-effects-wasm-route.md`
- `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/architecture/wasm-plugin-abi-v3-design.md`

## Targeted Retrieval
```bash
# latest refactoring docs
rg --files docs/refactoring | sort | tail -n 30

# find docs by capability
rg -n "permission|automation|app_scope|effects|wasm" docs/refactoring docs/automation docs/architecture

# doc hygiene gate
./tools/docs/doc-hygiene-check.sh --strict
```

## AI Context Router
```bash
# regenerate machine index + human map
./tools/docs/ai-context.sh index

# get minimal read set for one task
./tools/docs/ai-context.sh route --task "automation gesture debug"

# enforce index freshness
./tools/docs/ai-context.sh check --strict
# optional hard gate for line limits
./tools/docs/ai-context.sh check --strict --enforce-line-limits

# local realtime refresh while editing docs
./tools/docs/ai-context.sh watch
# optional: install pre-commit auto-refresh gate
./tools/docs/install-git-hook.sh
```
- Generated files:
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/.ai/context-index.json`
  - `/Users/sunqin/study/language/cpp/code/MFCMouseEffect/docs/.ai/context-map.md`
- Contract:
  - `route` always keeps first-read baseline (P0 + P1) and adds keyword-matched P2 docs under token budget.
  - `check` fails when markdown/AGENTS changed but index was not refreshed.
  - installed `pre-commit` hook regenerates and stages the two generated files into the same commit, so they should not normally reappear as post-commit drift.

## Local Commands
```bash
# unified Makefile; pass native options through ARGS
make build | make test | make test-webui | make check-docs | make check

./mfx run
# skips core/WebUI rebuild
./mfx run-no-build
./mfx run-no-build --seconds 30
# macOS current-host build entrypoint
./mfx build
# macOS build without rebuilding WebUIWorkspace
./mfx build --skip-webui-build
# Windows shipping build
./mfx build --shipping
# Windows full GPU build
./mfx build --gpu
# full build + native package for current host
# macOS: .app/zip/dmg
# Windows: installer exe
./mfx package
# skips rebuild while packaging
./mfx package-no-build
# same as package
./mfx pkg
./mfx effects
./mfx verify-effects
./mfx verify-full
# backward-compatible aliases
./mfx start
# same as run
# same as run-no-build
./mfx fast
# same as package
./mfx pack
./tools/platform/manual/run-macos-core-websettings-manual.sh --auto-stop-seconds 60
./tools/platform/manual/run-macos-automation-injection-selfcheck.sh --skip-build
./tools/platform/manual/run-macos-effects-type-parity-selfcheck.sh --skip-build
./tools/platform/regression/run-macos-objcxx-surface-regression.sh
./tools/platform/regression/run-theme-catalog-surface-regression.sh
```

Windows terminal wrapper:
```powershell
.\mfx.cmd build
.\mfx.cmd build --shipping
.\mfx.cmd build --gpu
.\mfx.cmd package
.\mfx.cmd package-no-build
```

## Note
Do not add long historical phase lists back to this top-level index. Keep details in targeted docs.
