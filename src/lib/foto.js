// Foto del giocatore: qualsiasi foto del telefono (anche HEIC dell'iPhone) diventa
// un quadrato di 320 px leggerissimo (WebP o JPEG, di solito 10-25 KB) prima del caricamento.
import { supabase } from './supabase.js'
import { auth } from './auth.svelte.js'

const LATO = 320

function eHeic(file) {
  return /image\/hei[cf]/i.test(file.type) || /\.(heic|heif)$/i.test(file.name || '')
}

async function decodifica(file) {
  // 1) via veloce: il browser sa leggere il formato (iPhone legge anche HEIC)
  try { return await createImageBitmap(file) } catch { /* proviamo altro */ }
  try { return await caricaImmagine(file) } catch { /* proviamo altro */ }
  // 2) HEIC su Android o computer: conversione con heic2any (caricato solo se serve)
  if (eHeic(file)) {
    const heic2any = (await import('heic2any')).default
    const jpeg = await heic2any({ blob: file, toType: 'image/jpeg', quality: 0.9 })
    const blob = Array.isArray(jpeg) ? jpeg[0] : jpeg
    try { return await createImageBitmap(blob) } catch { return await caricaImmagine(blob) }
  }
  throw new Error('formato')
}

function caricaImmagine(blob) {
  return new Promise((risolvi, rifiuta) => {
    const url = URL.createObjectURL(blob)
    const img = new Image()
    img.onload = () => { URL.revokeObjectURL(url); risolvi(img) }
    img.onerror = () => { URL.revokeObjectURL(url); rifiuta(new Error('formato')) }
    img.src = url
  })
}

function versoBlob(canvas, tipo, qualita) {
  return new Promise((risolvi) => canvas.toBlob(risolvi, tipo, qualita))
}

/** Riduce la foto a un quadrato di 320 px (ritaglio centrale). Restituisce { blob, tipo, estensione }. */
export async function riduciFoto(file) {
  const img = await decodifica(file)
  const w = img.width, h = img.height
  const lato = Math.min(w, h)
  const canvas = document.createElement('canvas')
  canvas.width = LATO; canvas.height = LATO
  const ctx = canvas.getContext('2d')
  ctx.imageSmoothingQuality = 'high'
  ctx.drawImage(img, (w - lato) / 2, (h - lato) / 2, lato, lato, 0, 0, LATO, LATO)
  img.close?.()
  let blob = await versoBlob(canvas, 'image/webp', 0.8)
  if (blob && blob.type === 'image/webp') return { blob, tipo: 'image/webp', estensione: 'webp' }
  // Safari non sa salvare in WebP: JPEG
  blob = await versoBlob(canvas, 'image/jpeg', 0.8)
  return { blob, tipo: 'image/jpeg', estensione: 'jpg' }
}

function percorsoDa(url) {
  const m = /\/storage\/v1\/object\/public\/foto\/(.+)$/.exec(url || '')
  return m ? decodeURIComponent(m[1]) : null
}

/** Riduce, carica e salva la foto nel profilo. */
export async function caricaFoto(file) {
  const { blob, tipo, estensione } = await riduciFoto(file)
  const uid = auth.utente.id
  const percorso = `${uid}/${Date.now()}.${estensione}`
  const { error } = await supabase.storage.from('foto').upload(percorso, blob, { contentType: tipo, cacheControl: '31536000', upsert: false })
  if (error) throw error
  const { data } = supabase.storage.from('foto').getPublicUrl(percorso)
  const vecchia = percorsoDa(auth.profilo?.foto_url)
  const { error: e2 } = await supabase.from('profili').update({ foto_url: data.publicUrl }).eq('id', uid)
  if (e2) throw e2
  auth.profilo = { ...auth.profilo, foto_url: data.publicUrl }
  if (vecchia) supabase.storage.from('foto').remove([vecchia]).catch(() => {})
  return { url: data.publicUrl, peso: blob.size }
}

export async function togliFoto() {
  const vecchia = percorsoDa(auth.profilo?.foto_url)
  const { error } = await supabase.from('profili').update({ foto_url: null }).eq('id', auth.utente.id)
  if (error) throw error
  auth.profilo = { ...auth.profilo, foto_url: null }
  if (vecchia) supabase.storage.from('foto').remove([vecchia]).catch(() => {})
}
