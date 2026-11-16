<script>
  // Liste di giocatori (Chat → Liste): gruppi privati creati da te, per invitare più amici in un colpo solo.
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import Avatar from './Avatar.svelte'
  import Icona from './Icona.svelte'
  import Foglio from './Foglio.svelte'
  import Caricamento from './Caricamento.svelte'

  let liste = $state([])
  let amici = $state([])
  let caricamento = $state(true)
  let errore = $state('')
  let avviso = $state('')
  let occupato = $state(false)
  let aperta = $state(null)        // id della lista aperta
  let nuovoNome = $state('')
  let foglio = $state(null)        // { tipo: 'aggiungi' | 'rinomina', lista }
  let nomeModifica = $state('')
  let filtro = $state('')

  async function carica() {
    const [{ data, error }, { data: a }] = await Promise.all([supabase.rpc('mie_liste'), supabase.rpc('miei_amici')])
    if (error) errore = error.message
    liste = data ?? []
    amici = (a ?? []).filter((x) => x.stato === 'amico')
    caricamento = false
  }
  onMount(carica)

  async function chiama(fn, args, msg) {
    occupato = true; errore = ''; avviso = ''
    const { data, error } = await supabase.rpc(fn, args)
    occupato = false
    if (error) { errore = error.message; return null }
    if (msg) avviso = msg
    await carica()
    return data ?? true
  }

  async function crea(e) {
    e.preventDefault()
    if (!nuovoNome.trim()) return
    const id = await chiama('crea_lista', { p_nome: nuovoNome }, `Lista "${nuovoNome.trim()}" creata: aggiungi i giocatori.`)
    if (id) { aperta = id; nuovoNome = '' }
  }
  const aggiungi = (l, g) => chiama('aggiungi_a_lista', { p_lista: l.id, p_giocatore: g.id })
  const togli = (l, g) => chiama('togli_da_lista', { p_lista: l.id, p_giocatore: g.id })
  async function rinomina() {
    const l = foglio.lista
    if (await chiama('rinomina_lista', { p_lista: l.id, p_nome: nomeModifica })) foglio = null
  }
  async function elimina(l) {
    if (!confirm(`Eliminare la lista "${l.nome}"? Gli amici restano amici.`)) return
    await chiama('elimina_lista', { p_lista: l.id }, 'Lista eliminata.')
  }
  const inLista = (l, id) => l.membri.some((m) => m.id === id)
  const daAggiungere = $derived(foglio?.tipo === 'aggiungi'
    ? amici.filter((a) => !filtro.trim() || a.nome?.toLowerCase().includes(filtro.trim().toLowerCase()))
    : [])
</script>

<div class="liste">
  {#if errore}<div class="errore">{errore}</div>{/if}
  {#if avviso}<div class="ok">{avviso}</div>{/if}

  <form class="nuova" onsubmit={crea}>
    <input class="input" type="text" maxlength="40" placeholder="Nuova lista (es. Calcetto giovedì)" bind:value={nuovoNome} aria-label="Nome della nuova lista" />
    <button type="submit" class="btn" style="width:auto; flex:0 0 auto" disabled={occupato || !nuovoNome.trim()}><Icona nome="piu" dimensione={18} spessore={2.4} /> Crea</button>
  </form>

  {#if caricamento}
    <Caricamento />
  {:else if !liste.length}
    <div class="vuoto">Crea una lista di giocatori (amici del calcetto, colleghi…): quando organizzi una partita li inviti tutti insieme.</div>
  {:else}
    {#each liste as l (l.id)}
      <div class="card lista">
        <button type="button" class="testa" onclick={() => (aperta = aperta === l.id ? null : l.id)} aria-expanded={aperta === l.id}>
          <div class="riempi" style="text-align:left">
            <div class="nome taglia">{l.nome}</div>
            <div class="sotto">{l.membri.length} {l.membri.length === 1 ? 'giocatore' : 'giocatori'}</div>
          </div>
          <div class="facce">{#each l.membri.slice(0, 4) as m (m.id)}<Avatar profilo={m} dimensione={28} />{/each}</div>
          <span style={`display:inline-flex; transition: transform .2s; transform: rotate(${aperta === l.id ? 90 : 0}deg)`}><Icona nome="avanti" dimensione={18} /></span>
        </button>
        {#if aperta === l.id}
          <div class="corpo">
            {#each l.membri as m (m.id)}
              <div class="riga-membro">
                <Avatar profilo={m} dimensione={36} />
                <div class="riempi taglia">{m.nome}</div>
                <button type="button" class="link-piccolo" disabled={occupato} onclick={() => togli(l, m)}>Togli</button>
              </div>
            {/each}
            <button type="button" class="btn bianco piccolo" onclick={() => { filtro = ''; foglio = { tipo: 'aggiungi', lista: l } }}><Icona nome="piu" dimensione={18} /> Aggiungi giocatori</button>
            <div class="azioni">
              <button type="button" class="link-piccolo" onclick={() => { nomeModifica = l.nome; foglio = { tipo: 'rinomina', lista: l } }}>Rinomina</button>
              <button type="button" class="link-piccolo" style="color: var(--errore)" onclick={() => elimina(l)}>Elimina lista</button>
            </div>
          </div>
        {/if}
      </div>
    {/each}
  {/if}
</div>

{#if foglio?.tipo === 'aggiungi'}
  {@const l = liste.find((x) => x.id === foglio.lista.id) ?? foglio.lista}
  <Foglio aperto titolo={`Aggiungi a "${l.nome}"`} sotto="Tocca i tuoi amici per aggiungerli o toglierli dalla lista." chiudi={() => (foglio = null)}>
    <input class="input" type="search" placeholder="Cerca tra gli amici" bind:value={filtro} aria-label="Cerca tra gli amici" />
    <div class="scelta-amici">
      {#each daAggiungere as a (a.id)}
        {@const dentro = inLista(l, a.id)}
        <button type="button" class="card riga" class:dentro disabled={occupato} onclick={() => (dentro ? togli(l, a) : aggiungi(l, a))}>
          <Avatar profilo={a} dimensione={36} />
          <div class="riempi taglia" style="text-align:left">{a.nome}</div>
          <span class="segno">{#if dentro}<Icona nome="spunta" dimensione={18} spessore={2.6} />{/if}</span>
        </button>
      {:else}
        <p class="aiuto">{amici.length ? 'Nessun amico con questo nome.' : 'Non hai ancora amici: aggiungili dalla scheda Amici.'}</p>
      {/each}
    </div>
  </Foglio>
{:else if foglio?.tipo === 'rinomina'}
  <Foglio aperto titolo="Rinomina la lista" chiudi={() => (foglio = null)}>
    <input class="input" type="text" maxlength="40" bind:value={nomeModifica} aria-label="Nuovo nome" />
    <button type="button" class="btn" disabled={occupato || !nomeModifica.trim()} onclick={rinomina}>Salva</button>
  </Foglio>
{/if}

<style>
  .liste { display: flex; flex-direction: column; gap: 12px; }
  .nuova { display: flex; gap: 8px; }
  .nuova .input { flex: 1 1 auto; min-width: 0; }
  .lista { padding: 0; overflow: hidden; }
  .testa { display: flex; align-items: center; gap: 10px; width: 100%; min-height: 64px; padding: 12px 16px; background: none; border: none; font: inherit; color: inherit; }
  .facce { display: flex; }
  .facce :global(*) { margin-left: -6px; border: 2px solid var(--superficie); border-radius: 50%; }
  .corpo { display: flex; flex-direction: column; gap: 8px; padding: 0 16px 14px; }
  .riga-membro { display: flex; align-items: center; gap: 10px; min-height: 44px; }
  .azioni { display: flex; justify-content: space-between; }
  .link-piccolo { background: none; border: none; color: var(--testo-2); text-decoration: underline; font-size: 13px; min-height: 44px; padding: 0 6px; }
  .scelta-amici { display: flex; flex-direction: column; gap: 8px; max-height: 50vh; overflow-y: auto; }
  .scelta-amici .riga { gap: 10px; border: 1px solid var(--bordo-2); font: inherit; color: inherit; }
  .scelta-amici .dentro { border-color: var(--verde); background: #EAF5EE; }
  .segno { width: 26px; height: 26px; border-radius: 50%; border: 2px solid var(--bordo); display: flex; align-items: center; justify-content: center; color: #fff; flex: 0 0 auto; }
  .dentro .segno { background: var(--verde); border-color: var(--verde); }
</style>
