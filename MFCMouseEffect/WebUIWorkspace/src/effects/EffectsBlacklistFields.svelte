<script>
  import { createEventDispatcher } from "svelte";
  import MappingScopePanel from "../automation/MappingScopePanel.svelte";
  import { filterCatalogEntries, normalizeCatalogEntries } from "../automation/app-catalog.js";
  import { readAutomationAppCatalog } from "../automation/shortcut-capture-remote.js";
  import {
    catalogMetaText,
    scopeFileAccept as resolveScopeFileAccept,
  } from "../automation/mapping-panel-helpers.js";
  import { textOf } from "../automation/model.js";
  import { webUiText } from "./web-i18n-text.js";

  export let apps = [];
  export let platform = "windows";
  // Optional pre-resolved text table (same shape as AutomationEditor's
  // `i18n` prop). When absent, fall back to the runtime catalog adapter.
  export let i18n = null;

  const dispatch = createEventDispatcher();

  let draft = "";
  let appCatalogEntries = [];
  let appCatalogLoaded = false;
  let appCatalogLoading = false;
  let appCatalogError = "";
  let filePicker = null;

  function normalizedPlatform() {
    return `${platform || "windows"}`.trim().toLowerCase();
  }

  function scopeFileAccept() {
    return resolveScopeFileAccept(platform);
  }

  function normalizeAppName(value) {
    return `${value || ""}`.trim().toLowerCase();
  }

  function normalizeApps(values) {
    const out = [];
    for (const item of values || []) {
      const normalized = normalizeAppName(item);
      if (!normalized || out.includes(normalized)) {
        continue;
      }
      out.push(normalized);
    }
    return out;
  }

  function text(fallback, key) {
    if (i18n && typeof i18n === "object") {
      return textOf(i18n, key, fallback);
    }
    return webUiText(key, fallback);
  }

  $: normalizedApps = normalizeApps(apps);
  $: appCatalogView = filterCatalogEntries(
    appCatalogEntries,
    draft,
    normalizedApps,
    120,
    normalizedPlatform(),
  );
  $: scopeTexts = {
    scopeSearchPlaceholder: text("搜索应用名/app", "placeholder_effects_blacklist_search_app"),
    scopeAppPlaceholder: text("搜索应用名/app", "placeholder_effects_blacklist_search_app"),
    scopeRefreshCatalog: text("刷新应用列表", "btn_scope_refresh_catalog"),
    scopeRefreshingCatalog: text("正在刷新...", "btn_scope_refreshing_catalog"),
    scopePickFromFile: text("从文件选择 app", "btn_scope_pick_from_file_app"),
    scopeCatalogLoading: text("正在扫描应用列表...", "text_scope_catalog_loading"),
    scopeCatalogEmpty: text("没有匹配应用，可继续检索或从文件选择 app。", "text_effects_blacklist_catalog_empty_app"),
  };

  function emitChange(nextApps) {
    dispatch("change", { effects_blacklist_apps: normalizeApps(nextApps) });
  }

  function onScopeModeChange() {
    // blacklist panel always keeps selected-app mode.
  }

  function onScopeDraftInput(event) {
    draft = event.currentTarget.value;
  }

  function onScopeDraftKeydown(event) {
    if (event.key !== "Enter") {
      return;
    }
    event.preventDefault();
    if (appCatalogView.length > 0) {
      emitChange([...normalizedApps, appCatalogView[0].exe]);
      draft = "";
    }
  }

  function onRemoveScopeApp(app) {
    emitChange(normalizedApps.filter((item) => item !== app));
  }

  function onAddCatalogScopeApp(app) {
    emitChange([...normalizedApps, app]);
    draft = "";
  }

  async function loadAppCatalog(force = false) {
    if (appCatalogLoading) {
      return;
    }
    appCatalogLoading = true;
    appCatalogError = "";
    try {
      const appsFromRuntime = await readAutomationAppCatalog(force);
      appCatalogEntries = normalizeCatalogEntries(appsFromRuntime, normalizedPlatform());
      appCatalogLoaded = true;
    } catch (_error) {
      appCatalogError = text("应用列表加载失败。", "text_effects_blacklist_catalog_error_app");
      if (!appCatalogLoaded) {
        appCatalogEntries = [];
      }
    } finally {
      appCatalogLoading = false;
    }
  }

  function onRefreshAppCatalog() {
    void loadAppCatalog(true);
  }

  function onPickFile() {
    if (!filePicker) {
      return;
    }
    filePicker.value = "";
    filePicker.click();
  }

  function onFileChange(event) {
    const input = event.currentTarget;
    const files = Array.from(input?.files || []);
    for (const file of files) {
      const name = normalizeAppName(file?.name || "");
      if (!name) {
        continue;
      }
      emitChange([...normalizedApps, name]);
    }
    draft = "";
    if (input) {
      input.value = "";
    }
  }

  $: if (!appCatalogLoaded && !appCatalogLoading) {
    void loadAppCatalog(false);
  }
</script>

<div class="effects-blacklist-card">
  <MappingScopePanel
    layout="two-column"
    rowEnabled={true}
    scopeOptions={[{ value: "selected", label: text("指定应用（多选）", "auto_app_scope_selected") }]}
    scopeMode="selected"
    scopeApps={normalizedApps}
    scopeDraft={draft}
    texts={scopeTexts}
    catalogEntries={appCatalogView}
    {appCatalogLoading}
    {appCatalogError}
    {onScopeModeChange}
    {onScopeDraftInput}
    {onScopeDraftKeydown}
    {onRemoveScopeApp}
    {onAddCatalogScopeApp}
    {onRefreshAppCatalog}
    {onPickFile}
    {catalogMetaText}
  />

  <input
    class="automation-scope-file-input"
    type="file"
    bind:this={filePicker}
    accept={scopeFileAccept()}
    on:change={onFileChange}
  />
</div>

<style>
  .effects-blacklist-card {
    display: grid;
    gap: 10px;
  }

</style>
