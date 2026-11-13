<script>
  // Scheda "Metti Ne manca 1 sulla schermata Home": un tocco su Android/computer, istruzioni su iPhone.
  import { installa, installaOra } from '../lib/installa.svelte.js'
  import Foglio from './Foglio.svelte'

  let { chiudibile = false } = $props()
  const CHIAVE = 'nm1-installa-chiuso'
  let chiuso = $state((() => { try { return Date.now() - Number(localStorage.getItem(CHIAVE) || 0) < 14 * 86400000 } catch { return false } })())
  let guida = $state(false)

  const visibile = $derived(!installa.installata && (installa.possibile || installa.ios || !chiudibile) && !(chiudibile && chiuso))

  async function tocca() {
    if (installa.possibile) { await installaOra(); return }
    guida = true
  }
  function chiudi() { chiuso = true; try { localStorage.setItem(CHIAVE, String(Date.now())) } catch {} }
</script>

{#if visibile}
  <div class="card riga installa">
    <img src="/icona-192.png" alt="" width="44" height="44" style="border-radius:12px; flex:0 0 auto" />
    <div class="riempi">
      <div class="nome">Metti l'app sulla schermata Home</div>
      <div class="sotto">Si apre con un tocco, a schermo intero, come un'app vera</div>
    </div>
    <button type="button" class="btn piccolo" style="width:auto; flex:0 0 auto" onclick={tocca}>{installa.possibile ? 'Installa' : 'Come si fa'}</button>
    {#if chiudibile}<button type="button" class="chiudi" aria-label="Non ora" onclick={chiudi}>×</button>{/if}
  </div>
{/if}

<Foglio aperto={guida} titolo="Aggiungi alla schermata Home" chiudi={() => (guida = false)}>
  {#if installa.ios}
    <ol class="passi">
      <li>Apri <strong>www.nemanca1.com</strong> con <strong>Safari</strong>.</li>
      <li>Tocca il tasto <strong>Condividi</strong> (il quadrato con la freccia verso l'alto, in basso al centro).</li>
      <li>Scorri e tocca <strong>Aggiungi alla schermata Home</strong>.</li>
      <li>Tocca <strong>Aggiungi</strong> in alto a destra.</li>
    </ol>
    <p class="aiuto">Su iPhone le notifiche arrivano solo all'app aggiunta alla schermata Home.</p>
  {:else}
    <ol class="passi">
      <li>Apri <strong>www.nemanca1.com</strong> con <strong>Chrome</strong>.</li>
      <li>Tocca il menu <strong>⋮</strong> in alto a destra.</li>
      <li>Tocca <strong>Installa app</strong> (o <strong>Aggiungi a schermata Home</strong>) e conferma.</li>
    </ol>
    <p class="aiuto">Sul computer: in Chrome o Edge c'è l'icona di installazione nella barra dell'indirizzo.</p>
  {/if}
</Foglio>

<style>
  .installa { gap: 12px; position: relative; }
  .chiudi { position: absolute; top: 2px; right: 6px; background: none; border: none; font-size: 20px; color: var(--testo-2); width: 32px; height: 32px; }
  .passi { margin: 0; padding-left: 22px; display: flex; flex-direction: column; gap: 10px; font-size: 15px; line-height: 1.4; }
</style>
