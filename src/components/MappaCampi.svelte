<script>
  // Mappa dei campi (OpenStreetMap + Leaflet). Segnaposto verde = campo, arancio con numero = partite con posti liberi.
  // Leaflet si carica solo quando si apre la mappa, così la pagina resta leggera.
  import { onMount, onDestroy } from 'svelte'
  import 'leaflet/dist/leaflet.css'
  import { naviga } from '../lib/router.svelte.js'
  import { km } from '../lib/formato.js'

  let { campi = [], centro = null, raggioKm = null, organizza = false } = $props()

  let contenitore
  let L = null
  let mappa = null
  let livello = null
  let cerchio = null

  function icona(c) {
    const n = c.partite_aperte ?? 0
    const classe = n > 0 ? 'pin con-partite' : 'pin'
    const testo = n > 0 ? `<span>${n}</span>` : '<i></i>'
    return L.divIcon({ className: '', html: `<div class="${classe}">${testo}</div>`, iconSize: [36, 44], iconAnchor: [18, 42], popupAnchor: [0, -38] })
  }

  function testoSicuro(s) {
    return String(s ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]))
  }

  function disegna() {
    if (!mappa) return
    livello.clearLayers()
    if (cerchio) { cerchio.remove(); cerchio = null }
    const validi = campi.filter((c) => c.lat != null && c.lng != null)
    const haCentro = centro?.lat != null

    // prima si sceglie l'inquadratura (Leaflet vuole la vista pronta prima di disegnare)
    if (haCentro && raggioKm) mappa.fitBounds(L.latLng(centro.lat, centro.lng).toBounds(raggioKm * 2000), { padding: [12, 12], animate: false })
    else if (validi.length > 1) mappa.fitBounds(validi.map((c) => [c.lat, c.lng]), { padding: [36, 36], maxZoom: 15, animate: false })
    else if (validi.length === 1) mappa.setView([validi[0].lat, validi[0].lng], 14, { animate: false })
    else if (haCentro) mappa.setView([centro.lat, centro.lng], 12, { animate: false })
    else mappa.setView([41.9, 12.5], 6, { animate: false }) // Italia

    if (haCentro && raggioKm) {
      cerchio = L.circle([centro.lat, centro.lng], { radius: raggioKm * 1000, color: '#1E7B4E', weight: 1.5, fillColor: '#1E7B4E', fillOpacity: 0.06, interactive: false }).addTo(mappa)
    }
    if (haCentro) {
      L.circleMarker([centro.lat, centro.lng], { radius: 7, color: '#fff', weight: 3, fillColor: '#1E7B4E', fillOpacity: 1, interactive: false }).addTo(livello)
    }
    for (const c of validi) {
      const n = c.partite_aperte ?? 0
      const popup = document.createElement('div')
      popup.className = 'popup-campo'
      popup.innerHTML = `<strong>${testoSicuro(c.nome)}</strong><div>${testoSicuro(c.indirizzo)}${c.distanza_km != null ? ' · ' + km(c.distanza_km) : ''}</div>`
        + `<div class="stato ${n > 0 ? 'si' : ''}">${n > 0 ? `${n} ${n === 1 ? 'partita' : 'partite'} con posti liberi` : 'Nessuna partita aperta'}</div>`
      const bottone = document.createElement('button')
      bottone.type = 'button'
      bottone.textContent = organizza ? 'Organizza qui' : 'Apri il campo'
      bottone.onclick = () => naviga(`/campo/${c.id}${organizza ? '?organizza=1' : ''}`)
      popup.appendChild(bottone)
      L.marker([c.lat, c.lng], { icon: icona(c), title: c.nome, keyboard: true }).bindPopup(popup).addTo(livello)
    }
  }

  onMount(async () => {
    L = (await import('leaflet')).default
    mappa = L.map(contenitore, { zoomControl: true, attributionControl: true })
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>'
    }).addTo(mappa)
    livello = L.layerGroup()
    disegna()
    livello.addTo(mappa)
  })

  $effect(() => {
    // ridisegna quando cambiano campi, centro o raggio
    campi; centro; raggioKm
    disegna()
  })

  onDestroy(() => { mappa?.remove(); mappa = null })
</script>

<div class="mappa" bind:this={contenitore} role="region" aria-label="Mappa dei campi"></div>
<div class="legenda">
  <span><span class="punto"></span> Campo</span>
  <span><span class="punto arancio"></span> Partite con posti liberi</span>
  {#if centro?.lat != null}<span><span class="punto tu"></span> Il tuo comune</span>{/if}
</div>

<style>
  .mappa { width: 100%; height: min(62vh, 520px); border-radius: 16px; overflow: hidden; background: #e8eee9; z-index: 0; }
  .legenda { display: flex; gap: 14px; flex-wrap: wrap; font-size: 12.5px; color: var(--testo-2); }
  .legenda > span { display: inline-flex; align-items: center; gap: 6px; }
  .punto { width: 12px; height: 12px; border-radius: 50%; background: var(--verde); display: inline-block; }
  .punto.arancio { background: #F0B35B; }
  .punto.tu { background: #fff; border: 3px solid var(--verde); width: 10px; height: 10px; }

  :global(.pin) {
    width: 36px; height: 36px; border-radius: 50% 50% 50% 0; transform: rotate(-45deg);
    background: var(--verde); border: 3px solid #fff; box-shadow: 0 2px 6px rgba(0,0,0,.3);
    display: flex; align-items: center; justify-content: center;
  }
  :global(.pin > *) { transform: rotate(45deg); }
  :global(.pin i) { width: 10px; height: 10px; border-radius: 50%; background: #fff; display: block; }
  :global(.pin.con-partite) { background: #F0B35B; }
  :global(.pin span) { color: #14201A; font: 700 14px 'Space Grotesk', sans-serif; }
  :global(.popup-campo) { font-family: Inter, sans-serif; font-size: 13px; color: #5B6B62; min-width: 180px; }
  :global(.popup-campo strong) { display: block; font-size: 15px; color: #14201A; margin-bottom: 2px; }
  :global(.popup-campo .stato) { margin-top: 6px; font-weight: 600; }
  :global(.popup-campo .stato.si) { color: #9A4B0A; }
  :global(.popup-campo button) {
    margin-top: 10px; width: 100%; min-height: 44px; border: none; border-radius: 12px;
    background: #1E7B4E; color: #fff; font: 600 14px Inter, sans-serif; cursor: pointer;
  }
</style>
