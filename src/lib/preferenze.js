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
