<script>
  // Campo "comune" con suggerimenti. Se non si tocca il suggerimento, il comune viene preso lo stesso:
  // Invio o uscita dal campo scelgono il primo suggerimento (o lo cercano se non è ancora arrivato).
  import { cercaComune, risolviComune } from '../lib/geo.js'

  let { scelto = $bindable(null), id = 'comune', etichetta = 'Il tuo comune', aiuto = 'Scrivi il comune: lo riconosciamo anche senza toccare il suggerimento.' } = $props()
  let testo = $state(scelto?.comune ?? '')
  let suggerimenti = $state([])
  let cerco = $state(false)
  let nonTrovato = $state(false)
  let timer
  let richiesta = 0

  function scrivi(e) {
    testo = e.currentTarget.value
    scelto = null
    nonTrovato = false
    clearTimeout(timer)
    if (testo.trim().length < 2) { suggerimenti = []; cerco = false; return }
    cerco = true
    const mia = ++richiesta
    timer = setTimeout(async () => {
      let r = []
      try { r = await cercaComune(testo) } catch { r = [] }
      if (mia !== richiesta) return // risposta vecchia: arrivata dopo che hai scritto altro
      suggerimenti = r
      cerco = false
    }, 300)
  }

  function scegli(s) {
    scelto = { comune: s.comune, lat: s.lat, lng: s.lng }
    testo = s.comune
    suggerimenti = []
    cerco = false
    nonTrovato = false
    richiesta++ // ignora risposte ancora in arrivo
  }

  /** Prende il comune scritto anche se non hai toccato il suggerimento. Restituisce il comune o null. */
  export async function conferma() {
    if (scelto) return scelto
    if (testo.trim().length < 2) return null
    if (suggerimenti.length) { scegli(suggerimenti.find((x) => x.comune.toLowerCase() === testo.trim().toLowerCase()) ?? suggerimenti[0]); return scelto }
    cerco = true
    const mia = ++richiesta
    let r = null
    try { r = await risolviComune(testo) } catch { r = null }
    if (mia !== richiesta && scelto) return scelto
    cerco = false
    if (r) scegli(r); else nonTrovato = true
    return scelto
  }

  function tasto(e) {
    if (e.key === 'Enter') { e.preventDefault(); conferma() }
  }
  // uscendo dal campo: un attimo di pazienza per lasciar toccare un suggerimento, poi lo prende da solo
  function esci() { setTimeout(() => { if (!scelto && testo.trim()) conferma() }, 250) }
</script>

<div class="campo-form">
  <label for={id}>{etichetta}</label>
  <input {id} class="input" type="text" value={testo} oninput={scrivi} onkeydown={tasto} onblur={esci}
         placeholder="Galatina" autocomplete="off" enterkeyhint="done" aria-autocomplete="list" />
  {#if suggerimenti.length}
    <div class="suggerimenti" role="listbox">
      {#each suggerimenti as s}
        <button type="button" role="option" aria-selected="false" onpointerdown={(e) => e.preventDefault()} onclick={() => scegli(s)}>{s.comune}{s.provincia ? ` · ${s.provincia}` : ''}</button>
      {/each}
    </div>
  {/if}
  <p class="aiuto" style={nonTrovato ? 'color: var(--errore)' : ''}>
    {#if scelto}Scelto: <strong>{scelto.comune}</strong>{:else if cerco}Cerco "{testo.trim()}"…{:else if nonTrovato}Non trovo "{testo.trim()}": controlla come è scritto.{:else}{aiuto}{/if}
  </p>
</div>
