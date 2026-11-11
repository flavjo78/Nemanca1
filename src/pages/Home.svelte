<script>
  // Home personale: prossima partita, da approvare, partite vicine con posti liberi
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { naviga } from '../lib/router.svelte.js'
  import { posizioneAttuale } from '../lib/geo.js'
  import { dataEstesa, etichettaProssima, etichettaFormato, iniziali, nomeBreve, chipPosti, chipPostiDaConteggio, giornoBreve, giornoNumero, km, ora, etichettaRuolo } from '../lib/formato.js'
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Icona from '../components/Icona.svelte'

  let prossima = $state(null)
  let daApprovare = $state([])
  let inviti = $state([])
  let vicine = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let senzaPosizione = $state(false)

  const primoNome = $derived((auth.profilo?.nome ?? '').split(' ')[0] || 'ciao')

  onMount(carica)

  async function carica() {
    caricamento = true
    errore = ''
    try {
      await Promise.all([caricaProssima(), caricaDaApprovare(), caricaVicine(), caricaInviti()])
    } catch (e) {
      errore = e.message
    }
    caricamento = false
  }

  async function caricaProssima() {
    const uid = auth.utente.id
    // partite dove ho un posto o sono organizzatore, da adesso in poi
    const [{ data: mie }, { data: org }] = await Promise.all([
      supabase.from('posizioni').select('partita_id').eq('giocatore_id', uid),
      supabase.from('partite').select('id').eq('organizzatore_id', uid).gte('data_ora', new Date().toISOString())
    ])
    const ids = [...new Set([...(mie ?? []).map((x) => x.partita_id), ...(org ?? []).map((x) => x.id)])]
    if (!ids.length) { prossima = null; return }
    const { data, error } = await supabase
      .from('partite')
      .select('*, campo:campi(id, nome, indirizzo), posizioni(id, stato, ruolo, giocatore_id, giocatore:profili(nome, iniziali))')
      .in('id', ids)
      .in('stato', ['aperta', 'completa'])
      .gte('data_ora', new Date(Date.now() - 3 * 3600 * 1000).toISOString())
      .order('data_ora')
      .limit(1)
    if (error) throw error
    prossima = data?.[0] ?? null
  }

  async function caricaDaApprovare() {
    const { data, error } = await supabase
      .from('richieste')
      .select('*, giocatore:profili(id, nome, iniziali), partita:partite!inner(id, organizzatore_id, data_ora, formato)')
      .eq('stato', 'in_attesa')
      .eq('partita.organizzatore_id', auth.utente.id)
      .order('creato_il')
    if (error) throw error
    daApprovare = data ?? []
  }

  async function caricaInviti() {
    const { data } = await supabase.from('inviti')
      .select('*, da:profili!inviti_da_id_fkey(nome, iniziali), posizione:posizioni(ruolo, squadra), partita:partite(id, data_ora, formato, stato, campo:campi(nome))')
      .eq('a_id', auth.utente.id).eq('stato', 'in_attesa').order('creato_il', { ascending: false })
    inviti = (data ?? []).filter((i) => i.partita && ['aperta', 'completa'].includes(i.partita.stato))
  }

  async function caricaVicine() {
    let lat = auth.profilo?.lat, lng = auth.profilo?.lng
    if (lat == null) {
      try { ({ lat, lng } = await posizioneAttuale()) } catch { /* nessuna posizione */ }
    }
    if (lat == null) {
      senzaPosizione = true
      // fallback: le prossime partite aperte ovunque
      const { data, error } = await supabase
        .from('partite').select('id, formato, data_ora, quota, campo:campi(id, nome), posizioni(stato, ruolo)')
        .eq('stato', 'aperta').gte('data_ora', new Date().toISOString()).order('data_ora').limit(10)
      if (error) throw error
      vicine = (data ?? []).map((p) => {
        const liberi = p.posizioni.filter((x) => x.stato === 'libera')
        return { id: p.id, formato: p.formato, data_ora: p.data_ora, campo_nome: p.campo?.nome, distanza_km: null,
          posti_liberi: liberi.length, ruoli_liberi: [...new Set(liberi.map((x) => x.ruolo))] }
      }).filter((p) => p.posti_liberi > 0)
      return
    }
    const { data, error } = await supabase.rpc('partite_vicine', { p_lat: lat, p_lng: lng, p_raggio_km: 30, p_limite: 10 })
    if (error) throw error
    vicine = (data ?? []).filter((p) => p.organizzatore_id !== auth.utente.id)
  }

  async function rispondi(r, stato) {
    errore = ''
    const { error } = await supabase.rpc('rispondi_richiesta', { p_richiesta: r.id, p_accetta: stato === 'accettata' })
    if (error) { errore = error.message; return }
    daApprovare = daApprovare.filter((x) => x.id !== r.id)
    if (stato === 'accettata') caricaProssima()
  }

  function partecipanti(p) { return p.posizioni.filter((x) => x.giocatore_id) }
  function postiCampo(p) { return p.posizioni.filter((x) => x.ruolo !== 'panchina').length }
</script>

<div class="pagina">
  <header class="intestazione" style="justify-content: space-between">
    <div class="centro">
      <div class="sotto">{dataEstesa()}</div>
      <h1 style="font-size: 26px; letter-spacing: -0.5px">Ciao {primoNome}</h1>
    </div>
    <a href="/profilo" class="avatar verde grande" aria-label="Apri il profilo">{iniziali(auth.profilo)}</a>
  </header>

  <div class="contenuto con-barra">
    {#if caricamento}
      <Caricamento />
    {:else}
      {#if errore}<div class="errore">{errore}</div>{/if}

      <section class="sezione">
        <div class="sezione-titolo">La tua prossima partita</div>
        {#if prossima}
          {@const chip = chipPosti(prossima.posizioni)}
          <a href={`/partita/${prossima.id}`} class="card verde">
            <div style="display:flex; justify-content:space-between; align-items:center">
              <div class="titolo" style="color:#fff">{etichettaProssima(prossima.data_ora)}</div>
              <span class="chip bianco-su-verde">{etichettaFormato(prossima.formato)}</span>
            </div>
            <div class="sotto" style="font-size:15px">{prossima.campo?.nome}{prossima.campo?.indirizzo ? ` · ${prossima.campo.indirizzo.split(',').pop().trim()}` : ''}</div>
            <div style="display:flex; justify-content:space-between; align-items:center; gap:8px">
              <div style="display:flex; align-items:center; gap:8px">
                <div class="avatar-pila">
                  {#each partecipanti(prossima).slice(0, 3) as p}
                    <div class="avatar mini">{iniziali(p.giocatore)}</div>
                  {/each}
                  {#if partecipanti(prossima).length > 3}
                    <div class="avatar mini piu">+{partecipanti(prossima).length - 3}</div>
                  {/if}
                </div>
                <div class="sotto">{partecipanti(prossima).filter((x) => x.ruolo !== 'panchina').length} di {postiCampo(prossima)}</div>
              </div>
              {#if chip.classe !== 'neutro'}
                <span class="chip portiere">{chip.testo}</span>
              {:else}
                <span class="chip bianco-su-verde">Al completo</span>
              {/if}
            </div>
          </a>
        {:else}
          <div class="vuoto">Nessuna partita in programma. Trova un campo e organizzane una.</div>
        {/if}
      </section>

      {#if inviti.length}
        <section class="sezione">
          <div class="sezione-titolo">Ti chiedono di giocare</div>
          {#each inviti as i (i.id)}
            <a href={`/partita/${i.partita.id}`} class="card riga" style="border: 2px solid var(--portiere)">
              <div class="data-box"><div class="g">{giornoBreve(i.partita.data_ora)}</div><div class="n">{giornoNumero(i.partita.data_ora)}</div></div>
              <div class="riempi">
                <div class="nome taglia">{nomeBreve(i.da)} ti vuole in campo</div>
                <div class="sotto taglia">{i.posizione ? `${etichettaRuolo(i.posizione.ruolo)} · squadra ${i.posizione.squadra} · ` : ''}{i.partita.campo?.nome} · {ora(i.partita.data_ora)}</div>
              </div>
              <Icona nome="avanti" dimensione={18} />
            </a>
          {/each}
        </section>
      {/if}

      {#if daApprovare.length}
        <section class="sezione">
          <div class="sezione-titolo">Da approvare</div>
          {#each daApprovare as r (r.id)}
            <div class="card riga">
              <div class="avatar">{iniziali(r.giocatore)}</div>
              <div class="riempi">
                <div class="nome">{nomeBreve(r.giocatore)} vuole entrare</div>
                <div class="sotto">{r.ruolo_richiesto ? etichettaRuolo(r.ruolo_richiesto) : 'Qualsiasi ruolo'} · {etichettaFormato(r.partita.formato)} {ora(r.partita.data_ora)}</div>
              </div>
              <button type="button" class="btn-tondo piccolo bordo" aria-label="Rifiuta" onclick={() => rispondi(r, 'rifiutata')}><Icona nome="x" dimensione={18} spessore={2.2} /></button>
              <button type="button" class="btn-tondo piccolo verde" aria-label="Accetta" onclick={() => rispondi(r, 'accettata')}><Icona nome="spunta" dimensione={18} spessore={2.4} /></button>
            </div>
          {/each}
        </section>
      {/if}

      <section class="sezione">
        <div class="sezione-titolo">
          <span>{senzaPosizione ? 'Partite con posti liberi' : 'Serve un giocatore vicino a te'}</span>
          <a href="/campi">Campi</a>
        </div>
        {#if senzaPosizione}
          <p class="aiuto">Imposta il tuo comune nel <a href="/profilo">profilo</a> per vedere solo le partite vicine.</p>
        {/if}
        {#if vicine.length}
          {#each vicine as p (p.id)}
            {@const chip = chipPostiDaConteggio(p.posti_liberi, p.ruoli_liberi)}
            <a href={`/partita/${p.id}`} class="card riga">
              <div class="data-box"><div class="g">{giornoBreve(p.data_ora)}</div><div class="n">{giornoNumero(p.data_ora)}</div></div>
              <div class="riempi">
                <div class="nome">{etichettaFormato(p.formato)} · {ora(p.data_ora)}</div>
                <div class="sotto taglia">{p.campo_nome}{p.distanza_km != null ? ` · ${km(p.distanza_km)}` : ''}</div>
              </div>
              <span class="chip {chip.classe}">{chip.testo}</span>
            </a>
          {/each}
        {:else}
          <div class="vuoto">Nessuna partita con posti liberi al momento.</div>
        {/if}
      </section>

      <button type="button" class="btn tratteggiato" onclick={() => naviga('/campi?organizza=1')}>
        <Icona nome="piu" dimensione={18} spessore={2.4} /> Organizza una partita
      </button>
    {/if}
  </div>
  <BarraInferiore />
</div>
