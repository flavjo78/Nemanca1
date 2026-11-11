<script>
  // Pagina del campo (quella che si apre dal QR): visibile anche senza login
  import { onMount } from 'svelte'
  import QRCode from 'qrcode'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { naviga, router, indietro } from '../lib/router.svelte.js'
  import Icona from '../components/Icona.svelte'
  import CardPartita from '../components/CardPartita.svelte'
  import Caricamento from '../components/Caricamento.svelte'

  let { id } = $props()
  let campo = $state(null)
  let partite = $state([])
  let passate = $state(0)
  let caricamento = $state(true)
  let errore = $state('')
  let mostraQr = $state(false)
  let qrDati = $state('')
  const dalQr = $derived(router.query.get('qr') === '1')
  const appenaCreato = $derived(router.query.get('nuovo') === '1')
  const perOrganizzare = $derived(router.query.get('organizza') === '1')
  const urlCampo = $derived(`${window.location.origin}/campo/${id}?qr=1`)

  const sportTesto = $derived((campo?.sport ?? []).map((s) => s === 'calcio' ? 'Calcio a 5, 8 e 11' : s.charAt(0).toUpperCase() + s.slice(1)).join(' · '))

  onMount(carica)
  $effect(() => { if (appenaCreato) mostraQr = true })
  $effect(() => { if (mostraQr && !qrDati) generaQr() })

  async function carica() {
    caricamento = true
    const [{ data: c, error: e1 }, { data: p, error: e2 }, { count }] = await Promise.all([
      supabase.from('campi').select('*').eq('id', id).maybeSingle(),
      supabase.from('partite')
        .select('*, organizzatore:profili(id, nome, iniziali), posizioni(id, stato, ruolo)')
        .eq('campo_id', id).in('stato', ['aperta', 'completa'])
        .gte('data_ora', new Date(Date.now() - 2 * 3600 * 1000).toISOString())
        .order('data_ora'),
      supabase.from('partite').select('id', { count: 'exact', head: true }).eq('campo_id', id)
        .gte('data_ora', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString())
    ])
    if (e1 || !c) errore = 'Campo non trovato.'
    else if (e2) errore = e2.message
    campo = c
    partite = p ?? []
    passate = count ?? 0
    caricamento = false
  }

  async function generaQr() {
    qrDati = await QRCode.toDataURL(urlCampo, { width: 600, margin: 2, color: { dark: '#14201A', light: '#FFFFFF' } })
  }

  function organizza() {
    if (!auth.utente) naviga(`/login?next=${encodeURIComponent(`/campo/${id}/nuova`)}`)
    else naviga(`/campo/${id}/nuova`)
  }

  async function condividi() {
    const dati = { title: campo.nome, text: `Partite al ${campo.nome}`, url: urlCampo }
    if (navigator.share) { try { await navigator.share(dati) } catch { /* annullato */ } }
    else { await navigator.clipboard.writeText(urlCampo); alert('Link copiato') }
  }
</script>

<div class="pagina">
  {#if caricamento}
    <Caricamento />
  {:else if !campo}
    <div class="contenuto spazio-sopra"><div class="errore">{errore}</div><a href="/campi" class="btn bianco">Vai ai campi</a></div>
  {:else}
    <div class="intestazione-verde no-stampa">
      <div style="display:flex; justify-content:space-between; align-items:center">
        <button type="button" class="btn-tondo trasparente" aria-label="Torna indietro" onclick={() => indietro(auth.utente ? '/' : '/campi')}>
          <Icona nome="indietro" dimensione={20} spessore={2.4} />
        </button>
        {#if dalQr}
          <span class="chip trasparente"><Icona nome="qr" dimensione={14} spessore={2.2} /> Aperto dal QR del campo</span>
        {:else}
          <button type="button" class="chip trasparente" style="border:none; min-height:36px" onclick={() => (mostraQr = !mostraQr)}>
            <Icona nome="qr" dimensione={14} spessore={2.2} /> {mostraQr ? 'Nascondi QR' : 'QR del campo'}
          </button>
        {/if}
      </div>
      <div style="display:flex; flex-direction:column; gap:4px">
        <h1>{campo.nome}</h1>
        <div class="sotto">{campo.indirizzo} · {sportTesto}</div>
      </div>
      <div class="chip-riga">
        {#if campo.verificato}
          <span class="chip bianco-su-verde"><Icona nome="spunta" dimensione={14} spessore={2.6} /> Campo verificato</span>
        {/if}
        <span class="chip trasparente">{passate} {passate === 1 ? 'partita' : 'partite'} questo mese</span>
      </div>
    </div>

    <div class="contenuto spazio-sopra" style="gap:14px">
      {#if errore}<div class="errore">{errore}</div>{/if}

      {#if mostraQr}
        <div class="card" style="align-items:center; text-align:center; gap:10px" id="stampa-qr">
          {#if appenaCreato}<div class="ok no-stampa" style="width:100%">Campo registrato. Stampa questo QR e attaccalo all'ingresso.</div>{/if}
          <h2 style="font-size:22px">{campo.nome}</h2>
          <p class="sotto">Inquadra per vedere le partite e unirti</p>
          {#if qrDati}
            <img src={qrDati} alt={`QR code del campo ${campo.nome}`} style="width: 240px; height: 240px" />
          {:else}
            <Caricamento />
          {/if}
          <p class="aiuto" style="word-break: break-all">{urlCampo}</p>
          <div class="no-stampa" style="display:flex; gap:10px; width:100%">
            <button type="button" class="btn bianco piccolo" onclick={() => window.print()}><Icona nome="stampa" dimensione={18} /> Stampa</button>
            <button type="button" class="btn bianco piccolo" onclick={condividi}><Icona nome="condividi" dimensione={18} /> Condividi</button>
          </div>
        </div>
      {/if}

      <div class="sezione-titolo no-stampa">Prossime partite qui</div>
      {#if partite.length}
        {#each partite as p, i (p.id)}
          <CardPartita partita={p} evidenziata={i === 0 && p.posizioni.some((x) => x.stato === 'libera')} />
        {/each}
      {:else}
        <div class="vuoto no-stampa">Nessuna partita in programma su questo campo. Organizza tu la prima!</div>
      {/if}

      {#if campo.sponsor_nome}
        <div class="card riga">
          <div class="avatar" style="border-radius:10px; background: var(--sfondo); color: var(--testo-2)"><Icona nome="posizione" dimensione={20} /></div>
          <div class="riempi">
            <div class="nome" style="font-size:14px">{campo.sponsor_testo || campo.sponsor_nome}</div>
            <div class="sotto" style="font-size:12px">Sponsor del campo</div>
          </div>
        </div>
      {/if}

      {#if !auth.utente}
        <p class="aiuto no-stampa" style="text-align:center">Per unirti a una partita o organizzarne una <a href={`/login?next=${encodeURIComponent(`/campo/${id}`)}`}>accedi con la tua email</a>.</p>
      {/if}
    </div>

    <div class="pie-fisso no-stampa">
      <button type="button" class="btn" class:scuro={!perOrganizzare} onclick={organizza}>
        <Icona nome="piu" dimensione={18} spessore={2.4} /> Organizza una partita su questo campo
      </button>
    </div>
  {/if}
</div>

<style>
  @media print {
    :global(#stampa-qr) { box-shadow: none; }
    .intestazione-verde, .pie-fisso { display: none; }
  }
</style>
