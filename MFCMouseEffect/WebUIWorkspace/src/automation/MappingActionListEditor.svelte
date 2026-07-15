<script>
  import { createEventDispatcher } from 'svelte';

  export let rowId = '';
  export let row = {};
  export let rowEnabled = true;
  export let kind = 'mouse';
  export let texts = {};
  export let captureTargetKeys = 'keys';
  export let isCapturing = () => false;
  export let actionShortcutInputId = () => '';
  export let onActionShortcutKeydown = null;
  export let onActionShortcutInput = null;
  export let onToggleActionRecord = null;
  export let onActionTypeChange = null;
  export let onActionDelayInput = null;
  export let onActionUrlInput = null;
  export let onActionAppPathInput = null;
  export let onActionMoveUp = null;
  export let onActionMoveDown = null;
  export let onActionRemove = null;

  const dispatch = createEventDispatcher();
  let actions = [];

  function callHandler(handler, ...args) {
    if (typeof handler === 'function') {
      handler(...args);
    }
  }

  function emitAddAction(action) {
    dispatch('addaction', { action });
  }

  function actionTypeOf(action) {
    return `${action?.type || 'send_shortcut'}`.trim().toLowerCase() || 'send_shortcut';
  }

  $: actions = Array.isArray(row?.actions) ? row.actions : [];
</script>

<div
  class="automation-col automation-action-list"
  class:automation-action-list--mouse={kind === 'mouse'}
  class:automation-action-list--gesture={kind === 'gesture'}
>
  {#if kind !== 'mouse'}
    <div class="automation-shortcut-label">{texts.actionsLabel}</div>
  {/if}

  {#if actions.length === 0}
    <div class="automation-action-empty">{texts.actionsEmpty}</div>
  {/if}

  {#each actions as action, index (`${action.type || 'send_shortcut'}-${index}`)}
    <div class="automation-action-card">
      <div class="automation-action-card-head">
        <span class="automation-action-index">{texts.actionLabel} {index + 1}</span>
        <div class="automation-action-card-tools">
          <button
            class="btn-soft automation-action-tool"
            type="button"
            disabled={!rowEnabled || index === 0}
            title={texts.moveUp}
            aria-label={texts.moveUp}
            on:click={() => callHandler(onActionMoveUp, index)}
          >
            <span aria-hidden="true">&#8593;</span>
            <span class="sr-only">{texts.moveUp}</span>
          </button>
          <button
            class="btn-soft automation-action-tool"
            type="button"
            disabled={!rowEnabled || index >= actions.length - 1}
            title={texts.moveDown}
            aria-label={texts.moveDown}
            on:click={() => callHandler(onActionMoveDown, index)}
          >
            <span aria-hidden="true">&#8595;</span>
            <span class="sr-only">{texts.moveDown}</span>
          </button>
          <button
            class="btn-soft automation-action-tool"
            type="button"
            disabled={!rowEnabled}
            title={texts.remove}
            aria-label={texts.remove}
            on:click={() => callHandler(onActionRemove, index)}
          >
            <span aria-hidden="true">&times;</span>
            <span class="sr-only">{texts.remove}</span>
          </button>
        </div>
      </div>

      <div class="automation-shortcut-label">{texts.actionTypeLabel}</div>
      <select
        class="automation-modifier-mode automation-action-type-select"
        disabled={!rowEnabled}
        value={actionTypeOf(action)}
        on:change={(event) => callHandler(onActionTypeChange, index, event.currentTarget.value)}
      >
        <option value="send_shortcut">{texts.actionTypeShortcut}</option>
        <option value="delay">{texts.actionTypeDelay}</option>
        <option value="open_url">{texts.actionTypeOpenUrl}</option>
        <option value="launch_app">{texts.actionTypeLaunchApp}</option>
      </select>

      {#if actionTypeOf(action) === 'send_shortcut'}
        <div class="automation-shortcut-label">{texts.shortcutLabel}</div>
        <div
          class="automation-shortcut-head"
          class:is-recording={isCapturing(rowId, `${captureTargetKeys}:${index}`)}
        >
          <input
            id={actionShortcutInputId(index)}
            class="automation-keys"
            type="text"
            disabled={!rowEnabled}
            readonly={isCapturing(rowId, `${captureTargetKeys}:${index}`)}
            value={action.shortcut || ''}
            placeholder={texts.shortcutPlaceholder}
            on:keydown={(event) => callHandler(onActionShortcutKeydown, index, event)}
            on:input={(event) => callHandler(onActionShortcutInput, index, event)}
          />
          <button
            class="btn-soft automation-record"
            class:is-recording={isCapturing(rowId, `${captureTargetKeys}:${index}`)}
            type="button"
            disabled={!rowEnabled}
            on:click={() => callHandler(onToggleActionRecord, index)}
          >
            {isCapturing(rowId, `${captureTargetKeys}:${index}`) ? (texts.recordStop || texts.recording) : texts.record}
          </button>
        </div>
      {:else if actionTypeOf(action) === 'delay'}
        <div class="automation-shortcut-label">{texts.actionDelayLabel}</div>
        <input
          class="automation-keys"
          type="number"
          min="1"
          max="60000"
          step="1"
          disabled={!rowEnabled}
          value={action.delay_ms || ''}
          placeholder={texts.actionDelayPlaceholder}
          on:input={(event) => callHandler(onActionDelayInput, index, event)}
        />
        <div class="automation-action-hint">{texts.actionDelayHint}</div>
      {:else if actionTypeOf(action) === 'open_url'}
        <div class="automation-shortcut-label">{texts.actionUrlLabel}</div>
        <input
          class="automation-keys"
          type="text"
          disabled={!rowEnabled}
          value={action.url || ''}
          placeholder={texts.actionUrlPlaceholder}
          on:input={(event) => callHandler(onActionUrlInput, index, event)}
        />
      {:else if actionTypeOf(action) === 'launch_app'}
        <div class="automation-shortcut-label">{texts.actionAppPathLabel}</div>
        <input
          class="automation-keys"
          type="text"
          disabled={!rowEnabled}
          value={action.app_path || ''}
          placeholder={texts.actionAppPathPlaceholder}
          on:input={(event) => callHandler(onActionAppPathInput, index, event)}
        />
      {/if}
    </div>
  {/each}

  <div class="automation-action-adders">
    <button class="btn-soft automation-action-add automation-action-add--shortcut" type="button" disabled={!rowEnabled} on:click|stopPropagation={() => emitAddAction({ type: 'send_shortcut', shortcut: '' })}>
      <span class="automation-action-add-icon" aria-hidden="true">
        <svg viewBox="0 0 16 16" focusable="false">
          <rect x="2.25" y="4" width="11.5" height="8" rx="2" />
          <path d="M4.5 6.5h.01M7 6.5h.01M9.5 6.5h.01M11.5 6.5h.01M4.5 9.25h7" />
        </svg>
      </span>
      <span>{texts.addShortcutAction}</span>
    </button>
    <button class="btn-soft automation-action-add automation-action-add--delay" type="button" disabled={!rowEnabled} on:click|stopPropagation={() => emitAddAction({ type: 'delay', delay_ms: 120 })}>
      <span class="automation-action-add-icon" aria-hidden="true">
        <svg viewBox="0 0 16 16" focusable="false">
          <circle cx="8" cy="8.5" r="4.75" />
          <path d="M8 5.75v3l2 1.2M5.75 2.5h4.5" />
        </svg>
      </span>
      <span>{texts.addDelayAction}</span>
    </button>
    <button class="btn-soft automation-action-add automation-action-add--url" type="button" disabled={!rowEnabled} on:click|stopPropagation={() => emitAddAction({ type: 'open_url', url: '' })}>
      <span class="automation-action-add-icon" aria-hidden="true">
        <svg viewBox="0 0 16 16" focusable="false">
          <path d="M6.6 5.1l.9-.9a3 3 0 0 1 4.25 4.25l-.9.9M9.4 10.9l-.9.9a3 3 0 0 1-4.25-4.25l.9-.9M6.5 9.5l3-3" />
        </svg>
      </span>
      <span>{texts.addOpenUrlAction}</span>
    </button>
    <button class="btn-soft automation-action-add automation-action-add--app" type="button" disabled={!rowEnabled} on:click|stopPropagation={() => emitAddAction({ type: 'launch_app', app_path: '' })}>
      <span class="automation-action-add-icon" aria-hidden="true">
        <svg viewBox="0 0 16 16" focusable="false">
          <rect x="3" y="3.25" width="10" height="9.5" rx="2" />
          <path d="M3 6h10M5.25 4.75h.01M7 4.75h.01" />
        </svg>
      </span>
      <span>{texts.addLaunchAppAction}</span>
    </button>
  </div>
</div>

<style>
  .automation-action-list {
    gap: 10px;
  }

  .automation-action-empty {
    font-size: 12px;
    color: rgba(255, 255, 255, 0.68);
  }

  .automation-action-card {
    display: grid;
    gap: 8px;
    padding: 10px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    background: rgba(255, 255, 255, 0.03);
  }

  .automation-action-card-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .automation-action-card-tools {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }

  .automation-action-tool {
    min-width: 34px;
    width: 34px;
    height: 34px;
    padding: 0;
    border: 0;
    border-radius: 999px;
    background: transparent;
    color: #6e87a2;
    box-shadow: none;
    opacity: 0.64;
  }

  .automation-action-card:hover .automation-action-tool,
  .automation-action-card:focus-within .automation-action-tool {
    opacity: 1;
  }

  .automation-action-tool:hover:enabled,
  .automation-action-tool:focus-visible {
    background: rgba(226, 236, 247, 0.95);
    color: #476684;
    box-shadow: none;
  }

  .automation-action-tool:last-child:hover:enabled,
  .automation-action-tool:last-child:focus-visible {
    background: rgba(253, 236, 236, 0.96);
    color: #b14b4b;
  }

  .automation-action-index {
    font-size: 12px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.78);
  }

  .automation-action-type-select {
    width: 100%;
  }

  .automation-action-hint {
    font-size: 12px;
    color: rgba(255, 255, 255, 0.62);
  }

  .automation-action-adders {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .automation-action-add {
    display: inline-flex;
    align-items: center;
    gap: 7px;
  }

  .automation-action-add-icon {
    width: 20px;
    height: 20px;
    min-width: 20px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 6px;
    background: rgba(67, 102, 139, 0.1);
    color: currentColor;
    line-height: 1;
  }

  .automation-action-add-icon svg {
    width: 14px;
    height: 14px;
    fill: none;
    stroke: currentColor;
    stroke-width: 1.45;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  .automation-action-list--mouse {
    gap: 12px;
    padding: 0;
    border: 0;
    background: transparent;
  }

  .automation-action-list--gesture {
    gap: 12px;
    padding: 0;
    border: 0;
    background: transparent;
  }

  .automation-action-list--mouse .automation-action-empty {
    border: 1px dashed rgba(190, 211, 235, 0.68);
    border-radius: 10px;
    background: rgba(247, 251, 255, 0.52);
    color: #607896;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 12px 14px;
    text-align: center;
  }

  .automation-action-list--gesture .automation-action-empty {
    border: 1px dashed rgba(190, 221, 214, 0.72);
    border-radius: 10px;
    background: rgba(246, 252, 250, 0.52);
    color: #5d7b77;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 12px 14px;
    text-align: center;
  }

  .automation-action-list--mouse .automation-action-card {
    position: relative;
    gap: 10px;
    padding: 14px 14px 14px 18px;
    border: 1px solid #dbe6f2;
    border-radius: 14px;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.99), rgba(246, 250, 255, 0.97));
    box-shadow:
      0 10px 24px rgba(110, 145, 184, 0.09),
      inset 0 1px 0 rgba(255, 255, 255, 0.92);
  }

  .automation-action-list--gesture .automation-action-card {
    position: relative;
    gap: 10px;
    padding: 14px 14px 14px 18px;
    border: 1px solid #d9ebe6;
    border-radius: 14px;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.99), rgba(245, 251, 249, 0.97));
    box-shadow:
      0 10px 24px rgba(104, 163, 152, 0.09),
      inset 0 1px 0 rgba(255, 255, 255, 0.92);
  }

  .automation-action-list--mouse .automation-action-card::before {
    content: '';
    position: absolute;
    top: 14px;
    bottom: 14px;
    left: 0;
    width: 4px;
    border-radius: 999px;
    background: linear-gradient(180deg, #6ea3dc, #8ab9e8);
  }

  .automation-action-list--gesture .automation-action-card::before {
    content: '';
    position: absolute;
    top: 14px;
    bottom: 14px;
    left: 0;
    width: 4px;
    border-radius: 999px;
    background: linear-gradient(180deg, #58b7b0, #80d0c5);
  }

  .automation-action-list--mouse .automation-action-card-head {
    gap: 10px 14px;
    align-items: center;
  }

  .automation-action-list--gesture .automation-action-card-head {
    gap: 10px 14px;
    align-items: center;
  }

  .automation-action-list--mouse .automation-action-card-tools {
    gap: 8px;
    opacity: 0;
    transform: translateY(-2px);
    pointer-events: none;
    transition:
      opacity 140ms ease,
      transform 140ms ease;
  }

  .automation-action-list--gesture .automation-action-card-tools {
    gap: 8px;
    opacity: 0;
    transform: translateY(-2px);
    pointer-events: none;
    transition:
      opacity 140ms ease,
      transform 140ms ease;
  }

  .automation-action-list--mouse .automation-action-card:hover .automation-action-card-tools,
  .automation-action-list--mouse .automation-action-card:focus-within .automation-action-card-tools {
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
  }

  .automation-action-list--gesture .automation-action-card:hover .automation-action-card-tools,
  .automation-action-list--gesture .automation-action-card:focus-within .automation-action-card-tools {
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
  }

  .automation-action-list--mouse .automation-action-tool {
    min-width: 0;
    width: 30px;
    height: 30px;
    min-height: 30px;
    padding: 0;
    border-color: #d4deea;
    background: rgba(246, 250, 255, 0.92);
    color: #4f6a87;
    box-shadow: none;
    border-radius: 999px;
    font-size: 14px;
  }

  .automation-action-list--gesture .automation-action-tool {
    min-width: 0;
    width: 30px;
    height: 30px;
    min-height: 30px;
    padding: 0;
    border-color: #d1e3de;
    background: rgba(245, 251, 249, 0.92);
    color: #4f756f;
    box-shadow: none;
    border-radius: 999px;
    font-size: 14px;
  }

  .automation-action-list--mouse .automation-action-tool:hover:enabled {
    border-color: #bfd2e8;
    background: #f0f6ff;
    color: #254663;
  }

  .automation-action-list--gesture .automation-action-tool:hover:enabled {
    border-color: #b7ddd7;
    background: #eefaf8;
    color: #215952;
  }

  .automation-action-list--mouse .automation-action-tool:last-child:hover:enabled {
    border-color: #e4c5bf;
    background: #fff1ee;
    color: #9a3d2f;
  }

  .automation-action-list--gesture .automation-action-tool:last-child:hover:enabled {
    border-color: #e4c5bf;
    background: #fff1ee;
    color: #9a3d2f;
  }

  .automation-action-list--mouse .automation-action-index {
    display: inline-flex;
    align-items: center;
    min-height: 26px;
    padding: 0 10px;
    border-radius: 999px;
    background: #eaf3ff;
    color: #2e5377;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.02em;
  }

  .automation-action-list--gesture .automation-action-index {
    display: inline-flex;
    align-items: center;
    min-height: 26px;
    padding: 0 10px;
    border-radius: 999px;
    background: #e8f8f4;
    color: #2b5f59;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.02em;
  }

  .automation-action-list--mouse .automation-shortcut-label {
    color: #58708d;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.01em;
    text-transform: uppercase;
  }

  .automation-action-list--gesture .automation-shortcut-label {
    color: #5d7d79;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.01em;
    text-transform: uppercase;
  }

  .automation-action-list--mouse .automation-action-type-select,
  .automation-action-list--mouse .automation-keys {
    border-color: #d3deea;
    background: linear-gradient(180deg, #fbfdff, #f1f6fc);
    box-shadow:
      inset 0 -2px 0 rgba(198, 211, 225, 0.55),
      inset 0 1px 0 rgba(255, 255, 255, 0.96);
  }

  .automation-action-list--gesture .automation-action-type-select,
  .automation-action-list--gesture .automation-keys {
    border-color: #d4e6e1;
    background: linear-gradient(180deg, #fbfefd, #f1f8f6);
    box-shadow:
      inset 0 -2px 0 rgba(186, 214, 207, 0.55),
      inset 0 1px 0 rgba(255, 255, 255, 0.96);
  }

  .automation-action-list--mouse .automation-keys {
    font-family: "SFMono-Regular", "Consolas", monospace;
    color: #274767;
    letter-spacing: 0.02em;
  }

  .automation-action-list--gesture .automation-keys {
    font-family: "SFMono-Regular", "Consolas", monospace;
    color: #2b5a57;
    letter-spacing: 0.02em;
  }

  .automation-action-list--mouse .automation-shortcut-head {
    align-items: stretch;
  }

  .automation-action-list--gesture .automation-shortcut-head {
    align-items: stretch;
  }

  .automation-action-list--mouse .automation-shortcut-head.is-recording .automation-keys {
    border-color: #d78f89;
    background: linear-gradient(180deg, #fff8f8, #fff1f1);
    box-shadow:
      inset 0 -2px 0 rgba(217, 155, 149, 0.38),
      inset 0 1px 0 rgba(255, 255, 255, 0.96),
      0 0 0 3px rgba(222, 126, 116, 0.14);
    animation: automation-record-pulse 1.25s ease-in-out infinite;
  }

  .automation-action-list--gesture .automation-shortcut-head.is-recording .automation-keys {
    border-color: #d78f89;
    background: linear-gradient(180deg, #fff8f8, #fff1f1);
    box-shadow:
      inset 0 -2px 0 rgba(217, 155, 149, 0.38),
      inset 0 1px 0 rgba(255, 255, 255, 0.96),
      0 0 0 3px rgba(222, 126, 116, 0.14);
    animation: automation-record-pulse 1.25s ease-in-out infinite;
  }

  .automation-action-list--mouse .automation-shortcut-head.is-recording .automation-record {
    border-color: #d78f89;
    background: #fff1f1;
    color: #9a4031;
  }

  .automation-action-list--gesture .automation-shortcut-head.is-recording .automation-record {
    border-color: #d78f89;
    background: #fff1f1;
    color: #9a4031;
  }

  .automation-action-list--mouse .automation-record {
    align-self: stretch;
  }

  .automation-action-list--gesture .automation-record {
    align-self: stretch;
  }

  .automation-action-list--mouse .automation-action-hint {
    color: #6a819d;
  }

  .automation-action-list--gesture .automation-action-hint {
    color: #68827d;
  }

  .automation-action-list--mouse .automation-action-adders {
    gap: 8px;
    padding: 2px 0 0;
    border: 0;
    border-radius: 0;
    background: transparent;
  }

  .automation-action-list--gesture .automation-action-adders {
    gap: 8px;
    padding: 2px 0 0;
    border: 0;
    border-radius: 0;
    background: transparent;
  }

  .automation-action-list--mouse .automation-action-adders :global(button) {
    border-color: #cfdae7;
    background: linear-gradient(180deg, rgba(251, 253, 255, 0.98), rgba(242, 247, 253, 0.96));
    color: #385675;
    padding: 7px 10px;
  }

  .automation-action-list--gesture .automation-action-adders :global(button) {
    border-color: #d0e4de;
    background: linear-gradient(180deg, rgba(250, 254, 253, 0.98), rgba(242, 248, 246, 0.96));
    color: #2f6059;
    padding: 7px 10px;
  }

  .automation-action-list--mouse .automation-action-adders :global(button:hover:enabled) {
    border-color: #b8cce2;
    background: #edf5ff;
    color: #1f466a;
  }

  .automation-action-list--gesture .automation-action-adders :global(button:hover:enabled) {
    border-color: #b7ddd7;
    background: #eefaf8;
    color: #1f5750;
  }

  @keyframes automation-record-pulse {
    0%,
    100% {
      box-shadow:
        inset 0 -2px 0 rgba(217, 155, 149, 0.38),
        inset 0 1px 0 rgba(255, 255, 255, 0.96),
        0 0 0 3px rgba(222, 126, 116, 0.12);
    }

    50% {
      box-shadow:
        inset 0 -2px 0 rgba(217, 155, 149, 0.42),
        inset 0 1px 0 rgba(255, 255, 255, 0.98),
        0 0 0 5px rgba(222, 126, 116, 0.2);
    }
  }
</style>
