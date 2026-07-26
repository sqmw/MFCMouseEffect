// Shared adapter for JS-side text lookups against the runtime i18n
// catalog (`window.MfxWebI18n`, registered by WebUI/i18n.js). Language
// pick mirrors i18n-runtime.js: explicit `ui_language` select first,
// then browser language, then en-US.

const FALLBACK_LANG = 'en-US';

function resolveWindow(win) {
  if (win !== undefined) {
    return win;
  }
  return typeof window === 'undefined' ? null : window;
}

export function pickWebUiLang(win) {
  const w = resolveWindow(win);
  if (!w) {
    return FALLBACK_LANG;
  }
  const selected = w.document?.getElementById?.('ui_language')?.value || '';
  if (selected) {
    return selected;
  }
  const browserLang = `${w.navigator?.language || ''}`.toLowerCase();
  return browserLang.startsWith('zh') ? 'zh-CN' : FALLBACK_LANG;
}

export function resolveWebUiTextTable(win) {
  const w = resolveWindow(win);
  if (!w) {
    return {};
  }
  const catalog = w.MfxWebI18n;
  if (!catalog || typeof catalog !== 'object') {
    return {};
  }
  const lang = pickWebUiLang(w);
  const table = catalog[lang] || catalog[FALLBACK_LANG];
  return table && typeof table === 'object' ? table : {};
}

export function webUiText(key, fallback, win) {
  const table = resolveWebUiTextTable(win);
  const value = table[key];
  if (typeof value === 'string' && value) {
    return value;
  }
  return fallback || '';
}
