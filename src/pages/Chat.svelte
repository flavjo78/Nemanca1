<script>
  // Elenco delle chat delle mie partite (organizzo, gioco, sono in panchina o in tribuna)
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { etichettaFormato, giornoBreve, giornoNumero, ora } from '../lib/formato.js'
  import { nonLetti, aggiornaNonLetti } from '../lib/nonletti.svelte.js'
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Icona from '../components/Icona.svelte'
  import ElencoAmici from '../components/ElencoAmici.svelte'
  import { router, naviga } from '../lib/router.svelte.js'

  // due schede: le chat delle partite e gli amici (anche da /amici)
  const scheda = $derived(router.percorso === '/amici' ? 'amici' : 'partite')
  let richiesteAmici = $state(0)
  function vai(s) { naviga(s === 'amici' ? '/amici' : '/chat', { sostituisci: true }) }

  let chat = $state([])
  let caricamento = $state(true)
  let errore = $state('')

  onMount(async () => {
    aggiornaNonLetti()
    supabase.rpc('miei_amici').then(({ data }) => { richiesteAmici = (data ?? []).filter((a) => a.stato === 'ricevuta').length })
    const { data, error } = await supabase.rpc('mie_chat')
    if (error) errore = error.message
    chat = data ?? []
    caricamento = false
  })

  function anteprima(c) {
    if (!c.ultimo_testo) return 'Nessun messaggio: scrivi tu il primo'
    if (c.ultimo_tipo !== 'testo') return c.ultimo_testo
    return `${(c.ultimo_autore ?? 'Qualcuno').split(' ')[0]}: ${c.ultimo_testo}`
  }
</script>

<div class="pagina">
  <header class="intestazione"><div class="centro"><h1 style="font-size:26px">Chat</h1><div class="sotto">{scheda === 'amici' ? 'I tuoi amici, da invitare alle partite' : 'Le chat delle tue partite'}</div></div></header>
  <div class="contenuto con-barra">
    <div class="scelte" role="tablist" aria-label="Chat e amici">
      <button type="button" role="tab" class="scelta" class:attiva={scheda === 'partite'} aria-selected={scheda === 'partite'} onclick={() => vai('partite')}>Partite</button>
      <button type="button" role="tab" class="scelta" class:attiva={scheda === 'amici'} aria-selected={scheda === 'amici'} onclick={() => vai('amici')}>
        Amici{#if richiesteAmici} <span class="conta-nuovi" style="margin-left:4px">{richiesteAmici}</span>{/if}
      </button>
    </div>
    {#if scheda === 'amici'}
      <ElencoAmici />
    {:else if caricamento}
      <Caricamento />
    {:else if errore}
      <div class="errore">{errore}</div>
    {:else if !chat.length}
      <div class="vuoto" style="display:flex; flex-direction:column; align-items:center; gap:10px; padding: 36px 16px">
        <span style="color: var(--verde)"><Icona nome="chat" dimensione={36} /></span>
        <strong style="color: var(--testo)">Ancora nessuna chat</strong>
        Ogni partita in cui giochi, organizzi o sei in tribuna ha la sua chat. La trovi qui.
        <a href="/campi">Trova una partita</a>
      </div>
    {:else}
      <div class="sezione">
        {#each chat as c (c.partita_id)}
          {@const quanti = nonLetti.perPartita[c.partita_id] ?? 0}
          {@const nuovo = quanti > 0}
          <a href={`/chat/${c.partita_id}`} class="card riga" style={c.stato === 'annullata' || !c.attiva ? 'opacity:.7' : ''}>
            <div class="data-box"><div class="g">{giornoBreve(c.data_ora)}</div><div class="n">{giornoNumero(c.data_ora)}</div></div>
            <div class="riempi">
              <div class="nome taglia">{c.campo_nome} · {ora(c.data_ora)}{#if !c.attiva}<span class="chip neutro" style="margin-left:6px; font-size:11px; padding:2px 8px">Archivio</span>{/if}</div>
              <div class="sotto taglia" style={nuovo ? 'color: var(--testo); font-weight:600' : ''}>{anteprima(c)}</div>
            </div>
            {#if nuovo}<span class="conta-nuovi" aria-label={`${quanti} da leggere`}>{quanti > 99 ? '99+' : quanti}</span>{/if}
            <Icona nome="avanti" dimensione={18} />
          </a>
        {/each}
      </div>
    {/if}
  </div>
  <BarraInferiore />
</div>

<style>
  .conta-nuovi { min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px; background: #D93025; color: #fff; font-size: 12px; font-weight: 700; line-height: 22px; text-align: center; flex: 0 0 auto; }
</style>
