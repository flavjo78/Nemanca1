<script>
  // Chat della partita in tempo reale: bolle, messaggi di sistema, card con Accetta/Rifiuta
  import { onMount, onDestroy, tick } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { indietro, naviga } from '../lib/router.svelte.js'
  import { etichettaDataOra, etichettaFormato, etichettaRuolo, iniziali, nomeBreve, ora } from '../lib/formato.js'
  import { segnaLetto } from '../lib/letture.js'
  import Icona from '../components/Icona.svelte'
  import Caricamento from '../components/Caricamento.svelte'

  let { id } = $props()
  let partita = $state(null)
  // un'ora dopo l'inizio la chat diventa di sola lettura (regola anche nel database)
  const chatAttiva = $derived(partita && ['aperta', 'completa'].includes(partita.stato) && new Date(partita.data_ora) > new Date(Date.now() - 3600 * 1000))
  let messaggi = $state([])
  let richieste = $state({})       // id → richiesta
  let posti = $state({})           // id → posizione (per le card cambio ruolo)
  let mioInvito = $state(null)
  let partecipo = $state(false)
  let gestisco = $state(false)
  let caricamento = $state(true)
  let errore = $state('')
  let testo = $state('')
  let invio = $state(false)
  let listaEl = $state(null)
  let canale = null
  const uid = $derived(auth.utente?.id)

  onMount(async () => {
    await carica()
    caricamento = false
    await scorriInFondo()
    canale = supabase.channel(`chat-${id}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messaggi', filter: `partita_id=eq.${id}` }, (e) => arrivato(e.new))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'richieste', filter: `partita_id=eq.${id}` }, caricaStati)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posizioni', filter: `partita_id=eq.${id}` }, caricaStati)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'inviti', filter: `partita_id=eq.${id}` }, caricaStati)
      .subscribe()
  })
  onDestroy(() => { if (canale) supabase.removeChannel(canale) })

  async function carica() {
    const [{ data: p }, { data: part }, { data: gest }] = await Promise.all([
      supabase.from('partite').select('id, data_ora, formato, stato, archiviata, organizzatore_id, campo:campi(nome)').eq('id', id).maybeSingle(),
      supabase.rpc('partecipa', { p_partita: id }),
      supabase.rpc('e_organizzatore', { p_partita: id })
    ])
    partita = p
    partecipo = !!part
    gestisco = !!gest
    if (!partecipo) return
    const { data: m, error } = await supabase.from('messaggi')
      .select('*, autore:profili(id, nome, iniziali)').eq('partita_id', id)
      .order('creato_il', { ascending: false }).limit(300)
    if (error) errore = error.message
    messaggi = (m ?? []).reverse()
    await caricaStati()
    segnaLetto(id, messaggi.at(-1)?.creato_il)
  }

  async function caricaStati() {
    const [{ data: r }, { data: po }, { data: inv }] = await Promise.all([
      supabase.from('richieste').select('id, stato, giocatore_id, ruolo_richiesto, squadra_preferita, giocatore:profili(id, nome)').eq('partita_id', id),
      supabase.from('posizioni').select('id, stato, ruolo, squadra, giocatore_id, nuovo_ruolo_proposto').eq('partita_id', id),
      supabase.from('inviti').select('*, posizione:posizioni(ruolo, squadra)').eq('partita_id', id).eq('a_id', uid).eq('stato', 'in_attesa').maybeSingle()
    ])
    richieste = Object.fromEntries((r ?? []).map((x) => [x.id, x]))
    posti = Object.fromEntries((po ?? []).map((x) => [x.id, x]))
    mioInvito = inv ?? null
  }

  async function arrivato(m) {
    if (messaggi.some((x) => x.id === m.id)) return
    const { data } = await supabase.from('messaggi').select('*, autore:profili(id, nome, iniziali)').eq('id', m.id).maybeSingle()
    if (!data || messaggi.some((x) => x.id === data.id)) return
    const inFondo = !listaEl || listaEl.scrollHeight - listaEl.scrollTop - listaEl.clientHeight < 120
    messaggi = [...messaggi, data]
    segnaLetto(id, data.creato_il)
    if (data.tipo !== 'testo') caricaStati()
    if (inFondo || data.autore_id === uid) await scorriInFondo()
  }

  async function scorriInFondo() {
    await tick()
    if (listaEl) listaEl.scrollTop = listaEl.scrollHeight
  }

  async function invia(e) {
    e?.preventDefault()
    const t = testo.trim()
    if (!t || invio) return
    invio = true; errore = ''
    const { data, error } = await supabase.from('messaggi')
      .insert({ partita_id: id, autore_id: uid, testo: t.slice(0, 1000) })
      .select('*, autore:profili(id, nome, iniziali)').single()
    invio = false
    if (error) { errore = 'Messaggio non inviato. Riprova.'; return }
    testo = ''
    if (!messaggi.some((x) => x.id === data.id)) messaggi = [...messaggi, data]
    segnaLetto(id, data.creato_il)
    await scorriInFondo()
  }

  function tasto(e) {
    // Invio manda, Maiusc+Invio va a capo (sul telefono il tasto Invio va a capo)
    if (e.key === 'Enter' && !e.shiftKey && window.matchMedia('(hover: hover)').matches) invia(e)
  }

  async function rpc(nome, parametri) {
    errore = ''
    const { error } = await supabase.rpc(nome, parametri)
    if (error) errore = error.message
    await caricaStati()
  }

  async function entraTribuna() {
    const { error } = await supabase.rpc('entra_tribuna', { p_partita: id })
    if (error) { errore = error.message; return }
    caricamento = true; await carica(); caricamento = false; await scorriInFondo()
  }

  function giorno(d) {
    const x = new Date(d), oggi = new Date(), ieri = new Date(Date.now() - 86400000)
    if (x.toDateString() === oggi.toDateString()) return 'Oggi'
    if (x.toDateString() === ieri.toDateString()) return 'Ieri'
    return x.toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long' })
  }
  const nuovoGiorno = (i) => i === 0 || new Date(messaggi[i].creato_il).toDateString() !== new Date(messaggi[i - 1].creato_il).toDateString()
  const stessoAutore = (i) => i > 0 && messaggi[i - 1].tipo === 'testo' && messaggi[i - 1].autore_id === messaggi[i].autore_id && !nuovoGiorno(i)
</script>

<div class="pagina chat">
  <header class="intestazione" style="padding-bottom: 10px; border-bottom: 1px solid var(--bordo-2)">
    <button type="button" class="btn-tondo" aria-label="Torna indietro" onclick={() => indietro('/chat')}>
      <Icona nome="indietro" dimensione={20} spessore={2.4} />
    </button>
    <div class="centro">
      {#if partita}
        <h1>{partita.campo?.nome}</h1>
        <div class="sotto">{etichettaDataOra(partita.data_ora)} · {etichettaFormato(partita.formato)}{partita.stato === 'annullata' ? ' · annullata' : ''}</div>
      {:else}
        <h1>Chat</h1>
      {/if}
    </div>
    <a href={`/partita/${id}`} class="btn-tondo" aria-label="Apri la formazione" style="color: var(--verde)"><Icona nome="formazione" dimensione={22} /></a>
  </header>

  {#if caricamento}
    <Caricamento />
  {:else if !partita}
    <div class="contenuto spazio-sopra"><div class="errore">Partita non trovata.</div></div>
  {:else if !partecipo}
    <div class="contenuto spazio-sopra">
      <div class="vuoto" style="display:flex; flex-direction:column; gap:12px; align-items:center">
        La chat è per chi partecipa: giocatori, organizzatore e chi è in tribuna.
        <button type="button" class="btn" onclick={entraTribuna}>Entra in tribuna e leggi la chat</button>
        <a href={`/partita/${id}`}>Vai alla formazione</a>
      </div>
      {#if errore}<div class="errore">{errore}</div>{/if}
    </div>
  {:else}
    {#if mioInvito}
      <div class="avviso-invito">
        <div><strong>Ti chiedono di giocare</strong>{mioInvito.posizione ? ` come ${etichettaRuolo(mioInvito.posizione.ruolo).toLowerCase()}, squadra ${mioInvito.posizione.squadra}` : ''}.</div>
        <div style="display:flex; gap:8px">
          <button type="button" class="btn bianco piccolo" onclick={() => rpc('rispondi_invito', { p_partita: id, p_accetta: false })}>Resto in tribuna</button>
          <button type="button" class="btn piccolo" onclick={() => rpc('rispondi_invito', { p_partita: id, p_accetta: true })}>Scendo in campo</button>
        </div>
      </div>
    {/if}

    <div class="lista" bind:this={listaEl}>
      {#if !messaggi.length}
        <div class="sistema" style="margin-top: 20px">Nessun messaggio. Scrivi il primo!</div>
      {/if}
      {#each messaggi as m, i (m.id)}
        {#if nuovoGiorno(i)}<div class="giorno">{giorno(m.creato_il)}</div>{/if}

        {#if m.tipo === 'testo'}
          {@const mio = m.autore_id === uid}
          <div class="riga-msg" class:mio class:attaccato={stessoAutore(i)}>
            {#if !mio}
              <div class="avatar mini-chat" style:visibility={stessoAutore(i) ? 'hidden' : 'visible'}>{iniziali(m.autore)}</div>
            {/if}
            <div class="bolla" class:mio>
              {#if !mio && !stessoAutore(i)}<div class="autore">{m.autore?.nome ?? 'Giocatore'}{m.autore_id === partita.organizzatore_id ? ' · organizzatore' : ''}</div>{/if}
              <div class="testo">{m.testo}</div>
              <div class="ora">{ora(m.creato_il)}</div>
            </div>
          </div>

        {:else if m.tipo === 'richiesta'}
          {@const r = richieste[m.riferimento_id]}
          <div class="card-msg">
            <div class="testo-card"><Icona nome="utenti" dimensione={18} />
              {#if r?.giocatore?.nome}{r.giocatore.nome} si candida{r.ruolo_richiesto ? ` come ${etichettaRuolo(r.ruolo_richiesto).toLowerCase()}` : ''}{r.squadra_preferita ? ` · squadra ${r.squadra_preferita}` : ''}{:else}{m.testo}{/if}
            </div>
            {#if r?.stato === 'in_attesa' && gestisco}
              <div class="azioni">
                <button type="button" class="btn bianco piccolo" onclick={() => rpc('rispondi_richiesta', { p_richiesta: r.id, p_accetta: false })}>Rifiuta</button>
                <button type="button" class="btn piccolo" onclick={() => rpc('rispondi_richiesta', { p_richiesta: r.id, p_accetta: true })}>Accetta</button>
              </div>
            {:else if r?.stato === 'in_attesa'}
              <div class="stato">In attesa dell'organizzatore</div>
            {:else if r}
              <div class="stato">{r.stato === 'accettata' ? 'Accettata' : 'Non accettata'}</div>
            {/if}
            <div class="ora">{ora(m.creato_il)}</div>
          </div>

        {:else if m.tipo === 'cambio_ruolo'}
          {@const p = posti[m.riferimento_id]}
          <div class="card-msg arancio">
            <div class="testo-card">{m.testo}</div>
            {#if p?.stato === 'cambio_proposto' && p.giocatore_id === uid}
              <div class="azioni">
                <button type="button" class="btn bianco piccolo" onclick={() => rpc('rispondi_cambio', { p_posizione: p.id, p_accetta: false })}>Rifiuta</button>
                <button type="button" class="btn piccolo" onclick={() => rpc('rispondi_cambio', { p_posizione: p.id, p_accetta: true })}>Accetta</button>
              </div>
            {:else if p?.stato === 'cambio_proposto'}
              <div class="stato">In attesa di risposta</div>
            {:else}
              <div class="stato">Risolto</div>
            {/if}
            <div class="ora">{ora(m.creato_il)}</div>
          </div>

        {:else}
          <div class="sistema">{m.testo} · {ora(m.creato_il)}</div>
        {/if}
      {/each}
    </div>

    {#if !chatAttiva}
      <div class="scrivi"><div class="chiusa">Chat chiusa: la partita {partita.stato === 'annullata' ? 'è stata annullata' : partita.archiviata ? 'è in archivio' : 'è stata giocata'}. Puoi rileggere i messaggi.</div></div>
    {:else}
    <form class="scrivi" onsubmit={invia}>
      {#if errore}<div class="errore" style="margin-bottom: 8px">{errore}</div>{/if}
      <div class="barra-scrivi">
        <textarea rows="1" maxlength="1000" placeholder="Scrivi un messaggio" bind:value={testo} onkeydown={tasto} aria-label="Messaggio"></textarea>
        <button type="submit" class="btn-tondo verde" aria-label="Invia" disabled={invio || !testo.trim()}>
          <Icona nome="invia" dimensione={20} spessore={2.2} />
        </button>
      </div>
    </form>
    {/if}
  {/if}
</div>

<style>
  .chiusa { text-align: center; font-size: 13.5px; color: var(--testo-2); padding: 12px 8px; }
  .chat { height: 100dvh; min-height: 0; }
  .lista { flex: 1 1 0; min-height: 0; overflow-y: auto; padding: 12px 14px 8px; display: flex; flex-direction: column; gap: 6px; }
  .giorno { align-self: center; font-size: 12px; font-weight: 600; color: var(--testo-2); background: var(--neutro); padding: 4px 10px; border-radius: 999px; margin: 8px 0 4px; text-transform: capitalize; }
  .riga-msg { display: flex; align-items: flex-end; gap: 6px; max-width: 86%; }
  .riga-msg.mio { align-self: flex-end; }
  .riga-msg.attaccato { margin-top: -3px; }
  .mini-chat { width: 30px; height: 30px; font-size: 11px; flex: 0 0 30px; }
  .bolla { background: var(--superficie); border-radius: 16px 16px 16px 4px; padding: 7px 11px 5px; box-shadow: 0 1px 1px rgba(0,0,0,.05); min-width: 60px; }
  .bolla.mio { background: var(--verde); color: #fff; border-radius: 16px 16px 4px 16px; }
  .autore { font-size: 12px; font-weight: 700; color: var(--verde); margin-bottom: 2px; }
  .testo { font-size: 15px; line-height: 1.35; white-space: pre-wrap; word-break: break-word; }
  .ora { font-size: 10.5px; opacity: .65; text-align: right; margin-top: 2px; }
  .sistema { align-self: center; text-align: center; font-size: 12.5px; color: var(--testo-2); background: rgba(255,255,255,.7); padding: 5px 12px; border-radius: 12px; max-width: 90%; }
  .card-msg { align-self: center; width: min(100%, 340px); background: var(--superficie); border: 1px solid var(--bordo); border-left: 4px solid var(--verde); border-radius: 14px; padding: 10px 12px; display: flex; flex-direction: column; gap: 8px; }
  .card-msg.arancio { border-left-color: var(--da-confermare); }
  .testo-card { font-size: 14px; font-weight: 600; display: flex; gap: 6px; align-items: center; }
  .azioni { display: flex; gap: 8px; }
  .stato { font-size: 12.5px; color: var(--testo-2); }
  .avviso-invito { margin: 10px 14px 0; background: var(--avviso-sfondo); color: var(--avviso-testo); border-radius: 14px; padding: 10px 12px; display: flex; flex-direction: column; gap: 8px; font-size: 14px; }
  .scrivi { padding: 8px 12px calc(10px + var(--safe-bottom)); background: var(--sfondo); border-top: 1px solid var(--bordo-2); }
  .barra-scrivi { display: flex; gap: 8px; align-items: flex-end; }
  textarea { flex: 1 1 0; resize: none; min-height: 44px; max-height: 140px; border: 1px solid var(--bordo); border-radius: 22px; padding: 11px 16px; font-size: 16px; background: var(--superficie); outline: none; field-sizing: content; }
  textarea:focus { border-color: var(--verde); }
</style>
