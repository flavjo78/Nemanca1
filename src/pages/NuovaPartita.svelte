<script>
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { naviga } from '../lib/router.svelte.js'
  import { RUOLI, perInputDataOra } from '../lib/formato.js'
  import Intestazione from '../components/Intestazione.svelte'
  import { PREDEFINITI, testoModulo, moduloPerDb } from '../lib/formazione.js'
  import Contatori from '../components/Contatori.svelte'
  import { NOMI_SPORT, FORMATI, racchetta, sportPredefinito } from '../lib/sport.svelte.js'

  let { id } = $props()
  let campo = $state(null)
  let sport = $state(sportPredefinito())
  const conRacchetta = $derived(racchetta(sport))
  let formato = $state(racchetta(sportPredefinito()) ? 2 : 5)
  let lati = $state(true)        // 2 contro 2: ruoli destra/sinistra (facoltativi)
  let lato = $state('destra')
  const sportCampo = $derived((campo?.sport ?? []).filter((s) => FORMATI[s]))
  function cambiaSport(s) { if (s === sport) return; sport = s; formato = racchetta(s) ? 2 : 5; panchina = 0 }
  let dataOra = $state(perInputDataOra(prossimaOraTonda()))
  let descrizione = $state('')
  let quota = $state('')
  let durata = $state(60)
  const DURATE = [60, 90, 120]
  let squadra = $state('A')
  let ruolo = $state(auth.profilo?.ruoli_preferiti?.[0] ?? 'attacco')
  let giocoAnchio = $state(true)
  let modalita = $state('libera')
  let panchina = $state(0)
  let difesa = $state(2), centro = $state(0), attacco = $state(2)
  let formatoPrecedente = 5
  $effect(() => {
    if (formato !== formatoPrecedente && PREDEFINITI[formato]) {
      formatoPrecedente = formato
      ;({ difesa, centro, attacco } = PREDEFINITI[formato])
    }
  })
  const movimento = $derived(formato - 1)
  const mancano = $derived(movimento - (difesa + centro + attacco))
  const ruoliModulo = $derived(['portiere', ...['difesa', 'centro', 'attacco'].filter((r) => ({ difesa, centro, attacco })[r] > 0)])
  $effect(() => { if (!ruoliModulo.includes(ruolo)) ruolo = ruoliModulo.includes('attacco') ? 'attacco' : ruoliModulo[ruoliModulo.length - 1] })
  let errore = $state('')
  let occupato = $state(false)

  function prossimaOraTonda() {
    const d = new Date(Date.now() + 24 * 3600 * 1000)
    d.setHours(21, 0, 0, 0)
    return d
  }

  onMount(async () => {
    const { data } = await supabase.from('campi').select('id, nome, indirizzo, sport').eq('id', id).maybeSingle()
    campo = data
    // se il campo non ha lo sport scelto, si parte dal primo che ha
    const disponibili = (data?.sport ?? []).filter((s) => FORMATI[s])
    if (disponibili.length && !disponibili.includes(sport)) cambiaSport(disponibili[0])
  })

  async function crea(e) {
    e.preventDefault()
    errore = ''
    const quando = new Date(dataOra)
    if (isNaN(quando) || quando < new Date()) { errore = 'Scegli una data e un\'ora future.'; return }
    if (!(Number(durata) >= 15 && Number(durata) <= 300)) { errore = 'La durata va da 15 a 300 minuti.'; return }
    if (!conRacchetta && mancano !== 0) { errore = `Completa il modulo: servono ${movimento} giocatori più il portiere.`; return }
    occupato = true
    const { data, error } = await supabase.rpc('crea_partita', {
      p_campo_id: id,
      p_formato: formato,
      p_data_ora: quando.toISOString(),
      p_descrizione: descrizione.trim() || null,
      p_quota: quota === '' ? 0 : Number(String(quota).replace(',', '.')),
      p_sport: sport,
      p_squadra: squadra,
      p_ruolo: !giocoAnchio ? null : conRacchetta ? (formato === 2 && lati ? lato : 'singolo') : ruolo,
      p_modalita: modalita,
      p_panchina: panchina,
      p_modulo: conRacchetta ? (formato === 2 && lati ? 'lati' : null) : moduloPerDb({ difesa, centro, attacco })
    })
    if (!error && Number(durata) !== 60) {
      const r = await supabase.rpc('imposta_durata', { p_partita: data, p_minuti: Math.round(Number(durata)) })
      if (r.error) { occupato = false; errore = r.error.message; return }
    }
    occupato = false
    if (error) { errore = error.message; return }
    naviga(`/partita/${data}?nuova=1`, { sostituisci: true })
  }
</script>

<div class="pagina">
  <Intestazione titolo="Organizza una partita" sotto={campo ? `${NOMI_SPORT[sport]} · ${campo.nome}` : ''} ritorno={`/campo/${id}`} />
  <form class="contenuto" onsubmit={crea}>
    {#if sportCampo.length > 1}
      <div class="campo-form">
        <span class="aiuto" style="font-weight:600">Sport</span>
        <div class="scelte">
          {#each sportCampo as s}
            <button type="button" class="scelta" class:attiva={sport === s} onclick={() => cambiaSport(s)}>{NOMI_SPORT[s]}</button>
          {/each}
        </div>
      </div>
    {/if}
    {#if conRacchetta}
      <div class="campo-form">
        <span class="aiuto" style="font-weight:600">Formato</span>
        <div class="scelte">
          {#each [1, 2] as f}
            <button type="button" class="scelta" class:attiva={formato === f} onclick={() => (formato = f)}>{f} contro {f}</button>
          {/each}
        </div>
        <p class="aiuto">{formato === 1 ? `${NOMI_SPORT[sport]} singolo: 2 giocatori in tutto.` : `${NOMI_SPORT[sport]} in coppia: 4 giocatori in tutto, 2 per squadra.`}</p>
      </div>
      {#if formato === 2}
        <div class="campo-form">
          <span class="aiuto" style="font-weight:600">Ruoli (facoltativi)</span>
          <div class="scelte">
            <button type="button" class="scelta" class:attiva={lati} onclick={() => (lati = true)}>Destra e sinistra</button>
            <button type="button" class="scelta" class:attiva={!lati} onclick={() => (lati = false)}>Senza ruoli</button>
          </div>
          <p class="aiuto">{lati ? 'In ogni coppia un posto a destra e uno a sinistra: ognuno sceglie il suo lato.' : 'Due posti per coppia, senza lato: vi mettete d\'accordo in campo.'}</p>
        </div>
      {/if}
    {:else}
      <div class="campo-form">
        <span class="aiuto" style="font-weight:600">Formato</span>
        <div class="scelte">
          {#each [5, 8, 11] as f}
            <button type="button" class="scelta" class:attiva={formato === f} onclick={() => (formato = f)}>Calcio a {f}</button>
          {/each}
        </div>
        <p class="aiuto">{formato * 2} posti in tutto, {formato} per squadra.</p>
      </div>
      <div class="campo-form">
        <span class="aiuto" style="font-weight:600">Modulo: {testoModulo({ difesa, centro, attacco })} <span style="font-weight:400">(più il portiere)</span></span>
        <Contatori bind:difesa bind:centro bind:attacco massimo={movimento} />
        <p class="aiuto" style={mancano ? 'color: var(--avviso-testo)' : ''}>{mancano > 0
          ? `Mancano ${mancano} ${mancano === 1 ? 'giocatore' : 'giocatori'} per arrivare a ${movimento} più il portiere.`
          : `${movimento} giocatori più il portiere, per entrambe le squadre. Dopo puoi cambiarlo per ciascuna.`}</p>
      </div>
    {/if}
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
      <label for="durata">Durata (minuti)</label>
      <div class="scelte">
        {#each DURATE as d}
          <button type="button" class="scelta" class:attiva={Number(durata) === d} onclick={() => (durata = d)}>{d} min</button>
        {/each}
      </div>
      <input id="durata" class="input" type="number" inputmode="numeric" min="15" max="300" step="5" bind:value={durata} />
      {#if !conRacchetta}<p class="aiuto">Alla fine della partita i giocatori votano il migliore in campo.</p>{/if}
    </div>
    <div class="campo-form">
      <label for="quota">Quota a testa (€)</label>
      <input id="quota" class="input" type="text" inputmode="decimal" bind:value={quota} placeholder="0 = gratis" />
    </div>
    <div class="campo-form">
      <label for="descrizione">Descrizione (facoltativa)</label>
      <textarea id="descrizione" class="input" bind:value={descrizione} placeholder={conRacchetta ? 'Livello medio, le palline le porto io.' : 'Partita tranquilla, livello medio. Portate maglia chiara e scura.'}></textarea>
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
        {#if !conRacchetta}
          <span class="aiuto" style="font-weight:600">Il tuo ruolo</span>
          <div class="scelte">
            {#each ruoliModulo as chiave}
              <button type="button" class="scelta" class:attiva={ruolo === chiave} onclick={() => (ruolo = chiave)}>{RUOLI[chiave]}</button>
            {/each}
          </div>
        {:else if formato === 2 && lati}
          <span class="aiuto" style="font-weight:600">Il tuo lato</span>
          <div class="scelte">
            <button type="button" class="scelta" class:attiva={lato === 'destra'} onclick={() => (lato = 'destra')}>Destra</button>
            <button type="button" class="scelta" class:attiva={lato === 'sinistra'} onclick={() => (lato = 'sinistra')}>Sinistra</button>
          </div>
        {/if}
      {/if}
    </div>
    {#if errore}<div class="errore">{errore}</div>{/if}
    <button class="btn" type="submit" disabled={occupato}>{occupato ? 'Creazione…' : 'Crea la partita'}</button>
  </form>
</div>
