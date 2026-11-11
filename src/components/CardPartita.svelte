<script>
  // Card di una partita nell'elenco del campo (dal mockup campo.html)
  import { etichettaDataOra, etichettaFormato, nomeBreve, chipPosti } from '../lib/formato.js'
  let { partita, evidenziata = false } = $props()
  const posizioni = $derived(partita.posizioni ?? [])
  const totale = $derived(posizioni.length || partita.formato * 2)
  const occupati = $derived(posizioni.filter((p) => p.stato !== 'libera').length)
  const chip = $derived(partita.stato === 'annullata'
    ? { testo: 'Annullata', classe: 'neutro' }
    : partita.stato === 'giocata'
      ? { testo: 'Giocata', classe: 'neutro' }
      : chipPosti(posizioni))
  const percentuale = $derived(totale ? Math.round((occupati / totale) * 100) : 0)
</script>

<a href={`/partita/${partita.id}`} class="card" class:evidenziata>
  <div style="display:flex; justify-content:space-between; align-items:flex-start; gap:10px">
    <div style="display:flex; flex-direction:column; gap:2px; min-width:0">
      <div class="titolo">{etichettaDataOra(partita.data_ora)}</div>
      <div class="sotto taglia">{etichettaFormato(partita.formato)} · organizza {nomeBreve(partita.organizzatore)}</div>
    </div>
    <span class="chip {chip.classe}">{chip.testo}</span>
  </div>
  <div style="display:flex; align-items:center; gap:10px">
    <div class="barra" class:piena={occupati >= totale}><div style={`width:${percentuale}%`}></div></div>
    <div style="font-size:13px; font-weight:600">{occupati}/{totale}</div>
  </div>
</a>
