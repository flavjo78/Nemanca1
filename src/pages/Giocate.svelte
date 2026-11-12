<script>
  // Partite passate: "Giocate" (finite da almeno un'ora, fino a fine giornata) e "Archivio" (dal giorno dopo).
  // Nulla si cancella: aprendo una partita si rivedono formazione, modulo, panchina, tribuna e chat (sola lettura).
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { naviga } from '../lib/router.svelte.js'
  import { etichettaFormato, etichettaRuolo, giornoBreve, giornoNumero, ora } from '../lib/formato.js'
  import Caricamento from '../components/Caricamento.svelte'
  import Icona from '../components/Icona.svelte'

  let scheda = $state(new URLSearchParams(location.search).get('vista') === 'archivio' ? 'archivio' : 'giocate')
  let elenco = $state([])
  let caricamento = $state(true)
  let errore = $state('')

  async function carica() {
    caricamento = true; errore = ''
    const { data, error } = await supabase.rpc('mie_partite_passate', { p_archiviate: scheda === 'archivio' })
    if (error) errore = error.message
    elenco = data ?? []
    caricamento = false
  }
  onMount(carica)

  function cambia(s) {
    if (s === scheda) return
    scheda = s
    naviga(`/giocate${s === 'archivio' ? '?vista=archivio' : ''}`, { sostituisci: true })
    carica()
  }

  function mese(d) { return ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'][new Date(d).getMonth()] }
  function mioRuolo(p) {
    if (p.mio_ruolo === 'tribuna') return 'In tribuna'
    if (p.mio_ruolo) return `${etichettaRuolo(p.mio_ruolo)} · squadra ${p.mia_squadra}`
    return p.organizzatore ? 'Organizzatore' : ''
  }
  function risultato(p) {
    if (p.stato === 'annullata') return 'Annullata'
    if (p.risultato_a == null) return 'Risultato non inserito'
    return `Risultato ${p.risultato_a}-${p.risultato_b}`
  }
</script>

<div class="pagina">
  <header class="intestazione">
    <button type="button" class="btn-tondo" aria-label="Indietro" onclick={() => history.length > 1 ? history.back() : naviga('/profilo')}><Icona nome="indietro" /></button>
    <div class="centro"><h1 style="font-size:24px">Le mie partite passate</h1><div class="sotto">Tutto resta conservato</div></div>
  </header>
  <div class="contenuto">
    <div class="scelte" role="tablist">
      <button type="button" role="tab" class="scelta" class:attiva={scheda === 'giocate'} aria-selected={scheda === 'giocate'} onclick={() => cambia('giocate')}>Giocate</button>
      <button type="button" role="tab" class="scelta" class:attiva={scheda === 'archivio'} aria-selected={scheda === 'archivio'} onclick={() => cambia('archivio')}>Archivio</button>
    </div>
    <p class="aiuto">{scheda === 'giocate'
      ? 'Le partite finite oggi: un\'ora dopo l\'inizio escono dagli elenchi e la chat si chiude. Domani passano in archivio.'
      : 'Le partite dei giorni passati, con formazione, partecipanti, tribuna e risultato (quando si potrà inserire).'}</p>

    {#if caricamento}
      <Caricamento />
    {:else if errore}
      <div class="errore">{errore}</div>
    {:else if !elenco.length}
      <div class="vuoto">{scheda === 'giocate' ? 'Nessuna partita giocata oggi.' : 'L\'archivio è ancora vuoto.'}</div>
    {:else}
      <div class="sezione">
        {#each elenco as p (p.partita_id)}
          <a href={`/partita/${p.partita_id}`} class="card riga" style={p.stato === 'annullata' ? 'opacity:.7' : ''}>
            <div class="data-box"><div class="g">{giornoBreve(p.data_ora)}</div><div class="n">{giornoNumero(p.data_ora)}</div></div>
            <div class="riempi">
              <div class="nome taglia">{etichettaFormato(p.formato)} · {p.campo_nome}</div>
              <div class="sotto taglia">{giornoNumero(p.data_ora)} {mese(p.data_ora)} · {ora(p.data_ora)}{mioRuolo(p) ? ` · ${mioRuolo(p)}` : ''}</div>
              <div class="sotto taglia">{risultato(p)} · {p.giocatori} giocatori{p.in_tribuna ? ` · ${p.in_tribuna} in tribuna` : ''}</div>
            </div>
            <Icona nome="avanti" dimensione={18} />
          </a>
        {/each}
      </div>
    {/if}
  </div>
</div>
