import assert from 'node:assert/strict';

import {
  pickWebUiLang,
  resolveWebUiTextTable,
  webUiText,
} from '../src/effects/web-i18n-text.js';

let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`[pass] ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`[fail] ${name}`);
    console.error(error instanceof Error ? error.stack || error.message : error);
  }
}

const CATALOG = {
  'zh-CN': {
    placeholder_effects_blacklist_search_app: '搜索应用名/app',
    btn_scope_refresh_catalog: '刷新应用列表',
  },
  'en-US': {
    placeholder_effects_blacklist_search_app: 'Search app name',
    btn_scope_refresh_catalog: 'Refresh app list',
  },
};

function fakeWindow({ lang, selected, catalog } = {}) {
  return {
    MfxWebI18n: catalog === undefined ? CATALOG : catalog,
    navigator: { language: lang || '' },
    document: {
      getElementById(id) {
        if (id === 'ui_language' && selected) {
          return { value: selected };
        }
        return null;
      },
    },
  };
}

runTest('no window falls back to fallback text', () => {
  assert.equal(webUiText('btn_scope_refresh_catalog', '刷新应用列表', null), '刷新应用列表');
  assert.equal(pickWebUiLang(null), 'en-US');
});

runTest('browser zh language resolves zh-CN table', () => {
  const win = fakeWindow({ lang: 'zh-CN' });
  assert.equal(pickWebUiLang(win), 'zh-CN');
  assert.equal(
    webUiText('btn_scope_refresh_catalog', 'fallback', win),
    '刷新应用列表',
  );
});

runTest('browser en language resolves en-US table', () => {
  const win = fakeWindow({ lang: 'en-GB' });
  assert.equal(pickWebUiLang(win), 'en-US');
  assert.equal(
    webUiText('placeholder_effects_blacklist_search_app', 'fallback', win),
    'Search app name',
  );
});

runTest('explicit ui_language select wins over browser language', () => {
  const win = fakeWindow({ lang: 'zh-CN', selected: 'en-US' });
  assert.equal(pickWebUiLang(win), 'en-US');
  assert.equal(
    webUiText('btn_scope_refresh_catalog', 'fallback', win),
    'Refresh app list',
  );
});

runTest('unknown selected language falls back to en-US table', () => {
  const win = fakeWindow({ lang: 'zh-CN', selected: 'fr-FR' });
  assert.deepEqual(resolveWebUiTextTable(win), CATALOG['en-US']);
});

runTest('missing key or missing catalog falls back to provided text', () => {
  const win = fakeWindow({ lang: 'zh-CN' });
  assert.equal(webUiText('nonexistent_key', 'fallback', win), 'fallback');
  const noCatalog = fakeWindow({ lang: 'zh-CN', catalog: null });
  assert.equal(webUiText('btn_scope_refresh_catalog', 'fallback', noCatalog), 'fallback');
  assert.deepEqual(resolveWebUiTextTable(noCatalog), {});
});

runTest('non-string table values fall back to provided text', () => {
  const win = fakeWindow({
    lang: 'zh-CN',
    catalog: { 'zh-CN': { btn_scope_refresh_catalog: 42 } },
  });
  assert.equal(webUiText('btn_scope_refresh_catalog', 'fallback', win), 'fallback');
});

if (failed > 0) {
  console.error(`${failed} test(s) failed`);
  process.exit(1);
}
console.log('effects blacklist i18n adapter tests passed');
