<script>
  // Elenco delle chat delle mie partite (organizzo, gioco, sono in panchina o in tribuna)
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { etichettaFormato, giornoBreve, giornoNumero, ora } from '../lib/formato.js'
  import { haNuovi } from '../lib/letture.js'
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Icona from '../components/Icona.svelte'

  let chat = $state([])
  let caricamento = $state(true)
  let errore = $state('')

  onMount(async () => {
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
  <header class="intestazione"><div class="centro"><h1 style="font-size:26px">Chat</h1><div class="sotto">Le chat delle tue partite</div></div></header>
  <div class="contenuto con-barra">
    {#if caricamento}
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
          {@const nuovo = haNuovi(c.partita_id, c.ultimo_il)}
          <a href={`/chat/${c.partita_id}`} class="card riga" style={c.stato === 'annullata' ? 'opacity:.6' : ''}>
            <div class="data-box"><div class="g">{giornoBreve(c.data_ora)}</div><div class="n">{giornoNumero(c.data_ora)}</div></div>
            <div class="riempi">
              <div class="nome taglia">{c.campo_nome} · {ora(c.data_ora)}</div>
              <div class="sotto taglia" style={nuovo ? 'color: var(--testo); font-weight:600' : ''}>{anteprima(c)}</div>
            </div>
            {#if nuovo}<span class="pallino-nuovo" aria-label="Messaggi nuovi"></span>{/if}
            <Icona nome="avanti" dimensione={18} />
          </a>
        {/each}
      </div>
    {/if}
  </div>
  <BarraInferiore />
</div>

<style>
  .pallino-nuovo { width: 10px; height: 10px; border-radius: 5px; background: var(--da-confermare); flex: 0 0 10px; }
</style>
