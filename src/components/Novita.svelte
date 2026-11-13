<script>
  // Riquadro "Novità" alla prima apertura dopo un aggiornamento + avviso "nuova versione disponibile".
  import Foglio from './Foglio.svelte'
  import { auth } from '../lib/auth.svelte.js'
  import { novitaDaMostrare, segnaViste, ultimaVista, NOVITA } from '../lib/novita.js'
  import { aggiornamento, ricarica } from '../lib/aggiornamento.svelte.js'

  let { apriSempre = false, chiudiFuori = null } = $props()
  let aperto = $state(false)
  let elenco = $state([])

  $effect(() => {
    if (apriSempre) { elenco = NOVITA.slice(0, 3); aperto = true; return }
    if (!auth.utente || !auth.profilo?.nome) return
    // chi si è appena iscritto non ha "novità": parte già aggiornato
    const nuovo = auth.profilo?.creato_il && Date.now() - new Date(auth.profilo.creato_il).getTime() < 24 * 3600 * 1000
    if (!ultimaVista() && nuovo) { segnaViste(); return }
    const da = novitaDaMostrare()
    if (da.length) { elenco = da.slice(0, 3); aperto = true }
  })

  function chiudi() { aperto = false; if (!apriSempre) segnaViste(); chiudiFuori?.() }
</script>

{#if aggiornamento.disponibile}
  <button type="button" class="nuova-versione" onclick={ricarica}>È disponibile una versione nuova: <strong>tocca per aggiornare</strong></button>
{/if}

<Foglio aperto={aperto} titolo={elenco[0]?.titolo ?? 'Novità'} chiudi={chiudi}>
  {#each elenco as n (n.id)}
    <ul class="punti">
      {#each n.punti as p}<li>{p}</li>{/each}
    </ul>
  {/each}
  <button type="button" class="btn" onclick={chiudi}>Ho capito</button>
</Foglio>

<style>
  .punti { margin: 0; padding-left: 20px; display: flex; flex-direction: column; gap: 8px; font-size: 15px; line-height: 1.4; }
  .nuova-versione {
    position: fixed; left: 12px; right: 12px; top: calc(10px + env(safe-area-inset-top, 0px)); z-index: 60;
    max-width: 616px; margin: 0 auto; min-height: 48px; border: none; border-radius: 14px;
    background: var(--testo); color: #fff; font: 500 14px Inter, sans-serif; box-shadow: 0 4px 16px rgba(0,0,0,.2);
  }
</style>
