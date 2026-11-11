<script>
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { naviga } from '../lib/router.svelte.js'
  import { RUOLI, perInputDataOra } from '../lib/formato.js'
  import Intestazione from '../components/Intestazione.svelte'

  let { id } = $props()
  let campo = $state(null)
  let formato = $state(5)
  let dataOra = $state(perInputDataOra(prossimaOraTonda()))
  let descrizione = $state('')
  let quota = $state('')
  let squadra = $state('A')
  let ruolo = $state(auth.profilo?.ruoli_preferiti?.[0] ?? 'attacco')
  let giocoAnchio = $state(true)
  let modalita = $state('libera')
  let panchina = $state(0)
  let errore = $state('')
  let occupato = $state(false)

  function prossimaOraTonda() {
    const d = new Date(Date.now() + 24 * 3600 * 1000)
    d.setHours(21, 0, 0, 0)
    return d
  }

  onMount(async () => {
    const { data } = await supabase.from('campi').select('id, nome, indirizzo').eq('id', id).maybeSingle()
    campo = data
  })

  async function crea(e) {
    e.preventDefault()
    errore = ''
    const quando = new Date(dataOra)
    if (isNaN(quando) || quando < new Date()) { errore = 'Scegli una data e un\'ora future.'; return }
    occupato = true
    const { data, error } = await supabase.rpc('crea_partita', {
      p_campo_id: id,
      p_formato: formato,
      p_data_ora: quando.toISOString(),
      p_descrizione: descrizione.trim() || null,
      p_quota: quota === '' ? 0 : Number(String(quota).replace(',', '.')),
      p_sport: 'calcio',
      p_squadra: squadra,
      p_ruolo: giocoAnchio ? ruolo : null,
      p_modalita: modalita,
      p_panchina: panchina
    })
    occupato = false
    if (error) { errore = error.message; return }
    naviga(`/partita/${data}?nuova=1`, { sostituisci: true })
  }
</script>

<div class="pagina">
  <Intestazione titolo="Organizza una partita" sotto={campo ? campo.nome : ''} ritorno={`/campo/${id}`} />
  <form class="contenuto" onsubmit={crea}>
    <div class="campo-form">
      <span class="aiuto" style="font-weight:600">Formato</span>
      <div class="scelte">
        {#each [5, 8, 11] as f}
          <button type="button" class="scelta" class:attiva={formato === f} onclick={() => (formato = f)}>Calcio a {f}</button>
        {/each}
      </div>
      <p class="aiuto">{formato * 2} posti in tutto, {formato} per squadra. Lo schema lo puoi cambiare dopo.</p>
    </div>
    <div class="campo-form">
      <span class="aiuto" style="font-weight:600">Chi sceglie il posto?</span>
      <div class="scelte">
        <button type="button" class="scelta" class:attiva={modalita === 'libera'} onclick={() => (modalita = 'libera')}>Ognuno sceglie il suo</button>
        <button type="button" class="scelta" class:attiva={modalita === 'approvazione'} onclick={() => (modalita = 'approvazione')}>Decido io chi gioca</button>
      </div>
      <p class="aiuto">{modalita === 'libera'
        ? 'Chi apre la partita tocca un posto libero e si siede subito.'
        : 'Gli altri entrano in tribuna o si candidano; tu scegli chi mettere in campo.'}</p>
    </div>
    <div class="campo-form">
      <span class="aiuto" style="font-weight:600">Panchina: riserve per squadra</span>
      <div class="scelte">
        {#each [0, 1, 2, 3] as n}
          <button type="button" class="scelta" class:attiva={panchina === n} onclick={() => (panchina = n)}>{n === 0 ? 'Nessuna' : n}</button>
        {/each}
      </div>
    </div>
    <div class="campo-form">
      <label for="quando">Giorno e ora</label>
      <input id="quando" class="input" type="datetime-local" required bind:value={dataOra} />
    </div>
    <div class="campo-form">
      <label for="quota">Quota a testa (€)</label>
      <input id="quota" class="input" type="text" inputmode="decimal" bind:value={quota} placeholder="0 = gratis" />
    </div>
    <div class="campo-form">
      <label for="descrizione">Descrizione (facoltativa)</label>
      <textarea id="descrizione" class="input" bind:value={descrizione} placeholder="Partita tranquilla, livello medio. Portate maglia chiara e scura."></textarea>
    </div>
    <div class="campo-form">
      <label style="display:flex; align-items:center; gap:10px; min-height:44px; font-size:15px; color: var(--testo)">
        <input type="checkbox" bind:checked={giocoAnchio} style="width:22px; height:22px; accent-color: var(--verde)" />
        Gioco anch'io
      </label>
      {#if giocoAnchio}
        <span class="aiuto" style="font-weight:600">La tua squadra</span>
        <div class="scelte">
          <button type="button" class="scelta" class:attiva={squadra === 'A'} onclick={() => (squadra = 'A')}>Squadra A</button>
          <button type="button" class="scelta" class:attiva={squadra === 'B'} onclick={() => (squadra = 'B')}>Squadra B</button>
        </div>
        <span class="aiuto" style="font-weight:600">Il tuo ruolo</span>
        <div class="scelte">
          {#each Object.entries(RUOLI) as [chiave, testo]}
            {#if formato !== 5 || chiave !== 'centro'}
              <button type="button" class="scelta" class:attiva={ruolo === chiave} onclick={() => (ruolo = chiave)}>{testo}</button>
            {/if}
          {/each}
        </div>
      {/if}
    </div>
    {#if errore}<div class="errore">{errore}</div>{/if}
    <button class="btn" type="submit" disabled={occupato}>{occupato ? 'Creazione…' : 'Crea la partita'}</button>
  </form>
</div>
