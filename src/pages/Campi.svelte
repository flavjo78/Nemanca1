<script>
  // Elenco campi (vicini se conosciamo la posizione) + registrazione nuovo campo
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { router } from '../lib/router.svelte.js'
  import { posizioneAttuale } from '../lib/geo.js'
  import { km } from '../lib/formato.js'
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Icona from '../components/Icona.svelte'
  import RaggioKm from '../components/RaggioKm.svelte'

  let campi = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let ricerca = $state('')
  let conDistanza = $state(false)
  const perOrganizzare = $derived(router.query.get('organizza') === '1')

  // Lista o Mappa (ricordata su questo telefono)
  let vista = $state((() => { try { return localStorage.getItem('nm1-vista-campi') === 'mappa' ? 'mappa' : 'lista' } catch { return 'lista' } })())
  function scegliVista(v) { vista = v; try { localStorage.setItem('nm1-vista-campi', v) } catch {} }
  const caricaMappa = () => import('../components/MappaCampi.svelte')

  const filtrati = $derived(campi.filter((c) => {
    const q = ricerca.trim().toLowerCase()
    return !q || c.nome.toLowerCase().includes(q) || c.indirizzo.toLowerCase().includes(q)
  }))

  onMount(carica)

  async function carica() {
    caricamento = true
    conDistanza = false
    errore = ''
    let lat = auth.profilo?.lat, lng = auth.profilo?.lng
    if (lat == null) { try { ({ lat, lng } = await posizioneAttuale()) } catch { /* niente */ } }
    if (lat != null) {
      const { data, error } = await supabase.rpc('campi_vicini', { p_lat: lat, p_lng: lng, p_raggio_km: auth.profilo?.raggio_km ?? 20, p_limite: 50 })
      if (!error && data?.length) { campi = data; conDistanza = true; caricamento = false; return }
    }
    const { data, error } = await supabase.from('campi').select('*').order('nome').limit(100)
    if (error) errore = error.message
    campi = data ?? []
    caricamento = false
  }
</script>

<div class="pagina">
  <header class="intestazione" style="justify-content: space-between">
    <div class="centro">
      <h1 style="font-size: 26px">{perOrganizzare ? 'Dove si gioca?' : 'Campi'}</h1>
      <div class="sotto">{perOrganizzare ? 'Scegli il campo per la tua partita' : conDistanza ? 'Dal più vicino a te' : 'Tutti i campi registrati'}</div>
    </div>
    <a href="/campi/nuovo" class="btn-tondo verde" aria-label="Registra un nuovo campo"><Icona nome="piu" dimensione={20} spessore={2.4} /></a>
  </header>

  <div class="contenuto con-barra">
    <div style="position:relative">
      <input class="input" type="search" placeholder="Cerca per nome o indirizzo" bind:value={ricerca} aria-label="Cerca campo" style="padding-left: 44px" />
      <span style="position:absolute; left:14px; top:14px; color: var(--testo-2)"><Icona nome="cerca" dimensione={22} /></span>
    </div>
    <div class="scelte" role="tablist" aria-label="Vista dei campi">
      <button type="button" role="tab" class="scelta" class:attiva={vista === 'lista'} aria-selected={vista === 'lista'} onclick={() => scegliVista('lista')}>Lista</button>
      <button type="button" role="tab" class="scelta" class:attiva={vista === 'mappa'} aria-selected={vista === 'mappa'} onclick={() => scegliVista('mappa')}>Mappa</button>
    </div>
    {#if auth.profilo?.lat != null}
      <div style="display:flex; align-items:center; gap:10px; flex-wrap:wrap">
        <RaggioKm cambiato={carica} />
        <span class="aiuto">{caricamento ? '' : conDistanza ? 'dal tuo comune' : 'Nessun campo in questo raggio: ecco tutti i campi'}</span>
      </div>
    {/if}

    {#if caricamento}
      <Caricamento />
    {:else if errore}
      <div class="errore">{errore}</div>
    {:else if vista === 'mappa'}
      {#await caricaMappa()}
        <Caricamento />
      {:then modulo}
        <modulo.default campi={filtrati} organizza={perOrganizzare}
          centro={auth.profilo?.lat != null ? { lat: auth.profilo.lat, lng: auth.profilo.lng } : null}
          raggioKm={conDistanza ? (auth.profilo?.raggio_km ?? 20) : null} />
        {#if !filtrati.length}<p class="aiuto">{campi.length ? 'Nessun campo corrisponde alla ricerca.' : 'Non c\'è ancora nessun campo. Registra il primo!'}</p>{/if}
      {:catch}
        <div class="errore">Non sono riuscito a caricare la mappa. Controlla la connessione e riprova.</div>
      {/await}
    {:else if !filtrati.length}
      <div class="vuoto">
        {campi.length ? 'Nessun campo corrisponde alla ricerca.' : 'Non c\'è ancora nessun campo. Registra il primo!'}
      </div>
    {:else}
      <div class="sezione">
        {#each filtrati as c (c.id)}
          <a href={`/campo/${c.id}${perOrganizzare ? '?organizza=1' : ''}`} class="card riga">
            <div class="avatar" style="border-radius:12px; background: var(--verde-chiaro); color: var(--verde-scuro)"><Icona nome="campi" dimensione={22} /></div>
            <div class="riempi">
              <div class="nome taglia">{c.nome}</div>
              <div class="sotto taglia">{c.indirizzo}{c.distanza_km != null ? ` · ${km(c.distanza_km)}` : ''}</div>
            </div>
            {#if c.partite_aperte > 0}
              <span class="chip avviso">{c.partite_aperte} {c.partite_aperte === 1 ? 'partita' : 'partite'}</span>
            {/if}
            <Icona nome="avanti" dimensione={18} />
          </a>
        {/each}
      </div>
    {/if}

    <a href="/campi/nuovo" class="btn tratteggiato">
      <Icona nome="piu" dimensione={18} spessore={2.4} /> Registra un campo
    </a>
  </div>
  <BarraInferiore />
</div>
