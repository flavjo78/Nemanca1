<script>
  // Area riservata a Flavio: numeri, ultimi iscritti, prossime partite, campi
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { etichettaDataOra, etichettaFormato, nomeBreve, iniziali } from '../lib/formato.js'
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Caricamento from '../components/Caricamento.svelte'
  import Icona from '../components/Icona.svelte'

  let numeri = $state(null)
  let spazio = $state(null)
  const LIMITE = 500 * 1024 * 1024   // piano gratuito Supabase
  const mb = (b) => (b / 1024 / 1024).toLocaleString('it-IT', { maximumFractionDigits: 1 })
  let utenti = $state([])
  let partite = $state([])
  let campi = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let ultimaVisita = $state(0)
  const CHIAVE = 'nemanca1_admin_ultima_visita'

  const nuovi = $derived(utenti.filter((u) => new Date(u.creato_il).getTime() > ultimaVisita).length)

  onMount(async () => {
    try { ultimaVisita = Number(localStorage.getItem(CHIAVE) || 0) } catch { /* niente */ }
    await carica()
    caricamento = false
  })

  async function carica() {
    errore = ''
    const [n, u, p, c, sp] = await Promise.all([
      supabase.rpc('admin_numeri'),
      supabase.rpc('admin_utenti', { p_limite: 50 }),
      supabase.from('partite').select('*, campo:campi(nome), organizzatore:profili!partite_organizzatore_id_fkey(nome), posizioni(stato)')
        .gte('data_ora', new Date(Date.now() - 86400000).toISOString()).order('data_ora').limit(30),
      supabase.from('campi').select('*, partite(count)').order('creato_il', { ascending: false }).limit(50),
      supabase.rpc('admin_spazio')
    ])
    spazio = sp.data?.[0] ?? null
    const e = n.error || u.error || p.error || c.error
    if (e) errore = /does not exist|schema cache/i.test(e.message) ? 'Il database non è ancora aggiornato alla tappa 2 (manca la migrazione 0002).' : e.message
    numeri = n.data?.[0] ?? null
    utenti = u.data ?? []
    partite = p.data ?? []
    campi = c.data ?? []
  }

  function segnaVisti() {
    ultimaVisita = Date.now()
    try { localStorage.setItem(CHIAVE, String(ultimaVisita)) } catch { /* niente */ }
  }

  async function annullaPartita(p) {
    if (!confirm(`Annullare la partita di ${etichettaDataOra(p.data_ora)} al ${p.campo?.nome}?`)) return
    const { error } = await supabase.from('partite').update({ stato: 'annullata' }).eq('id', p.id)
    if (error) { errore = error.message; return }
    await carica()
  }
  async function alternaVerificato(c) {
    const { error } = await supabase.from('campi').update({ verificato: !c.verificato }).eq('id', c.id)
    if (error) { errore = error.message; return }
    await carica()
  }
  async function eliminaCampo(c) {
    const n = c.partite?.[0]?.count ?? 0
    if (n > 0) { errore = `Il campo "${c.nome}" ha ${n} partite: non si può eliminare. Puoi togliergli la spunta "verificato" o annullare le partite.`; return }
    if (!confirm(`Eliminare il campo "${c.nome}"? Non si può annullare.`)) return
    const { error } = await supabase.from('campi').delete().eq('id', c.id)
    if (error) { errore = error.message; return }
    await carica()
  }
  function dataBreve(d) { d = new Date(d); return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}` }
</script>

<div class="pagina">
  <header class="intestazione" style="justify-content: space-between">
    <div class="centro">
      <h1 style="font-size:26px">Amministrazione</h1>
      <div class="sotto">Solo tu vedi questa pagina</div>
    </div>
    <button type="button" class="btn-tondo" aria-label="Aggiorna" onclick={carica}><Icona nome="ricarica" dimensione={20} /></button>
  </header>

  <div class="contenuto con-barra">
    {#if !auth.profilo?.admin}
      <div class="vuoto">Pagina riservata all'amministratore.</div>
    {:else if caricamento}
      <Caricamento />
    {:else}
      {#if errore}<div class="errore">{errore}</div>{/if}

      {#if numeri}
        <div style="display:grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px">
          {#each [[numeri.utenti, 'Iscritti'], [numeri.partite_aperte, 'Partite aperte'], [numeri.campi, 'Campi']] as [n, t]}
            <div class="card" style="align-items:center; gap:2px; padding: 14px 8px">
              <div style="font-family: var(--font-titoli); font-size: 26px; font-weight: 700">{n}</div>
              <div class="sotto" style="text-transform: uppercase; letter-spacing: .6px; font-size: 11px; font-weight: 600; text-align:center">{t}</div>
            </div>
          {/each}
        </div>
        <p class="aiuto">{numeri.partite_settimana} partite nei prossimi 7 giorni · {numeri.partite_totali} create in tutto</p>
      {/if}

      {#if spazio}
        {@const perc = Math.min(100, (spazio.database_byte / LIMITE) * 100)}
        <section class="sezione">
          <div class="sezione-titolo">Spazio del database</div>
          <div class="card" style="gap:10px">
            <div style="display:flex; justify-content:space-between; font-size:14px"><strong>{mb(spazio.database_byte)} MB su 500 MB</strong><span>{perc.toFixed(1).replace('.', ',')}%</span></div>
            <div class="barra" style="flex:none; height:12px; border-radius:6px"><div style={`width:${Math.max(perc, 1)}%; height:12px; background:${perc >= 80 ? 'var(--errore)' : perc >= 60 ? 'var(--portiere)' : 'var(--verde)'}`}></div></div>
            <div class="sotto">Chat: {mb(spazio.messaggi_byte)} MB ({spazio.messaggi} messaggi) · Partite e posti: {mb(spazio.partite_byte)} MB ({spazio.partite}) · Utenti: {mb(spazio.profili_byte)} MB ({spazio.profili})</div>
            <p class="aiuto">{perc >= 80 ? 'Quasi pieno: scarica l\'archivio e fai pulizia, oppure passa a Supabase Pro.' : perc >= 60 ? 'Oltre metà: è il momento di pensare a Supabase Pro o alla pulizia delle chat vecchie.' : 'Tutto tranquillo. Il resto dello spazio è occupato dalla struttura di base di Supabase.'}</p>
          </div>
        </section>
      {/if}

      <section class="sezione">
        <div class="sezione-titolo">
          <span>Ultimi iscritti {#if nuovi}<span class="chip avviso" style="margin-left:6px">{nuovi} {nuovi === 1 ? 'nuovo' : 'nuovi'}</span>{/if}</span>
          {#if nuovi}<button type="button" class="chip" style="border:none" onclick={segnaVisti}>Segna come visti</button>{/if}
        </div>
        {#each utenti as u (u.id)}
          <div class="card riga" style={new Date(u.creato_il).getTime() > ultimaVisita ? 'border: 2px solid var(--portiere)' : ''}>
            <div class="avatar" class:verde={u.admin}>{iniziali(u)}</div>
            <div class="riempi">
              <div class="nome taglia">{u.nome ?? 'Profilo da completare'}{u.admin ? ' · admin' : ''}</div>
              <div class="sotto taglia">{u.email}{u.comune ? ` · ${u.comune}` : ''}</div>
              <div class="sotto" style="font-size:12px">Iscritto il {dataBreve(u.creato_il)}{u.ultimo_accesso ? ` · ultimo accesso ${dataBreve(u.ultimo_accesso)}` : ''}</div>
            </div>
          </div>
        {:else}
          <div class="vuoto">Nessun iscritto.</div>
        {/each}
        <p class="aiuto">Per eliminare un account: pannello Supabase → Authentication → Users.</p>
      </section>

      <section class="sezione">
        <div class="sezione-titolo">Prossime partite</div>
        {#each partite as p (p.id)}
          {@const occ = p.posizioni.filter((x) => x.stato !== 'libera').length}
          <a href={`/partita/${p.id}`} class="card riga">
            <div class="riempi">
              <div class="nome taglia">{etichettaDataOra(p.data_ora)} · {etichettaFormato(p.formato)}</div>
              <div class="sotto taglia">{p.campo?.nome} · organizza {nomeBreve(p.organizzatore)} · {occ}/{p.posizioni.length}</div>
            </div>
            <span class="chip {p.stato === 'annullata' ? 'neutro' : p.stato === 'completa' ? 'portiere' : 'leggero'}">{p.stato}</span>
            {#if p.stato === 'aperta' || p.stato === 'completa'}
              <button type="button" class="btn-tondo piccolo bordo" aria-label="Annulla partita" onclick={(e) => { e.preventDefault(); annullaPartita(p) }}><Icona nome="x" dimensione={18} spessore={2.2} /></button>
            {/if}
          </a>
        {:else}
          <div class="vuoto">Nessuna partita in programma.</div>
        {/each}
      </section>

      <section class="sezione">
        <div class="sezione-titolo">Campi registrati</div>
        {#each campi as c (c.id)}
          <div class="card riga">
            <div class="riempi">
              <a href={`/campo/${c.id}`} class="nome taglia" style="text-decoration:none; color:inherit">{c.nome}</a>
              <div class="sotto taglia">{c.indirizzo} · {c.partite?.[0]?.count ?? 0} partite</div>
            </div>
            <button type="button" class="chip" class:bianco-su-verde={!c.verificato} class:portiere={c.verificato} style="border:none" onclick={() => alternaVerificato(c)}>{c.verificato ? 'Verificato' : 'Verifica'}</button>
            <button type="button" class="btn-tondo piccolo bordo" aria-label="Elimina campo" onclick={() => eliminaCampo(c)}><Icona nome="x" dimensione={18} spessore={2.2} /></button>
          </div>
        {:else}
          <div class="vuoto">Nessun campo.</div>
        {/each}
      </section>
    {/if}
  </div>
  <BarraInferiore />
</div>
