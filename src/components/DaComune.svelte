<script>
  // Bottone "da Galatina": da dove contare i km. Si cambia scrivendo il comune o con la posizione del telefono.
  import Foglio from './Foglio.svelte'
  import ScegliComune from './ScegliComune.svelte'
  import { auth } from '../lib/auth.svelte.js'
  import { salvaComune, salvaPosizione } from '../lib/preferenze.js'
  import { posizioneAttuale, comuneDaCoordinate } from '../lib/geo.js'

  let { cambiato } = $props()
  let aperto = $state(false)
  let scelto = $state(null)
  let campo = $state(null)
  let occupato = $state(false)
  let errore = $state('')
  const etichetta = $derived(auth.profilo?.da_posizione ? 'questa posizione' : (auth.profilo?.comune ?? 'scegli'))

  function apri() {
    scelto = auth.profilo?.comune && !auth.profilo?.da_posizione ? { comune: auth.profilo.comune, lat: auth.profilo.lat, lng: auth.profilo.lng } : null
    errore = ''; aperto = true
  }
  async function salva(c) {
    occupato = true; errore = ''
    try { await salvaComune(c); aperto = false; cambiato?.() }
    catch { errore = 'Non sono riuscito a salvare. Riprova.' }
    finally { occupato = false }
  }
  async function conferma() {
    const c = await campo?.conferma()
    if (!c) { errore = 'Scrivi il comune da cui parti.'; return }
    await salva(c)
  }
  async function usaPosizione() {
    occupato = true; errore = ''
    try {
      const { lat, lng } = await posizioneAttuale()
      const nome = await comuneDaCoordinate(lat, lng).catch(() => null)
      await salvaPosizione(lat, lng, nome)
      aperto = false; cambiato?.()
    } catch { errore = 'Non riesco a leggere la posizione del telefono: scrivi il comune.' }
    finally { occupato = false }
  }
</script>

<button type="button" class="chip-km" onclick={apri} aria-label={`Km contati da ${etichetta}. Cambia`}>
  da <strong>{etichetta}</strong>
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
</button>

<Foglio aperto={aperto} titolo="Da dove parti?" sotto="I km si contano da qui: partite, campi e avvisi vicini." chiudi={() => (aperto = false)}>
  {#if aperto}
    <ScegliComune bind:this={campo} bind:scelto id="comune-partenza" etichetta="Comune" />
  {/if}
  {#if errore}<div class="errore">{errore}</div>{/if}
  <button type="button" class="btn" disabled={occupato} onclick={conferma}>{occupato ? 'Salvataggio…' : 'Salva'}</button>
  <button type="button" class="btn bianco" disabled={occupato} onclick={usaPosizione}>Da questa posizione</button>
  <p class="aiuto">"Da questa posizione" usa il punto in cui ti trovi, arrotondato a circa 1 km: nessuno vede dove sei esattamente.</p>
</Foglio>

<style>
  .chip-km {
    display: inline-flex; align-items: center; gap: 6px; min-height: 44px; padding: 0 14px;
    border-radius: 999px; border: 1px solid var(--bordo); background: var(--superficie);
    color: var(--testo); font-size: 14px; font-family: inherit; white-space: nowrap;
    text-transform: none; letter-spacing: normal; font-weight: 500; max-width: 100%;
  }
  .chip-km strong { color: var(--verde); overflow: hidden; text-overflow: ellipsis; }
</style>
