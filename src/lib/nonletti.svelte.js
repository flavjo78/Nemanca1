// Messaggi da leggere (numero sull'icona Chat). Il conteggio sta nel database,
// così vale su tutti i dispositivi; si aggiorna da solo quando arriva un messaggio.
import { supabase } from './supabase.js'

export const nonLetti = $state({ totale: 0, perPartita: {} })

let canale = null
let timer = null

export async function aggiornaNonLetti() {
  if (!supabase) return
  const { data, error } = await supabase.rpc('non_letti')
  if (error) return
  const per = {}
  let tot = 0
  for (const r of data ?? []) { per[r.partita_id] = Number(r.quanti); tot += Number(r.quanti) }
  nonLetti.perPartita = per
  nonLetti.totale = tot
}

function presto() { clearTimeout(timer); timer = setTimeout(aggiornaNonLetti, 400) }

/** Da chiamare dopo l'accesso: conta e resta in ascolto dei nuovi messaggi. */
export function avviaNonLetti() {
  aggiornaNonLetti()
  if (canale || !supabase) return
  canale = supabase.channel('non-letti')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messaggi' }, presto)
    .subscribe()
  document.addEventListener('visibilitychange', () => { if (!document.hidden) presto() })
}

export function fermaNonLetti() {
  if (canale) { supabase.removeChannel(canale); canale = null }
  nonLetti.totale = 0; nonLetti.perPartita = {}
}

/** Chat aperta: tutto letto fino ad adesso. */
export async function segnaLettoDb(partitaId) {
  if (!supabase || !partitaId) return
  if (nonLetti.perPartita[partitaId]) {
    nonLetti.totale = Math.max(0, nonLetti.totale - nonLetti.perPartita[partitaId])
    nonLetti.perPartita = { ...nonLetti.perPartita, [partitaId]: 0 }
  }
  await supabase.rpc('segna_letto', { p_partita: partitaId })
}
