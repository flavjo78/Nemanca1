<script>
  // Lista amici (dentro la Chat, scheda "Amici"): richieste ricevute, amici, richieste inviate, ricerca per nome e compagni di gioco.
  // Si diventa amici solo se l'altro accetta; poi l'organizzatore può invitarli direttamente alle partite.
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { etichettaRuolo } from '../lib/formato.js'
  import Avatar from '../components/Avatar.svelte'
  import Icona from '../components/Icona.svelte'
  import Caricamento from '../components/Caricamento.svelte'

  let elenco = $state([])
  let compagni = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let avviso = $state('')
  let occupato = $state(null)
  let testo = $state('')
  let trovati = $state([])
  let timer

  const ricevute = $derived(elenco.filter((a) => a.stato === 'ricevuta'))
  const amici = $derived(elenco.filter((a) => a.stato === 'amico'))
  const inviate = $derived(elenco.filter((a) => a.stato === 'inviata'))
  const suggeriti = $derived(compagni.filter((c) => !c.stato))

  async function carica() {
    errore = ''
    const [{ data, error }, { data: c }] = await Promise.all([supabase.rpc('miei_amici'), supabase.rpc('compagni_di_gioco')])
    if (error) errore = error.message
    elenco = data ?? []
    compagni = c ?? []
    caricamento = false
  }
  onMount(carica)

  function cerca(e) {
    testo = e.currentTarget.value
    clearTimeout(timer)
    if (testo.trim().length < 3) { trovati = []; return }
    timer = setTimeout(async () => {
      const { data } = await supabase.rpc('cerca_giocatori', { p_testo: testo })
      trovati = data ?? []
    }, 350)
  }

  async function azione(id, fn, args, messaggio) {
    occupato = id; errore = ''; avviso = ''
    const { data, error } = await supabase.rpc(fn, args)
    occupato = null
    if (error) { errore = error.message; return }
    avviso = typeof messaggio === 'function' ? messaggio(data) : messaggio
    trovati = trovati.map((t) => (t.id === id ? { ...t, stato: fn === 'togli_amicizia' ? null : data === 'accettata' ? 'amico' : 'inviata' } : t))
    await carica()
  }
  const aggiungi = (g) => azione(g.id, 'chiedi_amicizia', { p_altro: g.id },
    (r) => r === 'accettata' ? `Tu e ${g.nome} ora siete amici.` : r === 'gia_amici' ? `Siete già amici.` : `Richiesta inviata a ${g.nome}: quando accetta lo trovi tra gli amici.`)
  const rispondi = (a, si) => azione(a.id, 'rispondi_amicizia', { p_amicizia: a.amicizia_id, p_accetta: si }, si ? `Tu e ${a.nome} ora siete amici.` : 'Richiesta rifiutata.')
  const togli = (a, testoAvviso) => azione(a.id, 'togli_amicizia', { p_altro: a.id }, testoAvviso)

  function sotto(g) { return [g.comune, (g.ruoli_preferiti ?? []).map(etichettaRuolo).join(', ')].filter(Boolean).join(' · ') }
</script>

<div class="elenco-amici-pagina">
    {#if errore}<div class="errore">{errore}</div>{/if}
    {#if avviso}<div class="ok">{avviso}</div>{/if}

    <div style="position:relative">
      <input class="input" type="search" placeholder="Cerca un giocatore per nome" value={testo} oninput={cerca} aria-label="Cerca un giocatore per nome" style="padding-left: 44px" />
      <span style="position:absolute; left:14px; top:14px; color: var(--testo-2)"><Icona nome="cerca" dimensione={22} /></span>
    </div>
    {#if testo.trim().length >= 3}
      <section class="sezione">
        {#each trovati as g (g.id)}
          {@render riga(g, g.stato)}
        {:else}
          <div class="vuoto">Nessun giocatore con questo nome.</div>
        {/each}
      </section>
    {/if}

    {#if caricamento}
      <Caricamento />
    {:else}
      {#if ricevute.length}
        <section class="sezione">
          <div class="sezione-titolo">Richieste da accettare</div>
          {#each ricevute as a (a.amicizia_id)}
            <div class="card riga">
              <Avatar profilo={a} dimensione={44} />
              <div class="riempi"><div class="nome taglia">{a.nome}</div><div class="sotto taglia">vuole aggiungerti agli amici</div></div>
              <button type="button" class="btn-tondo piccolo bordo" aria-label={`Rifiuta ${a.nome}`} disabled={occupato === a.id} onclick={() => rispondi(a, false)}><Icona nome="x" dimensione={18} spessore={2.2} /></button>
              <button type="button" class="btn-tondo piccolo verde" aria-label={`Accetta ${a.nome}`} disabled={occupato === a.id} onclick={() => rispondi(a, true)}><Icona nome="spunta" dimensione={18} spessore={2.4} /></button>
            </div>
          {/each}
        </section>
      {/if}

      <section class="sezione">
        <div class="sezione-titolo">I tuoi amici{amici.length ? ` · ${amici.length}` : ''}</div>
        {#each amici as a (a.amicizia_id)}
          <div class="card riga">
            <Avatar profilo={a} dimensione={44} />
            <div class="riempi"><div class="nome taglia">{a.nome}</div><div class="sotto taglia">{sotto(a) || 'Amico'}</div></div>
            <button type="button" class="link-piccolo" disabled={occupato === a.id} onclick={() => togli(a, `${a.nome} non è più tra i tuoi amici.`)}>Togli</button>
          </div>
        {:else}
          <div class="vuoto">Non hai ancora amici. Cercali per nome qui sopra o aggiungi chi ha giocato con te.</div>
        {/each}
      </section>

      {#if suggeriti.length}
        <section class="sezione">
          <div class="sezione-titolo">Hai giocato con</div>
          {#each suggeriti as g (g.id)}
            {@render riga(g, g.stato, `${g.partite} ${g.partite === 1 ? 'partita' : 'partite'} insieme`)}
          {/each}
        </section>
      {/if}

      {#if inviate.length}
        <section class="sezione">
          <div class="sezione-titolo">In attesa di risposta</div>
          {#each inviate as a (a.amicizia_id)}
            <div class="card riga">
              <Avatar profilo={a} dimensione={44} />
              <div class="riempi"><div class="nome taglia">{a.nome}</div><div class="sotto taglia">Richiesta inviata</div></div>
              <button type="button" class="link-piccolo" disabled={occupato === a.id} onclick={() => togli(a, 'Richiesta annullata.')}>Annulla</button>
            </div>
          {/each}
        </section>
      {/if}
    {/if}
</div>

{#snippet riga(g, stato, testoSotto = '')}
  <div class="card riga">
    <Avatar profilo={g} dimensione={44} />
    <div class="riempi"><div class="nome taglia">{g.nome}</div><div class="sotto taglia">{testoSotto || g.comune || ''}</div></div>
    {#if stato === 'amico'}
      <span class="chip leggero">Amico</span>
    {:else if stato === 'inviata'}
      <span class="chip leggero">Richiesta inviata</span>
    {:else}
      <button type="button" class="btn piccolo" style="width:auto; flex:0 0 auto" disabled={occupato === g.id} onclick={() => aggiungi(g)}>
        {stato === 'ricevuta' ? 'Accetta' : 'Aggiungi'}
      </button>
    {/if}
  </div>
{/snippet}

<style>
  .elenco-amici-pagina { display: flex; flex-direction: column; gap: 14px; }
  .link-piccolo { background: none; border: none; color: var(--testo-2); text-decoration: underline; font-size: 13px; min-height: 44px; padding: 0 6px; }
</style>
