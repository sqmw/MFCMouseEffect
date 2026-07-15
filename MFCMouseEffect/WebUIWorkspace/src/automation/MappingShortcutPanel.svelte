<script>
  import { createEventDispatcher } from 'svelte';

  export let rowId = '';
  export let row = {};
  export let rowEnabled = true;
  export let kind = 'mouse';
  export let texts = {};
  export let captureTargetKeys = 'keys';
  export let captureTargetModifiers = 'modifiers';
  export let modifierInputId = '';
  export let modifierInputValue = '';
  export let modifierInputPlaceholder = '';
  export let gestureButtonValue = 'right';
  export let gestureButtonOptions = [];
  export let triggerOptions = [];
  export let chainValue = [];
  export let isCapturing = () => false;
  export let onModifierKeydown = null;
  export let onModifierInput = null;
  export let actionShortcutInputId = null;
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
  export let onToggleModifierRecord = null;
  export let onTriggerButtonChange = null;
  export let onGestureTriggerChange = null;
  export let onGesturePatternChange = null;
  export let onChainChange = null;

  import MappingActionListEditor from './MappingActionListEditor.svelte';
  import GesturePatternEditor from './GesturePatternEditor.svelte';
  import TriggerChainEditor from './TriggerChainEditor.svelte';

  const dispatch = createEventDispatcher();

  function callHandler(handler, ...args) {
    if (typeof handler === 'function') {
      handler(...args);
    }
  }
</script>

<div class="automation-chain-group automation-col">
  {#if kind === 'gesture'}
    <div class="automation-shortcut-label">{texts.gestureTriggerShortcutLabel}</div>
    <div class="automation-shortcut-head">
      <input
        id={modifierInputId}
        class="automation-keys"
        type="text"
        disabled={!rowEnabled}
        readonly={isCapturing(rowId, captureTargetModifiers)}
        value={modifierInputValue}
        placeholder={modifierInputPlaceholder}
        on:keydown={(event) => callHandler(onModifierKeydown, event)}
        on:input={(event) => callHandler(onModifierInput, event)}
      />
      <button
        class="btn-soft automation-record"
        class:is-recording={isCapturing(rowId, captureTargetModifiers)}
        type="button"
        disabled={!rowEnabled}
        on:click={() => callHandler(onToggleModifierRecord, captureTargetModifiers)}
      >
        {isCapturing(rowId, captureTargetModifiers) ? (texts.recordStop || texts.recording) : texts.record}
      </button>
    </div>
  {/if}

  {#if kind !== 'mouse'}
    <MappingActionListEditor
      {rowId}
      {row}
      {rowEnabled}
      {kind}
      {texts}
      {captureTargetKeys}
      {isCapturing}
      {actionShortcutInputId}
      onActionShortcutKeydown={onActionShortcutKeydown}
      onActionShortcutInput={onActionShortcutInput}
      onToggleActionRecord={onToggleActionRecord}
      onActionTypeChange={onActionTypeChange}
      onActionDelayInput={onActionDelayInput}
      onActionUrlInput={onActionUrlInput}
      onActionAppPathInput={onActionAppPathInput}
      onActionMoveUp={onActionMoveUp}
      onActionMoveDown={onActionMoveDown}
      onActionRemove={onActionRemove}
      on:addaction={(event) => dispatch('addaction', event.detail)}
    />
  {/if}

  {#if kind === 'gesture'}
    <div class="automation-gesture-trigger-group">
      <div class="automation-modifier-label">{texts.gestureTriggerButtonLabel}</div>
      <select
        class="automation-modifier-mode"
        disabled={!rowEnabled}
        value={gestureButtonValue}
        on:change={(event) => callHandler(onTriggerButtonChange, event)}
      >
        {#each gestureButtonOptions as option (option.value)}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </div>
    <GesturePatternEditor
      {row}
      disabled={!rowEnabled}
      options={triggerOptions}
      texts={{
        title: texts.gesturePatternTitle,
        modePreset: texts.gestureModePreset,
        modeCustom: texts.gestureModeCustom,
        preset: texts.gesturePatternPreset,
        custom: texts.gesturePatternCustom,
        threshold: texts.gestureThreshold,
        canvasEmpty: texts.gestureCanvasEmpty,
        canvasClear: texts.gestureCanvasClear,
        canvasUndo: texts.gestureCanvasUndo,
        canvasGuide: texts.gestureCanvasGuide,
        canvasLimitHint: texts.gestureCanvasLimitHint,
        canvasLimitBadge: texts.gestureCanvasLimitBadge,
        canvasLimitReached: texts.gestureCanvasLimitReached,
        canvasStrokeCount: texts.gestureCanvasStrokeCount,
        canvasPointUnit: texts.gestureCanvasPointUnit,
        canvasNoDirection: texts.gestureCanvasNoDirection,
        canvasDraw: texts.gestureCanvasDraw,
        canvasSave: texts.gestureCanvasSave,
        canvasLockedHint: texts.gestureCanvasLockedHint,
      }}
      on:triggerchange={(event) => callHandler(onGestureTriggerChange, event)}
      on:change={(event) => callHandler(onGesturePatternChange, event)}
    />
  {:else}
    <section class="automation-flow-section automation-flow-section--trigger">
      <div class="automation-flow-section__head">
        <div class="automation-flow-section__eyebrow">{texts.triggerSectionEyebrow}</div>
        <div class="automation-flow-section__title">{texts.triggerSectionTitle}</div>
        <div class="automation-flow-section__hint">{texts.triggerSectionHint}</div>
      </div>
      <TriggerChainEditor
        value={chainValue}
        options={triggerOptions}
        disabled={!rowEnabled}
        texts={{
          addNode: texts.addNextTriggerNode,
          removeNode: texts.removeChainNode,
          chainJoiner: texts.chainJoiner,
        }}
        on:chainchange={(event) => callHandler(onChainChange, event)}
      />
    </section>
    <section class="automation-flow-section automation-flow-section--actions automation-flow-section--actions-after-trigger">
      <div class="automation-flow-section__head">
        <div class="automation-flow-section__eyebrow">{texts.executeSectionEyebrow}</div>
        <div class="automation-flow-section__title">{texts.executeSectionTitle}</div>
        <div class="automation-flow-section__hint">{texts.executeSectionHint}</div>
      </div>
      <MappingActionListEditor
        {rowId}
        {row}
        {rowEnabled}
        {kind}
        {texts}
        {captureTargetKeys}
        {isCapturing}
        {actionShortcutInputId}
        onActionShortcutKeydown={onActionShortcutKeydown}
        onActionShortcutInput={onActionShortcutInput}
        onToggleActionRecord={onToggleActionRecord}
        onActionTypeChange={onActionTypeChange}
        onActionDelayInput={onActionDelayInput}
        onActionUrlInput={onActionUrlInput}
        onActionAppPathInput={onActionAppPathInput}
        onActionMoveUp={onActionMoveUp}
        onActionMoveDown={onActionMoveDown}
        onActionRemove={onActionRemove}
        on:addaction={(event) => dispatch('addaction', event.detail)}
      />
    </section>
  {/if}
</div>
