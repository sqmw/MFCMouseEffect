SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

# Pass options through to the underlying, platform-owned command. Example:
#   make build ARGS="--skip-webui-build"
#   make test ARGS="--skip-linux-gate"
ARGS ?=

.PHONY: help build build-macos build-windows test test-webui check check-docs package package-macos package-windows audit

help:
	@printf '%s\n' \
	  'MFCMouseEffect command entrypoints:' \
	  '  make build             Build for the current supported host.' \
	  '  make build-macos       Build the macOS core host.' \
	  '  make build-windows     Build the Windows x64 project (run on Windows).' \
	  '  make test              Run the canonical POSIX regression suite.' \
	  '  make test-webui        Run WebUI model and dev-contract tests.' \
	  '  make check             Run docs checks, WebUI tests, and POSIX regression.' \
	  '  make check-docs        Validate generated AI-context and doc hygiene.' \
	  '  make package           Package for the current supported host.' \
	  '  make package-macos     Build the macOS portable package.' \
	  '  make package-windows   Build the Windows installer (run on Windows).' \
	  '  make audit             Run non-mutating repository audit prerequisites.' \
	  '' \
	  'Append command-specific options with ARGS="...".'

build:
	@case "$$(uname -s)" in \
	  Darwin) $(MAKE) --no-print-directory build-macos ARGS="$(ARGS)" ;; \
	  MINGW*|MSYS*|CYGWIN*) $(MAKE) --no-print-directory build-windows ARGS="$(ARGS)" ;; \
	  *) echo "[mfx:fail] build is supported on macOS or Windows; use make test/check on this host." >&2; exit 1 ;; \
	esac

build-macos:
	@bash ./tools/platform/build/build-macos-project.sh $(ARGS)

build-windows:
	@bash ./tools/platform/build/build-windows-project.sh $(ARGS)

test:
	@bash ./tools/platform/regression/run-posix-regression-suite.sh --platform auto $(ARGS)

test-webui:
	@pnpm --dir MFCMouseEffect/WebUIWorkspace run test:webui-models $(ARGS)

check: check-docs test-webui test

check-docs:
	@bash ./tools/docs/ai-context.sh check --strict
	@bash ./tools/docs/doc-hygiene-check.sh

package:
	@case "$$(uname -s)" in \
	  Darwin) $(MAKE) --no-print-directory package-macos ARGS="$(ARGS)" ;; \
	  MINGW*|MSYS*|CYGWIN*) $(MAKE) --no-print-directory package-windows ARGS="$(ARGS)" ;; \
	  *) echo "[mfx:fail] package is supported on macOS or Windows." >&2; exit 1 ;; \
	esac

package-macos:
	@bash ./tools/platform/package/build-macos-portable.sh $(ARGS)

package-windows:
	@bash ./tools/platform/package/build-windows-installer.sh $(ARGS)

audit:
	@git diff --check
	@$(MAKE) --no-print-directory check-docs
	@$(MAKE) --no-print-directory test-webui
