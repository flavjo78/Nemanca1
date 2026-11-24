<script>
  // QR del campo da stampare (A4 o adesivo). Lo può stampare chi è al campo (entro 500 m, GPS) e sempre l'amministratore.
  // Spazio per lo sponsor facoltativo. "Stampa" apre la stampa del telefono/computer (da lì anche "Salva come PDF").
  import { onMount } from 'svelte'
  import QRCode from 'qrcode'
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { naviga } from '../lib/router.svelte.js'
  import { posizioneAttuale, distanzaKm } from '../lib/geo.js'
  import Logo from '../components/Logo.svelte'
  import Icona from '../components/Icona.svelte'
  import Caricamento from '../components/Caricamento.svelte'

  let { id } = $props()
  const DISTANZA_MAX_KM = 0.5

  let campo = $state(null)
  let qr = $state('')
  let stato = $state('carico') // carico | verifico | ok | lontano | senza_gps | errore
  let distanza = $state(null)
  let formato = $state('a4')    // a4 | adesivo
  let conSponsor = $state(false)
  const url = $derived(`${window.location.origin}/campo/${id}?qr=1`)

  onMount(async () => {
    const { data, error } = await supabase.from('campi').select('id, nome, indirizzo, lat, lng, sponsor_nome, sponsor_testo').eq('id', id).maybeSingle()
    if (error || !data) { stato = 'errore'; return }
    campo = data
    conSponsor = !!(data.sponsor_nome || data.sponsor_testo)
    qr = await QRCode.toDataURL(url, { width: 900, margin: 1, errorCorrectionLevel: 'M', color: { dark: '#14201A', light: '#FFFFFF' } })
    if (auth.profilo?.admin) { stato = 'ok'; return }
    await verifica()
  })

  async function verifica() {
    stato = 'verifico'
    try {
      const { lat, lng } = await posizioneAttuale()
      distanza = distanzaKm(lat, lng, campo.lat, campo.lng)
      stato = distanza <= DISTANZA_MAX_KM ? 'ok' : 'lontano'
    } catch { stato = 'senza_gps' }
  }
</script>

<div class="pagina">
  <header class="intestazione no-stampa">
    <button type="button" class="btn-tondo" aria-label="Indietro" onclick={() => history.length > 1 ? history.back() : naviga(`/campo/${id}`)}><Icona nome="indietro" /></button>
    <div class="centro"><h1 style="font-size:24px">QR da stampare</h1><div class="sotto">{campo?.nome ?? ''}</div></div>
  </header>

  <div class="contenuto">
    {#if stato === 'carico' || stato === 'verifico'}
      <Caricamento />
      {#if stato === 'verifico'}<p class="aiuto" style="text-align:center">Controllo di essere al campo…</p>{/if}
    {:else if stato === 'errore'}
      <div class="errore">Campo non trovato.</div>
    {:else if stato === 'lontano' || stato === 'senza_gps'}
      <div class="card" style="gap:10px">
        <div class="nome">Il QR si stampa quando sei al campo</div>
        <p class="sotto">{stato === 'lontano'
          ? `Sei a circa ${distanza < 10 ? distanza.toFixed(1).replace('.', ',') : Math.round(distanza)} km dal campo: per stampare il QR devi essere lì (entro 500 m).`
          : 'Non riesco a leggere la posizione del telefono. Consenti la posizione e riprova quando sei al campo.'}</p>
        <button type="button" class="btn" onclick={verifica}>Riprova</button>
      </div>
    {:else}
      <div class="comandi no-stampa">
        <div class="scelte">
          <button type="button" class="scelta" class:attiva={formato === 'a4'} onclick={() => (formato = 'a4')}>Foglio A4</button>
          <button type="button" class="scelta" class:attiva={formato === 'adesivo'} onclick={() => (formato = 'adesivo')}>Adesivo 10×10</button>
        </div>
        <label class="spunta"><input type="checkbox" bind:checked={conSponsor} /> Spazio per lo sponsor</label>
        <button type="button" class="btn" onclick={() => window.print()}><Icona nome="stampa" dimensione={18} /> Stampa o salva PDF</button>
        <p class="aiuto">Consiglio: plastificalo o mettilo in una bacheca. Sotto vedi come verrà.</p>
      </div>

      <div class="foglio {formato}">
        {#if formato === 'a4'}
          <div class="testa"><Logo verticale dimensione={34} slogan /></div>
          <div class="nome-campo">{campo.nome}</div>
          <img class="qr" src={qr} alt={`QR del campo ${campo.nome}`} />
          <ol class="passi">
            <li><b>Inquadra</b> con la fotocamera</li>
            <li><b>Guarda</b> le partite di questo campo con i posti liberi</li>
            <li><b>Entra in squadra</b> o organizza la tua partita</li>
          </ol>
          <div class="indirizzo">www.nemanca1.com</div>
          {#if conSponsor}
            <div class="sponsor">
              {#if campo.sponsor_nome || campo.sponsor_testo}
                <span class="eti">Con il sostegno di</span>
                <b>{campo.sponsor_nome ?? ''}</b>
                {#if campo.sponsor_testo}<span>{campo.sponsor_testo}</span>{/if}
              {:else}
                <span class="eti">Spazio sponsor</span>
              {/if}
            </div>
          {/if}
        {:else}
          <div class="riga-adesivo"><Logo dimensione={16} /></div>
          <img class="qr" src={qr} alt={`QR del campo ${campo.nome}`} />
          <div class="nome-campo">{campo.nome}</div>
          <div class="piccolo">Inquadra · trova chi manca in campo</div>
          {#if conSponsor && (campo.sponsor_nome || campo.sponsor_testo)}<div class="piccolo"><b>{campo.sponsor_nome ?? campo.sponsor_testo}</b></div>{/if}
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .comandi { display: flex; flex-direction: column; gap: 10px; }
  .spunta { display: flex; align-items: center; gap: 10px; min-height: 44px; font-size: 15px; }
  .spunta input { width: 22px; height: 22px; accent-color: var(--verde); }

  /* anteprima a schermo */
  .foglio { background: #fff; color: #14201A; margin: 8px auto 24px; box-shadow: 0 2px 12px rgba(0,0,0,.12); display: flex; flex-direction: column; align-items: center; text-align: center; }
  .foglio.a4 { width: 100%; max-width: 420px; aspect-ratio: 210 / 297; padding: 6% 7%; gap: 3.2%; border-radius: 6px; }
  .foglio.adesivo { width: 260px; aspect-ratio: 1; padding: 12px; gap: 6px; border-radius: 14px; border: 2px dashed #BFE3CC; }
  .testa { margin-bottom: 2%; }
  .nome-campo { font-family: var(--font-titoli); font-weight: 700; font-size: 22px; line-height: 1.15; }
  .a4 .qr { width: 58%; aspect-ratio: 1; }
  .adesivo .qr { width: 62%; aspect-ratio: 1; }
  .adesivo .nome-campo { font-size: 14px; }
  .passi { text-align: left; margin: 0; padding-left: 1.3em; font-size: 14px; line-height: 1.5; }
  .indirizzo { font-weight: 700; color: #1E7B4E; font-size: 15px; letter-spacing: .02em; }
  .sponsor { margin-top: auto; width: 100%; border: 2px dashed #BFE3CC; border-radius: 12px; padding: 10px; display: flex; flex-direction: column; gap: 2px; font-size: 13px; min-height: 56px; justify-content: center; }
  .sponsor .eti { font-size: 11px; text-transform: uppercase; letter-spacing: .1em; color: #5B6B62; }
  .piccolo { font-size: 11px; color: #5B6B62; }

  @media print {
    @page { size: A4; margin: 0; }
    :global(body) { background: #fff !important; }
    :global(.cornice), :global(.pagina) { max-width: none !important; width: auto !important; padding: 0 !important; margin: 0 !important; }
    :global(.barra-inferiore), :global(.barra) { display: none !important; }
    .contenuto { padding: 0 !important; }
    .foglio { box-shadow: none; margin: 0 auto; }
    .foglio { box-sizing: border-box; }
    .foglio.a4 { width: 210mm; max-width: none; height: 297mm; aspect-ratio: auto; padding: 16mm 20mm; gap: 7mm; border-radius: 0; }
    .foglio.a4 .testa { zoom: 1.6; }
    .foglio.a4 .nome-campo { font-size: 30pt; }
    .foglio.a4 .qr { width: 110mm; }
    .foglio.a4 .passi { font-size: 15pt; }
    .foglio.a4 .indirizzo { font-size: 16pt; }
    .foglio.adesivo { width: 100mm; height: 100mm; margin: 15mm auto; }
  }
</style>
