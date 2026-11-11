<script>
  // Foglio dal basso per scelte rapide (bottom sheet)
  let { aperto = false, titolo = '', sotto = '', chiudi, children } = $props()
  function tasto(e) { if (e.key === 'Escape') chiudi?.() }
</script>

<svelte:window onkeydown={tasto} />

{#if aperto}
  <div class="sfondo" role="presentation" onclick={chiudi}></div>
  <div class="foglio" role="dialog" aria-modal="true" aria-label={titolo}>
    <div class="maniglia"></div>
    {#if titolo}<h2>{titolo}</h2>{/if}
    {#if sotto}<p class="aiuto">{sotto}</p>{/if}
    <div class="corpo">{@render children?.()}</div>
    <button type="button" class="btn bianco" onclick={chiudi}>Annulla</button>
  </div>
{/if}

<style>
  .sfondo { position: fixed; inset: 0; background: rgba(20,32,26,0.45); z-index: 40; }
  .foglio {
    position: fixed; left: 0; right: 0; bottom: 0; z-index: 41; max-width: 640px; margin: 0 auto;
    background: var(--superficie); border-radius: 20px 20px 0 0; padding: 10px 20px calc(20px + var(--safe-bottom)) 20px;
    display: flex; flex-direction: column; gap: 12px; max-height: 85dvh; overflow-y: auto;
    animation: sali .2s ease-out;
  }
  @keyframes sali { from { transform: translateY(30px); opacity: 0 } to { transform: none; opacity: 1 } }
  .maniglia { width: 40px; height: 4px; border-radius: 2px; background: var(--bordo); margin: 0 auto 4px; }
  h2 { font-size: 20px; }
  .corpo { display: flex; flex-direction: column; gap: 10px; }
</style>
