# Project Main TODO

Status source of truth for cross-capability work. Capability documents retain their details but must link back here when they create a follow-up.

## Current

| Status | Item | Acceptance / next step | Related material |
| --- | --- | --- | --- |
| pending | Full regression execution | Run `make check` in an external terminal, then record macOS/Linux results. | `docs/reviews/2026-07-15-repository-audit.md` |
| pending | Windows build validation | Confirm Syncthing freshness, then run `make build-windows` from the synced Windows workspace. | `docs/reviews/2026-07-15-repository-audit.md` |
| pending | Oversized owned modules | Triage bounded SRP refactors for the audit candidates before adding more behavior to them. | `docs/reviews/2026-07-15-repository-audit.md` |
| pending | P1 context compaction | Reduce `docs/agent-context/current.md` to its 220-line budget without discarding current contracts. | `docs/reviews/2026-07-15-repository-audit.md` |
| in_progress | Automation mapping capability | Continue only through its scoped roadmap; copy new cross-capability follow-ups here. | `docs/automation/automation-mapping-todo.zh-CN.md` |

## Risks / constraints

- Full `make check` is a high-load command. Use its component targets for low-cost validation; run the full suite from an external terminal when a complete regression pass is required.
- macOS is the primary workspace. The Windows mirror is `D:\language\cpp\code\MFCMouseEffect`; confirm Syncthing freshness before Windows-only builds.

## Archive

Completed items move here with date, outcome, validation, relevant commit, and remaining risk.

| Date | Item | Outcome / validation | Remaining risk |
| --- | --- | --- | --- |
| 2026-07-15 | Unified Makefile entrypoints | Added documented, thin `build/test/check/package/audit` targets; verified help and all underlying command-help dispatches, `make audit`, WebUI tests, and CMake configure. | Full native regression and Windows build remain pending above. |
| 2026-07-15 | Repository-wide static audit | Reviewed tracked source plus current WebUI diff; shell/Node syntax checks, security-pattern scan, CMake configure, and targeted surface gates completed. | Dynamic full-suite and Windows coverage remain pending above. |
