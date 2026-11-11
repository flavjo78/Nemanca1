<script>
  // Tre contatori (difesa, centrocampo, attacco) con + e −; il portiere è sempre 1 e non si conta.
  let { difesa = $bindable(0), centro = $bindable(0), attacco = $bindable(0), massimo = 10 } = $props()
  const righe = [['difesa', 'Difesa'], ['centro', 'Centrocampo'], ['attacco', 'Attacco']]
  const valori = $derived({ difesa, centro, attacco })
  const totale = $derived(difesa + centro + attacco)
  function cambia(chiave, delta) {
    const nuovo = Math.max(0, valori[chiave] + delta)
    if (delta > 0 && totale >= massimo) return
    if (chiave === 'difesa') difesa = nuovo
    else if (chiave === 'centro') centro = nuovo
    else attacco = nuovo
  }
</script>

<div class="contatori">
  {#each righe as [chiave, testo]}
    <div class="riga">
      <span class="nome">{testo}</span>
      <button type="button" class="tasto" aria-label={`Togli un giocatore in ${testo}`} disabled={valori[chiave] === 0} onclick={() => cambia(chiave, -1)}>−</button>
      <span class="numero" aria-live="polite">{valori[chiave]}</span>
      <button type="button" class="tasto" aria-label={`Aggiungi un giocatore in ${testo}`} disabled={totale >= massimo} onclick={() => cambia(chiave, 1)}>+</button>
    </div>
  {/each}
</div>

<style>
  .contatori { display: flex; flex-direction: column; gap: 8px; }
  .riga { display: flex; align-items: center; gap: 10px; background: var(--superficie); border: 1px solid var(--bordo); border-radius: 14px; padding: 6px 8px 6px 14px; }
  .nome { flex: 1 1 0; font-size: 15px; font-weight: 600; }
  .numero { width: 28px; text-align: center; font-family: var(--font-titoli); font-size: 20px; font-weight: 700; }
  .tasto {
    width: 44px; height: 44px; border-radius: 22px; border: 1px solid var(--bordo); background: var(--sfondo);
    font-size: 22px; font-weight: 600; color: var(--verde); display: flex; align-items: center; justify-content: center; padding: 0;
  }
  .tasto:disabled { opacity: .35; }
</style>
