<script>
  // Video di apertura (5 s): parte all'avvio dell'app, si ferma sull'ultimo fotogramma (il logo),
  // il logo sfuma e compare la prima schermata. Una volta per apertura dell'app; "Salta" per chi ha fretta.
  import { onMount } from 'svelte'

  const CHIAVE = 'nm1-avvio-visto'
  let mostra = $state((() => { try { return !sessionStorage.getItem(CHIAVE) } catch { return true } })())
  let fase = $state('video') // video → fine (ultimo fotogramma) → sfuma → (rimosso)
  let video = $state(null)
  let timer = null

  function fine() {
    if (fase !== 'video') return
    fase = 'fine'
    clearTimeout(timer)
    setTimeout(() => (fase = 'sfuma'), 450)   // un attimo fermo sul logo
    setTimeout(chiudi, 450 + 900)             // poi sfuma (0,9 s)
  }
  function chiudi() {
    mostra = false
    try { sessionStorage.setItem(CHIAVE, '1') } catch {}
  }

  onMount(() => {
    if (!mostra) return
    const ridotto = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    if (ridotto || !video) { fine(); return }
    timer = setTimeout(fine, 7000) // rete lenta o video bloccato: non si resta mai fermi
    const p = video.play?.()
    if (p?.catch) p.catch(() => fine()) // risparmio energetico o autoplay bloccato
  })
</script>

{#if mostra}
  <div class="avvio" class:sfuma={fase === 'sfuma'} aria-hidden="true">
    <!-- svelte-ignore a11y_media_has_caption -->
    <video bind:this={video} src="/avvio.mp4" poster="/avvio-inizio.jpg" muted playsinline autoplay preload="auto"
           onended={fine} onerror={fine}></video>
    {#if fase !== 'video'}<img class="ultimo" src="/avvio-fine.jpg" alt="" />{/if}
    {#if fase === 'video'}<button type="button" class="salta" onclick={fine}>Salta</button>{/if}
  </div>
{/if}

<style>
  .avvio {
    position: fixed; inset: 0; z-index: 1000; background: #0E1F16;
    display: flex; align-items: center; justify-content: center; overflow: hidden;
    transition: opacity .9s ease, transform .9s ease, filter .9s ease;
  }
  .avvio.sfuma { opacity: 0; transform: scale(1.06); filter: blur(6px); pointer-events: none; }
  /* telefono (schermo verticale): il video riempie tutto, senza bande */
  video, .ultimo { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  /* schermi larghi (computer, tablet in orizzontale): video intero al centro e ai lati la stessa immagine sfocata, niente nero */
  .avvio::before {
    content: ''; position: absolute; inset: -40px; background: url('/avvio-fine.jpg') center / cover no-repeat;
    filter: blur(28px) brightness(.55);
  }
  @media (min-aspect-ratio: 3/4) {
    video, .ultimo { object-fit: contain; }
  }
  .salta {
    position: absolute; right: 16px; bottom: calc(20px + env(safe-area-inset-bottom, 0px));
    min-height: 44px; padding: 0 18px; border-radius: 22px; border: 1px solid rgba(255,255,255,.35);
    background: rgba(0,0,0,.25); color: #fff; font: 600 14px Inter, sans-serif; backdrop-filter: blur(4px);
  }
</style>
