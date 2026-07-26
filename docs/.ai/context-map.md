# AI Context Map

Generated: 2026-07-26T10:24:31.470Z

## Goal
Load minimal docs by task keyword while keeping AGENTS + current context as mandatory baseline.

## Mandatory First Read
- 1. `AGENTS.md` (1500 tok)
- 2. `docs/agent-context/current.md` (1100 tok)
- 3. `docs/refactoring/phase-roadmap-macos-m1-status.md` (1100 tok)

## Topic Routes (Top Candidates)
### automation
- `docs/agent-context/current.md` (P1, 1100 tok)
- `docs/agent-context/p2-capability-index.md` (P2, 750 tok)
- `docs/architecture/agent-doc-governance.md` (P2, 750 tok)
- `docs/architecture/posix-core-automation-contract-workflow.md` (P2, 750 tok)

### wasm
- `docs/architecture/cursor-decoration-plugin-contract.md` (P2, 750 tok)
- `docs/architecture/custom-effects-wasm-route.md` (P2, 750 tok)
- `docs/architecture/custom-effects-wasm-route.zh-CN.md` (P2, 750 tok)
- `docs/architecture/mouse-companion-appearance-contract.zh-CN.md` (P2, 750 tok)

### effects
- `docs/architecture/click-ripple-cross-platform-alignment.md` (P2, 750 tok)
- `docs/architecture/mouse-companion-action-clip-contract.zh-CN.md` (P2, 750 tok)
- `docs/architecture/mouse-companion-procedural-effect-profile-contract.zh-CN.md` (P2, 750 tok)
- `docs/ops/windows-installer-packaging.md` (P2, 750 tok)

### workflow
- `AGENTS.md` (P0, 1500 tok)
- `docs/architecture/posix-core-lane-smoke-workflow.md` (P2, 435 tok)
- `docs/architecture/posix-linux-compile-gate-workflow.md` (P2, 490 tok)
- `docs/architecture/windows-mouse-companion-phase15-exit-contract.md` (P2, 750 tok)

### general
- `docs/architecture/mouse-companion-3d-runtime-blueprint.zh-CN.md` (P2, 750 tok)
- `docs/architecture/mouse-companion-click-parity-tauri-contract.zh-CN.md` (P2, 750 tok)
- `docs/architecture/mouse-companion-model-import-pipeline-contract.zh-CN.md` (P2, 750 tok)
- `docs/architecture/mouse-companion-position-mode-contract.zh-CN.md` (P2, 750 tok)

## Commands
```bash
./tools/docs/ai-context.sh index
./tools/docs/ai-context.sh route --task "automation gesture debug"
./tools/docs/ai-context.sh check --strict
./tools/docs/ai-context.sh watch
```

## Largest Docs (Trim Candidates)
- `docs/architecture/windows-mouse-companion-real-renderer-contract.md` -> ~17229 tok
- `docs/ops/windows-mouse-companion-manual-checklist.md` -> ~16102 tok
- `docs/agent-context/current.md` -> ~8515 tok
- `docs/ops/manual-commands.md` -> ~8354 tok
- `docs/architecture/windows-mouse-companion-phase1-plan.md` -> ~7505 tok
- `docs/architecture/custom-effects-wasm-route.zh-CN.md` -> ~6872 tok
- `docs/architecture/custom-effects-wasm-route.md` -> ~6707 tok
- `docs/refactoring/phase-roadmap-macos-m1-status.md` -> ~5868 tok

## Notes
- Index is machine-readable: `docs/.ai/context-index.json`.
- Route output uses token budget + keyword scoring + priority gating.
- `watch` rebuilds index on AGENTS/docs markdown changes.
