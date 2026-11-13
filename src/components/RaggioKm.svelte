<script>
  // Bottone "Entro 20 km": apre un foglio con cursore e scorciatoie, salva subito nel profilo.
  import Foglio from './Foglio.svelte'
  import { RAGGI_RAPIDI, raggioAttuale, salvaRaggio } from '../lib/preferenze.js'

  let { cambiato } = $props()
  let aperto = $state(false)
  let valore = $state(20)
  let occupato = $state(false)
  let errore = $state('')

  function apri() { valore = raggioAttuale(); errore = ''; aperto = true }
  async function applica() {
    occupato = true; errore = ''
    try { await salvaRaggio(valore); aperto = false; cambiato?.(valore) }
    catch (e) { errore = 'Non sono riuscito a salvare. Riprova.' }
    finally { occupato = false }
  }
</script>

<button type="button" class="chip-km" onclick={apri} aria-label={`Distanza massima: ${raggioAttuale()} km. Cambia`}>
  Entro <strong>{raggioAttuale()} km</strong>
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
</button>

<Foglio aperto={aperto} titolo="Fino a quanti km vai a giocare?" sotto="Ti mostriamo partite e campi entro questa distanza dal tuo comune." chiudi={() => (aperto = false)}>
  <div class="valore">{valore} km</div>
  <input type="range" min="1" max="100" step="1" bind:value={valore} aria-label="Distanza in km" />
  <div class="scelte">
    {#each RAGGI_RAPIDI as r}
      <button type="button" class="scelta" class:attiva={valore === r} onclick={() => (valore = r)}>{r} km</button>
    {/each}
  </div>
  {#if errore}<div class="errore">{errore}</div>{/if}
  <button type="button" class="btn" disabled={occupato} onclick={applica}>{occupato ? 'Salvataggio…' : `Mostra entro ${valore} km`}</button>
</Foglio>

<style>
  .chip-km {
    display: inline-flex; align-items: center; gap: 6px; min-height: 44px; padding: 0 14px;
    border-radius: 999px; border: 1px solid var(--bordo); background: var(--superficie);
    color: var(--testo); font-size: 14px; font-family: inherit; white-space: nowrap;
    text-transform: none; letter-spacing: normal; font-weight: 500;
  }
  .chip-km strong { color: var(--verde); }
  .valore { font-family: 'Space Grotesk', sans-serif; font-weight: 700; font-size: 32px; color: var(--verde); text-align: center; }
  input[type=range] { width: 100%; min-height: 44px; accent-color: var(--verde); }
</style>
