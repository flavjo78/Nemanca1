<script>
  // Mappa piccola con un segnaposto da trascinare (o tocca la mappa per spostarlo). Leaflet caricato al bisogno.
  import { onMount, onDestroy } from 'svelte'
  import 'leaflet/dist/leaflet.css'

  let { lat = $bindable(41.9), lng = $bindable(12.5) } = $props()
  let contenitore
  let mappa = null
  let punto = null

  onMount(async () => {
    const L = (await import('leaflet')).default
    mappa = L.map(contenitore, { zoomControl: true }).setView([lat, lng], 16)
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>'
    }).addTo(mappa)
    const icona = L.divIcon({ className: '', html: '<div class="pin"><i></i></div>', iconSize: [36, 44], iconAnchor: [18, 42] })
    punto = L.marker([lat, lng], { draggable: true, icon: icona, keyboard: true, title: 'Posizione del campo' }).addTo(mappa)
    punto.on('dragend', () => { const p = punto.getLatLng(); lat = +p.lat.toFixed(6); lng = +p.lng.toFixed(6) })
    mappa.on('click', (e) => { punto.setLatLng(e.latlng); lat = +e.latlng.lat.toFixed(6); lng = +e.latlng.lng.toFixed(6) })
  })
  // se lat/lng cambiano da fuori (es. "cerca indirizzo"), sposta segnaposto e vista
  $effect(() => {
    if (!punto || !mappa) return
    const p = punto.getLatLng()
    if (Math.abs(p.lat - lat) > 1e-7 || Math.abs(p.lng - lng) > 1e-7) { punto.setLatLng([lat, lng]); mappa.setView([lat, lng], Math.max(mappa.getZoom(), 15)) }
  })
  onDestroy(() => { mappa?.remove(); mappa = null })
</script>

<div class="mappa-punto" bind:this={contenitore} role="application" aria-label="Mappa: trascina il segnaposto sul campo"></div>

<style>
  .mappa-punto { width: 100%; height: 260px; border-radius: 14px; overflow: hidden; background: #e8eee9; z-index: 0; }
  :global(.pin) { width: 36px; height: 36px; border-radius: 50% 50% 50% 0; transform: rotate(-45deg); background: var(--verde); border: 3px solid #fff; box-shadow: 0 2px 6px rgba(0,0,0,.3); display: flex; align-items: center; justify-content: center; }
  :global(.pin i) { width: 10px; height: 10px; border-radius: 50%; background: #fff; display: block; transform: rotate(45deg); }
</style>
