// "Entra come" per l'amministratore: usa l'app come un altro utente (per i test) e poi torna indietro.
// La sessione dell'amministratore resta salvata su questo telefono finché non si torna.
import { supabase } from './supabase.js'

const CHIAVE = 'nm1-sessione-admin'

export function sessioneAdmin() {
  try { return JSON.parse(localStorage.getItem(CHIAVE) || 'null') } catch { return null }
}

async function attendi(richiesta) {
  for (let i = 0; i < 20; i++) {
    await new Promise((r) => setTimeout(r, 600))
    const { data, error } = await supabase.rpc('admin_esito', { p_richiesta: richiesta })
    if (error) throw error
    if (data?.pronto) {
      if (!data.ok) throw new Error(data.errore || 'Richiesta non riuscita')
      return data
    }
  }
  throw new Error('Supabase non ha risposto in tempo. Riprova.')
}

/** Entra come l'utente indicato. */
export async function entraCome(utente) {
  const { data: s } = await supabase.auth.getSession()
  if (!s.session) throw new Error('Sessione non trovata')
  if (!sessioneAdmin()) {
    localStorage.setItem(CHIAVE, JSON.stringify({ access_token: s.session.access_token, refresh_token: s.session.refresh_token, id: s.session.user.id }))
  }
  const { data: richiesta, error } = await supabase.rpc('admin_entra_come', { p_utente: utente.id })
  if (error) throw error
  const esito = await attendi(richiesta)
  if (!esito.codice) throw new Error('Codice di accesso non ricevuto')
  let r = await supabase.auth.verifyOtp({ email: esito.email, token: esito.codice, type: 'email' })
  if (r.error) r = await supabase.auth.verifyOtp({ email: esito.email, token: esito.codice, type: 'magiclink' })
  if (r.error) throw r.error
  try { sessionStorage.setItem('nm1-avvio-visto', '1') } catch {}
  location.href = '/'
}

/** Torna all'account dell'amministratore. */
export async function tornaAdmin() {
  const s = sessioneAdmin()
  if (!s) return
  const { error } = await supabase.auth.setSession({ access_token: s.access_token, refresh_token: s.refresh_token })
  localStorage.removeItem(CHIAVE)
  if (error) { alert('La sessione da amministratore è scaduta: entra di nuovo con il tuo codice.'); await supabase.auth.signOut({ scope: 'local' }) }
  try { sessionStorage.setItem('nm1-avvio-visto', '1') } catch {}
  location.href = '/admin'
}

/** Crea un giocatore di prova e restituisce il suo id. */
export async function creaGiocatoreProva(nome, ruoli = []) {
  const { data: richiesta, error } = await supabase.rpc('admin_crea_prova')
  if (error) throw error
  const esito = await attendi(richiesta)
  const { error: e2 } = await supabase.rpc('admin_imposta_prova', { p_utente: esito.id, p_nome: nome, p_ruoli: ruoli })
  if (e2) throw e2
  return esito.id
}
