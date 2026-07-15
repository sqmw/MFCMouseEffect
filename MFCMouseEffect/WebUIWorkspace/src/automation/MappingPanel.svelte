<script>
  import { createEventDispatcher, onDestroy } from 'svelte';
  import MappingScopePanel from './MappingScopePanel.svelte';
  import MappingShortcutPanel from './MappingShortcutPanel.svelte';
  import { filterCatalogEntries, normalizeCatalogEntries } from './app-catalog.js';
  import { normalizeEditorActions } from './model.js';
  import {
    pollShortcutCapture,
    readAutomationAppCatalog,
    startShortcutCapture,
    stopShortcutCapture,
  } from './shortcut-capture-remote.js';
  import { shortcutFromKeyboardEvent } from './shortcuts.js';
  import {
    CAPTURE_TARGET_KEYS,
    CAPTURE_TARGET_MODIFIERS,
    buildModifierPayloadFromShortcut,
    chainForRow as buildChainForRow,
    catalogMetaText as buildCatalogMetaText,
    gestureButtonForRow as buildGestureButtonForRow,
    gestureSummaryForRow as buildGestureSummaryForRow,
    isModifierOnlyShortcut,
    modifierInputPlaceholderForRow as buildModifierInputPlaceholderForRow,
    modifierInputValueForRow as buildModifierInputValueForRow,
    modifierShortcutTextForRow as buildModifierShortcutTextForRow,
    normalizedPlatform as resolveNormalizedPlatform,
    scopeAppsForRow as resolveScopeAppsForRow,
    scopeDraftForRow as resolveScopeDraftForRow,
    scopeFileAccept as resolveScopeFileAccept,
    scopeModeForRow as resolveScopeModeForRow,
    scopeSummaryForRow as buildScopeSummaryForRow,
    shortcutSummaryForRow as buildShortcutSummaryForRow,
    triggerValueFromEvent as buildTriggerValueFromEvent,
  } from './mapping-panel-helpers.js';

  export let kind = 'mouse';
  export let rows = [];
  export let options = [];
  export let scopeOptions = [];
  export let gestureButtonOptions = [];
  export let templateValue = '';
  export let templateOptions = [];
  export let texts = {};
  export let platform = 'windows';
  const dispatch = createEventDispatcher();
  let recordingRowId = '';
  let recordingTarget = '';
  let remoteCaptureSessionId = '';
  let remoteCapturePollTimer = 0;
  let localCaptureCommitTimer = 0;
  let localCapturePending = null;
  let globalShortcutSuppressionBound = false;
  let appCatalogEntries = [];
  let appCatalogLoaded = false;
  let appCatalogLoading = false;
  let appCatalogError = '';
  let scopeFilePicker = null;
  let scopeFileRowId = '';

  function normalizedPlatform() {
    return resolveNormalizedPlatform(platform);
  }

  function scopeFileAccept() {
    return resolveScopeFileAccept(platform);
  }

  function isCapturing(rowId, target = '') {
    return recordingRowId === rowId && recordingTarget === target;
  }

  function clearRemotePollTimer() {
    if (!remoteCapturePollTimer) {
      return;
    }
    window.clearTimeout(remoteCapturePollTimer);
    remoteCapturePollTimer = 0;
  }

  function clearLocalCapturePending() {
    if (localCaptureCommitTimer) {
      window.clearTimeout(localCaptureCommitTimer);
      localCaptureCommitTimer = 0;
    }
    localCapturePending = null;
  }

  function onGlobalCaptureShortcut(event) {
    if (!recordingRowId) {
      return;
    }
    if (!event) {
      return;
    }
    event.preventDefault();
    if (typeof event.stopImmediatePropagation === 'function') {
      event.stopImmediatePropagation();
    }
    if (typeof event.stopPropagation === 'function') {
      event.stopPropagation();
    }
  }

  function bindGlobalShortcutSuppression() {
    if (globalShortcutSuppressionBound || typeof window === 'undefined') {
      return;
    }
    window.addEventListener('keydown', onGlobalCaptureShortcut, true);
    window.addEventListener('keyup', onGlobalCaptureShortcut, true);
    window.addEventListener('keypress', onGlobalCaptureShortcut, true);
    globalShortcutSuppressionBound = true;
  }

  function unbindGlobalShortcutSuppression() {
    if (!globalShortcutSuppressionBound || typeof window === 'undefined') {
      return;
    }
    window.removeEventListener('keydown', onGlobalCaptureShortcut, true);
    window.removeEventListener('keyup', onGlobalCaptureShortcut, true);
    window.removeEventListener('keypress', onGlobalCaptureShortcut, true);
    globalShortcutSuppressionBound = false;
  }

  async function endRemoteCapture(sessionId = remoteCaptureSessionId) {
    clearRemotePollTimer();
    if (!sessionId) {
      return;
    }
    if (remoteCaptureSessionId === sessionId) {
      remoteCaptureSessionId = '';
    }
    try {
      await stopShortcutCapture(sessionId);
    } catch (_error) {
      // Keep UI responsive even if server session already ended.
    }
  }

  function activeCaptureInputId(rowId, target = recordingTarget) {
    if (target === CAPTURE_TARGET_MODIFIERS) {
      return modifierInputId(rowId);
    }
    const actionIndex = actionIndexFromCaptureTarget(target);
    if (actionIndex >= 0) {
      return actionShortcutInputId(rowId, actionIndex);
    }
    return '';
  }

  function stopRecording(rowId, blurInput = false) {
    if (recordingRowId !== rowId) {
      return;
    }
    clearLocalCapturePending();
    const target = recordingTarget;
    recordingRowId = '';
    recordingTarget = '';
    if (blurInput) {
      const input = document.getElementById(activeCaptureInputId(rowId, target));
      if (input) {
        input.blur();
      }
    }
  }

  function scheduleRemotePoll(rowId, target, sessionId) {
    clearRemotePollTimer();
    remoteCapturePollTimer = window.setTimeout(() => {
      void pollRemoteCapture(rowId, target, sessionId);
    }, 120);
  }

  async function pollRemoteCapture(rowId, target, sessionId) {
    if (recordingRowId !== rowId || recordingTarget !== target || remoteCaptureSessionId !== sessionId) {
      return;
    }

    try {
      const result = await pollShortcutCapture(sessionId);
      if (recordingRowId !== rowId || recordingTarget !== target || remoteCaptureSessionId !== sessionId) {
        return;
      }

      if (result.status === 'captured' && result.shortcut) {
        clearLocalCapturePending();
        if (target === CAPTURE_TARGET_MODIFIERS) {
          applyTriggerModifierShortcut(rowId, result.shortcut);
        } else {
          const actionIndex = actionIndexFromCaptureTarget(target);
          if (actionIndex >= 0) {
            applyActionShortcut(rowId, actionIndex, result.shortcut);
          }
        }
        remoteCaptureSessionId = '';
        stopRecording(rowId, true);
        return;
      }

      if (result.status === 'expired' || result.status === 'invalid') {
        remoteCaptureSessionId = '';
        stopRecording(rowId, true);
        return;
      }

      scheduleRemotePoll(rowId, target, sessionId);
    } catch (_error) {
      // Fallback to local keydown capture if remote polling fails.
      remoteCaptureSessionId = '';
      clearRemotePollTimer();
    }
  }

  async function beginRemoteCapture(rowId, target = '') {
    try {
      const sessionId = await startShortcutCapture(10000);
      if (!sessionId || recordingRowId !== rowId || recordingTarget !== target) {
        return;
      }
      remoteCaptureSessionId = sessionId;
      scheduleRemotePoll(rowId, target, sessionId);
    } catch (_error) {
      // Server capture unavailable. Keep local keydown capture active.
      remoteCaptureSessionId = '';
      clearRemotePollTimer();
    }
  }

  function emitRowChange(rowId, key, value) {
    const detail = { kind, rowId, key, value };
    dispatch('rowchange', detail);
  }

  function emitRemove(rowId) {
    if (recordingRowId === rowId) {
      clearLocalCapturePending();
      recordingRowId = '';
      recordingTarget = '';
      void endRemoteCapture();
    }
    const detail = { kind, rowId };
    dispatch('remove', detail);
  }

  function emitAdd() {
    const detail = { kind };
    dispatch('add', detail);
  }

  function emitTemplateChange(value) {
    const detail = { kind, value };
    dispatch('templatechange', detail);
  }

  function emitApplyTemplate() {
    const detail = { kind };
    dispatch('applytemplate', detail);
  }

  function actionShortcutCaptureTarget(index) {
    return `${CAPTURE_TARGET_KEYS}:${index}`;
  }

  function actionIndexFromCaptureTarget(target) {
    const text = `${target || ''}`;
    if (!text.startsWith(`${CAPTURE_TARGET_KEYS}:`)) {
      return -1;
    }
    const parsed = Number.parseInt(text.slice(`${CAPTURE_TARGET_KEYS}:`.length), 10);
    return Number.isInteger(parsed) && parsed >= 0 ? parsed : -1;
  }

  function actionShortcutInputId(rowId, index) {
    return `auto_action_shortcut_${kind}_${rowId}_${index}`;
  }

  function normalizedActionsForRow(row) {
    return normalizeEditorActions(row?.actions);
  }

  function commitRowActions(row, nextActions) {
    emitRowChange(row.id, 'actions', normalizeEditorActions(nextActions));
  }

  function updateActionByIndex(row, index, updater) {
    const actions = normalizedActionsForRow(row);
    if (index < 0 || index >= actions.length) {
      return;
    }
    const nextAction = updater(actions[index], index);
    const nextActions = actions.slice();
    if (nextAction) {
      nextActions[index] = nextAction;
    } else {
      nextActions.splice(index, 1);
    }
    commitRowActions(row, nextActions);
  }

  function findRowById(rowId) {
    return rows.find((item) => item.id === rowId);
  }

  function applyActionShortcut(rowId, index, shortcut) {
    const row = findRowById(rowId);
    if (!row) {
      return;
    }
    updateActionByIndex(row, index, (action) => ({
      ...action,
      type: 'send_shortcut',
      shortcut,
    }));
  }

  function focusCaptureInput(rowId, target = '') {
    const input = document.getElementById(activeCaptureInputId(rowId, target));
    if (!input) {
      return;
    }
    input.focus();
    input.select();
  }

  function onActionShortcutKeydown(row, index, event) {
    if (!row.enabled) {
      return;
    }

    if (!isCapturing(row.id, actionShortcutCaptureTarget(index))) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    const lowered = `${event.key || ''}`.toLowerCase();
    if (lowered === 'escape') {
      clearLocalCapturePending();
      event.currentTarget.blur();
      stopRecording(row.id);
      void endRemoteCapture();
      return;
    }

    if ((lowered === 'backspace' || lowered === 'delete') &&
      !event.ctrlKey &&
      !event.altKey &&
      !event.shiftKey &&
      !event.metaKey) {
      clearLocalCapturePending();
      updateActionByIndex(row, index, () => null);
      stopRecording(row.id);
      void endRemoteCapture();
      return;
    }

    const shortcut = shortcutFromKeyboardEvent(event, platform);
    if (!shortcut) {
      return;
    }

    if (isModifierOnlyShortcut(shortcut)) {
      clearLocalCapturePending();
      localCapturePending = { rowId: row.id, target: actionShortcutCaptureTarget(index), shortcut };
      localCaptureCommitTimer = window.setTimeout(() => {
        if (!localCapturePending) {
          return;
        }
        const pending = localCapturePending;
        clearLocalCapturePending();
        const pendingIndex = actionIndexFromCaptureTarget(pending.target);
        if (pendingIndex >= 0) {
          applyActionShortcut(pending.rowId, pendingIndex, pending.shortcut);
        }
        stopRecording(pending.rowId);
        void endRemoteCapture();
      }, 240);
      return;
    }

    clearLocalCapturePending();
    applyActionShortcut(row.id, index, shortcut);
    stopRecording(row.id);
    void endRemoteCapture();
  }

  function onActionShortcutInput(row, index, event) {
    if (isCapturing(row.id, actionShortcutCaptureTarget(index))) {
      return;
    }
    applyActionShortcut(row.id, index, event.currentTarget.value);
  }

  function onActionTypeChange(row, index, type) {
    const normalizedType = `${type || ''}`.trim().toLowerCase();
    updateActionByIndex(row, index, () => {
      if (normalizedType === 'delay') {
        return { type: 'delay', delay_ms: 120 };
      }
      if (normalizedType === 'open_url') {
        return { type: 'open_url', url: '' };
      }
      if (normalizedType === 'launch_app') {
        return { type: 'launch_app', app_path: '' };
      }
      return { type: 'send_shortcut', shortcut: '' };
    });
  }

  function onActionDelayInput(row, index, event) {
    const value = Number.parseInt(event.currentTarget.value, 10);
    updateActionByIndex(row, index, (action) => ({
      ...action,
      type: 'delay',
      delay_ms: Number.isFinite(value) ? value : 0,
    }));
  }

  function onActionUrlInput(row, index, event) {
    updateActionByIndex(row, index, (action) => ({
      ...action,
      type: 'open_url',
      url: event.currentTarget.value,
    }));
  }

  function onActionAppPathInput(row, index, event) {
    updateActionByIndex(row, index, (action) => ({
      ...action,
      type: 'launch_app',
      app_path: event.currentTarget.value,
    }));
  }

  function moveAction(row, index, direction) {
    const nextIndex = index + direction;
    const actions = normalizedActionsForRow(row);
    if (index < 0 || nextIndex < 0 || index >= actions.length || nextIndex >= actions.length) {
      return;
    }
    const nextActions = actions.slice();
    const [moved] = nextActions.splice(index, 1);
    nextActions.splice(nextIndex, 0, moved);
    commitRowActions(row, nextActions);
  }

  function removeAction(row, index) {
    updateActionByIndex(row, index, () => null);
  }

  function addAction(row, action) {
    const actions = normalizedActionsForRow(row);
    commitRowActions(row, actions.concat(action));
  }

  function modifierInputId(rowId) {
    return `auto_trigger_modifiers_${kind}_${rowId}`;
  }

  function applyTriggerModifierFlags(rowId, shortcut, emptyMode = 'any') {
    emitRowChange(rowId, 'modifiers', buildModifierPayloadFromShortcut(shortcut, emptyMode));
  }

  function applyTriggerModifierShortcut(rowId, shortcut) {
    applyTriggerModifierFlags(rowId, shortcut, 'none');
  }

  function modifierShortcutTextForRow(row) {
    return buildModifierShortcutTextForRow(row, texts, platform);
  }

  function modifierInputValueForRow(row) {
    return buildModifierInputValueForRow(row, texts, platform);
  }

  function modifierInputPlaceholderForRow(row) {
    return buildModifierInputPlaceholderForRow(row, texts, platform);
  }

  function onTriggerModifierKeydown(row, event) {
    if (!row.enabled) {
      return;
    }
    if (!isCapturing(row.id, CAPTURE_TARGET_MODIFIERS)) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    const lowered = `${event.key || ''}`.toLowerCase();
    if (lowered === 'escape') {
      clearLocalCapturePending();
      event.currentTarget.blur();
      stopRecording(row.id);
      void endRemoteCapture();
      return;
    }

    if ((lowered === 'backspace' || lowered === 'delete') &&
      !event.ctrlKey &&
      !event.altKey &&
      !event.shiftKey &&
      !event.metaKey) {
      clearLocalCapturePending();
      emitRowChange(row.id, 'modifiers', {
        mode: 'none',
        primary: false,
        shift: false,
        alt: false,
      });
      stopRecording(row.id);
      void endRemoteCapture();
      return;
    }

    const shortcut = shortcutFromKeyboardEvent(event, platform);
    if (!shortcut) {
      return;
    }

    if (isModifierOnlyShortcut(shortcut)) {
      clearLocalCapturePending();
      localCapturePending = { rowId: row.id, target: CAPTURE_TARGET_MODIFIERS, shortcut };
      localCaptureCommitTimer = window.setTimeout(() => {
        if (!localCapturePending) {
          return;
        }
        const pending = localCapturePending;
        clearLocalCapturePending();
        applyTriggerModifierShortcut(pending.rowId, pending.shortcut);
        stopRecording(pending.rowId);
        void endRemoteCapture();
      }, 240);
      return;
    }

    clearLocalCapturePending();
    applyTriggerModifierShortcut(row.id, shortcut);
    stopRecording(row.id);
    void endRemoteCapture();
  }

  function onTriggerModifierInput(row, event) {
    if (isCapturing(row.id, CAPTURE_TARGET_MODIFIERS)) {
      return;
    }
    applyTriggerModifierFlags(row.id, event.currentTarget.value, 'none');
  }

  function chainForRow(row) {
    return buildChainForRow(row, options);
  }

  function triggerValueFromEvent(event, fallbackTrigger) {
    return buildTriggerValueFromEvent(event, fallbackTrigger, options);
  }

  function onChainChange(row, event) {
    const nextTrigger = triggerValueFromEvent(event, row?.trigger || row?.triggerChain || '');
    if (!nextTrigger) {
      return;
    }
    emitRowChange(row.id, 'triggerChain', nextTrigger);
  }

  function scopeModeForRow(row) {
    return resolveScopeModeForRow(row);
  }

  function scopeAppsForRow(row) {
    return resolveScopeAppsForRow(row);
  }

  function scopeDraftForRow(row) {
    return resolveScopeDraftForRow(row);
  }

  function onScopeModeChange(row, event) {
    emitRowChange(row.id, 'appScopeMode', event.currentTarget.value);
  }

  function onScopeDraftInput(row, event) {
    emitRowChange(row.id, 'appScopeDraft', event.currentTarget.value);
  }

  function onScopeDraftKeydown(row, event) {
    if (event.key !== 'Enter') {
      return;
    }
    event.preventDefault();
    const entries = catalogEntriesForRow(row);
    if (entries.length === 0) {
      return;
    }
    addCatalogScopeApp(row, entries[0].exe);
    emitRowChange(row.id, 'appScopeDraft', '');
  }

  function removeScopeApp(row, app) {
    emitRowChange(row.id, 'appScopeRemove', app);
  }

  function catalogEntriesForRow(row) {
    return filterCatalogEntries(
      appCatalogEntries,
      scopeDraftForRow(row),
      scopeAppsForRow(row),
      120,
      normalizedPlatform());
  }

  function catalogMetaText(entry) {
    return buildCatalogMetaText(entry);
  }

  function addCatalogScopeApp(row, processName) {
    if (!row || !row.id || !row.enabled) {
      return;
    }
    emitRowChange(row.id, 'appScopeAdd', processName);
  }

  function onScopeFilePick(row) {
    if (!row || !row.id || !row.enabled || !scopeFilePicker) {
      return;
    }
    scopeFileRowId = row.id;
    scopeFilePicker.value = '';
    scopeFilePicker.click();
  }

  function onScopeFileChange(event) {
    const input = event.currentTarget;
    const rowId = scopeFileRowId;
    scopeFileRowId = '';
    const files = Array.from(input?.files || []);
    if (!rowId || files.length === 0) {
      if (input) {
        input.value = '';
      }
      return;
    }

    for (const file of files) {
      const name = `${file?.name || ''}`.trim();
      if (!name) {
        continue;
      }
      emitRowChange(rowId, 'appScopeAdd', name);
    }
    if (input) {
      input.value = '';
    }
  }

  async function loadAppCatalog(force = false) {
    if (appCatalogLoading) {
      return;
    }
    appCatalogLoading = true;
    appCatalogError = '';
    try {
      const apps = await readAutomationAppCatalog(force);
      appCatalogEntries = normalizeCatalogEntries(apps, normalizedPlatform());
      appCatalogLoaded = true;
    } catch (_error) {
      appCatalogError = texts.scopeCatalogLoadFailed || 'Failed to load app list.';
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

  function toggleRecord(rowId, target = '') {
    if (recordingRowId === rowId && recordingTarget === target) {
      clearLocalCapturePending();
      recordingRowId = '';
      recordingTarget = '';
      const input = document.getElementById(activeCaptureInputId(rowId, target));
      if (input) {
        input.blur();
      }
      void endRemoteCapture();
      return;
    }

    if (recordingRowId && recordingRowId !== rowId) {
      stopRecording(recordingRowId, true);
    }
    if (remoteCaptureSessionId) {
      void endRemoteCapture(remoteCaptureSessionId);
    }

    clearLocalCapturePending();
    recordingRowId = rowId;
    recordingTarget = target;
    focusCaptureInput(rowId, target);
    void beginRemoteCapture(rowId, target);
  }

  function onRowToggle(rowId, event) {
    const details = event?.currentTarget;
    if (!details || details.open) {
      return;
    }
    if (recordingRowId === rowId) {
      clearLocalCapturePending();
      stopRecording(rowId, true);
      void endRemoteCapture();
    }
  }

  function scopeSummaryForRow(row) {
    return buildScopeSummaryForRow(row, texts);
  }

  function shortcutSummaryForRow(row) {
    return buildShortcutSummaryForRow(row, texts);
  }

  function gestureButtonForRow(row) {
    return buildGestureButtonForRow(row, gestureButtonOptions);
  }

  function gestureSummaryForRow(row) {
    return buildGestureSummaryForRow(row, { kind, options, texts, gestureButtonOptions });
  }

  $: {
    if (recordingRowId) {
      const activeRow = rows.find((item) => item.id === recordingRowId);
      if (activeRow && activeRow.enabled) {
        // Active capture row still valid.
      } else {
        const staleId = recordingRowId;
        const staleTarget = recordingTarget;
        clearLocalCapturePending();
        recordingRowId = '';
        recordingTarget = '';
        void endRemoteCapture();
        const input = document.getElementById(activeCaptureInputId(staleId, staleTarget));
        if (input) {
          input.blur();
        }
      }
    }
  }

  $: {
    const hasSelectedScopeRow = rows.some((row) => scopeModeForRow(row) === 'selected');
    if (hasSelectedScopeRow && !appCatalogLoaded && !appCatalogLoading) {
      void loadAppCatalog(false);
    }
  }

  onDestroy(() => {
    clearLocalCapturePending();
    unbindGlobalShortcutSuppression();
    clearRemotePollTimer();
    if (remoteCaptureSessionId) {
      void endRemoteCapture(remoteCaptureSessionId);
    }
  });

  $: {
    if (recordingRowId) {
      bindGlobalShortcutSuppression();
    } else {
      unbindGlobalShortcutSuppression();
    }
  }
</script>

<div
  class="automation-panel"
  class:automation-panel--mouse={kind === 'mouse'}
  class:automation-panel--gesture={kind === 'gesture'}
>
  <div class="automation-list">
    {#if rows.length === 0}
      <div class="automation-empty">{texts.empty}</div>
    {/if}
    {#each rows as row (row.id)}
      <div
        class="automation-row"
        class:automation-row--mouse={kind === 'mouse'}
        class:automation-row--gesture={kind === 'gesture'}
        class:is-disabled={!row.enabled}
        class:is-conflict={row.hasConflict}
      >
        <input
          class="automation-toggle"
          type="checkbox"
          checked={row.enabled}
          title={texts.enabledTitle}
          on:change={(event) => emitRowChange(row.id, 'enabled', event.currentTarget.checked)}
        />
        <details class="automation-collapse" on:toggle={(event) => onRowToggle(row.id, event)}>
          <summary
            class="automation-row-head"
            title={texts.expand || 'Expand'}
            aria-label={texts.expand || 'Expand'}
          >
            <span class="automation-row-head-icon" aria-hidden="true"></span>
            <span class="automation-row-head-main">{gestureSummaryForRow(row)}</span>
            <span class="automation-row-head-badges">
              <span class="automation-row-head-meta">{scopeSummaryForRow(row)}</span>
              {#if kind === 'gesture'}
                <span class="automation-row-head-meta">{modifierShortcutTextForRow(row)}</span>
              {/if}
              <span class="automation-row-head-meta">{shortcutSummaryForRow(row)}</span>
            </span>
            <span class="automation-row-head-tools">
              <button
                class="automation-row-remove"
                type="button"
                on:click|preventDefault|stopPropagation={() => emitRemove(row.id)}
                title={texts.remove}
                aria-label={texts.remove}
              >
                <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
                  <path
                    d="M6 2.5h4m-6 2h8m-7 0v7m3-7v7m3-7v7M5.5 2.5l.4-1h4.2l.4 1m-6.1 0h7.2l-.5 9.2a1 1 0 0 1-1 .8H5.9a1 1 0 0 1-1-.8L4.4 2.5Z"
                    fill="none"
                    stroke="currentColor"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.3"
                  />
                </svg>
              </button>
            </span>
          </summary>
          <div
            class="automation-row-body"
            class:automation-row-body--mouse={kind === 'mouse'}
            class:automation-row-body--gesture={kind === 'gesture'}
            class:is-scope-all={scopeModeForRow(row) !== 'selected'}
          >
            <MappingShortcutPanel
              rowId={row.id}
              {row}
              rowEnabled={row.enabled}
              {kind}
              {texts}
              captureTargetKeys={CAPTURE_TARGET_KEYS}
              captureTargetModifiers={CAPTURE_TARGET_MODIFIERS}
              modifierInputId={modifierInputId(row.id)}
              actionShortcutInputId={(index) => actionShortcutInputId(row.id, index)}
              modifierInputValue={modifierInputValueForRow(row)}
              modifierInputPlaceholder={modifierInputPlaceholderForRow(row)}
              gestureButtonValue={gestureButtonForRow(row)}
              {gestureButtonOptions}
              triggerOptions={options}
              chainValue={chainForRow(row)}
              {isCapturing}
              onModifierKeydown={(event) => onTriggerModifierKeydown(row, event)}
              onModifierInput={(event) => onTriggerModifierInput(row, event)}
              onActionShortcutKeydown={(index, event) => onActionShortcutKeydown(row, index, event)}
              onActionShortcutInput={(index, event) => onActionShortcutInput(row, index, event)}
              onToggleActionRecord={(index) => toggleRecord(row.id, actionShortcutCaptureTarget(index))}
              onActionTypeChange={(index, type) => onActionTypeChange(row, index, type)}
              onActionDelayInput={(index, event) => onActionDelayInput(row, index, event)}
              onActionUrlInput={(index, event) => onActionUrlInput(row, index, event)}
              onActionAppPathInput={(index, event) => onActionAppPathInput(row, index, event)}
              onActionMoveUp={(index) => moveAction(row, index, -1)}
              onActionMoveDown={(index) => moveAction(row, index, 1)}
              onActionRemove={(index) => removeAction(row, index)}
              on:addaction={(event) => addAction(row, event.detail?.action)}
              onToggleModifierRecord={(target) => toggleRecord(row.id, target)}
              onTriggerButtonChange={(event) => emitRowChange(row.id, 'triggerButton', event.currentTarget.value)}
              onGestureTriggerChange={(event) => emitRowChange(row.id, 'triggerChain', event.detail?.trigger)}
              onGesturePatternChange={(event) => emitRowChange(row.id, 'gesturePattern', event.detail?.gesturePattern)}
              onChainChange={(event) => onChainChange(row, event)}
            />
            <MappingScopePanel
              rowEnabled={row.enabled}
              scopeOptions={scopeOptions}
              scopeMode={scopeModeForRow(row)}
              scopeApps={scopeAppsForRow(row)}
              scopeDraft={scopeDraftForRow(row)}
              {texts}
              catalogEntries={filterCatalogEntries(appCatalogEntries, scopeDraftForRow(row), scopeAppsForRow(row), 120, normalizedPlatform())}
              appCatalogLoading={appCatalogLoading}
              appCatalogError={appCatalogError}
              onScopeModeChange={(event) => onScopeModeChange(row, event)}
              onScopeDraftInput={(event) => onScopeDraftInput(row, event)}
              onScopeDraftKeydown={(event) => onScopeDraftKeydown(row, event)}
              onRemoveScopeApp={(app) => removeScopeApp(row, app)}
              onAddCatalogScopeApp={(app) => addCatalogScopeApp(row, app)}
              onRefreshAppCatalog={onRefreshAppCatalog}
              onPickFile={() => onScopeFilePick(row)}
              catalogMetaText={catalogMetaText}
            />
          </div>
        </details>
        <div class="automation-note" class:is-visible={!!row.note}>{row.note}</div>
      </div>
    {/each}
  </div>

  {#if recordingRowId}
    <div class="automation-capture-hint is-active">
      {recordingTarget === CAPTURE_TARGET_MODIFIERS
        ? (texts.captureHintModifierActive || texts.captureHintActive)
        : texts.captureHintActive}
    </div>
  {/if}

  <div class="automation-actions">
    <button class="btn-soft" type="button" on:click={emitAdd}>
      {texts.add}
    </button>
    <select
      class="automation-template-select"
      value={templateValue}
      title={texts.templateTitle}
      on:change={(event) => emitTemplateChange(event.currentTarget.value)}
    >
      <option value="">{texts.templateNone}</option>
      {#each templateOptions as option (option.id)}
        <option value={option.id}>{option.label}</option>
      {/each}
    </select>
    <button class="btn-soft" type="button" disabled={!templateValue} on:click={emitApplyTemplate}>
      {texts.applyTemplate}
    </button>
  </div>

  <input
    class="automation-scope-file-input"
    type="file"
    accept={scopeFileAccept()}
    multiple
    bind:this={scopeFilePicker}
    on:change={onScopeFileChange}
  />
</div>
