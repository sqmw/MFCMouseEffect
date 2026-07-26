// Single source of truth for WebUI build artifacts.
//
// Consumed by:
// - vite.config.js (build targets)
// - scripts/copy-output.mjs (staging copy + retired-artifact purge)
// - scripts/test-webui-bundle-manifest.mjs (contract regression)
//
// The C++ resolver required-asset list in
// MouseFx/Server/webui/WebSettingsServer.WebUiPathResolver.cpp must stay a
// subset of the files listed here; update both sides in the same change.

export const WEBUI_BUILD_TARGETS = {
  indicator: {
    entry: 'input-indicator-main.js',
    name: 'MfxInputIndicatorSettingsBundle',
    fileName: 'input-indicator-settings.svelte.js',
  },
  trail: {
    entry: 'trail-main.js',
    name: 'MfxTrailSettingsBundle',
    fileName: 'trail-settings.svelte.js',
  },
  text: {
    entry: 'text-main.js',
    name: 'MfxTextSettingsBundle',
    fileName: 'text-settings.svelte.js',
  },
  effects: {
    entry: 'effects-main.js',
    name: 'MfxEffectsSettingsBundle',
    fileName: 'effects-settings.svelte.js',
  },
  general: {
    entry: 'general-main.js',
    name: 'MfxGeneralSettingsBundle',
    fileName: 'general-settings.svelte.js',
  },
  'mouse-companion': {
    entry: 'mouse-companion-main.js',
    name: 'MfxMouseCompanionSettingsBundle',
    fileName: 'mouse-companion-settings.svelte.js',
  },
  automation: {
    entry: 'automation-main.js',
    name: 'MfxAutomationUiBundle',
    fileName: 'automation-ui.svelte.js',
  },
  wasm: {
    entry: 'wasm-main.js',
    name: 'MfxWasmSectionBundle',
    fileName: 'wasm-settings.svelte.js',
  },
  dialog: {
    entry: 'dialog-main.js',
    name: 'MfxDialogBundle',
    fileName: 'dialog.svelte.js',
  },
  shell: {
    entry: 'shell-main.js',
    name: 'MfxSettingsShellBundle',
    fileName: 'settings-shell.svelte.js',
  },
  workspace: {
    entry: 'main.js',
    name: 'MfxSectionWorkspaceBundle',
    fileName: 'section-workspace.svelte.js',
  },
};

export const generatedWebUiFiles = Object.values(WEBUI_BUILD_TARGETS).map(
  (target) => target.fileName,
);

// Hand-maintained static files tracked in git under MFCMouseEffect/WebUI.
export const staticWebUiFiles = [
  'index.html',
  'app.js',
  'app-core.js',
  'app-actions.js',
  'app-gesture-debug.js',
  'styles.css',
  'web-api.js',
  'settings-form.js',
  'settings-form-input-indicator.js',
  'i18n.js',
  'i18n-runtime.js',
  'automation-templates.js',
];

export const managedWebUiFiles = [...generatedWebUiFiles, ...staticWebUiFiles];
