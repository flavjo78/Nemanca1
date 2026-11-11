<script>
  // Schermata partita: campo disegnato con la formazione (tappa 1: sola lettura)
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { router, indietro, naviga } from '../lib/router.svelte.js'
  import { etichettaDataOra, etichettaFormato, nomeBreve, chipPosti, euro } from '../lib/formato.js'
  import Icona from '../components/Icona.svelte'
  import CampoDisegnato from '../components/CampoDisegnato.svelte'
  import Caricamento from '../components/Caricamento.svelte'

  let { id } = $props()
  let partita = $state(null)
  let caricamento = $state(true)
  let errore = $state('')
  const appenaCreata = $derived(router.query.get('nuova') === '1')
  const posizioni = $derived(partita?.posizioni ?? [])
  const occupati = $derived(posizioni.filter((p) => p.stato !== 'libera').length)
  const chip = $derived(chipPosti(posizioni))
  const sonoOrganizzatore = $derived(auth.utente && partita?.organizzatore_id === auth.utente.id)
  const partecipo = $derived(auth.utente && posizioni.some((p) => p.giocatore_id === auth.utente.id))

  onMount(carica)

  async function carica() {
    const { data, error } = await supabase
      .from('partite')
      .select('*, campo:campi(id, nome, indirizzo), organizzatore:profili(id, nome, iniziali), posizioni(*, giocatore:profili(id, nome, iniziali))')
      .eq('id', id).maybeSingle()
    if (error || !data) errore = 'Partita non trovata.'
    partita = data
    if (partita) partita.posizioni.sort((a, b) => a.squadra.localeCompare(b.squadra) || a.y - b.y || a.x - b.x)
    caricamento = false
  }

  async function condividi() {
    const url = `${window.location.origin}/partita/${id}`
    const dati = { title: 'Ne manca 1 · partita di calcetto', text: `${etichettaFormato(partita.formato)} · ${etichettaDataOra(partita.data_ora)} · ${partita.campo.nome}`, url }
    if (navigator.share) { try { await navigator.share(dati) } catch { /* annullato */ } }
    else { await navigator.clipboard.writeText(url); alert('Link copiato') }
  }

  async function annulla() {
    if (!confirm('Vuoi annullare questa partita?')) return
    const { error } = await supabase.from('partite').update({ stato: 'annullata' }).eq('id', id)
    if (error) { errore = error.message; return }
    partita.stato = 'annullata'
  }
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
      {#if partecipo || sonoOrganizzatore}
        <a href={`/chat/${id}`} class="btn-tondo" style="color: var(--verde)" aria-label="Apri la chat della partita"><Icona nome="chat" dimensione={22} /></a>
      {/if}
    </header>

    <div class="contenuto" style="gap:14px; padding-bottom: 16px">
      {#if appenaCreata}
        <div class="ok">Partita creata. Condividi il link o fai inquadrare il QR del campo: gli altri potranno prendere un posto libero.</div>
      {/if}
      {#if errore}<div class="errore">{errore}</div>{/if}

      <div class="chip-riga">
        {#if partita.stato === 'annullata'}
          <span class="chip neutro">Annullata</span>
        {:else}
          <span class="chip {chip.classe}">{chip.testo}</span>
        {/if}
        <span class="chip leggero">{occupati} di {posizioni.length}</span>
        <span class="chip leggero">{euro(partita.quota)}</span>
      </div>

      {#if partita.descrizione}
        <p style="font-size:14px; color: var(--testo-3)">{partita.descrizione}</p>
      {/if}

      <CampoDisegnato {posizioni} mioId={auth.utente?.id ?? null} />

      <div class="legenda">
        <div><span class="pallino" style="background: var(--portiere)"></span>Portiere</div>
        <div><span class="pallino tratteggiato"></span>Posto libero</div>
        <div><span class="pallino" style="background: var(--da-confermare)"></span>Da confermare</div>
      </div>

      <p class="aiuto" style="text-align:center">{partita.campo.indirizzo}</p>
    </div>

    <div class="pie-fisso">
      {#if partita.stato === 'annullata'}
        <div class="btn bianco" style="color: var(--testo-2)">Partita annullata</div>
      {:else if sonoOrganizzatore}
        <button type="button" class="btn bianco" onclick={annulla}>Annulla partita</button>
      {:else if !auth.utente}
        <button type="button" class="btn" onclick={() => naviga(`/login?next=${encodeURIComponent(`/partita/${id}`)}`)}>Accedi per candidarti</button>
      {:else if partecipo}
        <div class="btn bianco" style="color: var(--verde)">Sei in squadra</div>
      {:else}
        <button type="button" class="btn" disabled title="Arriva con la prossima tappa">Candidati (prossima tappa)</button>
      {/if}
      <button type="button" class="btn bianco quadrato" aria-label="Condividi la partita" onclick={condividi}><Icona nome="condividi" dimensione={20} spessore={2.2} /></button>
    </div>
  {/if}
</div>
