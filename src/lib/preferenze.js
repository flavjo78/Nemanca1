// Preferenze del giocatore salvate subito nel profilo (raggio in km, "Cercami per le partite")
import { supabase } from './supabase.js'
import { auth } from './auth.svelte.js'

export const RAGGI_RAPIDI = [5, 10, 20, 30, 50]

export function raggioAttuale() { return auth.profilo?.raggio_km ?? 20 }

async function salva(campi) {
  const { error } = await supabase.from('profili').update(campi).eq('id', auth.utente.id)
  if (error) throw error
  auth.profilo = { ...auth.profilo, ...campi }
}

export function salvaRaggio(km) { return salva({ raggio_km: Math.min(100, Math.max(1, Math.round(km))) }) }
export function salvaCercami(si) { return salva({ cercami: !!si }) }
export function salvaAvvisi({ ruoli, dalle, alle }) {
  return salva({ avvisi_ruoli: ruoli === 'tutti' ? 'tutti' : 'miei', avvisi_dalle: dalle, avvisi_alle: alle })
}
export function salvaComune(c) {
  return salva(c ? { comune: c.comune, lat: c.lat, lng: c.lng, da_posizione: false } : { comune: null, lat: null, lng: null, da_posizione: false })
}
/** "Da questa posizione": il punto del telefono arrotondato a ~1 km (per la privacy); il comune serve solo da etichetta. */
export function salvaPosizione(lat, lng, comune) {
  const tondo = (x) => Math.round(x * 100) / 100
  return salva({ lat: tondo(lat), lng: tondo(lng), comune: comune || null, da_posizione: true })
}
