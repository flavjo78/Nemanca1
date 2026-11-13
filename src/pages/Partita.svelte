<script>
  import { proponiNotifiche } from '../lib/notifiche.svelte.js'
  // Schermata partita: campo disegnato interattivo (tappa 2)
  import { onMount, onDestroy } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { router, indietro, naviga } from '../lib/router.svelte.js'
  import { etichettaDataOra, etichettaFormato, nomeBreve, chipPosti, euro, etichettaRuolo, iniziali, RUOLI } from '../lib/formato.js'
  import { conta, contaRuoli, testoModulo, moduloPerDb, disponi } from '../lib/formazione.js'
  import Contatori from '../components/Contatori.svelte'
  import Icona from '../components/Icona.svelte'
  import CampoDisegnato from '../components/CampoDisegnato.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Foglio from '../components/Foglio.svelte'
  import Divisa from '../components/Divisa.svelte'
  import Avatar from '../components/Avatar.svelte'
  import { COLORI, divisaDi, testoDivisa, testoPorta } from '../lib/divise.js'

  let { id } = $props()
  let partita = $state(null)
  let richieste = $state([])
  let tribuna = $state([])
  let vice = $state([])
  let moduloSquadra = $state('A')
  // selettore del posto a passi: squadra → ruolo → cerchio
  let scelta = $state(null)   // { titolo, sotto, posti: [...], azione: (p) => ..., squadra, ruolo }
  function apriScelta(titolo, sotto, posti, azione) {
    const squadre = [...new Set(posti.map((x) => x.squadra))].sort()
    scelta = { titolo, sotto, posti, azione, squadra: squadre.length === 1 ? squadre[0] : null, ruolo: null }
    foglio = { tipo: 'scegli' }
  }
  const ORDINE_RUOLI = ['portiere', 'difesa', 'centro', 'attacco', 'panchina']
  // etichetta del cerchio: lato del campo (dai cerchi come sono disegnati) o numero di panchina
  function lato(p) {
    if (p.ruolo === 'panchina') {
      const panca = posizioni.filter((x) => x.squadra === p.squadra && x.ruolo === 'panchina')
      return `posto ${panca.findIndex((x) => x.id === p.id) + 1}`
    }
    const fila = posizioni.filter((x) => x.squadra === p.squadra && x.ruolo === p.ruolo)
    if (fila.length === 1) return ''
    const c = coordinateCampo[p.id]?.x ?? 50
    // per la squadra B il campo è visto dall'altra parte, ma "sinistra" resta quella dello schermo
    const nome = c < 40 ? 'a sinistra' : c > 60 ? 'a destra' : 'al centro'
    const uguali = fila.filter((x) => { const cx = coordinateCampo[x.id]?.x ?? 50; return (cx < 40 ? 'a sinistra' : cx > 60 ? 'a destra' : 'al centro') === nome })
      .sort((a, b) => (coordinateCampo[a.id]?.x ?? 50) - (coordinateCampo[b.id]?.x ?? 50))
    return uguali.length > 1 ? `${nome} (${uguali.findIndex((x) => x.id === p.id) + 1})` : nome
  }
  let nuovo = $state({ difesa: 0, centro: 0, attacco: 0 })
  // amici: chiedere l'amicizia a un giocatore e invitare gli amici alla partita
  let amici = $state([])
  let invitaScelti = $state([])
  async function chiediAmicizia(g) {
    errore = ''; avviso = ''
    const { data, error } = await supabase.rpc('chiedi_amicizia', { p_altro: g.id })
    foglio = null
    if (error) { errore = error.message; return }
    avviso = data === 'accettata' ? `Tu e ${g.nome} ora siete amici.` : data === 'gia_amici' ? `${g.nome} è già tra i tuoi amici.` : `Richiesta di amicizia inviata a ${g.nome}.`
  }
  async function apriInvitaAmici() {
    errore = ''
    const { data, error } = await supabase.rpc('miei_amici')
    if (error) { errore = error.message; return }
    amici = (data ?? []).filter((a) => a.stato === 'amico')
    invitaScelti = []
    foglio = { tipo: 'invita-amici' }
  }
  const giaInPartita = (idGiocatore) => posizioni.some((x) => x.giocatore_id === idGiocatore)
  const giaInvitato = (idGiocatore) => inviti.some((x) => x.a_id === idGiocatore && x.stato === 'in_attesa')
  function alternaScelto(idGiocatore) { invitaScelti = invitaScelti.includes(idGiocatore) ? invitaScelti.filter((x) => x !== idGiocatore) : [...invitaScelti, idGiocatore] }
  async function invitaAmici(lista) {
    if (!lista.length) return
    occupato = true; errore = ''; avviso = ''
    const { data, error } = await supabase.rpc('invita_amici', { p_partita: id, p_amici: lista })
    occupato = false
    foglio = null
    if (error) { errore = error.message; return }
    avviso = data ? `Invito mandato a ${data} ${data === 1 ? 'amico' : 'amici'}: riceveranno una notifica.` : 'Nessun nuovo invito da mandare.'
    await carica()
  }

  // "Serve un portiere vicino a te": avviso ai giocatori della zona
  const NOMI_RUOLO = { portiere: 'portiere', difesa: 'difensore', centro: 'centrocampista', attacco: 'attaccante' }
  const PLURALI_RUOLO = { portiere: 'portieri', difesa: 'difensori', centro: 'centrocampisti', attacco: 'attaccanti' }
  const ruoliMancanti = $derived(Object.entries(posizioni.filter((p) => p.stato === 'libera' && p.ruolo !== 'panchina')
    .reduce((acc, p) => { acc[p.ruolo] = (acc[p.ruolo] || 0) + 1; return acc }, {})))
  let ruoloCercato = $state('qualsiasi')
  async function cercaChiManca() {
    occupato = true; errore = ''; avviso = ''
    const { data, error } = await supabase.rpc('cerca_chi_manca', { p_partita: id, p_ruolo: ruoloCercato })
    occupato = false
    foglio = null
    if (error) { errore = error.message; return }
    avviso = data > 0
      ? `Avviso mandato a ${data} ${data === 1 ? 'giocatore vicino' : 'giocatori vicini'}: il primo che entra prende il posto.`
      : 'In questo momento non ci sono giocatori disponibili in zona. Prova a invitare i tuoi amici.'
  }

  // divise
  let divisaSquadra = $state('A')
  let divisaNuova = $state({ maglia: 'bianco', pantaloncini: 'nero' })
  function apriDivise(sq) { divisaSquadra = sq; divisaNuova = { ...divisaDi(partita, sq) }; foglio = { tipo: 'divise' } }
  const salvaDivisa = () => esegui('imposta_divisa', { p_partita: id, p_squadra: divisaSquadra, p_maglia: divisaNuova.maglia, p_pantaloncini: divisaNuova.pantaloncini },
    `Squadra ${divisaSquadra}: ${testoDivisa(divisaNuova)}.`)
  function apriModulo(sq) { moduloSquadra = sq; nuovo = contaRuoli(posizioni, sq); foglio = { tipo: 'modulo' } }
  let inviti = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let avviso = $state('')
  let occupato = $state(false)
  let foglio = $state(null)          // { tipo, posizione }
  let ruoloScelto = $state(null)
  let squadraScelta = $state('A')
  let squadraPreferita = $state(null)
  let canale = null
  let timerRicarica = null

  const appenaCreata = $derived(router.query.get('nuova') === '1')
  const uid = $derived(auth.utente?.id ?? null)
  const posizioni = $derived(partita?.posizioni ?? [])
  const numeri = $derived(conta(posizioni))
  const chip = $derived(chipPosti(posizioni))
  const sonoTitolare = $derived(!!uid && partita?.organizzatore_id === uid)
  const miaViceSquadra = $derived(vice.find((v) => v.giocatore_id === uid)?.squadra ?? null)
  // chi gestisce la formazione: organizzatore (entrambe le squadre) o vice (solo la sua)
  const sonoOrganizzatore = $derived(sonoTitolare || !!miaViceSquadra)
  const gestisco = (squadra) => sonoTitolare || miaViceSquadra === squadra
  const eVice = (giocatoreId) => vice.some((v) => v.giocatore_id === giocatoreId)
  const viceDi = (giocatoreId) => vice.find((v) => v.giocatore_id === giocatoreId)?.squadra ?? null
  const mioPosto = $derived(posizioni.find((p) => p.giocatore_id === uid) ?? null)
  const miaRichiesta = $derived(richieste.find((r) => r.giocatore_id === uid) ?? null)
  const sonoInTribuna = $derived(!!uid && tribuna.some((t) => t.giocatore_id === uid))
  const mioInvito = $derived(inviti.find((i) => i.a_id === uid) ?? null)
  const approvazione = $derived(partita?.modalita === 'approvazione')
  // persone a cui l'organizzatore può chiedere di giocare: tribuna + candidati, non già in campo
  const disponibili = $derived.by(() => {
    const visti = new Map()
    for (const t of tribuna) visti.set(t.giocatore_id, { id: t.giocatore_id, profilo: t.giocatore, dove: 'tribuna' })
    for (const r of richieste) visti.set(r.giocatore_id, { id: r.giocatore_id, profilo: r.giocatore, dove: r.ruolo_richiesto ? `candidato ${etichettaRuolo(r.ruolo_richiesto).toLowerCase()}` : 'candidato' })
    return [...visti.values()].filter((x) => !posizioni.some((p) => p.giocatore_id === x.id))
  })
  const invitoPer = (giocatoreId) => inviti.find((i) => i.a_id === giocatoreId) ?? null
  const richiesteDaApprovare = $derived(sonoOrganizzatore ? richieste : [])
  const modificabile = $derived(partita && ['aperta', 'completa'].includes(partita.stato) && new Date(partita.data_ora) > new Date(Date.now() - 3600 * 1000))

  onMount(async () => {
    await carica()
    caricamento = false
    canale = supabase.channel(`partita-${id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posizioni', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'richieste', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'partite', filter: `id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tribuna', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'inviti', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'vice', filter: `partita_id=eq.${id}` }, pianificaRicarica)
      .subscribe()
  })
  onDestroy(() => { if (canale) supabase.removeChannel(canale); clearTimeout(timerRicarica) })

  function pianificaRicarica() { clearTimeout(timerRicarica); timerRicarica = setTimeout(carica, 150) }

  async function carica() {
    const { data, error } = await supabase
      .from('partite')
      .select('*, campo:campi(id, nome, indirizzo), organizzatore:profili!partite_organizzatore_id_fkey(id, nome, iniziali), posizioni(*, giocatore:profili(id, nome, iniziali, foto_url))')
      .eq('id', id).maybeSingle()
    if (error || !data) { errore = 'Partita non trovata.'; return }
    data.posizioni.sort((a, b) => a.squadra.localeCompare(b.squadra) || a.y - b.y || a.x - b.x || a.creato_il.localeCompare(b.creato_il))
    partita = data
    const { data: v } = await supabase.from('vice').select('giocatore_id, squadra').eq('partita_id', id)
    vice = v ?? []
    if (uid) {
      const [{ data: r }, { data: t }, { data: inv }] = await Promise.all([
        supabase.from('richieste').select('*, giocatore:profili(id, nome, iniziali, foto_url)')
          .eq('partita_id', id).eq('stato', 'in_attesa').order('creato_il'),
        supabase.from('tribuna').select('*, giocatore:profili(id, nome, iniziali, foto_url)').eq('partita_id', id).order('creato_il'),
        supabase.from('inviti').select('*, posizione:posizioni(id, ruolo, squadra, stato)').eq('partita_id', id).eq('stato', 'in_attesa')
      ])
      richieste = r ?? []
      tribuna = t ?? []
      inviti = inv ?? []
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

  const prendi = (p) => esegui('prendi_posto', { p_posizione: p.id }, mioPosto ? 'Ti sei spostato.' : 'Sei in squadra!').then((ok) => { if (ok) proponiNotifiche({ forza: true }) })
  const lascia = () => esegui('lascia_posto', { p_partita: id }, 'Hai lasciato il posto.')
  const libera = (p) => esegui('libera_posto', { p_posizione: p.id }, 'Posto liberato.')
  const rimuovi = (p) => esegui('rimuovi_posto', { p_posizione: p.id }, 'Posto tolto dallo schema.')
  const proponi = (p, ruolo) => esegui('proponi_cambio', { p_posizione: p.id, p_nuovo_ruolo: ruolo }, p.giocatore_id ? 'Proposta inviata: il giocatore deve accettare.' : 'Ruolo cambiato.')
  const rispondiCambio = (accetta) => esegui('rispondi_cambio', { p_posizione: mioPosto.id, p_accetta: accetta }, accetta ? 'Ruolo aggiornato.' : 'Hai rifiutato il cambio.')
  const candidati = () => esegui('candidati', { p_partita: id, p_ruolo: ruoloScelto, p_squadra: squadraPreferita }, 'Candidatura inviata: l\'organizzatore riceve la richiesta.').then((ok) => { if (ok) proponiNotifiche({ forza: true }) })
  const ritira = () => esegui('ritira_candidatura', { p_richiesta: miaRichiesta.id }, 'Candidatura ritirata.')
  const rispondiRichiesta = (r, accetta) => esegui('rispondi_richiesta', { p_richiesta: r.id, p_accetta: accetta }, accetta ? `${nomeBreve(r.giocatore)} è in squadra.` : 'Candidatura rifiutata.')
  const aggiungi = () => esegui('aggiungi_posto', { p_partita: id, p_squadra: squadraScelta, p_ruolo: ruoloScelto ?? 'centro' }, 'Posto aggiunto.')
  const entraTribuna = () => esegui('entra_tribuna', { p_partita: id }, 'Sei in tribuna: segui la partita e la chat.')
  const esciTribuna = () => esegui('esci_tribuna', { p_partita: id }, 'Sei uscito dalla tribuna.')
  const chiedi = (p, giocatoreId) => esegui('chiedi_di_giocare', { p_posizione: p.id, p_giocatore: giocatoreId }, 'Richiesta inviata: deve accettare.')
  const rispondiInvito = (accetta) => esegui('rispondi_invito', { p_partita: id, p_accetta: accetta }, accetta ? 'Sei in campo!' : 'Resti in tribuna.')
  // trascinamento: alla prima volta fisso anche gli altri posti della squadra dove sono, così non si rimescolano
  async function trascina(p, x, y) {
    errore = ''; avviso = ''
    const fissi = disponi(posizioni)
    const daFissare = Object.fromEntries(posizioni.filter((q) => q.squadra === p.squadra && q.ruolo !== 'panchina' && !q.manuale && q.id !== p.id).map((q) => [q.id, fissi[q.id]]))
    if (Object.keys(daFissare).length) {
      const { error } = await supabase.rpc('fissa_posti', { p_partita: id, p_squadra: p.squadra, p_coordinate: daFissare })
      if (error) { errore = pulisci(error.message); return }
    }
    await esegui('trascina_posto', { p_posizione: p.id, p_x: x, p_y: y })
  }
  const sposta = (da, a) => esegui('sposta_giocatore', { p_da: da.id, p_a: a.id }, a.giocatore_id ? 'Posti scambiati.' : 'Giocatore spostato.')
  const cambiaModulo = (squadra, m) => esegui('cambia_modulo', { p_partita: id, p_squadra: squadra, p_modulo: moduloPerDb(m) }, `Squadra ${squadra}: modulo ${testoModulo(m)}.`)
  const nominaVice = (giocatoreId, squadra, si) => esegui('nomina_vice', { p_partita: id, p_giocatore: giocatoreId, p_squadra: squadra, p_si: si }, si ? `Ora è vice della squadra ${squadra}.` : 'Non è più vice.')
  let copiato = $state(false)
  async function copiaLink() {
    const url = `${window.location.origin}/partita/${id}`
    try { await navigator.clipboard.writeText(url) } catch {
      const t = document.createElement('textarea'); t.value = url; document.body.appendChild(t); t.select(); document.execCommand('copy'); t.remove()
    }
    copiato = true; setTimeout(() => (copiato = false), 2500)
  }
  const altriPosti = (p) => posizioni.filter((x) => x.id !== p.id && gestisco(x.squadra)).sort((a, b) => (a.ruolo === 'panchina') - (b.ruolo === 'panchina') || a.squadra.localeCompare(b.squadra) || (a.giocatore_id ? 1 : 0) - (b.giocatore_id ? 1 : 0))
  const coordinateCampo = $derived(disponi(posizioni))
  const postiLiberi = $derived(posizioni.filter((p) => p.stato === 'libera').sort((a, b) => (a.ruolo === 'panchina') - (b.ruolo === 'panchina') || a.squadra.localeCompare(b.squadra)))

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
  const ruoliCambio = $derived([...ruoliDisponibili, 'panchina'])
  const haPanchina = $derived(posizioni.some((p) => p.ruolo === 'panchina'))
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
      {#if mioPosto || sonoOrganizzatore || sonoInTribuna}
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
        {:else if partita.archiviata}
          <span class="chip neutro">In archivio</span>
        {:else if partita.stato === 'giocata' || !modificabile}
          <span class="chip neutro">Giocata</span>
        {:else}
          <span class="chip {chip.classe}">{chip.testo}</span>
        {/if}
        <span class="chip leggero">{numeri.occupati} di {numeri.totale}</span>
        <span class="chip leggero">{euro(partita.quota)}</span>
        {#if numeri.panchinaTotale}<span class="chip leggero">Panchina {numeri.panchinaTotale - numeri.panchinaLiberi}/{numeri.panchinaTotale}</span>{/if}
        {#if approvazione}<span class="chip leggero">Posti assegnati dall'organizzatore</span>{/if}
      </div>

      {#if partita.descrizione}
        <p style="font-size:14px; color: var(--testo-3)">{partita.descrizione}</p>
      {/if}

      {#if mioInvito && !mioPosto}
        <div class="card" style="border: 2px solid var(--portiere); gap: 10px">
          <div class="nome">L'organizzatore ti chiede di giocare</div>
          <div class="sotto">{mioInvito.posizione ? `Come ${etichettaRuolo(mioInvito.posizione.ruolo).toLowerCase()}, squadra ${mioInvito.posizione.squadra}.` : 'Ti ha riservato un posto.'} Ci stai?</div>
          <div style="display:flex; gap:10px">
            <button type="button" class="btn bianco piccolo" disabled={occupato} onclick={() => rispondiInvito(false)}>Resto in tribuna</button>
            <button type="button" class="btn piccolo" disabled={occupato} onclick={() => rispondiInvito(true)}>Scendo in campo</button>
          </div>
        </div>
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
                <div class="sotto">{r.ruolo_richiesto ? etichettaRuolo(r.ruolo_richiesto) : 'Qualsiasi ruolo'} · {r.squadra_preferita ? `squadra ${r.squadra_preferita}` : 'qualsiasi squadra'}</div>
              </div>
              <button type="button" class="btn-tondo piccolo bordo" aria-label="Rifiuta" disabled={occupato} onclick={() => rispondiRichiesta(r, false)}><Icona nome="x" dimensione={18} spessore={2.2} /></button>
              <button type="button" class="btn-tondo piccolo verde" aria-label="Accetta" disabled={occupato} onclick={() => rispondiRichiesta(r, true)}><Icona nome="spunta" dimensione={18} spessore={2.4} /></button>
            </div>
          {/each}
        </section>
      {/if}

      <CampoDisegnato {posizioni} mioId={uid} alClick={modificabile ? tocca : null} divise={{ A: divisaDi(partita, 'A'), B: divisaDi(partita, 'B') }}
        trascinabile={modificabile ? (p) => gestisco(p.squadra) : null} alTrascina={trascina} />
      {#if mioPosto && partita.stato !== 'annullata'}
        {@const miaDivisa = divisaDi(partita, mioPosto.squadra)}
        <div class="card riga promemoria-divisa">
          <Divisa maglia={miaDivisa.maglia} pantaloncini={miaDivisa.pantaloncini} dimensione={30} />
          <div class="riempi"><div class="nome">{testoPorta(miaDivisa)}</div><div class="sotto">Divisa della squadra {mioPosto.squadra}</div></div>
        </div>
        {#if modificabile && !sonoTitolare}
          <button type="button" class="btn bianco" onclick={apriInvitaAmici}><Icona nome="utenti" dimensione={18} /> Invita amici a questa partita</button>
        {/if}
      {/if}
      {#if modificabile && (mioPosto || sonoOrganizzatore || sonoInTribuna) && ruoliMancanti.length}
        <button type="button" class="btn tratteggiato" onclick={() => { ruoloCercato = ruoliMancanti.length === 1 ? ruoliMancanti[0][0] : 'qualsiasi'; foglio = { tipo: 'cerca' } }}>
          <Icona nome="cerca" dimensione={18} /> Cerca chi manca tra i giocatori vicini
        </button>
      {/if}
      {#if modificabile && sonoOrganizzatore}
        <p class="aiuto" style="text-align:center">Tieni premuto un cerchio e trascinalo: vicino alla porta è difesa, in mezzo centrocampo, avanti attacco. Il modulo si aggiorna da solo.</p>
      {/if}

      <div class="legenda">
        <div><span class="pallino" style="background: var(--portiere)"></span>Portiere</div>
        <div><span class="pallino tratteggiato"></span>Posto libero</div>
        <div><span class="pallino" style="background: var(--da-confermare)"></span>Da confermare</div>
      </div>

      {#if modificabile && uid && !mioPosto && approvazione && !sonoOrganizzatore}
        <p class="aiuto" style="text-align:center">In questa partita i posti li assegna l'organizzatore: candidati o entra in tribuna.</p>
      {:else if modificabile && uid && !mioPosto && numeri.liberi > 0}
        <p class="aiuto" style="text-align:center">Tocca un posto libero per sederti, oppure candidati e lascia scegliere all'organizzatore.</p>
      {:else if modificabile && !uid}
        <p class="aiuto" style="text-align:center">Accedi per prendere un posto o candidarti.</p>
      {/if}

      {#if partita.stato !== 'annullata'}
        <section class="sezione">
          <div class="sezione-titolo">
            <span>Tribuna · {tribuna.length}</span>
            {#if uid && !mioPosto && !sonoOrganizzatore}
              {#if sonoInTribuna}
                <button type="button" class="chip" style="border:none" disabled={occupato} onclick={esciTribuna}>Esci dalla tribuna</button>
              {:else}
                <button type="button" class="chip bianco-su-verde" style="border:none" disabled={occupato} onclick={entraTribuna}>Entra in tribuna</button>
              {/if}
            {/if}
          </div>
          {#if tribuna.length}
            <div class="chip-riga">
              {#each tribuna as t (t.giocatore_id)}
                {#if sonoOrganizzatore && modificabile}
                  <button type="button" class="chip" style="border: 1px solid var(--bordo); min-height: 36px" onclick={() => apriScelta(t.giocatore?.nome ?? 'Giocatore', 'È in tribuna. Scegli il posto che gli proponi: deve accettare.', postiLiberi.filter((x) => gestisco(x.squadra)), (x) => chiedi(x, t.giocatore_id))}>
                    <span class="avatar mini" style="width:22px;height:22px;font-size:9px;border-width:1px">{iniziali(t.giocatore)}</span>
                    {nomeBreve(t.giocatore)}{invitoPer(t.giocatore_id) ? ' · invitato' : ''}
                  </button>
                {:else}
                  <span class="chip"><span class="avatar mini" style="width:22px;height:22px;font-size:9px;border-width:1px">{iniziali(t.giocatore)}</span>{t.giocatore_id === uid ? 'Tu' : nomeBreve(t.giocatore)}</span>
                {/if}
              {/each}
            </div>
            {#if sonoOrganizzatore && modificabile}<p class="aiuto">Tocca un nome per chiedergli di giocare.</p>{/if}
          {:else}
            <p class="aiuto">{uid ? 'Nessuno in tribuna. Chi entra qui segue la partita e la chat senza giocare.' : 'Accedi per seguire la partita dalla tribuna.'}</p>
          {/if}
        </section>
      {/if}

      {#if sonoOrganizzatore && modificabile}
        <section class="sezione">
          <div class="sezione-titolo">{sonoTitolare ? "Sei l'organizzatore" : `Sei vice · squadra ${miaViceSquadra}`}</div>
          <div class="card" style="gap: 8px">
            <div class="sotto">Tocca un posto per cambiarne il ruolo o spostare chi lo occupa. In campo restano sempre {partita.formato} per squadra.</div>
            {#if sonoTitolare}
              <button type="button" class="btn piccolo" onclick={apriInvitaAmici}><Icona nome="utenti" dimensione={18} /> Invita amici</button>
            {/if}
            <button type="button" class="btn bianco piccolo" onclick={() => apriModulo(sonoTitolare ? 'A' : miaViceSquadra)}>Cambia modulo</button>
            <button type="button" class="btn bianco piccolo" onclick={() => apriDivise(sonoTitolare ? 'A' : miaViceSquadra)}>
              <Divisa maglia={divisaDi(partita, sonoTitolare ? 'A' : miaViceSquadra).maglia} pantaloncini={divisaDi(partita, sonoTitolare ? 'A' : miaViceSquadra).pantaloncini} dimensione={18} /> Colori delle divise
            </button>
            <button type="button" class="btn bianco piccolo" onclick={() => { ruoloScelto = 'panchina'; squadraScelta = sonoTitolare ? 'A' : miaViceSquadra; foglio = { tipo: 'aggiungi' } }}>
              <Icona nome="piu" dimensione={18} spessore={2.4} /> Aggiungi una riserva in panchina
            </button>
            {#if sonoTitolare}
              <p class="aiuto">Tocca un giocatore per spostarlo o per dargli il permesso di gestire la formazione.</p>
              <button type="button" class="btn bianco piccolo" style="color: var(--errore)" onclick={annulla}>Annulla la partita</button>
            {:else}
              <p class="aiuto">Sei vice della squadra {miaViceSquadra}: gestisci modulo e posizioni solo lì.</p>
            {/if}
          </div>
        </section>
      {/if}

      <p class="aiuto" style="text-align:center">{partita.campo.indirizzo}</p>
    </div>

    <div class="pie-fisso">
      {#if partita.stato === 'annullata'}
        <div class="btn bianco" style="color: var(--testo-2)">Partita annullata</div>
      {:else if !modificabile}
        <div class="btn bianco" style="color: var(--testo-2)">{partita.archiviata ? 'Partita in archivio' : 'Partita giocata'}</div>
      {:else if !uid}
        <button type="button" class="btn" onclick={() => naviga(`/login?next=${encodeURIComponent(`/partita/${id}`)}`)}>Accedi per unirti</button>
      {:else if mioPosto}
        <button type="button" class="btn bianco" style="color: var(--verde)" onclick={() => (foglio = { tipo: 'mio-posto', posizione: mioPosto })}>
          <Icona nome="spunta" dimensione={18} spessore={2.4} /> Sei in squadra · {etichettaRuolo(mioPosto.ruolo)}
        </button>
      {:else if mioInvito}
        <button type="button" class="btn" disabled={occupato} onclick={() => rispondiInvito(true)}>Scendo in campo</button>
      {:else if miaRichiesta}
        <button type="button" class="btn bianco" disabled={occupato} onclick={ritira}>Candidatura inviata · tocca per ritirarla</button>
      {:else}
        <button type="button" class="btn" onclick={() => { ruoloScelto = null; squadraPreferita = null; foglio = { tipo: 'candidati' } }}>
          {numeri.liberi > 0 ? 'Candidati per un ruolo' : 'Al completo · mettiti in lista'}
        </button>
      {/if}
      <button type="button" class="btn bianco quadrato" aria-label="Copia il link della partita" onclick={copiaLink}>
        {#if copiato}<Icona nome="spunta" dimensione={20} spessore={2.4} />{:else}<Icona nome="link" dimensione={20} spessore={2.2} />{/if}
      </button>
      <button type="button" class="btn bianco quadrato" aria-label="Condividi la partita" onclick={condividi}><Icona nome="condividi" dimensione={20} spessore={2.2} /></button>
    </div>
    {#if copiato}<div class="toast">Link copiato: incollalo dove vuoi</div>{/if}

    <!-- Fogli delle scelte -->
    {#if foglio?.tipo === 'posto-libero'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={`Posto libero · ${etichettaRuolo(p.ruolo)}`} sotto={`Squadra ${p.squadra}`} chiudi={() => (foglio = null)}>
        {#if mioPosto}
          <p class="aiuto">Hai già un posto ({etichettaRuolo(mioPosto.ruolo)}, squadra {mioPosto.squadra}): ti sposti qui e quello si libera.</p>
        {/if}
        {#if approvazione && !sonoOrganizzatore}
          <p class="aiuto">In questa partita i posti li assegna l'organizzatore.</p>
          {#if !miaRichiesta}
            <button type="button" class="btn" disabled={occupato} onclick={() => { ruoloScelto = p.ruolo; squadraPreferita = p.squadra; candidati() }}>Candidati come {etichettaRuolo(p.ruolo).toLowerCase()}</button>
          {/if}
          {#if !sonoInTribuna}
            <button type="button" class="btn bianco" disabled={occupato} onclick={entraTribuna}>Entra in tribuna</button>
          {/if}
        {:else}
          <button type="button" class="btn" disabled={occupato} onclick={() => prendi(p)}>{mioPosto ? 'Spostati qui' : 'Posizionati qui'}</button>
        {/if}
        {#if gestisco(p.squadra) && disponibili.length}
          <div class="campo-form" style="margin-top: 6px">
            <span class="aiuto" style="font-weight:600">Chiedi a qualcuno di giocare qui</span>
            {#each disponibili as d (d.id)}
              <button type="button" class="btn bianco piccolo" style="justify-content:flex-start" disabled={occupato} onclick={() => chiedi(p, d.id)}>
                <span class="avatar mini" style="width:26px;height:26px">{iniziali(d.profilo)}</span>
                {nomeBreve(d.profilo)} <span class="aiuto">· {d.dove}{invitoPer(d.id) ? ' · già invitato' : ''}</span>
              </button>
            {/each}
          </div>
        {/if}
        {#if gestisco(p.squadra)}
          <div class="campo-form" style="margin-top: 6px">
            <span class="aiuto" style="font-weight:600">Cambia il ruolo di questo posto</span>
            <div class="scelte">
              {#each ruoliCambio.filter((r) => r !== p.ruolo) as r}
                <button type="button" class="scelta" disabled={occupato} onclick={() => proponi(p, r)}>{etichettaRuolo(r)}</button>
              {/each}
            </div>
          </div>
          {#if p.ruolo === 'panchina'}
            <button type="button" class="btn bianco" style="color: var(--errore)" disabled={occupato} onclick={() => rimuovi(p)}>Togli questo posto dalla panchina</button>
          {/if}
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'posto-occupato'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={p.giocatore?.nome ?? 'Giocatore'} sotto={`${etichettaRuolo(p.ruolo)} · squadra ${p.squadra}${p.giocatore_id === partita.organizzatore_id ? ' · organizzatore' : viceDi(p.giocatore_id) ? ` · vice squadra ${viceDi(p.giocatore_id)}` : ''}${p.stato === 'cambio_proposto' ? ` · cambio proposto: ${etichettaRuolo(p.nuovo_ruolo_proposto)}` : ''}`} chiudi={() => (foglio = null)}>
        {#if gestisco(p.squadra)}
          <button type="button" class="btn" disabled={occupato} onclick={() => apriScelta(`Sposta ${p.giocatore?.nome ?? 'il giocatore'}`, 'Il giocatore va sul cerchio che scegli; se è occupato, i due si scambiano.', altriPosti(p), (a) => sposta(p, a))}>Sposta in un altro posto</button>
          <div class="campo-form">
            <span class="aiuto" style="font-weight:600">{approvazione ? 'Cambia ruolo' : 'Proponi un cambio di ruolo (deve accettare)'}</span>
            <div class="scelte">
              {#each ruoliCambio.filter((r) => r !== p.ruolo) as r}
                <button type="button" class="scelta" disabled={occupato} onclick={() => proponi(p, r)}>{etichettaRuolo(r)}</button>
              {/each}
            </div>
          </div>
          {#if sonoTitolare && p.giocatore_id !== uid}
            {#if eVice(p.giocatore_id)}
              <button type="button" class="btn bianco" disabled={occupato} onclick={() => nominaVice(p.giocatore_id, p.squadra, false)}>Togli il ruolo di vice</button>
            {:else}
              <button type="button" class="btn bianco" disabled={occupato} onclick={() => nominaVice(p.giocatore_id, p.squadra, true)}>Nomina vice della squadra {p.squadra}</button>
            {/if}
          {/if}
          <button type="button" class="btn bianco" style="color: var(--errore)" disabled={occupato} onclick={() => libera(p)}>Manda in tribuna</button>
        {:else}
          <p class="aiuto">{sonoOrganizzatore ? `Gestisci solo la squadra ${miaViceSquadra}.` : 'Solo chi organizza la partita può spostare gli altri giocatori.'}</p>
        {/if}
        {#if uid && p.giocatore_id && p.giocatore_id !== uid}
          <button type="button" class="btn bianco" disabled={occupato} onclick={() => chiediAmicizia(p.giocatore)}>Aggiungi agli amici</button>
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'mio-posto'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={`Il tuo posto · ${etichettaRuolo(p.ruolo)}`} sotto={`Squadra ${p.squadra}. Per spostarti, tocca un altro posto libero sul campo.`} chiudi={() => (foglio = null)}>
        {#if sonoOrganizzatore}
          <button type="button" class="btn" disabled={occupato} onclick={() => apriScelta('Sposta te', 'Vai sul cerchio che scegli; se è occupato, vi scambiate.', altriPosti(p), (a) => sposta(p, a))}>Sposta o scambia con un altro</button>
          <div class="campo-form">
            <span class="aiuto" style="font-weight:600">Cambia il tuo ruolo</span>
            <div class="scelte">
              {#each ruoliCambio.filter((r) => r !== p.ruolo) as r}
                <button type="button" class="scelta" disabled={occupato} onclick={() => proponi(p, r)}>{etichettaRuolo(r)}</button>
              {/each}
            </div>
          </div>
        {/if}
        <button type="button" class="btn bianco" style="color: var(--errore)" disabled={occupato} onclick={lascia}>Lascia il posto</button>
      </Foglio>
    {:else if foglio?.tipo === 'candidati'}
      <Foglio aperto titolo="Candidati" sotto="L'organizzatore riceve la richiesta e ti assegna un posto." chiudi={() => (foglio = null)}>
        <span class="aiuto" style="font-weight:600">Squadra</span>
        <div class="scelte">
          <button type="button" class="scelta" class:attiva={squadraPreferita === null} onclick={() => (squadraPreferita = null)}>Qualsiasi</button>
          <button type="button" class="scelta" class:attiva={squadraPreferita === 'A'} onclick={() => (squadraPreferita = 'A')}>Squadra A</button>
          <button type="button" class="scelta" class:attiva={squadraPreferita === 'B'} onclick={() => (squadraPreferita = 'B')}>Squadra B</button>
        </div>
        <span class="aiuto" style="font-weight:600">Ruolo</span>
        <div class="scelte">
          <button type="button" class="scelta" class:attiva={ruoloScelto === null} onclick={() => (ruoloScelto = null)}>Qualsiasi ruolo</button>
          {#each (haPanchina ? ruoliCambio : ruoliDisponibili) as r}
            <button type="button" class="scelta" class:attiva={ruoloScelto === r} onclick={() => (ruoloScelto = r)}>{etichettaRuolo(r)}</button>
          {/each}
        </div>
        <button type="button" class="btn" disabled={occupato} onclick={candidati}>Invia candidatura</button>
        {#if !sonoInTribuna}
          <button type="button" class="btn bianco" disabled={occupato} onclick={entraTribuna}>Solo tribuna: seguo e sto in chat</button>
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'aggiungi'}
      <Foglio aperto titolo="Aggiungi una riserva" sotto={`In campo restano sempre ${partita.formato} per squadra: in più si aggiungono solo riserve in panchina.`} chiudi={() => (foglio = null)}>
        <span class="aiuto" style="font-weight:600">Squadra</span>
        <div class="scelte">
          {#each ['A', 'B'].filter(gestisco) as sq}
            <button type="button" class="scelta" class:attiva={squadraScelta === sq} onclick={() => (squadraScelta = sq)}>Squadra {sq}</button>
          {/each}
        </div>
        <button type="button" class="btn" disabled={occupato} onclick={aggiungi}>Aggiungi in panchina</button>
      </Foglio>
    {:else if foglio?.tipo === 'scegli' && scelta}
      {@const squadre = [...new Set(scelta.posti.map((x) => x.squadra))].sort()}
      {@const ruoli = ORDINE_RUOLI.filter((r) => scelta.posti.some((x) => x.squadra === scelta.squadra && x.ruolo === r))}
      {@const cerchi = scelta.posti.filter((x) => x.squadra === scelta.squadra && x.ruolo === scelta.ruolo).sort((a, b) => (coordinateCampo[a.id]?.x ?? 0) - (coordinateCampo[b.id]?.x ?? 0))}
      <Foglio aperto titolo={scelta.titolo} sotto={scelta.sotto} chiudi={() => { foglio = null; scelta = null }}>
        {#if !scelta.posti.length}
          <p class="aiuto">Non ci sono posti disponibili. Aggiungi un posto allo schema e riprova.</p>
        {:else}
          {#if squadre.length > 1}
            <span class="aiuto" style="font-weight:600">1. Squadra</span>
            <div class="scelte">
              {#each squadre as sq}
                <button type="button" class="scelta" class:attiva={scelta.squadra === sq} onclick={() => { scelta.squadra = sq; scelta.ruolo = null }}>Squadra {sq}</button>
              {/each}
            </div>
          {/if}
          {#if scelta.squadra}
            <span class="aiuto" style="font-weight:600">{squadre.length > 1 ? '2. ' : '1. '}Ruolo</span>
            <div class="scelte">
              {#each ruoli as r}
                {@const n = scelta.posti.filter((x) => x.squadra === scelta.squadra && x.ruolo === r).length}
                <button type="button" class="scelta" class:attiva={scelta.ruolo === r} onclick={() => (scelta.ruolo = r)}>{etichettaRuolo(r)}{n > 1 ? ` · ${n}` : ''}</button>
              {/each}
            </div>
          {/if}
          {#if scelta.ruolo}
            <span class="aiuto" style="font-weight:600">{squadre.length > 1 ? '3. ' : '2. '}{cerchi.length > 1 ? 'Quale posto' : 'Conferma'}</span>
            {#each cerchi as c (c.id)}
              <button type="button" class="btn bianco piccolo" style="justify-content:flex-start" disabled={occupato} onclick={() => { const a = scelta.azione; scelta = null; a(c) }}>
                {etichettaRuolo(c.ruolo)} {lato(c)}
                <span class="aiuto">· {c.giocatore_id ? `scambio con ${c.giocatore_id === uid ? 'te' : nomeBreve(c.giocatore)}` : 'libero'}</span>
              </button>
            {/each}
          {/if}
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'sposta'}
      {@const p = foglio.posizione}
      <Foglio aperto titolo={`Sposta ${p.giocatore_id === uid ? 'te' : (p.giocatore?.nome ?? 'il giocatore')}`} sotto="Su un posto libero si sposta; su un posto occupato i due si scambiano." chiudi={() => (foglio = null)}>
        {#each altriPosti(p) as a (a.id)}
          <button type="button" class="btn bianco piccolo" style="justify-content:flex-start" disabled={occupato} onclick={() => sposta(p, a)}>
            {etichettaRuolo(a.ruolo)} · squadra {a.squadra}
            <span class="aiuto">· {a.giocatore_id ? `scambia con ${a.giocatore_id === uid ? 'te' : nomeBreve(a.giocatore)}` : 'libero'}</span>
          </button>
        {/each}
      </Foglio>
    {:else if foglio?.tipo === 'cerca'}
      <Foglio aperto titolo="Cerca chi manca" sotto="Avvisiamo con una notifica i giocatori vicini al campo che hanno acceso &quot;Cercami&quot;, secondo i km e gli orari che hanno scelto." chiudi={() => (foglio = null)}>
        <div class="scelte">
          {#each ruoliMancanti as [ruolo, n]}
            <button type="button" class="scelta" class:attiva={ruoloCercato === ruolo} onclick={() => (ruoloCercato = ruolo)}>{n > 1 ? `${n} ${PLURALI_RUOLO[ruolo]}` : `Un ${NOMI_RUOLO[ruolo]}`}</button>
          {/each}
          {#if ruoliMancanti.length > 1}
            <button type="button" class="scelta" class:attiva={ruoloCercato === 'qualsiasi'} onclick={() => (ruoloCercato = 'qualsiasi')}>Qualsiasi ruolo</button>
          {/if}
        </div>
        <p class="aiuto">Ogni giocatore riceve al massimo un avviso per partita; per lo stesso ruolo si può riprovare dopo 2 ore.</p>
        <button type="button" class="btn" disabled={occupato} onclick={cercaChiManca}>Avvisa i giocatori vicini</button>
      </Foglio>
    {:else if foglio?.tipo === 'invita-amici'}
      {@const invitabili = amici.filter((a) => !giaInPartita(a.id))}
      <Foglio aperto titolo="Invita amici" sotto={approvazione && !sonoTitolare ? "Ricevono una notifica; se accettano, l'organizzatore decide se farli giocare." : "Ricevono una notifica; chi accetta va nel primo posto libero adatto ai suoi ruoli."} chiudi={() => (foglio = null)}>
        {#if !amici.length}
          <p class="aiuto">Non hai ancora amici. Aggiungili dalla pagina <a href="/amici">Amici</a> (Profilo → Amici) o toccando un giocatore sul campo.</p>
        {:else}
          <div class="elenco-amici">
            {#each amici as a (a.id)}
              {@const dentro = giaInPartita(a.id)}
              <label class="card riga" class:spento={dentro}>
                <input type="checkbox" checked={invitaScelti.includes(a.id)} disabled={dentro} onchange={() => alternaScelto(a.id)} style="width:22px; height:22px; accent-color: var(--verde)" />
                <Avatar profilo={a} dimensione={36} />
                <div class="riempi"><div class="nome taglia">{a.nome}</div><div class="sotto taglia">{dentro ? 'Già in partita' : giaInvitato(a.id) ? 'Già invitato: puoi richiederlo' : (a.ruoli_preferiti ?? []).map(etichettaRuolo).join(', ')}</div></div>
              </label>
            {/each}
          </div>
          <button type="button" class="btn" disabled={occupato || !invitaScelti.length} onclick={() => invitaAmici(invitaScelti)}>Invita {invitaScelti.length ? `${invitaScelti.length} ${invitaScelti.length === 1 ? 'amico' : 'amici'}` : 'gli amici scelti'}</button>
          <button type="button" class="btn bianco" disabled={occupato || !invitabili.length} onclick={() => invitaAmici(invitabili.map((a) => a.id))}>Invita tutti ({invitabili.length})</button>
        {/if}
      </Foglio>
    {:else if foglio?.tipo === 'divise'}
      <Foglio aperto titolo={`Divisa squadra ${divisaSquadra}`} sotto="Scegli i colori: i giocatori vedranno cosa portare." chiudi={() => (foglio = null)}>
        {#if ['A', 'B'].filter(gestisco).length > 1}
          <div class="scelte">
            {#each ['A', 'B'] as sq}
              <button type="button" class="scelta" class:attiva={divisaSquadra === sq} onclick={() => apriDivise(sq)}>Squadra {sq}</button>
            {/each}
          </div>
        {/if}
        <div style="display:flex; justify-content:center"><Divisa maglia={divisaNuova.maglia} pantaloncini={divisaNuova.pantaloncini} dimensione={64} titolo={testoDivisa(divisaNuova)} /></div>
        <p class="aiuto" style="text-align:center; font-weight:600">{testoDivisa(divisaNuova)}</p>
        {#each [['maglia', 'Maglia'], ['pantaloncini', 'Pantaloncini']] as [pezzo, nomePezzo]}
          <span class="aiuto" style="font-weight:600">{nomePezzo}</span>
          <div class="tavolozza" role="radiogroup" aria-label={nomePezzo}>
            {#each Object.entries(COLORI) as [chiave, c]}
              <button type="button" role="radio" aria-checked={divisaNuova[pezzo] === chiave} aria-label={chiave}
                class="colore" class:scelto={divisaNuova[pezzo] === chiave} style={`background:${c.hex}`}
                onclick={() => (divisaNuova = { ...divisaNuova, [pezzo]: chiave })}></button>
            {/each}
          </div>
        {/each}
        <button type="button" class="btn" disabled={occupato} onclick={salvaDivisa}>Salva la divisa della squadra {divisaSquadra}</button>
      </Foglio>
    {:else if foglio?.tipo === 'modulo'}
      {@const attuale = contaRuoli(posizioni, moduloSquadra)}
      {@const totNuovo = nuovo.difesa + nuovo.centro + nuovo.attacco}
      <Foglio aperto titolo={`Modulo squadra ${moduloSquadra}: ${testoModulo(nuovo)}`} sotto="Il portiere è sempre uno. Chi è già in campo resta in campo: cambia solo il posto." chiudi={() => (foglio = null)}>
        {#if ['A', 'B'].filter(gestisco).length > 1}
          <div class="scelte">
            {#each ['A', 'B'] as sq}
              <button type="button" class="scelta" class:attiva={moduloSquadra === sq} onclick={() => apriModulo(sq)}>Squadra {sq} · {testoModulo(contaRuoli(posizioni, sq))}</button>
            {/each}
          </div>
        {/if}
        <Contatori bind:difesa={nuovo.difesa} bind:centro={nuovo.centro} bind:attacco={nuovo.attacco} massimo={partita.formato - 1} />
        <p class="aiuto" style={totNuovo !== partita.formato - 1 ? 'color: var(--avviso-testo)' : ''}>{totNuovo === partita.formato - 1
          ? `${totNuovo} giocatori più il portiere: giusto per il calcio a ${partita.formato}.`
          : `Nel calcio a ${partita.formato} servono ${partita.formato - 1} giocatori più il portiere: ${totNuovo < partita.formato - 1 ? `ne mancano ${partita.formato - 1 - totNuovo}` : `ce ne sono ${totNuovo - (partita.formato - 1)} di troppo`}.`}</p>
        <button type="button" class="btn" disabled={occupato || totNuovo !== partita.formato - 1 || testoModulo(nuovo) === testoModulo(attuale)} onclick={() => cambiaModulo(moduloSquadra, nuovo)}>Applica alla squadra {moduloSquadra}</button>
      </Foglio>
    {:else if foglio?.tipo === 'tribuna-membro'}
      {@const d = foglio.persona}
      <Foglio aperto titolo={d.profilo?.nome ?? 'Giocatore'} sotto="È in tribuna. Scegli il posto che gli proponi: deve accettare." chiudi={() => (foglio = null)}>
        {#each postiLiberi.filter((x) => gestisco(x.squadra)) as p (p.id)}
          <button type="button" class="btn bianco piccolo" disabled={occupato} onclick={() => chiedi(p, d.id)}>
            {etichettaRuolo(p.ruolo)} · squadra {p.squadra}
          </button>
        {:else}
          <p class="aiuto">Non ci sono posti liberi. Aggiungi un posto allo schema, poi chiediglielo.</p>
        {/each}
      </Foglio>
    {/if}
  {/if}
</div>

<style>
  .promemoria-divisa { gap: 12px; }
  .elenco-amici { display: flex; flex-direction: column; gap: 8px; max-height: 45vh; overflow-y: auto; }
  .elenco-amici .riga { gap: 10px; cursor: pointer; }
  .elenco-amici .spento { opacity: .55; cursor: default; }
  .tavolozza { display: grid; grid-template-columns: repeat(6, 1fr); gap: 8px; }
  .colore { width: 100%; aspect-ratio: 1; min-height: 44px; border-radius: 50%; border: 2px solid var(--bordo); cursor: pointer; }
  .colore.scelto { outline: 3px solid var(--verde); outline-offset: 2px; border-color: #14201A; }

  .toast {
    position: fixed; left: 50%; bottom: calc(90px + var(--safe-bottom)); transform: translateX(-50%); z-index: 50;
    background: var(--testo); color: #fff; font-size: 14px; font-weight: 600; padding: 10px 16px; border-radius: 999px;
  }
</style>
