<script>
  // "Fai conoscere Ne manca 1": QR dell'app da far inquadrare a un amico, oppure link da mandare.
  import QRCode from 'qrcode'
  import Foglio from './Foglio.svelte'
  import Icona from './Icona.svelte'
  import Logo from './Logo.svelte'

  const URL_APP = 'https://www.nemanca1.com/?da=invito'
  let aperto = $state(false)
  let qr = $state('')
  let avviso = $state('')

  async function apri() {
    avviso = ''
    if (!qr) qr = await QRCode.toDataURL(URL_APP, { width: 640, margin: 1, color: { dark: '#14201A', light: '#FFFFFF' } })
    aperto = true
  }
  async function condividi() {
    const dati = { title: 'Ne manca 1', text: 'Trova chi manca in campo: organizza e unisciti alle partite di calcetto vicino a te.', url: URL_APP }
    if (navigator.share) { try { await navigator.share(dati) } catch { /* annullato */ } }
    else copia()
  }
  async function copia() {
    try { await navigator.clipboard.writeText(URL_APP); avviso = 'Link copiato: incollalo dove vuoi.' } catch { avviso = URL_APP }
  }
</script>

<button type="button" class="card riga invita" onclick={apri}>
  <span class="icona-qr" aria-hidden="true"><Icona nome="qr" dimensione={22} /></span>
  <div class="riempi" style="text-align:left">
    <div class="nome">Fai conoscere Ne manca 1</div>
    <div class="sotto">Il QR dell'app da far inquadrare o da mandare agli amici</div>
  </div>
  <Icona nome="avanti" dimensione={18} />
</button>

<Foglio aperto={aperto} chiudi={() => (aperto = false)}>
  <div class="contenuto-qr">
    <Logo verticale dimensione={24} slogan />
    {#if qr}<img src={qr} alt="QR code dell'app Ne manca 1" />{/if}
    <p class="aiuto">Fai inquadrare questo QR con la fotocamera: si apre l'app, senza scaricare niente.</p>
  </div>
  {#if avviso}<div class="ok" style="word-break: break-all">{avviso}</div>{/if}
  <button type="button" class="btn" onclick={condividi}><Icona nome="condividi" dimensione={18} /> Manda il link</button>
  <button type="button" class="btn bianco" onclick={copia}><Icona nome="link" dimensione={18} /> Copia il link</button>
</Foglio>

<style>
  .invita { gap: 12px; border: none; font: inherit; color: inherit; width: 100%; }
  .icona-qr { width: 44px; height: 44px; border-radius: 12px; background: var(--verde-chiaro); color: var(--verde-scuro); display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; }
  .contenuto-qr { display: flex; flex-direction: column; align-items: center; gap: 12px; text-align: center; }
  .contenuto-qr img { width: min(260px, 70vw); aspect-ratio: 1; }
</style>
