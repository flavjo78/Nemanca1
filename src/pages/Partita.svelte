<script>
  // Schermata partita: campo disegnato interattivo (tappa 2)
  import { onMount, onDestroy } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { router, indietro, naviga } from '../lib/router.svelte.js'
  import { etichettaDataOra, etichettaFormato, nomeBreve, chipPosti, euro, etichettaRuolo, iniziali, RUOLI } from '../lib/formato.js'
  import { conta } from '../lib/formazione.js'
  import Icona from '../components/Icona.svelte'
  import CampoDisegnato from '../components/CampoDisegnato.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Foglio from '../components/Foglio.svelte'

  let { id } = $props()
  let partita = $state(null)
  let richieste = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let avviso = $state('')
  let occupato = $state(false)
  let foglio = $state(null)          // { tipo, posizione }
  let ruoloScelto = $state(null)
  let squadraScelta = $state('A')
  let canale = null
  let timerRicarica = null

  const appenaCreata = $derived(router.query.get('nuova') === '1')
  const uid = $derived(auth.utente?.id ?? null)
  const posizioni = $derived(partita?.posizioni ?? [])
  const numeri = $derived(conta(posizioni))
  const chip = $derived(chipPosti(posizioni))
  const sonoOrganizzatore = $derived(!!uid && partita?.organizzatore_id === uid)
  const mioPosto = $derived(posizioni.find((p) => p.giocatore_id === uid) ?? null)
  const miaRichiesta = $derived(richieste.find((r) => r.giocatore_id === uid) ?? null)
  const richiesteDaApprovare = $derived(sonoOrganizzatore ? richieste : [])
  const modificabile = $derived(partita && ['aperta', 'completa'].includes(partita.stato) && new Date(partita.data_ora) > new Date(Date.now() - 2 * 3600 * 1000))

  onMount(async () => {
    await carica()
    caricamento = false
    canale = supabase.channel(`partita-${id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posizioni', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'richieste', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'partite', filter: `id=eq.${id}` }, pianificaRicarica)
      .subscribe()
  })
  onDestroy(() => { if (canale) supabase.removeChannel(canale); clearTimeout(timerRicarica) })

  function pianificaRicarica() { clearTimeout(timerRicarica); timerRicarica = setTimeout(carica, 150) }

  async function carica() {
    const { data, error } = await supabase
      .from('partite')
      .select('*, campo:campi(id, nome, indirizzo), organizzatore:profili!partite_organizzatore_id_fkey(id, nome, iniziali), posizioni(*, giocatore:profili(id, nome, iniziali))')
      .eq('id', id).maybeSingle()
    if (error || !data) { errore = 'Partita non trovata.'; return }
    data.posizioni.sort((a, b) => a.squadra.localeCompare(b.squadra) || a.y - b.y || a.x - b.x || a.creato_il.localeCompare(b.creato_il))
    partita = data
    if (uid) {
      const { data: r } = await supabase.from('richieste')
        .select('*, giocatore:profili(id, nome, iniziali)')
        .eq('partita_id', id).eq('stato', 'in_attesa').order('creato_il')
      richieste = r ?? []
    }
  }

  // esegue una funzione lato DB e ricarica; mostra l'errore in italiano
  async function esegui(nome, parametri, messaggioOk = '') {
    errore = ''; avviso = ''
    occupato = true
    const { error } = await supabase.rpc(nome, parametri)
    occupato = false
    if (error) { errore = pulisci(error.message); return false }
    foglio = null
    avviso = messaggioOk
    await carica()
    return true
  }
  function pulisci(m = '') {
    if (/JWT|not authenticated|autenticato/i.test(m)) return 'Devi accedere per fare questa operazione.'
    if (/function .* does not exist|schema cache/i.test(m)) return 'Il database non è ancora aggiornato alla tappa 2 (manca la migrazione 0002).'
    return m
  }

  function tocca(p) {
    errore = ''; avviso = ''
    if (!modificabile) return
    if (!uid) { naviga(`/login?next=${encodeURIComponent(`/partita/${id}`)}`); return }
    ruoloScelto = null
    if (p.giocatore_id === uid) foglio = { tipo: 'mio-posto', posizione: p }
    else if (p.stato === 'libera') foglio = { tipo: 'posto-libero', posizione: p }
    else foglio = { tipo: 'posto-occupato', posizione: p }
  }

  const prendi = (p) => esegui('prendi_posto', { p_posizione: p.id }, mioPosto ? 'Ti sei spostato.' : 'Sei in squadra!')
  const lascia = () => esegui('lascia_posto', { p_partita: id }, 'Hai lasciato il posto.')
  const libera = (p) => esegui('libera_posto', { p_posizione: p.id }, 'Posto liberato.')
  const rimuovi = (p) => esegui('rimuovi_posto', { p_posizione: p.id }, 'Posto tolto dallo schema.')
  const proponi = (p, ruolo) => esegui('proponi_cambio', { p_posizione: p.id, p_nuovo_ruolo: ruolo }, p.giocatore_id ? 'Proposta inviata: il giocatore deve accettare.' : 'Ruolo cambiato.')
  const rispondiCambio = (accetta) => esegui('rispondi_cambio', { p_posizione: mioPosto.id, p_accetta: accetta }, accetta ? 'Ruolo aggiornato.' : 'Hai rifiutato il cambio.')
  const candidati = () => esegui('candidati', { p_partita: id, p_ruolo: ruoloScelto }, 'Candidatura inviata: l\'organizzatore riceve la richiesta.')
  const ritira = () => esegui('ritira_candidatura', { p_richiesta: miaRichiesta.id }, 'Candidatura ritirata.')
  const rispondiRichiesta = (r, accetta) => esegui('rispondi_richiesta', { p_richiesta: r.id, p_accetta: accetta }, accetta ? `${nomeBreve(r.giocatore)} è in squadra.` : 'Candidatura rifiutata.')
  const aggiungi = () => esegui('aggiungi_posto', { p_partita: id, p_squadra: squadraScelta, p_ruolo: ruoloScelto ?? 'centro' }, 'Posto aggiunto.')

  async function annulla() {
    if (!confirm('Vuoi annullare questa partita? I giocatori la vedranno come annullata.')) return
    const { error } = await supabase.from('partite').update({ stato: 'annullata' }).eq('id', id)
    if (error) { errore = error.message; return }
    await carica()
  }

  async function condividi() {
    const url = `${window.location.origin}/partita/${id}`
    const dati = { title: 'Ne manca 1 · partita di calcetto', text: `${etichettaFormato(partita.formato)} · ${etichettaDataOra(partita.data_ora)} · ${partita.campo.nome}`, url }
    if (navigator.share) { try { await navigator.share(dati) } catch { /* annullato */ } }
    else { await navigator.clipboard.writeText(url); avviso = 'Link copiato.' }
  }

  const ruoliDisponibili = $derived(Object.keys(RUOLI).filter((r) => partita?.formato !== 5 || r !== 'centro'))
</script>

<div class="pagina">
  {#if caricamento}
    <Caricamento />
  {:else if !partita}
    <div class="contenuto spazio-sopra"><div class="errore">{errore}</div><a href="/" class="btn bianco">Torna alla home</a></div>
  {:else}
    <header class="intestazione" style="padding-bottom: 12px">
      <button type="button" class="btn-tondo" aria-label="Torna al campo" onclick={() => indietro(`/campo/${partita.campo_id}`)}>
        <Icona nome="indietro" dimensione={20} spessore={2.4} />
      </button>
      <div class="centro">
        <h1>{etichettaDataOra(partita.data_ora)} · {etichettaFormato(partita.formato)}</h1>
        <a href={`/campo/${partita.campo_id}`} class="sotto" style="text-decoration:none">{partita.campo.nome} · organizza {nomeBreve(partita.organizzatore)}</a>
      </div>
      {#if mioPosto || sonoOrganizzatore}
        <a href={`/chat/${id}`} class="btn-tondo" style="color: var(--verde)" aria-label="Apri la chat della partita"><Icona nome="chat" dimensione={22} /></a>
      {/if}
    </header>

    <div class="contenuto" style="gap:14px; padding-bottom: 16px">
      {#if appenaCreata}
        <div class="ok">Partita creata. Condividi il link o fai inquadrare il QR del campo: gli altri potranno prendere un posto libero. Tocca un posto per cambiare lo schema.</div>
      {/if}
      {#if errore}<div class="errore">{errore}</div>{/if}
      {#if avviso}<div class="ok">{avviso}</div>{/if}

      <div class="chip-riga">
        {#if partita.stato === 'annullata'}
          <span class="chip neutro">Annullata</span>
        {:else if partita.stato === 'giocata'}
          <span class="chip neutro">Giocata</span>
        {:else}
          <span class="chip {chip.classe}">{chip.testo}</span>
        {/if}
        <span class="chip leggero">{numeri.occupati} di {numeri.totale}</span>
        <span class="chip leggero">{euro(partita.quota)}</span>
      </div>

      {#if partita.descrizione}
        <p style="font-size:14px; color: var(--testo-3)">{partita.descrizione}</p>
      {/if}

      {#if mioPosto?.stato === 'cambio_proposto'}
        <div class="card" style="border: 2px solid var(--da-confermare); gap: 10px">
          <div class="nome">L'organizzatore ti propone un cambio di ruolo</div>
          <div class="sotto">Da <strong>{etichettaRuolo(mioPosto.ruolo)}</strong> a <strong>{etichettaRuolo(mioPosto.nuovo_ruolo_proposto)}</strong>. Decidi tu.</div>
          <div style="display:flex; gap:10px">
            <button type="button" class="btn bianco piccolo" disabled={occupato} onclick={() => rispondiCambio(false)}>Rifiuta</button>
            <button type="button" class="btn piccolo" disabled={occupato} onclick={() => rispondiCambio(true)}>Accetta</button>
          </div>
        </div>
      {/if}

      {#if richiesteDaApprovare.length}
        <section class="sezione">
          <div class="sezione-titolo">Da approvare</div>
          {#each richiesteDaApprovare as r (r.id)}
            <div class="card riga">
              <div class="avatar">{iniziali(r.giocatore)}</div>
              <div class="riempi">
                <div class="nome">{nomeBreve(r.giocatore)} vuole entrare</div>
                <div class="sotto">{r.ruolo_richiesto ? etichettaRuolo(r.ruolo_richiesto) : 'Qualsiasi ruolo'}</div>
              </div>
              <button type="button" class="btn-tondo piccolo bordo" aria-label="Rifiuta" disabled={occupato} onclick={() => rispondiRichiesta(r, false)}><Icona nome="x" dimensione={18} spessore={2.2} /></button>
              <button type="button" class="btn-tondo piccolo verde" aria-label="Accetta" disabled={occupato} onclick={() => rispondiRichiesta(r, true)}><Icona nome="spunta" dimensione={18} spessore={2.4} /></button>
            </div>
          {/each}
        </section>
      {/if}

      <CampoDisegnato {posizioni} mioId={uid} alClick={modificabile ? tocca : null} />

      <div class="legenda">
        <div><span class="pallino" style="background: var(--portiere)"></span>Portiere</div>
        <div><span class="pallino tratteggiato"></span>Posto libero</div>
        <div><span class="pallino" style="background: var(--da-confermare)"></span>Da confermare</div>
      </div>

      {#if modificabile && uid && !mioPosto && numeri.liberi > 0}
        <p class="aiuto" style="text-align:center">Tocca un posto libero per sederti, oppure candidati e lascia scegliere all'organizzatore.</p>
      {:else if modificabile && !uid}
        <p class="aiuto" style="text-align:center">Accedi per prendere un posto o candidarti.</p>
      {/if}

      {#if sonoOrganizzatore && modificabile}
        <section class="sezione">
          <div class="sezione-titolo">Sei l'organizzatore</div>
          <div class="card" style="gap: 8px">
            <div class="sotto">Tocca un posto per cambiarne il ruolo, toglierlo o proporre un cambio a chi lo occupa. Il totale ora è {numeri.totale} posti.</div>
            <button type="button" class="btn bianco piccolo" onclick={() => { ruoloScelto = null; squadraScelta = 'A'; foglio = { tipo: 'aggiungi' } }}>
              <Icona nome="piu" dimensione={18} spessore={2.4} /> Aggiungi un posto
            </button>
            <button type="button" class="btn bianco piccolo" style="color: var(--errore)" onclick={annulla}>Annulla la partita</button>
          </div>
        </section>
      {/if}

      <p class="aiuto" style="text-align:center">{partita.campo.indirizzo}</p>
    </div>

    <div class="pie-fisso">
      {#if partita.stato === 'annullata'}
        <div class="btn bianco" style="color: var(--testo-2)">Partita annullata</div>
      {:else if !modificabile}
        <div class="btn bianco" style="color: var(--testo-2)">Iscrizioni chiuse</div>
      {:else if !uid}
        <button type="button" class="btn" onclick={() => naviga(`/login?next=${encodeURIComponent(`/partita/${id}`)}`)}>Accedi per unirti</button>
      {:else if mioPosto}
        <button type="button" class="btn bianco" style="color: var(--verde)" onclick={() => (foglio = { tipo: 'mio-posto', posizione: mioPosto })}>
          <Icona nome="spunta" dimensione={18} spessore={2.4} /> Sei in squadra · {etichettaRuolo(mioPosto.ruolo)}
        </button>
      {:else if miaRichiesta}
        <button type="button" class="btn bianco" disabled={occupato} onclick={ritira}>Candidatura inviata · tocca per ritirarla</button>
      {:else}
        <button type="button" class="btn" onclick={() => { ruoloScelto = null; foglio = { tipo: 'candidati' } }}>
          {numeri.liberi > 0 ? 'Candidati per un ruolo' : 'Al completo · mettiti in lista'}
        </button>
      {/if}
      <button type="button" class="btn bianco quadrato" aria-label="Condividi la partita" onclick={condividi}><Icona nome="condividi" dimensione={20} spessore={2.2} /></button>
    </div>

    <!-- Fogli delle scelte -->
    {#if foglio?.tipo === 'posto-libero'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={`Posto libero · ${etichettaRuolo(p.ruolo)}`} sotto={`Squadra ${p.squadra}`} chiudi={() => (foglio = null)}>
        {#if mioPosto}
          <p class="aiuto">Hai già un posto ({etichettaRuolo(mioPosto.ruolo)}, squadra {mioPosto.squadra}): ti sposti qui e quello si libera.</p>
        {/if}
        <button type="button" class="btn" disabled={occupato} onclick={() => prendi(p)}>{mioPosto ? 'Spostati qui' : `Siediti come ${etichettaRuolo(p.ruolo).toLowerCase()}`}</button>
        {#if sonoOrganizzatore}
          <div class="campo-form" style="margin-top: 6px">
            <span class="aiuto" style="font-weight:600">Cambia il ruolo di questo posto</span>
            <div class="scelte">
              {#each ruoliDisponibili.filter((r) => r !== p.ruolo) as r}
                <button type="button" class="scelta" disabled={occupato} onclick={() => proponi(p, r)}>{RUOLI[r]}</button>
              {/each}
            </div>
          </div>
          <button type="button" class="btn bianco" style="color: var(--errore)" disabled={occupato} onclick={() => rimuovi(p)}>Togli questo posto dallo schema</button>
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'posto-occupato'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={p.giocatore?.nome ?? 'Giocatore'} sotto={`${etichettaRuolo(p.ruolo)} · squadra ${p.squadra}${p.stato === 'cambio_proposto' ? ` · cambio proposto: ${etichettaRuolo(p.nuovo_ruolo_proposto)}` : ''}`} chiudi={() => (foglio = null)}>
        {#if sonoOrganizzatore}
          <div class="campo-form">
            <span class="aiuto" style="font-weight:600">Proponi un cambio di ruolo (deve accettare)</span>
            <div class="scelte">
              {#each ruoliDisponibili.filter((r) => r !== p.ruolo) as r}
                <button type="button" class="scelta" disabled={occupato} onclick={() => proponi(p, r)}>{RUOLI[r]}</button>
              {/each}
            </div>
          </div>
          <button type="button" class="btn bianco" style="color: var(--errore)" disabled={occupato} onclick={() => libera(p)}>Togli dal posto</button>
        {:else}
          <p class="aiuto">Solo l'organizzatore può spostare gli altri giocatori.</p>
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'mio-posto'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={`Il tuo posto · ${etichettaRuolo(p.ruolo)}`} sotto={`Squadra ${p.squadra}. Per spostarti, tocca un altro posto libero sul campo.`} chiudi={() => (foglio = null)}>
        {#if sonoOrganizzatore}
          <div class="campo-form">
            <span class="aiuto" style="font-weight:600">Cambia il tuo ruolo</span>
            <div class="scelte">
              {#each ruoliDisponibili.filter((r) => r !== p.ruolo) as r}
                <button type="button" class="scelta" disabled={occupato} onclick={() => proponi(p, r)}>{RUOLI[r]}</button>
              {/each}
            </div>
          </div>
        {/if}
        <button type="button" class="btn bianco" style="color: var(--errore)" disabled={occupato} onclick={lascia}>Lascia il posto</button>
      </Foglio>
    {:else if foglio?.tipo === 'candidati'}
      <Foglio aperto titolo="Candidati" sotto="L'organizzatore riceve la richiesta e ti assegna un posto." chiudi={() => (foglio = null)}>
        <div class="scelte">
          <button type="button" class="scelta" class:attiva={ruoloScelto === null} onclick={() => (ruoloScelto = null)}>Qualsiasi ruolo</button>
          {#each ruoliDisponibili as r}
            <button type="button" class="scelta" class:attiva={ruoloScelto === r} onclick={() => (ruoloScelto = r)}>{RUOLI[r]}</button>
          {/each}
        </div>
        <button type="button" class="btn" disabled={occupato} onclick={candidati}>Invia candidatura</button>
      </Foglio>
    {:else if foglio?.tipo === 'aggiungi'}
      <Foglio aperto titolo="Aggiungi un posto" sotto="Il posto nasce libero: chiunque potrà sedersi." chiudi={() => (foglio = null)}>
        <span class="aiuto" style="font-weight:600">Squadra</span>
        <div class="scelte">
          <button type="button" class="scelta" class:attiva={squadraScelta === 'A'} onclick={() => (squadraScelta = 'A')}>Squadra A</button>
          <button type="button" class="scelta" class:attiva={squadraScelta === 'B'} onclick={() => (squadraScelta = 'B')}>Squadra B</button>
        </div>
        <span class="aiuto" style="font-weight:600">Ruolo</span>
        <div class="scelte">
          {#each Object.entries(RUOLI) as [r, testo]}
            <button type="button" class="scelta" class:attiva={ruoloScelto === r} onclick={() => (ruoloScelto = r)}>{testo}</button>
          {/each}
        </div>
        <button type="button" class="btn" disabled={occupato || !ruoloScelto} onclick={aggiungi}>Aggiungi</button>
      </Foglio>
    {/if}
  {/if}
</div>
