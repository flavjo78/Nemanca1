import { dopoAvvio } from './avvio.js'
// Geocoding con Nominatim (OpenStreetMap). Rispettare la policy: max 1 richiesta/secondo.
const BASE = 'https://nominatim.openstreetmap.org'

export async function cercaIndirizzo(testo, limite = 5) {
  const q = testo.trim()
  if (q.length < 3) return []
  const url = `${BASE}/search?format=jsonv2&addressdetails=1&countrycodes=it&limit=${limite}&q=${encodeURIComponent(q)}`
  const r = await fetch(url, { headers: { 'Accept-Language': 'it' } })
  if (!r.ok) throw new Error('Ricerca indirizzo non riuscita')
  const righe = await r.json()
  return righe.map((x) => ({
    etichetta: x.display_name,
    breve: indirizzoBreve(x),
    comune: comuneDa(x.address),
    lat: Number(x.lat),
    lng: Number(x.lon)
  }))
}

export async function cercaComune(testo, limite = 5) {
  const q = testo.trim()
  if (q.length < 2) return []
  const url = `${BASE}/search?format=jsonv2&addressdetails=1&countrycodes=it&limit=${limite}&featureType=settlement&q=${encodeURIComponent(q)}`
  const r = await fetch(url, { headers: { 'Accept-Language': 'it' } })
  if (!r.ok) throw new Error('Ricerca comune non riuscita')
  const righe = await r.json()
  const visti = new Set()
  return righe
    .map((x) => ({ comune: comuneDa(x.address) || x.name, provincia: x.address?.county || x.address?.state || '', lat: Number(x.lat), lng: Number(x.lon) }))
    .filter((x) => { const k = x.comune + x.provincia; if (visti.has(k)) return false; visti.add(k); return true })
}

function comuneDa(a = {}) {
  return a.city || a.town || a.village || a.municipality || a.hamlet || a.county || ''
}

function indirizzoBreve(x) {
  const a = x.address || {}
  const via = [a.road, a.house_number].filter(Boolean).join(' ')
  const c = comuneDa(a)
  return [via || x.name, c].filter(Boolean).join(', ')
}

/** Posizione del telefono (se l'utente la concede). */
export async function posizioneAttuale() {
  await dopoAvvio() // la richiesta "consenti posizione" non deve coprire il video d'apertura
  return new Promise((risolvi, rifiuta) => {
    if (!navigator.geolocation) return rifiuta(new Error('Geolocalizzazione non disponibile'))
    navigator.geolocation.getCurrentPosition(
      (p) => risolvi({ lat: p.coords.latitude, lng: p.coords.longitude }),
      (e) => rifiuta(e),
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 300000 }
    )
  })
}

/** Distanza in km (haversine), uguale alla funzione lato DB. */
export function distanzaKm(lat1, lng1, lat2, lng2) {
  const r = Math.PI / 180
  const a = Math.sin(((lat2 - lat1) * r) / 2) ** 2 +
    Math.cos(lat1 * r) * Math.cos(lat2 * r) * Math.sin(((lng2 - lng1) * r) / 2) ** 2
  return 6371 * 2 * Math.asin(Math.sqrt(a))
}
