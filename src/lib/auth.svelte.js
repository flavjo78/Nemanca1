import { supabase } from './supabase.js'
import { avviaNotifiche, scollegaNotifiche } from './notifiche.svelte.js'

export const auth = $state({
  pronto: false,      // vero quando abbiamo letto la sessione salvata
  utente: null,       // auth.users
  profilo: null       // riga di public.profili
})

export async function caricaProfilo() {
  if (!auth.utente) { auth.profilo = null; return }
  const { data } = await supabase.from('profili').select('*').eq('id', auth.utente.id).maybeSingle()
  if (data) {
    auth.profilo = data
  } else {
    // il trigger lato DB di solito l'ha già creato; nel dubbio lo creiamo noi
    const { data: nuovo } = await supabase.from('profili').upsert({ id: auth.utente.id }).select().single()
    auth.profilo = nuovo ?? { id: auth.utente.id }
  }
}

export async function avviaAuth() {
  if (!supabase) { auth.pronto = true; return }
  const { data } = await supabase.auth.getSession()
  auth.utente = data.session?.user ?? null
  await caricaProfilo()
  auth.pronto = true
  if (auth.utente) avviaNotifiche(auth.utente.id)

  supabase.auth.onAuthStateChange((_evento, sessione) => {
    const nuovoId = sessione?.user?.id ?? null
    if (nuovoId === auth.utente?.id) return
    auth.utente = sessione?.user ?? null
    // non attendere chiamate Supabase dentro il callback
    setTimeout(caricaProfilo, 0)
    if (auth.utente) setTimeout(() => avviaNotifiche(auth.utente.id), 0)
  })
}

export async function esci() {
  await scollegaNotifiche()
  await supabase.auth.signOut()
  auth.utente = null
  auth.profilo = null
}

/** vero se l'utente deve ancora inserire il nome */
export function profiloIncompleto() {
  return auth.utente && auth.profilo && !auth.profilo.nome
}
