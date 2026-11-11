import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const chiave = import.meta.env.VITE_SUPABASE_ANON_KEY

/** vero se il file .env contiene URL e chiave di Supabase */
export const supabaseConfigurato = Boolean(url && chiave && url.startsWith('http'))

export const supabase = supabaseConfigurato
  ? createClient(url, chiave, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } })
  : null
